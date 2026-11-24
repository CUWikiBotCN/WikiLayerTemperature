--[=[<%-- [PAGE_INFO]
    comment = #Please do not remove this struct. It's record contains some important information of edit. This struct will be removed automatically after you push edits.#
    pageTitle = #模块:平滑折线图#
    pageID = #2782#
    revisionID = #13049#
    contentModel = #Scribunto#
    contentFormat = #text/plain#
[END_PAGE_INFO] --%>--]=]

-- Module:平滑折线图
-- 通用 ECharts 平滑折线图生成器
-- 调用方式: local chart = require('Module:平滑折线图')
--           local code = chart.generate(points, opts)
-- points: {{时间标签, 温度值}, ...}  时间标签支持 "M:SS" 格式或纯数字
-- opts: 可选配置覆盖（yAxisName, lineColor, pointColor, useGradient 等）
-- 返回: {{#echarts:option=...|style=...}} wiki 代码字符串

local p = {}

-- ═════════════════════════════════════════════
-- 默认配色（金色主题 + 深蓝紫背景元素）
-- ═════════════════════════════════════════════
local defaultConfig = {
    bgPanel     = "#25252E",
    textPrimary = "#FFF3C4",
    textSecond  = "#A89F7E",
    gridColor   = "#2E2E3A",
    spineColor  = "#3A3A4A",
    lineColor   = "#ffd961",
    pointColor  = "#fff3c4",
    fillColor   = "rgba(255,217,97,0.15)",
    yAxisName   = "温度 ( °C )",
    xAxisName   = "时间 (秒)",
    style       = "min-height:30rem",
    -- 数据点标签格式化（{c} 为 y 值）
    labelFormatter = "{c}°C",
    -- X 轴标签格式化（{value} 为 x 数值，秒）
    xAxisLabelFormatter = "{value}",
    -- 可选显示开关（默认全部开启）
    showLabel     = true,     -- 数据点上的温度标签
    showMarkPoint = true, -- 最高/最低温气泡标记
    showMarkLine  = true,  -- 平均温度虚线
    showAllPoints = true, -- 显示全部数据点（false=隐藏，仅鼠标悬停时通过 tooltip 显示）
    -- 极值点去重阈值（秒）：多个极值点距离小于此值时只保留一个
    THRESHOLD = 10,
    -- ★ 渐变配色（useGradient=true 时生效，visualMap 控制线/点/面积颜色）
    useGradient  = false,
    colorLow     = "#5DADE2",     -- 低温端（蓝）
    colorLowMid  = "#4FC3F7",  -- 0°C 冰蓝
    colorMid     = "#ffd961",     -- 10~22°C 金
    colorHighMid = "#FF9800", -- 32°C 橙
    colorHigh    = "#FF7B54",    -- 高温端（红）
    -- 固定渐变范围（不随数据 min/max 变化）
    gradientMin     = -50,    -- 最蓝
    gradientLowMid  = 0,   -- 冰蓝
    gradientMidLow  = 10,  -- 金色区间下界
    gradientMidHigh = 22, -- 金色区间上界
    gradientHighMid = 32, -- 橙色
    gradientMax     = 50      -- 最红
}

-- ═════════════════════════════════════════════
-- 颜色插值工具：hex ↔ rgb ↔ hex
-- ═════════════════════════════════════════════
local function hexToRgb(hex)
    hex = hex:gsub("#", "")
    return { tonumber(hex:sub(1, 2), 16) or 0, tonumber(hex:sub(3, 4), 16) or 0, tonumber(hex:sub(5, 6), 16) or 0 }
end

local function rgbToHex(rgb)
    return string.format("#%02x%02x%02x", rgb[1], rgb[2], rgb[3])
end

local function lerpRgb(c1, c2, t)
    return {
        math.floor(c1[1] + (c2[1] - c1[1]) * t + 0.5), math.floor(c1[2] + (c2[2] - c1[2]) * t + 0.5),
        math.floor(c1[3] + (c2[3] - c1[3]) * t + 0.5)
    }
end

-- 根据值在五色间插值（蓝→冰蓝→金→橙→红）
-- 段1: gradientMin → gradientLowMid     蓝 → 冰蓝
-- 段2: gradientLowMid → gradientMidLow   冰蓝 → 金
-- 段3: gradientMidLow ~ gradientMidHigh  金色区间（纯金）
-- 段4: gradientMidHigh → gradientHighMid 金 → 橙
-- 段5: gradientHighMid → gradientMax     橙 → 红
local function getGradientColor(
    value, gMin, gLowMid, gMidLow, gMidHigh, gHighMid, gMax, cLow, cLowMid, cMid, cHighMid, cHigh
)
    if value <= gMin then return cLow end
    if value >= gMax then return cHigh end
    if value < gLowMid then
        -- 蓝 → 冰蓝
        local t = (value - gMin) / (gLowMid - gMin)
        return rgbToHex(lerpRgb(hexToRgb(cLow), hexToRgb(cLowMid), t))
    elseif value < gMidLow then
        -- 冰蓝 → 金
        local t = (value - gLowMid) / (gMidLow - gLowMid)
        return rgbToHex(lerpRgb(hexToRgb(cLowMid), hexToRgb(cMid), t))
    elseif value <= gMidHigh then
        -- 金色区间：纯金
        return cMid
    elseif value < gHighMid then
        -- 金 → 橙
        local t = (value - gMidHigh) / (gHighMid - gMidHigh)
        return rgbToHex(lerpRgb(hexToRgb(cMid), hexToRgb(cHighMid), t))
    else
        -- 橙 → 红
        local t = (value - gHighMid) / (gMax - gHighMid)
        return rgbToHex(lerpRgb(hexToRgb(cHighMid), hexToRgb(cHigh), t))
    end
end

-- 为 visualMap 生成多色阶数组（五段渐变 + 金色区间）
local function buildGradientColors(
    cLow, cLowMid, cMid, cHighMid, cHigh, gMin, gLowMid, gMidLow, gMidHigh, gHighMid, gMax, numStops
)
    numStops = numStops or 100
    local colors = {}
    local r1 = (gLowMid - gMin) / (gMax - gMin)  -- 0°C 比例
    local r2 = (gMidLow - gMin) / (gMax - gMin)  -- 10°C 比例
    local r3 = (gMidHigh - gMin) / (gMax - gMin) -- 22°C 比例
    local r4 = (gHighMid - gMin) / (gMax - gMin) -- 32°C 比例
    local rgbLow = hexToRgb(cLow)
    local rgbLowMid = hexToRgb(cLowMid)
    local rgbMid = hexToRgb(cMid)
    local rgbHighMid = hexToRgb(cHighMid)
    local rgbHigh = hexToRgb(cHigh)
    for i = 0, numStops do
        local t = i / numStops
        local rgb
        if t <= r1 then
            -- 蓝 → 冰蓝
            local t2 = r1 > 0 and (t / r1) or 0
            rgb = lerpRgb(rgbLow, rgbLowMid, t2)
        elseif t <= r2 then
            -- 冰蓝 → 金
            local t2 = (t - r1) / (r2 - r1)
            rgb = lerpRgb(rgbLowMid, rgbMid, t2)
        elseif t <= r3 then
            -- 金色区间：纯金
            rgb = rgbMid
        elseif t <= r4 then
            -- 金 → 橙
            local t2 = (t - r3) / (r4 - r3)
            rgb = lerpRgb(rgbMid, rgbHighMid, t2)
        else
            -- 橙 → 红
            local t2 = (1 - r4) > 0 and ((t - r4) / (1 - r4)) or 0
            rgb = lerpRgb(rgbHighMid, rgbHigh, t2)
        end
        table.insert(colors, rgbToHex(rgb))
    end
    return colors
end

-- ═════════════════════════════════════════════
-- JSON 工具
-- ═════════════════════════════════════════════
local function escapeUnicode(s)
    local result = {}
    local i = 1
    while i <= #s do
        local byte = string.byte(s, i)
        if byte < 128 then
            table.insert(result, string.char(byte))
            i = i + 1
        elseif byte >= 240 then
            local cp = (byte - 240) * 262144
            cp = cp + (string.byte(s, i + 1) - 128) * 4096
            cp = cp + (string.byte(s, i + 2) - 128) * 64
            cp = cp + (string.byte(s, i + 3) - 128)
            table.insert(result, string.format("\\u%04x", cp))
            i = i + 4
        elseif byte >= 224 then
            local cp = (byte - 224) * 4096
            cp = cp + (string.byte(s, i + 1) - 128) * 64
            cp = cp + (string.byte(s, i + 2) - 128)
            table.insert(result, string.format("\\u%04x", cp))
            i = i + 3
        elseif byte >= 192 then
            local cp = (byte - 192) * 64
            cp = cp + (string.byte(s, i + 1) - 128)
            table.insert(result, string.format("\\u%04x", cp))
            i = i + 2
        else
            i = i + 1
        end
    end
    return table.concat(result)
end

local function fixBraces(s)
    local result = {}
    local len = #s
    local i = 1
    while i <= len do
        local char = s:sub(i, i)
        if char == "}" and i < len and s:sub(i + 1, i + 1) == "}" then
            table.insert(result, "} ")
        elseif char == "{" and i < len and s:sub(i + 1, i + 1) == "{" then
            table.insert(result, "{ ")
        else
            table.insert(result, char)
        end
        i = i + 1
    end
    return table.concat(result)
end

local function jsonString(s)
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, '"', '\\"')
    s = string.gsub(s, "\n", "\\n")
    s = string.gsub(s, "\r", "\\r")
    s = string.gsub(s, "\t", "\\t")
    return '"' .. s .. '"'
end

local function jsonValue(v)
    local t = type(v)
    if t == "string" then
        return jsonString(v)
    elseif t == "number" then
        return tostring(v)
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "nil" then
        return "null"
    elseif t == "table" then
        local isArray = true
        local count = 0
        ---@type number
        local maxIdx = 0
        for k, _ in pairs(v) do
            count = count + 1
            if type(k) == "number" and k == math.floor(k) and k >= 1 then
                if k > maxIdx then maxIdx = k end
            else
                isArray = false
                break
            end
        end
        if isArray and count == maxIdx and count > 0 then
            local parts = {}
            for i = 1, maxIdx do
                table.insert(parts, jsonValue(v[i]))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, val in pairs(v) do
                table.insert(parts, jsonString(tostring(k)) .. ":" .. jsonValue(val))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

-- ═════════════════════════════════════════════
-- 生成 ECharts wiki 代码
-- ═════════════════════════════════════════════
function p.generate(points, opts)
    if type(points) ~= 'table' or #points == 0 then
        return ''
    end
    opts = opts or {}
    local cfg = {}
    for k, v in pairs(defaultConfig) do
        if opts[k] ~= nil then
            cfg[k] = opts[k]
        else
            cfg[k] = v
        end
    end

    -- 提取 x 值和温度值，找出最高/最低温
    -- pt[1] 已经是秒数（数值），无需解析
    local xValues = {}
    local temps = {}
    local maxTemp, minTemp
    for _, pt in ipairs(points) do
        table.insert(xValues, pt[1])
        table.insert(temps, pt[2])
        if not maxTemp or pt[2] > maxTemp then maxTemp = pt[2] end
        if not minTemp or pt[2] < minTemp then minTemp = pt[2] end
    end
    if maxTemp == nil or minTemp == nil then
        return ''
    end

    -- 找出所有最高温/最低温的索引（可能有多个）
    local maxIndices = {}
    local minIndices = {}
    for i, t in ipairs(temps) do
        if t == maxTemp then table.insert(maxIndices, i) end
        if t == minTemp then table.insert(minIndices, i) end
    end

    -- ★ 极值点去重：距离小于 THRESHOLD 秒的多个极值点只保留第一个
    local function filterNearby(indices)
        if #indices <= 1 then return indices end
        local result = { indices[1] }
        for j = 2, #indices do
            local prevIdx = result[#result]
            local currIdx = indices[j]
            if xValues[currIdx] - xValues[prevIdx] >= cfg.THRESHOLD then
                table.insert(result, currIdx)
            end
        end
        return result
    end
    maxIndices = filterNearby(maxIndices)
    minIndices = filterNearby(minIndices)

    -- 乒乓折返会让同一个极值在一个周期里出现两次（正放一次、倒放一次），
    -- 数值完全相同，标两个气泡只是噪音：每种极值只留第一个。
    if #maxIndices > 1 then maxIndices = { maxIndices[1] } end
    if #minIndices > 1 then minIndices = { minIndices[1] } end

    -- 格式化数值：整数去小数点，非整数保留原样
    local function formatVal(v)
        if v == math.floor(v) then return tostring(math.floor(v)) end
        return tostring(v)
    end

    -- 构建 2D 数据数组 [[x, y], ...]
    -- 每个数据点的标签预格式化为纯 y 值文本
    -- 当 showLabel=true 且 showMarkPoint=true 时，最高/最低温点隐藏标签
    -- ★ showAllPoints=false 时隐藏所有标签（点都不显示了，标签也没意义）
    -- ★ 渐变模式：标签颜色也跟随温度渐变
    local tempsData = {}
    local hideExtremeLabels = cfg.showLabel and cfg.showMarkPoint
    local showLabels = cfg.showLabel and cfg.showAllPoints        -- showAllPoints=false 时强制隐藏标签
    local labelStyle = { position = "top", color = cfg.pointColor, fontSize = 10, fontWeight = "bold" }
    for i, t in ipairs(temps) do
        local xy = { xValues[i], t }
        local labelText = string.gsub(cfg.labelFormatter, "{c}", formatVal(t))
        -- 渐变模式下，标签颜色跟随温度值（五段渐变）
        local labelColor = cfg.pointColor
        if cfg.useGradient then
            labelColor = getGradientColor(
                t, cfg.gradientMin, cfg.gradientLowMid, cfg.gradientMidLow, cfg.gradientMidHigh, cfg.gradientHighMid,
                cfg.gradientMax, cfg.colorLow, cfg.colorLowMid, cfg.colorMid, cfg.colorHighMid, cfg.colorHigh
            )
        end
        if not showLabels or (hideExtremeLabels and (t == maxTemp or t == minTemp)) then
            table.insert(tempsData, { value = xy, label = { show = false } })
        else
            local lbl = {}
            for k, v in pairs(labelStyle) do
                lbl[k] = v
            end
            lbl.show = cfg.showLabel
            lbl.formatter = labelText
            lbl.color = labelColor
            table.insert(tempsData, { value = xy, label = lbl })
        end
    end

    -- 计算 Y 轴范围（留 15% 余量，最小跨度 5）
    local tRange = maxTemp - minTemp
    if tRange < 5 then tRange = 5 end
    local yMin = minTemp - tRange * 0.15
    local yMax = maxTemp + tRange * 0.15

    -- X 轴范围
    local xMin = xValues[1]
    local xMax = xValues[#xValues]

    -- 构建 ECharts option（Lua table）
    local option = {
        backgroundColor = "transparent",
        tooltip = {
            trigger = "axis",
            backgroundColor = cfg.bgPanel,
            borderColor = cfg.spineColor,
            textStyle = { color = cfg.textPrimary }
        },
        grid = { left = 70, right = 25, top = 25, bottom = 90 },
        -- value 轴：按实际时间值（秒）比例定位
        xAxis = {
            type = "value",
            name = cfg.xAxisName,
            nameLocation = "middle",
            nameGap = 50,
            nameTextStyle = { color = cfg.textPrimary, fontSize = 13, fontWeight = "bold" },
            min = xMin,
            max = xMax,
            axisLabel = { color = cfg.textSecond, fontSize = 10, formatter = cfg.xAxisLabelFormatter },
            axisLine = { lineStyle = { color = cfg.spineColor } },
            splitLine = { lineStyle = { color = cfg.gridColor, type = "dashed" } }
        },
        yAxis = {
            type = "value",
            name = cfg.yAxisName,
            nameLocation = "middle",
            nameGap = 35,
            nameTextStyle = { color = cfg.textPrimary, fontSize = 13, fontWeight = "bold" },
            min = yMin,
            max = yMax,
            axisLabel = { color = cfg.textSecond, fontSize = 11 },
            axisLine = { lineStyle = { color = cfg.spineColor } },
            splitLine = { lineStyle = { color = cfg.gridColor, type = "dashed" } }
        },
        dataZoom = {
            { type = "inside", start = 0, ["end"] = 100 },
            {
                type = "slider",
                start = 0,
                ["end"] = 100,
                height = 20,
                bottom = 10,
                borderColor = cfg.spineColor,
                fillerColor = cfg.fillColor,
                handleStyle = { color = cfg.lineColor },
                textStyle = { color = cfg.textSecond },
                dataBackground = { lineStyle = { color = cfg.spineColor }, areaStyle = { color = cfg.gridColor } }
            }
        },
        series = {
            {
                name = "温度",
                type = "line",
                smooth = true,
                showSymbol = cfg.showAllPoints,
                symbol = "circle",
                symbolSize = 7,
                -- 渐变模式下不设 color，让 visualMap 控制；非渐变模式用固定色
                lineStyle = cfg.useGradient and { width = 2.5 } or { color = cfg.lineColor, width = 2.5 },
                itemStyle = cfg.useGradient and { borderColor = "transparent", borderWidth = 2 }
                    or { color = cfg.pointColor, borderColor = "transparent", borderWidth = 2 },
                areaStyle = cfg.useGradient and { opacity = 0.2 } or { color = cfg.fillColor },
                data = tempsData
            }
        }
    }

    -- ★ 渐变模式：添加 visualMap，让线/点/面积颜色跟随 y 值
    -- 五段渐变 + 金色区间，生成多色阶数组
    if cfg.useGradient then
        local gradientColors = buildGradientColors(
            cfg.colorLow, cfg.colorLowMid, cfg.colorMid, cfg.colorHighMid, cfg.colorHigh, cfg.gradientMin,
            cfg.gradientLowMid, cfg.gradientMidLow, cfg.gradientMidHigh, cfg.gradientHighMid, cfg.gradientMax
        )
        option.visualMap = {
            type = "continuous",
            min = cfg.gradientMin,
            max = cfg.gradientMax,
            inRange = { color = gradientColors },
            show = false
        }
    end

    -- 条件添加 markPoint（最高/最低温气泡标记）
    -- 手动找出所有最高/最低温点，用显式坐标标记
    -- ★ 渐变模式下气泡颜色跟随当前温度值的渐变颜色（与线/点同色）
    -- 非渐变模式用线条色
    -- 恒定曲线（max == min）没有"极值"可言：每个点都等于极值，
    -- 否则会沿整条线每隔 THRESHOLD 秒冒出一个气泡。直接不画。
    if cfg.showMarkPoint and maxTemp > minTemp then
        local maxMarkColor, minMarkColor
        if cfg.useGradient then
            maxMarkColor = getGradientColor(
                maxTemp, cfg.gradientMin, cfg.gradientLowMid, cfg.gradientMidLow, cfg.gradientMidHigh,
                cfg.gradientHighMid, cfg.gradientMax, cfg.colorLow, cfg.colorLowMid, cfg.colorMid, cfg.colorHighMid,
                cfg.colorHigh
            )
            minMarkColor = getGradientColor(
                minTemp, cfg.gradientMin, cfg.gradientLowMid, cfg.gradientMidLow, cfg.gradientMidHigh,
                cfg.gradientHighMid, cfg.gradientMax, cfg.colorLow, cfg.colorLowMid, cfg.colorMid, cfg.colorHighMid,
                cfg.colorHigh
            )
        else
            maxMarkColor = cfg.lineColor
            minMarkColor = cfg.lineColor
        end
        local markData = {}
        for _, idx in ipairs(maxIndices) do
            table.insert(markData, {
                coord = { xValues[idx], temps[idx] },
                name = "最高温",
                value = formatVal(maxTemp),
                itemStyle = { color = maxMarkColor }
            })
        end
        for _, idx in ipairs(minIndices) do
            table.insert(markData, {
                coord = { xValues[idx], temps[idx] },
                name = "最低温",
                value = formatVal(minTemp),
                itemStyle = { color = minMarkColor }
            })
        end
        option.series[1].markPoint = { data = markData }
    end

    -- 条件添加 markLine（平均温度虚线）
    -- ★ 显式设置 lineStyle.color，避免被 visualMap 接管变成蓝色
    -- 恒定曲线画平均线没有信息量，且必然与唯一的水平线重合
    if cfg.showMarkLine and maxTemp > minTemp then
        option.series[1].markLine = {
            symbol = "none",
            -- 标签挪到折线右端上方并加底色：原来放在 start（贴着 y 轴），
            -- 平均值与某个刻度同值时，"平均" 文字会和刻度值叠在一起
            label = {
                color = cfg.textPrimary,
                fontSize = 10,
                position = "insideEndTop",
                backgroundColor = cfg.bgPanel,
                padding = { 2, 4 },
                borderRadius = 2,
            },
            lineStyle = { color = cfg.lineColor, type = "dashed", width = 1.2 },
            data = { { type = "average", name = "平均" } }
        }
    end

    -- 序列化为 JSON
    local jsonStr = jsonValue(option)
    jsonStr = escapeUnicode(jsonStr)
    jsonStr = fixBraces(jsonStr)
    return "{{#echarts:option=" .. jsonStr .. "|style=" .. cfg.style .. "}}"
end

return p