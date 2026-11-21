# 曲线语义

游戏里的环境温度来自 `WorldGeneration.temperatureCurves`：一个 `AnimationCurve[]`，按当前地层取下标。
Unity 的 `AnimationCurve.Evaluate(t)` 就是本仓库 `wikilayertemp/curve.py` 和 `lua/runtime/api.lua` 实现的算法。

## 插值

两个关键帧 `a`、`b` 之间（`dt = b.time - a.time`，`u = (t - a.time) / dt`）：

```
h00 = 2u³ - 3u² + 1
h10 = u³ - 2u² + u
h01 = -2u³ + 3u²
h11 = u³ - u²
v(t) = h00·a.value + h10·a.outTangent·dt + h01·b.value + h11·b.inTangent·dt
```

切线单位是 °C/秒，所以乘 `dt` 换成整段的位移量。导数同理，除以 `dt` 换回 °C/秒：

```
v'(t) = (dh00·a.value + dh10·a.outTangent·dt + dh01·b.value + dh11·b.inTangent·dt) / dt
```

## 卷绕模式

`preWrapMode` / `postWrapMode` 决定关键帧区间之外怎么取值。区间是 `[t0, t1] = [首帧时间, 末帧时间]`。

| 模式 | 区间外行为 | 周期 |
| --- | --- | --- |
| `PingPong` | 以端点为轴折返，像乒乓 | `2·(t1 - t0)` |
| `Loop` | 平移重复 | `t1 - t0` |
| `ClampForever` | 停在端点值 | 无 |
| `Once` / `Default` | 按钳制处理 | 无 |

站内 12 层里，10 层是 `PingPong/PingPong`，猩红长阶是 `Loop/Loop`，必须抵达之地与地球是 `ClampForever/ClampForever`。

**注意 `t0 > 0` 的情况。** 干旱沙漠、辐射废土、深林丛渊的首帧在 16.10 s，地热喷口在 1.65 s。
进入地层后的头十几秒落在区间左侧，由 `preWrapMode` 决定：这里是 `PingPong`，所以取值等于把时间镜像到 `2·t0 - t` 后再求值。
以干旱沙漠为例，`Evaluate(0) = 31.25 °C`，而首帧是 30.90 °C——两者并不相等。

## 极值会过冲出关键帧的范围

三次埃尔米特不保证单调。切线方向与后续走向相反时会过冲，所以**极值不一定落在关键帧上**，也不能拿关键帧的 min/max 当曲线极值。

实测（`data/build-report.json`）：

| 层 | 关键帧 min/max | 曲线真实 min/max |
| --- | --- | --- |
| 深林丛渊 | 18.12 / 31.50 | **5.63** / 31.50 |
| 干旱沙漠 | 12.92 / 32.74 | 12.44 / **35.65** |
| 辐射废土 | −19.55 / 38.64 | −19.55 / 38.64 |

生成数据里的 `minTemp` / `maxTemp` / `minAt` / `maxAt` 是扫描一个完整周期得到的，不是从关键帧直接取的。

## 切线权重（inWeight / outWeight）

关键帧上还存了 `inWeight` / `outWeight`，Unity 编辑器里用于"权重切线"。直觉上它们会影响求值，**但这批资产上不会**：

用插件导出的 101 个采样点（由 Unity 自己的 `Evaluate` 生成）做基准，对比两种实现：

| 实现 | 12 层的最大偏差 |
| --- | --- |
| 直接使用原始切线（本仓库） | 0.00005 °C |
| 按 `3·weight` 缩放切线 | 最高 11.6 °C（深林丛渊） |

也就是说，至少对这 12 条曲线，`Evaluate` 等价于"按原始切线做埃尔米特、忽略权重"。
两种实现的差距远大于采样精度，不存在"都能对上"的可能。

因此本仓库不处理权重字段。若以后游戏改用真正的权重切线，`verify` 会立刻失败（偏差超过 0.01 °C），届时再补。

## 为什么只存关键帧

- 12 层合计 60 个关键帧 vs 采样成 3612 个点；
- 关键帧能与游戏资源一一对应（可核对），采样点只能靠脚本比对；
- 折线图与横向表格都能从同一份关键帧派生，不会再出现两份数据互相矛盾；
- 采样密度、折返原点、开头几秒这些口径问题，从"重新生成一遍"变成"改一行参数"。
