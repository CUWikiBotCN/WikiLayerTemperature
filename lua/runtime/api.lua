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

-- 四舍五入到指定位数（负数也正确：-1.234 -> -1.23）
local function round(value, digits)
    local factor = 10 ^ (digits or 0)
    return math.floor(value * factor + 0.5) / factor
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
-- 第三个参数可选：给定时按该位数四舍五入（界面显示用 1~2 位就够）。
function p.eval(name, t, precision)
    local curve = resolve(name)
    if not curve then
        return nil
    end
    local value = eval_curve(curve, tonumber(t) or 0)
    if precision then
        return round(value, tonumber(precision) or 0)
    end
    return value
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
-- options.precision 温度保留位数（默认 2），options.timePrecision 时间保留位数（默认 1）
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

    local precision = tonumber(options.precision) or 2
    local time_precision = tonumber(options.timePrecision) or 1

    local result = {}
    for i = 0, count do
        local t = from + (to - from) * i / count
        result[i + 1] = { round(t, time_precision), round(eval_curve(curve, t), precision) }
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
                round(eval_curve(curve, t), 2),
                round(slope_curve(curve, t) * 60, 2),
                round(t, 1),
            }
        end
    end
    return result
end

return p
