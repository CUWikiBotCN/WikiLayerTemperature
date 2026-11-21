# 数据源：TemperatureMonitor 插件

本仓库的输入来自 BepInEx 插件 `TemperatureMonitor.dll`（位于游戏目录 `BepInEx/plugins/Testing Mods/`）。
它把游戏里的温度曲线导成 JSON。本文记录它做了什么、以及为什么本仓库只采信其中的关键帧部分。

## 它怎么拿到数据

插件是一个 BepInEx `BaseUnityPlugin`，本身不修改游戏逻辑，全部通过反射读取：

1. `Awake` 注册配置项 `General/ToggleWindowKey`（默认 `KeyCode` 287 = F6）并打日志。
2. 第一次按 F6 打开窗口时执行 `CacheReflection`：遍历 `AppDomain.CurrentDomain.GetAssemblies()`，
   按类型名找 `WorldGeneration` 与 `PlayerCamera`，再按**字段名**取 `FieldInfo`。

   读取的字段：

   | 类型 | 字段 |
   | --- | --- |
   | `WorldGeneration` | `world`、`ambientTemperature`、`temperatureOffset`、`bonusTemperatureOffset`、`temperatureCurves`、`biomeDepth`、`currentTempCurve`、`maxTimePerLayer`、`layerTimeSpent`、`biomeTitles` |
   | `PlayerCamera` | `main`、`body` |

3. 当前曲线 = `temperatureCurves[currentTempCurve]`，取不到时回退 `biomeDepth`。
4. 窗口里的 Ambient 值 = `curve.Evaluate(进入该地层的时间) + temperatureOffset + bonusTemperatureOffset`，
   与 `环境温度` 页面的公式一致；同时显示体温、场景时间、地层时间 / `maxTimePerLayer`（超时标 OVERDUE）。
5. 导出的采样与关键帧来自同一个 `AnimationCurve` 对象，`Evaluate` 由 Unity 本体执行。

## 导出文件结构

```json
{
  "exportTime": "2026-11-22 00:13:26",
  "sampleCount": 100,
  "layers": [
    {
      "layer": 3, "title": "辐射废土", "keyframeCount": 17,
      "preWrapMode": "PingPong", "postWrapMode": "PingPong",
      "keyframes": [ { "time": 16.1, "value": 31.5, "inTangent": -0.028, "outTangent": -0.028,
                       "inWeight": 0.333, "outWeight": 0.333 }, ... ],
      "samples": { "count": 100, "cycleType": "PingPong",
                   "timeStart": 16.1, "timeEnd": 1790.97,
                   "data": [ { "t": 16.1, "v": 31.5 }, ... ] }
    }
  ]
}
```

写入位置是 `Application.persistentDataPath`（Windows 上一般在 `%USERPROFILE%\AppData\LocalLow\<厂商>\Casualties Unknown\`），
文件名为 `TempCurves_All_<yyyyMMdd_HHmmss>.json` 或 `TempCurve_Layer<序号>_<时间戳>.json`。

## 采样块的问题

这些问题不影响本仓库（我们只用 `keyframes` + 两个 wrap 模式，`samples` 仅用于交叉验证），但值得记录，
因为把 `samples` 当数据源的下游会踩到：

1. **`count` 比实际点数少一。** 生成循环是 `for (i = 0; i <= count; i++)`，写出 `count + 1` 个点，
   但字段仍写 `count`。当前样例：`"count": 100`，`data` 长度 101。
2. **不覆盖进入地层的头几秒。** `timeStart` 取的是首个关键帧的时间（干旱沙漠 / 辐射废土 / 深林丛渊 16.10 s、
   地热喷口 1.65 s），所以 `[0, timeStart)` 这段完全不在采样里；而游戏里这段是由 `preWrapMode` 折返出来的，
   数值与首帧并不相同（干旱沙漠 `Evaluate(0) = 31.25`，首帧 30.90）。
3. **均匀采样抹掉尖峰。** 采样间隔 = 周期 / count。默认 100 段时，辐射废土的间隔约 18 秒，
   而它在 251.8 s 处 9 秒内从 25.8 °C 掉到 −19.55 °C——谷底很可能整段跳过。
4. **`cycleType` 只看 `postWrapMode`。** 恒定曲线（ClampForever）也会给 `timeStart/timeEnd`，容易被读成一个周期。
5. **出口文件名只有秒级时间戳。** 同一秒导出两次会静默覆盖前者。
6. **没有稳定的 id 字段。** 只有 `layer` 下标和 `title`；`title` 来自 `biomeTitles`，带空格甚至换行
   （样例里有一层是 `"地球\n某个实验室..."`）。所以本仓库用 `data/layers.json` 按下标建立 id 映射。
7. **`NaN` / `Infinity` 直接写进 JSON。** 数值格式化对非有限值有特判，输出裸的 `NaN`、`Infinity`，不是合法 JSON。

## 插件本身的鲁棒性

- **全靠字段名。** 游戏更新改名或改类型时，反射拿不到字段，只打一行 `Failed to cache reflection: ...` 日志，
  界面照常打开但没有数据。没有版本校验，也没有"字段缺失"的显式报错。
- **首次反射要扫全部程序集**，在打开的瞬间有一次额外开销。
- **导出在主线程的 OnGUI 里做**，采样数上限 100000；数字填大了会明显卡帧。
- 只读，不改游戏状态；导出的曲线就是当前 `AnimationCurve` 对象本身，不存在二次加工。

## 对本仓库的意义

- 输入只需要 `keyframes` 与 `preWrapMode` / `postWrapMode`，这三样是插件机械导出的原始值，可信度高。
- `samples` 只用来验证我们复刻的求值是否与 Unity 一致（`verify` / `luatest`，当前偏差 5e-5 °C 量级）。
- `title` 只做一致性提示，不做主键。
- 切线权重（`inWeight` / `outWeight`）导出但不参与求值，见 [curve-semantics.md](curve-semantics.md)。
