# WikiLayerTemperature

把游戏里各地层的环境温度曲线，从插件导出的原始 JSON 编译成《未知伤亡》中文维基使用的 Lua 数据模块。

产出的模块页是 `Module:Data/Layer_Temperature`，供 `{{地层温度|<id>}}` 一系的模板读取。

```
TempCurves_All_*.json   ──build──►   Module_Data_Layer_Temperature.lua   ──上传──►   Module:Data/Layer_Temperature
     （插件导出）                      （关键帧 + 查询接口）                        （wiki 页面）
```

## 为什么不是直接存采样点

旧做法是把曲线按固定间隔采样成 300 个点写进 Lua。这样存的是**生成器的输出**，不是游戏里的事实：

- 改采样密度、改折返原点、补上开头几秒，都得整表重生成并逐点复核；
- 同一批曲线被采样了两份（折线图一份、横向表格一份），两份会各自漂移——站内已经出现过表格数据与折线数据矛盾的情况；
- 采样间隔一粗，尖峰就被抹掉。例如辐射废土在 251.8 s 处 9 秒内从 25.8 °C 掉到 −19.55 °C，100 段均匀采样（每段 18 秒）根本取不到谷底。

本仓库只存**原始关键帧**（12 层合计 60 个），温度由三次埃尔米特插值 + 卷绕模式现算。
数据量从 3612 个数降到 60 个，且与游戏里的 `AnimationCurve` 一一对应。

## 快速开始

```bash
# 生成 Lua 模块 + 构建报告
python3 -m wikilayertemp build

# 只用插件导出的采样点校验算法（不需要 Lua 环境）
python3 -m wikilayertemp verify

# 用 luajit 实跑生成的模块，和 Python 参考实现逐点比对
python3 -m wikilayertemp luatest

# 单元测试（需要 pytest）
uv run --with pytest pytest -q
```

`build` 会写出：

| 路径 | 内容 |
| --- | --- |
| `lua/generated/Module_Data_Layer_Temperature.lua` | 待上传的模块页全文 |
| `data/build-report.json` | 每层的关键帧数、周期、极值、与采样点的偏差、告警 |

## 目录

```
data/
  raw/TempCurves_All_20261122_001326.json   插件导出的原始数据（冻结的一份，供复现）
  layers.json                                层序号 → id / 中文名 / 英文名
  build-report.json                          最近一次构建的报告
lua/
  runtime/api.lua                            运行时（求值、采样、表格行），与 data 表拼接
  generated/Module_Data_Layer_Temperature.lua 生成物（上传用）
  wiki/                                      两个展示模块的源码（对应 wiki 页面）
wikilayertemp/
  curve.py    曲线模型：埃尔米特求值、卷绕、扫描极值
  sources.py  读取原始 JSON 与映射表、字段校验
  lua.py      渲染 Lua 文本
  cli.py      build / verify / luatest
tests/
docs/
```

## 数据契约

生成的模块里，每层是一条记录：

```lua
{
    id = "wasteland", cn = "辐射废土", en = "Wasteland", layer = 3,
    preWrap = "PingPong", postWrap = "PingPong",
    period = 1774.87, minTemp = -19.554, maxTemp = 38.644,
    minAt = 251.83, maxAt = 828.14,
    keys = {          -- { 时间(秒), 温度(°C), 入切线, 出切线 }
        { 16.1047, 31.5, -0.0282, -0.0282 },
        ...
    },
}
```

对外接口（`lua/runtime/api.lua`）：

| 函数 | 说明 |
| --- | --- |
| `get(name)` | 按 id / 中文名 / 英文名取记录，大小写与空格不敏感 |
| `eval(name, t)` | 第 t 秒的温度（°C），已按卷绕模式折返 |
| `derivative(name, t)` / `rate(name, t)` | 变化率，°C/秒 与 °C/分钟 |
| `period(name)` / `period_label(name)` | 周期秒数与 `M:SS` 文本；恒定曲线返回 nil |
| `series(name, {count=240})` | 折线图采样，返回 `{ {t, 温度}, ... }` |
| `rows(name, {max_gap=...})` | 表格行，按关键帧 + 折返点 + 段内补点生成 |
| `all()` | 全部记录 |

## 游戏更新后怎么重录

1. 进游戏，按 F6 打开监控窗口，点 **Export All Layers**；
2. 在 `%USERPROFILE%\AppData\LocalLow\<厂商>\Casualties Unknown\`（即 Unity 的 persistentDataPath）取走 `TempCurves_All_*.json`；
3. 放进 `data/raw/`，改 `data/layers.json`（如果新增了地层），然后：

```bash
python3 -m wikilayertemp build && python3 -m wikilayertemp verify && python3 -m wikilayertemp luatest
```

4. 用 wiki 侧的页面同步工具上传 `lua/generated/Module_Data_Layer_Temperature.lua`。

构建会自己检查：关键帧时间是否严格递增、切线是否有限值、导出标题与映射表是否一致、与插件采样点的偏差是否超过 0.01 °C。
任何一项不过，`verify` 以非零码退出。

## 推送到 wiki

`lua/` 下是纯页面正文；上传器（`wiki-batch-grab` 的推回、`cwb upload` 或工作区工具）需要页面前面那段
`[PAGE_INFO]` 头来知道目标页与冲突基准。生成一次：

```bash
python3 -m wikilayertemp pageinfo
```

产物在 `dist/page-info/`，文件名与 `wiki-batch-grab --name-style dash` 一致：

| 文件 | 目标页 | 基线修订 |
| --- | --- | --- |
| `模块_Data_Layer Temperature.lua` | 模块:Data/Layer Temperature | 17495 |
| `模块_温度平滑折线图.lua` | 模块:温度平滑折线图 | 12753 |
| `模块_温度横向表格.lua` | 模块:温度横向表格 | 17323 |

头的结构（`comment` / `pageTitle` / `pageID` / `revisionID` / `contentModel` / `contentFormat`）与
`wiki-batch-grab` 写出的完全一致，上传器推完之后会自己清掉这段。

**推送前先刷基线**：`data/page-info.json` 里的 `pageid` / `revid` 是本次改写所基于的版本。
如果页面上已经有了别人的新编辑，先同步一次、确认没有冲突，再更新这两个值重新生成，否则会被判成基于旧版本的编辑。

顺序建议：先推数据模块（不影响现有页面），再推两个渲染模块。

## 已知的数据源限制

插件导出的 `samples` 块不参与生成，只用来交叉验证；它本身有若干问题（`count` 比实际点数少一、不覆盖进入地层的头几秒、均匀采样会漏尖峰），
详见 [docs/data-source.md](docs/data-source.md)。

## 文档

- [docs/curve-semantics.md](docs/curve-semantics.md) — 埃尔米特、卷绕模式、切线权重实测结论
- [docs/data-source.md](docs/data-source.md) — TemperatureMonitor 插件做了什么、有哪些坑
- [docs/wiki-integration.md](docs/wiki-integration.md) — 与 wiki 现有模板/模块的对接与迁移
