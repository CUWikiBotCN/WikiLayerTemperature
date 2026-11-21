"""曲线数学的单元测试：埃尔米特、卷绕、极值。"""

from __future__ import annotations

import math
from pathlib import Path

import pytest

from wikilayertemp.curve import Keyframe, LayerCurve
from wikilayertemp.sources import build_curves, load_raw

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw" / "TempCurves_All_20261122_001326.json"


def make(keys, pre="ClampForever", post="ClampForever"):
    return LayerCurve(
        layer=0,
        source_title="test",
        pre_wrap=pre,
        post_wrap=post,
        keys=[Keyframe(*k) for k in keys],
    )


def test_linear_segment():
    # 切线等于斜率时，三次埃尔米特退化成直线
    curve = make([(0.0, 0.0, 1.0, 1.0), (10.0, 10.0, 1.0, 1.0)])
    assert curve.eval(5.0) == pytest.approx(5.0)
    assert curve.eval(2.5) == pytest.approx(2.5)
    assert curve.slope(5.0) == pytest.approx(1.0)


def test_clamp_outside_range():
    curve = make([(0.0, 10.0, 0.0, 0.0), (10.0, 20.0, 0.0, 0.0)])
    assert curve.eval(-5.0) == pytest.approx(10.0)
    assert curve.eval(15.0) == pytest.approx(20.0)
    assert curve.slope(15.0) == 0.0


def test_pingpong_is_symmetric():
    curve = make(
        [(0.0, 0.0, 0.0, 0.0), (10.0, 10.0, 0.0, 0.0)],
        pre="PingPong",
        post="PingPong",
    )
    assert curve.period() == pytest.approx(20.0)
    for t in (0.0, 2.5, 7.5, 10.0, 15.0):
        assert curve.eval(t) == pytest.approx(curve.eval(20.0 - t))
    assert curve.eval(20.0) == pytest.approx(curve.eval(0.0))
    # 折返后残值是下降的
    assert curve.eval(15.0) == pytest.approx(5.0)


def test_loop_and_period():
    curve = make([(0.0, 0.0, 1.0, 1.0), (10.0, 10.0, 1.0, 1.0)], post="Loop")
    assert curve.period() == pytest.approx(10.0)
    assert curve.eval(12.0) == pytest.approx(curve.eval(2.0))


def test_constant_curve():
    curve = make([(0.0, 15.0, 0.0, 0.0)])
    assert curve.period() is None
    assert curve.eval(123.0) == pytest.approx(15.0)
    assert curve.slope(123.0) == 0.0


def test_pre_wrap_pingpong_before_first_key():
    """首个关键帧不在 0 时，进入地层的最初几秒由 preWrap 决定。"""
    curve = make(
        [(10.0, 30.0, -0.1, -0.1), (20.0, 20.0, -0.1, -0.1)],
        pre="PingPong",
        post="PingPong",
    )
    # t=0 镜像到 2*10-0 = 20 -> 与 t=20 同值
    assert curve.eval(0.0) == pytest.approx(curve.eval(20.0))
    assert curve.eval(0.0) != pytest.approx(30.0)


def test_hermite_matches_plugin_samples():
    """插件用 Unity 的 Evaluate 采样；我们的实现要与它逐点一致。"""
    curves = build_curves(load_raw(RAW))
    assert len(curves) == 12
    for curve in curves:
        assert curve.samples, f"{curve.source_title} 没有采样点"
        for t, v in curve.samples:
            assert curve.eval(t) == pytest.approx(v, abs=1e-3)


def test_extremes_can_exceed_keyframes():
    """曲线会过冲：极值不一定等于关键帧的取值。"""
    curves = {c.layer: c for c in build_curves(load_raw(RAW))}
    overgrown = curves[4]
    key_min = min(k.value for k in overgrown.keys)
    lo, hi, _, _ = overgrown.scan(20000)
    assert lo < key_min - 1.0, "深林丛渊的过冲低于关键帧最小值"
    assert math.isfinite(lo) and math.isfinite(hi)
