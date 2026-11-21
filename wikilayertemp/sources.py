"""读取插件导出的原始 JSON 与地层映射表。"""

from __future__ import annotations

import json
from pathlib import Path

from .curve import KNOWN_WRAPS, Keyframe, LayerCurve


class SourceError(Exception):
    pass


def load_raw(path: Path) -> dict:
    data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    if "layers" not in data or not isinstance(data["layers"], list):
        raise SourceError(f"{path} 不是 TemperatureMonitor 的批量导出：缺少 layers 数组")
    return data


def build_curves(raw: dict) -> list[LayerCurve]:
    curves: list[LayerCurve] = []
    for entry in raw["layers"]:
        keys = []
        for k in entry["keyframes"]:
            for name in ("time", "value", "inTangent", "outTangent"):
                if name not in k:
                    raise SourceError(f"第 {entry.get('layer')} 层的关键帧缺少 {name}")
            for name in ("time", "value", "inTangent", "outTangent"):
                if not isinstance(k[name], (int, float)) or k[name] != k[name] or abs(k[name]) == float("inf"):
                    raise SourceError(f"第 {entry.get('layer')} 层关键帧的 {name} 不是有限数值：{k[name]!r}")
            keys.append(
                Keyframe(
                    time=float(k["time"]),
                    value=float(k["value"]),
                    in_tangent=float(k["inTangent"]),
                    out_tangent=float(k["outTangent"]),
                    in_weight=float(k.get("inWeight", 1 / 3)),
                    out_weight=float(k.get("outWeight", 1 / 3)),
                )
            )
        if not keys:
            raise SourceError(f"第 {entry.get('layer')} 层没有任何关键帧")

        times = [k.time for k in keys]
        if any(b <= a for a, b in zip(times, times[1:])):
            raise SourceError(f"第 {entry.get('layer')} 层的关键帧时间不是严格递增：{times}")

        for name in ("preWrapMode", "postWrapMode"):
            mode = entry.get(name)
            if mode not in KNOWN_WRAPS:
                raise SourceError(f"第 {entry.get('layer')} 层的 {name} 未知：{mode!r}")

        samples_entry = entry.get("samples") or {}
        samples = [(float(p["t"]), float(p["v"])) for p in samples_entry.get("data", [])]

        curves.append(
            LayerCurve(
                layer=int(entry["layer"]),
                source_title=str(entry.get("title", "")),
                pre_wrap=entry["preWrapMode"],
                post_wrap=entry["postWrapMode"],
                keys=keys,
                samples=samples,
                declared_sample_count=int(samples_entry.get("count", 0)),
            )
        )
    curves.sort(key=lambda c: c.layer)
    return curves


def load_layer_meta(path: Path) -> dict[int, dict]:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    meta: dict[int, dict] = {}
    for row in data["layers"]:
        idx = int(row["layer"])
        if idx in meta:
            raise SourceError(f"layers.json 中第 {idx} 层重复")
        for field in ("id", "cn", "en"):
            if not row.get(field):
                raise SourceError(f"layers.json 中第 {idx} 层缺少 {field}")
        meta[idx] = row
    return meta
