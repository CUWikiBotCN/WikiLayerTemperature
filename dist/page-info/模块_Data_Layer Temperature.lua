--[=[<%-- [PAGE_INFO]
    comment = #Please do not remove this struct. It's record contains some important information of edit. This struct will be removed automatically after you push edits.#
    pageTitle = #模块:Data/Layer Temperature#
    pageID = #2779#
    revisionID = #17495#
    contentModel = #Scribunto#
    contentFormat = #text/plain#
[END_PAGE_INFO] --%>--]=]

-- Module:Data/Layer_Temperature
-- 各地层的环境温度曲线，供 {{地层温度}} 一系的模板/模块查询。
--
-- 本页由 WikiLayerTemperature 生成，请勿手工编辑；要改数据请改仓库后重新生成。
-- 源数据：TempCurves_All_20261122_001326.json（插件导出时间 2026-11-22 00:13:26）
-- 源文件 SHA-256：be870efd8dfb8da086e79040e9a7e6faec8516bca8cfd79e56c4eb90a792d401
-- 生成时间：2026-11-22T01:58:00+0800
--
-- 每层的 keys 是 Unity AnimationCurve 的原始关键帧：
--   { 时间(秒), 温度(°C), 入切线, 出切线 }
-- 温度由三次埃尔米特插值求出，并按 preWrap/postWrap 折返，
-- 与游戏里 AmbientTemperature 的取值一致。查询接口见文件末尾。

local data = {
    {
        id = "gravel_lands",
        cn = "砾石荒原",
        en = "Gravel_Lands",
        layer = 0,
        preWrap = "PingPong",
        postWrap = "PingPong",
        period = 2000,
        minTemp = 12.6438,
        maxTemp = 18.54944,
        minAt = 593,
        maxAt = 1000,
        keys = {
            { 0, 17.06391, 0, 0 },
            { 295.6437, 13.87863, 0, 0 },
            { 448.1291, 14.31169, 0, 0 },
            { 592.9485, 12.6438, 0, 0 },
            { 1000, 18.54944, 0, 0 },
        },
    },
    {
        id = "deeper_gravel_lands",
        cn = "深层砾石带",
        en = "Deeper_Gravel_Lands",
        layer = 1,
        preWrap = "PingPong",
        postWrap = "PingPong",
        period = 2397.501,
        minTemp = 12.47208,
        maxTemp = 21.37298,
        minAt = 467.5127,
        maxAt = 692.8779,
        keys = {
            { 0, 17.06435, 0, 0 },
            { 240.7808, 15.74586, -0.009817443, -0.009817443 },
            { 467.7674, 12.47207, 0, 0 },
            { 692.4109, 21.37298, 0, 0 },
            { 1198.751, 18.10219, 0, 0 },
        },
    },
    {
        id = "dried_desert",
        cn = "干旱沙漠",
        en = "Dried_Desert",
        layer = 2,
        preWrap = "PingPong",
        postWrap = "PingPong",
        period = 1356.845,
        minTemp = 12.43569,
        maxTemp = 35.64614,
        minAt = 905.3551,
        maxAt = 976.5895,
        keys = {
            { 16.10473, 30.89856, 0.011771, 0.011771 },
            { 142.7495, 32.3893, -0.07809066, -0.07809066 },
            { 252.3916, 13.97465, -0.1167547, -0.1167547 },
            { 440.3805, 32.74022, -0.2191921, -0.2191921 },
            { 477.2129, 12.91675, -0.154762, -0.154762 },
            { 543.9254, 28.17278, 0.1186493, 0.1186493 },
            { 694.5275, 29.47028, 0.008615475, 0.008615475 },
        },
    },
    {
        id = "wasteland",
        cn = "辐射废土",
        en = "Wasteland",
        layer = 3,
        preWrap = "PingPong",
        postWrap = "PingPong",
        period = 1774.866,
        minTemp = -19.55342,
        maxTemp = 38.64421,
        minAt = 1555.226,
        maxAt = 978.8385,
        keys = {
            { 16.10473, 31.49754, -0.02823994, -0.02823994 },
            { 91.44989, 29.36979, -0.2858631, -0.2858631 },
            { 118.7352, 9.780962, 0.04347361, 0.04347361 },
            { 156.4472, 36.31501, 0.000509556, 0.000509556 },
            { 183.335, 29.67124, -0.1557041, -0.1557041 },
            { 242.8512, 25.84338, -0.0732732, -0.0732732 },
            { 251.8171, -19.55349, -0.003223889, -0.003223889 },
            { 279.5956, 26.08345, 0.02535901, 0.02535901 },
            { 400.3025, 31.4164, 0.03768691, 0.03768691 },
            { 452.371, 33.04057, -0.04444499, -0.04444499 },
            { 501.045, 10.55635, -0.00458169, -0.00458169 },
            { 576.4827, 32.38375, -0.007978944, -0.007978944 },
            { 694.5275, 30.06926, 0.001470914, 0.001470914 },
            { 739.8911, 33.24512, 0, 0 },
            { 803.9267, -14.11454, -0.1084787, -0.1084787 },
            { 828.1419, 38.64426, 0, 0 },
            { 903.5376, 28.53738, 0, 0 },
        },
    },
    {
        id = "overgrown_depths",
        cn = "深林丛渊",
        en = "Overgrown_Depths",
        layer = 4,
        preWrap = "PingPong",
        postWrap = "PingPong",
        period = 1335.479,
        minTemp = 5.625561,
        maxTemp = 31.49306,
        minAt = 817.3132,
        maxAt = 16.02575,
        keys = {
            { 16.10473, 31.49754, -0.05666172, -0.05666172 },
            { 228.7894, 19.44646, -0.01292634, -0.01292634 },
            { 493.3799, 27.59823, -0.03432999, -0.03432999 },
            { 498.2052, 18.11973, -0.5261931, -0.5261931 },
            { 683.8442, 30.61259, 0.06729651, 0.06729651 },
        },
    },
    {
        id = "frozen_chasm",
        cn = "覆冰断崖",
        en = "Frozen_Chasm",
        layer = 5,
        preWrap = "ClampForever",
        postWrap = "PingPong",
        period = 600,
        minTemp = -32.97762,
        maxTemp = -24,
        minAt = 164.1,
        maxAt = 300,
        keys = {
            { 0, -28.5, 0.01640635, 0.01640635 },
            { 53.49715, -27.62231, -0.01498603, -0.01498603 },
            { 168.4557, -32.9539, 0.01084459, 0.01084459 },
            { 300, -24, 0.0680676, 0.0680676 },
        },
    },
    {
        id = "fungal_pools",
        cn = "真菌洼地",
        en = "Fungal_Pools",
        layer = 6,
        preWrap = "ClampForever",
        postWrap = "PingPong",
        period = 601.6756,
        minTemp = 14.22241,
        maxTemp = 23.19565,
        minAt = 163.6558,
        maxAt = 299.9353,
        keys = {
            { -0.8378148, 18.70004, 0.01636066, 0.01636066 },
            { 52.80874, 19.57773, -0.0149443, -0.0149443 },
            { 168.0883, 14.24614, 0.01081439, 0.01081439 },
            { 300, 23.20004, 0.06787802, 0.06787802 },
        },
    },
    {
        id = "crystalline_hollow",
        cn = "晶蚀空穴",
        en = "Crystalline_Hollow",
        layer = 7,
        preWrap = "ClampForever",
        postWrap = "PingPong",
        period = 1062.649,
        minTemp = 16.91709,
        maxTemp = 20.69679,
        minAt = 870.3096,
        maxAt = 530.5275,
        keys = {
            { -0.8378148, 19.15884, 0.007808365, 0.007808365 },
            { 52.80874, 19.57773, -0.007894264, -0.007894264 },
            { 163.3095, 16.97026, -0.003968991, -0.003968991 },
            { 530.4867, 20.6972, 0.01015026, 0.01015026 },
        },
    },
    {
        id = "geothermal_vents",
        cn = "地热喷口",
        en = "Geothermal_Vents",
        layer = 8,
        preWrap = "PingPong",
        postWrap = "PingPong",
        period = 238.7196,
        minTemp = 35.43244,
        maxTemp = 42.65671,
        minAt = 1.671037,
        maxAt = 121.0308,
        keys = {
            { 1.650508, 35.43119, 0.060546, 0.060546 },
            { 121.0103, 42.65795, 0.060546, 0.060546 },
        },
    },
    {
        id = "where_we_must_reach",
        cn = "必须抵达之地",
        en = "Where_We_Must_Reach",
        layer = 9,
        preWrap = "ClampForever",
        postWrap = "ClampForever",
        period = nil,
        minTemp = 15,
        maxTemp = 15,
        minAt = 0,
        maxAt = 0,
        keys = {
            { 0, 15, -1.81616, -1.81616 },
        },
    },
    {
        id = "crimson_ascent",
        cn = "猩红长阶",
        en = "Crimson_Ascent",
        layer = 10,
        preWrap = "Loop",
        postWrap = "Loop",
        period = 300,
        minTemp = 15.77304,
        maxTemp = 23.11334,
        minAt = 207,
        maxAt = 88.8,
        keys = {
            { 0, 20.00001, 0.02999987, 0.02999987 },
            { 100, 22.99999, -0.02087824, -0.02087824 },
            { 200, 15.82436, -0.01499991, -0.01499991 },
            { 300, 20.00001, 0.04175651, 0.04175651 },
        },
    },
    {
        id = "earth",
        cn = "地球",
        en = "Earth",
        layer = 11,
        preWrap = "ClampForever",
        postWrap = "ClampForever",
        period = nil,
        minTemp = 20.01154,
        maxTemp = 20.01154,
        minAt = 0.00425,
        maxAt = 0.0005,
        keys = {
            { 0, 20.01154, 0, 0 },
            { 1, 20.01154, 0, 0 },
        },
    },
}

-- ===========================================================================
-- 运行时：把上面的 data 表包装成可查询的接口
-- 本文件由仓库维护（lua/runtime/api.lua），生成脚本把 data 表与它拼接成整份模块。
-- 只用 Lua 5.1 / Scribunto 兼容语法。
-- ===========================================================================

local p = {}

-- 归一化：去首尾空白、转小写、空格换下划线。
-- 于是 "Gravel_Lands" / "gravel lands" / "GRAVEL_LANDS" 命中同一条记录。
local function norm(value)
    local text = tostring(value)
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    text = text:lower():gsub('%s+', '_')
    return text
end

local index = {}
for _, curve in ipairs(data) do
    index[norm(curve.id)] = curve
    index[norm(curve.cn)] = curve
    index[norm(curve.en)] = curve
end

-- 接受 id / 中文名 / 英文名 / 记录本身
local function resolve(value)
    if type(value) == 'table' then
        return value
    end
    if value == nil or value == '' then
        return nil
    end
    return index[norm(value)]
end

local function bounds(curve)
    local keys = curve.keys
    return keys[1][1], keys[#keys][1]
end

-- PingPong 折返：把任意时刻映射回 [t0, t1]
local function mirror(curve, t)
    local t0, t1 = bounds(curve)
    local span = t1 - t0
    if span <= 0 then
        return t0
    end
    local phase = (t - t0) % (2 * span)
    if phase > span then
        phase = 2 * span - phase
    end
    return t0 + phase
end

-- 应用卷绕模式。第二个返回值表示是否被钳制在端点（此时导数按 0 处理）。
local function wrap_time(curve, t)
    local t0, t1 = bounds(curve)
    local span = t1 - t0
    if span <= 0 then
        return t0, true
    end

    if t < t0 then
        if curve.preWrap == 'Loop' then
            return t0 + (t - t0) % span, false
        elseif curve.preWrap == 'PingPong' then
            return mirror(curve, t), false
        end
        return t0, true
    end

    if t > t1 then
        if curve.postWrap == 'Loop' then
            return t0 + (t - t0) % span, false
        elseif curve.postWrap == 'PingPong' then
            return mirror(curve, t), false
        end
        return t1, true
    end

    return t, false
end

-- 二分找到左端关键帧下标
local function locate(keys, t)
    local lo, hi = 1, #keys
    if t <= keys[1][1] then
        return 1
    end
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if keys[mid][1] <= t then
            lo = mid
        else
            hi = mid
        end
    end
    return lo
end

-- 三次埃尔米特（Unity AnimationCurve 的 Evaluate 在无权重修正时就是这条公式）
local function eval_curve(curve, t)
    local keys = curve.keys
    if #keys == 1 then
        return keys[1][2]
    end

    local tt, clamped = wrap_time(curve, t)
    if clamped then
        if tt <= keys[1][1] then
            return keys[1][2]
        end
        return keys[#keys][2]
    end

    local i = locate(keys, tt)
    local a, b = keys[i], keys[i + 1]
    local span = b[1] - a[1]
    if span <= 0 then
        return b[2]
    end

    local u = (tt - a[1]) / span
    local u2 = u * u
    local u3 = u2 * u
    local h00 = 2 * u3 - 3 * u2 + 1
    local h10 = u3 - 2 * u2 + u
    local h01 = -2 * u3 + 3 * u2
    local h11 = u3 - u2

    return h00 * a[2] + h10 * a[4] * span + h01 * b[2] + h11 * b[3] * span
end

-- 导数，单位 °C/秒
local function slope_curve(curve, t)
    local keys = curve.keys
    if #keys == 1 then
        return 0
    end

    local tt, clamped = wrap_time(curve, t)
    if clamped then
        return 0
    end

    local i = locate(keys, tt)
    local a, b = keys[i], keys[i + 1]
    local span = b[1] - a[1]
    if span <= 0 then
        return 0
    end

    local u = (tt - a[1]) / span
    local u2 = u * u
    local dh00 = 6 * u2 - 6 * u
    local dh10 = 3 * u2 - 4 * u + 1
    local dh01 = -6 * u2 + 6 * u
    local dh11 = 3 * u2 - 2 * u

    return (dh00 * a[2] + dh10 * a[4] * span + dh01 * b[2] + dh11 * b[3] * span) / span
end

-- 周期（秒）。PingPong 为往返一个来回，Loop 为单程，恒定曲线返回 nil。
local function period_of(curve)
    local t0, t1 = bounds(curve)
    if t1 <= t0 then
        return nil
    end
    if curve.postWrap == 'PingPong' then
        return 2 * (t1 - t0)
    end
    if curve.postWrap == 'Loop' then
        return t1 - t0
    end
    return nil
end

local function format_time(seconds)
    local total = math.floor(seconds + 0.5)
    local minutes = math.floor(total / 60)
    return string.format('%d:%02d', minutes, total - minutes * 60)
end

-- ---------------------------------------------------------------------------
-- 公开接口
-- ---------------------------------------------------------------------------

function p.all()
    return data
end

function p.get(name)
    return resolve(name)
end

-- 某地层在时刻 t 的温度（°C）。t 从进入该地层起算，单位秒。
function p.eval(name, t)
    local curve = resolve(name)
    if not curve then
        return nil
    end
    return eval_curve(curve, tonumber(t) or 0)
end

-- 某地层在时刻 t 的温度变化率（°C/秒）。
function p.derivative(name, t)
    local curve = resolve(name)
    if not curve then
        return nil
    end
    return slope_curve(curve, tonumber(t) or 0)
end

-- 同上，但换成 °C/分钟，供表格直接显示。
function p.rate(name, t)
    local value = p.derivative(name, t)
    if value == nil then
        return nil
    end
    return value * 60
end

function p.period(name)
    local curve = resolve(name)
    if not curve then
        return nil
    end
    return period_of(curve)
end

function p.period_label(name)
    local seconds = p.period(name)
    if not seconds then
        return nil
    end
    return format_time(seconds)
end

-- 折线图用的采样序列。返回 { {t, 温度}, ... }，t 为秒。
-- options.count 采样段数（默认 240，产出 count+1 个点）
-- options.from / options.to 覆盖时间范围；恒定曲线默认取 0..300
function p.series(name, options)
    local curve = resolve(name)
    if not curve then
        return nil
    end
    options = options or {}

    local count = math.max(2, math.floor(tonumber(options.count) or 240))
    local from = tonumber(options.from) or 0
    local to = tonumber(options.to) or period_of(curve)
    if not to or to <= from then
        to = tonumber(options.span) or 300
    end

    local result = {}
    for i = 0, count do
        local t = from + (to - from) * i / count
        result[i + 1] = { t, eval_curve(curve, t) }
    end
    return result
end

-- 横向表格用的行。取关键帧时间、折返点，并在过长的段内补点，
-- 保证不会漏掉任何极值（极值只会出现在关键帧上）。
-- 返回 { {时间标签, 温度, 变化率(°C/分), t}, ... }
function p.rows(name, options)
    local curve = resolve(name)
    if not curve then
        return nil
    end
    options = options or {}

    local period = period_of(curve)
    local span = period or tonumber(options.span) or 300
    local max_gap = tonumber(options.max_gap) or (span / 12)

    local marks = { [0] = true }
    if curve.minAt then marks[curve.minAt] = true end
    if curve.maxAt then marks[curve.maxAt] = true end
    if period then
        marks[period] = true
        for _, key in ipairs(curve.keys) do
            local offset = key[1] - curve.keys[1][1]
            marks[offset] = true
            marks[period - offset] = true
        end
    else
        for _, key in ipairs(curve.keys) do
            marks[key[1] - curve.keys[1][1]] = true
        end
    end

    local times = {}
    for t in pairs(marks) do
        if t >= 0 and t <= span then
            times[#times + 1] = t
        end
    end
    table.sort(times)

    -- 段内补点
    local filled = { times[1] }
    for i = 2, #times do
        local prev, cur = times[i - 1], times[i]
        local gaps = math.floor((cur - prev) / max_gap + 0.5)
        for step = 1, gaps - 1 do
            filled[#filled + 1] = prev + (cur - prev) * step / gaps
        end
        filled[#filled + 1] = cur
    end

    -- 按整秒去重
    local result, seen = {}, {}
    for _, t in ipairs(filled) do
        local second = math.floor(t + 0.5)
        if not seen[second] then
            seen[second] = true
            result[#result + 1] = {
                format_time(second),
                eval_curve(curve, t),
                slope_curve(curve, t) * 60,
                t,
            }
        end
    end
    return result
end

return p
