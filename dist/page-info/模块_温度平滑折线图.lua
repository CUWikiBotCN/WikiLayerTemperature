--[=[<%-- [PAGE_INFO]
    comment = #Please do not remove this struct. It's record contains some important information of edit. This struct will be removed automatically after you push edits.#
    pageTitle = #模块:温度平滑折线图#
    pageID = #2780#
    revisionID = #12753#
    contentModel = #Scribunto#
    contentFormat = #text/plain#
[END_PAGE_INFO] --%>--]=]

-- Module:温度平滑折线图
-- 根据地层 id / 中文名 / 英文名，取 Module:Data/Layer_Temperature 的曲线，
-- 采样后交给 Module:平滑折线图 生成 ECharts 代码。
--
-- 调用方式: {{#invoke:温度平滑折线图|main|gravel_lands}}
--           {{#invoke:温度平滑折线图|main|砾石荒原}}
--           {{#invoke:温度平滑折线图|main|Gravel_Lands}}
-- 可选参数: showLabel / showMarkPoint / showMarkLine / showAllPoints / useGradient / threshold / points
--
-- 与旧版的区别：不再预存 301 个采样点，而是由原始关键帧现算，
-- 因此曲线形状、周期、折返段都与游戏一致（详见仓库 docs/curve-semantics.md）。

local p = {}

local chart = require('Module:平滑折线图')
local dataModule = require('Module:Data/Layer_Temperature')

-- 默认采样段数：240 段 = 241 个点，足够画出尖峰又不至于让图表卡顿
local DEFAULT_POINTS = 240

-- 解析布尔参数：仅支持 true/false
local function parseBool(val, default)
    if val == nil or val == "" then
        return default
    end
    val = mw.text.trim(val)
    if val == "false" then
        return false
    end
    if val == "true" then
        return true
    end
    return default
end

-- 主函数：根据区域名生成图表
-- 通过模板调用时，参数从父框架（frame:getParent()）读取
function p.main(frame)
    local fargs = frame.args
    local parent = frame:getParent()
    local pargs = parent and parent.args or {}

    -- 辅助函数：优先从直接参数读取，回退到模板参数
    local function getArg(key)
        if fargs[key] ~= nil and fargs[key] ~= "" then return fargs[key] end
        if pargs[key] ~= nil and pargs[key] ~= "" then return pargs[key] end
        return nil
    end

    local name = getArg(1) or getArg("region")
    if not name or name == "" then
        return '<strong class="error">错误：未指定地层。用法: {{温度平滑折线图|gravel_lands}}</strong>'
    end

    name = mw.text.trim(name)

    -- 从数据模块查找（支持 id、中文名、英文名，大小写与空格不敏感）
    local curve = dataModule.get(name)
    if not curve then
        return '<strong class="error">错误：找不到地层 "' .. name .. '" 的温度数据。</strong>'
    end

    -- 读取可选参数
    local opts = {
        showLabel     = parseBool(getArg("showLabel"), true),
        showMarkPoint = parseBool(getArg("showMarkPoint"), true),
        showMarkLine  = parseBool(getArg("showMarkLine"), true),
        showAllPoints = parseBool(getArg("showAllPoints"), true),
        useGradient   = parseBool(getArg("useGradient"), false),
        THRESHOLD     = tonumber(getArg("threshold")) or 10
    }

    local points = dataModule.series(curve, {
        count = tonumber(getArg("points")) or DEFAULT_POINTS
    })
    if not points then
        return '<strong class="error">错误：地层 "' .. name .. '" 没有可用的采样序列。</strong>'
    end

    -- 调用通用图表模块生成 ECharts wiki 代码
    local echartsCode = chart.generate(points, opts)

    -- 关键：用 frame:preprocess() 让 MediaWiki 解析器处理 {{#echarts:...}}
    return frame:preprocess(echartsCode)
end

return p
