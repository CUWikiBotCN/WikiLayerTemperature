"""温度曲线模型：Unity AnimationCurve 的关键帧 + 卷绕语义。

这里实现的是「游戏里 AmbientTemperature 实际取到的值」的还原：
三次埃尔米特插值 + pre/postWrapMode 折返。与 lua/runtime/api.lua 中的算法逐行对应，
tests/ 里会用插件导出的 101 个采样点做交叉验证。
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field


KNOWN_WRAPS = {"Loop", "PingPong", "ClampForever", "Once", "Default"}


@dataclass(frozen=True)
class Keyframe:
    time: float
    value: float
    in_tangent: float
    out_tangent: float
    in_weight: float = 1 / 3
    out_weight: float = 1 / 3


@dataclass
class LayerCurve:
    layer: int
    source_title: str
    pre_wrap: str
    post_wrap: str
    keys: list[Keyframe]
    samples: list[tuple[float, float]] = field(default_factory=list)
    declared_sample_count: int = 0

    def __post_init__(self) -> None:
        self.keys.sort(key=lambda k: k.time)

    # -- 基本量 ---------------------------------------------------------

    @property
    def t0(self) -> float:
        return self.keys[0].time

    @property
    def t1(self) -> float:
        return self.keys[-1].time

    def period(self) -> float | None:
        """往返/循环一个完整周期所需秒数；恒定曲线（端点重合）返回 None。"""
        span = self.t1 - self.t0
        if span <= 0:
            return None
        if self.post_wrap == "PingPong":
            return 2 * span
        if self.post_wrap == "Loop":
            return span
        return None

    # -- 卷绕 -----------------------------------------------------------

    def _mirror(self, t: float) -> float:
        span = self.t1 - self.t0
        if span <= 0:
            return self.t0
        phase = (t - self.t0) % (2 * span)
        if phase > span:
            phase = 2 * span - phase
        return self.t0 + phase

    def wrap_time(self, t: float) -> tuple[float, bool]:
        """把时刻折回关键帧区间。第二项为 True 表示被钳在端点。"""
        span = self.t1 - self.t0
        if span <= 0:
            return self.t0, True

        if t < self.t0:
            if self.pre_wrap == "Loop":
                return self.t0 + (t - self.t0) % span, False
            if self.pre_wrap == "PingPong":
                return self._mirror(t), False
            return self.t0, True

        if t > self.t1:
            if self.post_wrap == "Loop":
                return self.t0 + (t - self.t0) % span, False
            if self.post_wrap == "PingPong":
                return self._mirror(t), False
            return self.t1, True

        return t, False

    # -- 求值 -----------------------------------------------------------

    def _segment(self, t: float) -> tuple[Keyframe, Keyframe]:
        keys = self.keys
        lo, hi = 0, len(keys) - 1
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if keys[mid].time <= t:
                lo = mid
            else:
                hi = mid
        return keys[lo], keys[lo + 1]

    def eval(self, t: float) -> float:
        if len(self.keys) == 1:
            return self.keys[0].value

        tt, clamped = self.wrap_time(t)
        if clamped:
            return self.keys[0].value if tt <= self.t0 else self.keys[-1].value

        a, b = self._segment(tt)
        span = b.time - a.time
        if span <= 0:
            return b.value

        u = (tt - a.time) / span
        u2 = u * u
        u3 = u2 * u
        h00 = 2 * u3 - 3 * u2 + 1
        h10 = u3 - 2 * u2 + u
        h01 = -2 * u3 + 3 * u2
        h11 = u3 - u2
        return h00 * a.value + h10 * a.out_tangent * span + h01 * b.value + h11 * b.in_tangent * span

    def slope(self, t: float) -> float:
        """温度变化率，°C/秒。"""
        if len(self.keys) == 1:
            return 0.0

        tt, clamped = self.wrap_time(t)
        if clamped:
            return 0.0

        a, b = self._segment(tt)
        span = b.time - a.time
        if span <= 0:
            return 0.0

        u = (tt - a.time) / span
        u2 = u * u
        dh00 = 6 * u2 - 6 * u
        dh10 = 3 * u2 - 4 * u + 1
        dh01 = -6 * u2 + 6 * u
        dh11 = 3 * u2 - 2 * u
        return (dh00 * a.value + dh10 * a.out_tangent * span + dh01 * b.value + dh11 * b.in_tangent * span) / span

    # -- 派生视图 -------------------------------------------------------

    def scan(self, steps: int = 4000) -> tuple[float, float, float, float]:
        """在一个周期内扫描，返回 (最低温, 最高温, 最低温时刻, 最高温时刻)。

        注意：极值不一定落在关键帧上——切线较大的段会过冲出关键帧的取值范围，
        所以这里用扫描而不是直接取关键帧的 min/max。
        """
        period = self.period()
        span = period if period else max(self.t1 - self.t0, 1.0)
        lo, hi = math.inf, -math.inf
        at_lo = at_hi = 0.0
        for i in range(steps + 1):
            t = span * i / steps
            v = self.eval(t)
            if v < lo:
                lo, at_lo = v, t
            if v > hi:
                hi, at_hi = v, t
        return lo, hi, at_lo, at_hi
