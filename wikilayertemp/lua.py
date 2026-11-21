"""把曲线渲染成 wiki 可用的 Lua 模块文本。"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path

from .curve import LayerCurve


def num(value: float) -> str:
    """Lua 数字字面量：7 位有效数字，足够覆盖 Unity 的 float32 精度。"""
    text = f"{value:.7g}"
    if text in ("-0", "-0.0"):
        return "0"
    return text


def quote(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(
    curves: list[LayerCurve],
    meta: dict[int, dict],
    *,
    source_name: str,
    source_sha256: str,
    export_time: str,
    api_text: str,
    stamp: datetime | None = None,
) -> str:
    lines: list[str] = []
    lines.append("-- Module:Data/Layer_Temperature")
    lines.append("-- 各地层的环境温度曲线，供 {{地层温度}} 一系的模板/模块查询。")
    lines.append("--")
    lines.append("-- 本页由 WikiLayerTemperature 生成，请勿手工编辑；要改数据请改仓库后重新生成。")
    lines.append(f"-- 源数据：{source_name}（插件导出时间 {export_time}）")
    lines.append(f"-- 源文件 SHA-256：{source_sha256}")
    if stamp:
        lines.append(f"-- 生成时间：{stamp.strftime('%Y-%m-%dT%H:%M:%S%z')}")
    lines.append("--")
    lines.append("-- 每层的 keys 是 Unity AnimationCurve 的原始关键帧：")
    lines.append("--   { 时间(秒), 温度(°C), 入切线, 出切线 }")
    lines.append("-- 温度由三次埃尔米特插值求出，并按 preWrap/postWrap 折返，")
    lines.append("-- 与游戏里 AmbientTemperature 的取值一致。查询接口见文件末尾。")
    lines.append("")
    lines.append("local data = {")

    for curve in curves:
        row = meta[curve.layer]
        low, high, at_low, at_high = curve.scan()
        period = curve.period()
        lines.append("    {")
        lines.append(f"        id = {quote(row['id'])},")
        lines.append(f"        cn = {quote(row['cn'])},")
        lines.append(f"        en = {quote(row['en'])},")
        lines.append(f"        layer = {curve.layer},")
        lines.append(f"        preWrap = {quote(curve.pre_wrap)},")
        lines.append(f"        postWrap = {quote(curve.post_wrap)},")
        if period:
            lines.append(f"        period = {num(period)},")
        else:
            lines.append("        period = nil,")
        lines.append(f"        minTemp = {num(low)},")
        lines.append(f"        maxTemp = {num(high)},")
        lines.append(f"        minAt = {num(at_low)},")
        lines.append(f"        maxAt = {num(at_high)},")
        lines.append("        keys = {")
        for key in curve.keys:
            lines.append(
                f"            {{ {num(key.time)}, {num(key.value)}, {num(key.in_tangent)}, {num(key.out_tangent)} }},"
            )
        lines.append("        },")
        lines.append("    },")

    lines.append("}")
    lines.append("")
    lines.append(api_text.rstrip("\n"))
    lines.append("")
    return "\n".join(lines)


def load_api(path: Path) -> str:
    return Path(path).read_text(encoding="utf-8")
