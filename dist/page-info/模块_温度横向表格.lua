--[=[<%-- [PAGE_INFO]
    comment = #Please do not remove this struct. It's record contains some important information of edit. This struct will be removed automatically after you push edits.#
    pageTitle = #模块:温度横向表格#
    pageID = #2823#
    revisionID = #17693#
    contentModel = #Scribunto#
    contentFormat = #text/plain#
[END_PAGE_INFO] --%>--]=]

-- Module:温度横向表格
-- 读取 Module:Data/Layer_Temperature 的曲线，现算温度与变化率，输出横向滚动的表格。
--
-- 调用方式: {{#invoke:温度横向表格|main|gravel_lands}}
--           {{温度横向表格|砾石荒原}}
--
-- 与旧版的区别：行不再是预先写死的采样，而是由关键帧 + 周期现算；
-- 着色用的最高/最低温取自整条曲线的真实极值（曲线会过冲出关键帧范围）。

local p = {}

-- ═════════════════════════════════════════════
-- 颜色定义（在此处修改即可调整全局配色）
-- ═════════════════════════════════════════════
local COLOR_MIN = "#ddeeff"       -- 最低温度 / 负变化率
local COLOR_MAX = "#ffeedd"       -- 最高温度 / 正变化率
local COLOR_DEFAULT = "#888888"   -- 其余温度和变化率
local COLOR_ZERO_RATE = "#FFFFFF" -- 变化率为0且非最高温的温度值

local dataModule = require('Module:Data/Layer_Temperature')

-- 格式化温度数值：确保显示一位小数
local function formatTemp(t)
    return string.format("%.1f", t) .. "°C"
end

-- 格式化变化率：带正负号，两位小数
local function formatChange(c)
    return string.format("%+.2f", c) .. "°C/分"
end

-- 获取温度单元格颜色
-- 规则:
--   1. 最高温 → COLOR_MAX
--   2. 最低温 → COLOR_MIN
--   3. 变化率为0且非最高温 → COLOR_ZERO_RATE
--   4. 其余 → COLOR_DEFAULT
local function getTempColor(t, c, maxT, minT)
    local EPS = 0.011
    if math.abs(t - maxT) <= EPS then
        return COLOR_MAX
    elseif math.abs(t - minT) <= EPS then
        return COLOR_MIN
    elseif c == 0 then
        return COLOR_ZERO_RATE
    else
        return COLOR_DEFAULT
    end
end

-- 获取变化率单元格颜色
-- 规则:
--   1. 正变化率 → COLOR_MAX
--   2. 负变化率 → COLOR_MIN
--   3. 零 → COLOR_DEFAULT
local function getChangeColor(c)
    if c > 0 then
        return COLOR_MAX
    elseif c < 0 then
        return COLOR_MIN
    else
        return COLOR_DEFAULT
    end
end

-- 主函数
function p.main(frame)
    -- 同时获取直接框架参数和父框架（模板）参数
    local fargs = frame.args
    local parent = frame:getParent()
    local pargs = parent and parent.args or {}

    local function getArg(key)
        if fargs[key] ~= nil and fargs[key] ~= "" then return fargs[key] end
        if pargs[key] ~= nil and pargs[key] ~= "" then return pargs[key] end
        return nil
    end

    local name = getArg(1) or getArg("region")
    if not name or name == "" then
        return '<strong class="error">错误：未指定地层。用法: {{温度横向表格|gravel_lands}}</strong>'
    end

    name = mw.text.trim(name)

    local curve = dataModule.get(name)
    if not curve then
        return '<strong class="error">错误：找不到地层 "' .. name .. '" 的温度数据。</strong>'
    end

    local points = dataModule.rows(curve, {
        max_gap = tonumber(getArg("maxgap")) or nil
    })
    if not points or #points == 0 then
        return '<strong class="error">错误：地层 "' .. name .. '" 没有可用的采样行。</strong>'
    end

    local n = #points
    local maxT = curve.maxTemp
    local minT = curve.minTemp

    -- 构建 wikitext 表格
    local parts = {}

    -- 外层滚动容器
    table.insert(parts, '<div style="max-width:100%;overflow-x:auto;overflow-y:hidden;">\n')

    -- 表格开始
    table.insert(parts, '{| class="wikitable"\n')
    table.insert(parts, '|+ 温度与变化率\n')

    -- 表头行：时间 + 各时间标签
    local headerCells = { "! 时间" }
    for _, pt in ipairs(points) do
        table.insert(headerCells, " !! " .. pt[1])
    end
    table.insert(parts, table.concat(headerCells) .. "\n")
    table.insert(parts, "|-\n")

    -- 温度行
    table.insert(parts, "! 温度\n")
    local tempCells = {}
    for _, pt in ipairs(points) do
        local t = pt[2]
        local c = pt[3] or 0
        local color = getTempColor(t, c, maxT, minT)
        table.insert(tempCells, '| <span style="color:' .. color .. '">' .. formatTemp(t) .. "</span>")
    end
    table.insert(parts, table.concat(tempCells, " || ") .. "\n")
    table.insert(parts, "|-\n")

    -- 变化率行
    table.insert(parts, "! 变化率\n")
    local changeCells = {}
    for _, pt in ipairs(points) do
        local c = pt[3] or 0
        local color = getChangeColor(c)
        table.insert(changeCells, '| <span style="color:' .. color .. '">' .. formatChange(c) .. "</span>")
    end
    table.insert(parts, table.concat(changeCells, " || ") .. "\n")
    table.insert(parts, "|-\n")

    -- 底部循环说明行
    local cycleLabel = dataModule.period_label(curve)
    local cycleNote = cycleLabel and ("每 " .. cycleLabel .. " 重复一次") or "温度保持不变"
    table.insert(parts, '| colspan="' .. (n + 1) .. '" | ' .. cycleNote .. "\n")
    table.insert(parts, "|}\n")
    table.insert(parts, "</div>")

    local html = table.concat(parts)
    return frame:preprocess(html)
end

return p
