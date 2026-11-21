"""命令行入口：把插件导出的 JSON 编译成 wiki 用的 Lua 数据模块。

    python3 -m wikilayertemp build      # 生成 lua/generated/... 并输出报告
    python3 -m wikilayertemp verify     # 只用采样点校验算法（不需要 Lua）
    python3 -m wikilayertemp luatest    # 用 luajit 实跑生成的模块（可选）
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from . import lua as lua_writer
from .curve import LayerCurve
from .sources import SourceError, build_curves, load_layer_meta, load_raw

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_RAW = ROOT / "data" / "raw" / "TempCurves_All_20261122_001326.json"
DEFAULT_LAYERS = ROOT / "data" / "layers.json"
DEFAULT_API = ROOT / "lua" / "runtime" / "api.lua"
DEFAULT_OUT = ROOT / "lua" / "generated" / "Module_Data_Layer_Temperature.lua"
DEFAULT_REPORT = ROOT / "data" / "build-report.json"


def normalize_title(text: str) -> str:
    return re.sub(r"\s+", "", text or "")


def mmss(seconds: float) -> str:
    total = int(round(seconds))
    return f"{total // 60}:{total % 60:02d}"


def sample_deviation(curve: LayerCurve) -> tuple[float, int]:
    worst = 0.0
    for t, v in curve.samples:
        worst = max(worst, abs(curve.eval(t) - v))
    return worst, len(curve.samples)


def analyse(curves: list[LayerCurve], meta: dict[int, dict]) -> tuple[list[dict], list[str]]:
    rows: list[dict] = []
    notes: list[str] = []
    missing = sorted(set(c.layer for c in curves) - set(meta))
    if missing:
        raise SourceError(f"layers.json 缺少这些层的映射：{missing}")

    for curve in curves:
        row = meta[curve.layer]
        warnings: list[str] = []
        period = curve.period()
        low, high, at_low, at_high = curve.scan()
        worst, sample_len = sample_deviation(curve)

        expected = normalize_title(row.get("titlePattern") or row["cn"])
        actual = normalize_title(curve.source_title)
        if not actual.startswith(expected):
            warnings.append(f"导出标题 {curve.source_title!r} 与映射表 {row['cn']!r} 不一致")

        if curve.t0 > 0:
            warnings.append(
                f"首个关键帧在 {curve.t0:g}s，之前由 preWrap={curve.pre_wrap} 决定取值"
            )

        if curve.post_wrap in ("Once", "Default"):
            warnings.append(f"postWrap={curve.post_wrap} 按钳制处理")

        if worst > 0.01:
            warnings.append(f"与插件采样点偏差 {worst:.3f}°C，疑似卷绕语义不一致")

        rows.append(
            {
                "layer": curve.layer,
                "id": row["id"],
                "cn": row["cn"],
                "en": row["en"],
                "wikiPage": row.get("wikiPage"),
                "keys": len(curve.keys),
                "t0": round(curve.t0, 3),
                "t1": round(curve.t1, 3),
                "period": None if period is None else round(period, 3),
                "periodLabel": mmss(period) if period else None,
                "min": round(low, 3),
                "max": round(high, 3),
                "minAt": round(at_low, 2),
                "maxAt": round(at_high, 2),
                "samples": sample_len,
                "declaredSampleCount": curve.declared_sample_count,
                "sampleMaxDeviation": round(worst, 6),
                "warnings": warnings,
            }
        )

    counts = {(c.declared_sample_count, len(c.samples)) for c in curves if c.samples}
    for declared, actual in sorted(counts):
        if declared and declared != actual:
            notes.append(
                f"插件写成 samples.count={declared}，实际给了 {actual} 个点：循环是 i <= count，"
                f"所以 data 长度总比声明多一；下游按数组长度而不是 count 字段计算。"
            )
    if any(
        (round(k.in_weight, 6), round(k.out_weight, 6)) != (round(1 / 3, 6), round(1 / 3, 6))
        for c in curves
        for k in c.keys
    ):
        notes.append(
            "部分关键帧的 inWeight/outWeight 不是 1/3；已用插件导出的 101 个采样点验证，"
            "Unity 的取值等效于「按原始切线做埃尔米特、忽略权重」，所以本仓库不处理权重。"
        )
    return rows, notes


def render_module(
    raw_path: Path,
    layers_path: Path,
    api_path: Path,
    stamp: datetime | None = None,
) -> tuple[str, dict]:
    """读取原始导出 + 映射表，产出 Lua 文本与构建报告。build 与测试共用这条路径。"""
    raw = load_raw(raw_path)
    curves = build_curves(raw)
    meta = load_layer_meta(layers_path)
    api_text = lua_writer.load_api(api_path)

    rows, notes = analyse(curves, meta)
    digest = hashlib.sha256(raw_path.read_bytes()).hexdigest()

    text = lua_writer.render(
        curves,
        meta,
        source_name=raw_path.name,
        source_sha256=digest,
        export_time=str(raw.get("exportTime", "unknown")),
        api_text=api_text,
        stamp=stamp,
    )
    report = {
        "source": {
            "file": raw_path.name,
            "sha256": digest,
            "exportTime": raw.get("exportTime"),
            "declaredSampleCount": raw.get("sampleCount"),
            "layers": len(curves),
        },
        "notes": notes,
        "layers": rows,
    }
    return text, report


def cmd_build(args: argparse.Namespace) -> int:
    raw_path = Path(args.raw)
    layers_path = Path(args.layers)
    api_path = Path(args.api)
    stamp = None if args.no_stamp else datetime.now().astimezone()

    text, report = render_module(raw_path, layers_path, api_path, stamp)
    rows = report["layers"]
    notes = report["notes"]

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(text, encoding="utf-8")

    report["output"] = {
        "file": str(out_path.relative_to(ROOT)) if out_path.is_relative_to(ROOT) else str(out_path),
        "bytes": len(text.encode("utf-8")),
    }
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"源：{raw_path.name}（{report['source']['exportTime']}，{report['source']['layers']} 层）")
    print(f"输出：{out_path}（{len(text.encode('utf-8')) / 1024:.1f} KB）")
    print()
    print(f"{'层':<22}{'id':<22}{'关键帧':>4}{'周期':>8}{'最低':>8}{'最高':>8}{'采样偏差':>9}")
    for row in rows:
        print(
            f"{row['cn']:<22}{row['id']:<22}{row['keys']:>4}"
            f"{row['periodLabel'] or '—':>8}{row['min']:>8.2f}{row['max']:>8.2f}"
            f"{row['sampleMaxDeviation']:>9.4f}"
        )
    warn = [(r["cn"], w) for r in rows for w in r["warnings"]]
    if warn:
        print()
        for cn, text_ in warn:
            print(f"  ! {cn}：{text_}")
    if notes:
        print()
        for note in notes:
            print(f"  · {note}")
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    raw = load_raw(Path(args.raw))
    curves = build_curves(raw)
    rows, notes = analyse(curves, load_layer_meta(Path(args.layers)))

    worst = max((r["sampleMaxDeviation"] for r in rows), default=0)
    print("逐层用插件采样点校验埃尔米特 + 卷绕：")
    for row in rows:
        print(f"  {row['cn']:<14} {row['samples']:>4} 点  最大偏差 {row['sampleMaxDeviation']:.6f} °C")
    print(f"\n全局最大偏差 {worst:.6f} °C")
    if worst > 0.01:
        print("失败：偏差超过 0.01 °C，说明算法与游戏不一致。", file=sys.stderr)
        return 1
    print("通过。")
    return 0


def cmd_luatest(args: argparse.Namespace) -> int:
    lua = shutil.which("luajit") or shutil.which("lua5.1") or shutil.which("lua")
    if not lua:
        print("找不到 luajit / lua，跳过。", file=sys.stderr)
        return 0

    generated = Path(args.out)
    if not generated.exists():
        print(f"{generated} 不存在，先跑 build。", file=sys.stderr)
        return 1

    probe = ROOT / ".luatest.lua"
    probe.write_text(
        """
local path = arg[1]
local mod = dofile(path)
local ids = {}
for _, curve in ipairs(mod.all()) do ids[#ids + 1] = curve.id end
for _, id in ipairs(ids) do
  local period = mod.period(id) or 1
  for i = 0, 20 do
    local t = period * i / 20
    print(string.format("%s\\t%.6f\\t%.6f", id, t, mod.eval(id, t)))
  end
end
""",
        encoding="utf-8",
    )
    proc = subprocess.run([lua, str(probe), str(generated)], capture_output=True, text=True)
    probe.unlink(missing_ok=True)
    if proc.returncode != 0:
        print(proc.stdout)
        print(proc.stderr, file=sys.stderr)
        return 1

    raw = load_raw(Path(args.raw))
    curves = {c.layer: c for c in build_curves(raw)}
    meta = load_layer_meta(Path(args.layers))
    by_id = {row["id"]: curves[row["layer"]] for row in meta.values()}

    worst, worst_at, count = 0.0, None, 0
    for line in proc.stdout.strip().splitlines():
        layer_id, t, v = line.split("\t")
        diff = abs(by_id[layer_id].eval(float(t)) - float(v))
        count += 1
        if diff > worst:
            worst, worst_at = diff, (layer_id, float(t))
    print(f"luajit 实跑 {count} 个点，与 Python 参考实现最大偏差 {worst:.6f} °C（{worst_at}）")
    if worst > 1e-4:
        print("失败：Lua 实现与参考实现不一致。", file=sys.stderr)
        return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="wikilayertemp", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    def common(p: argparse.ArgumentParser) -> None:
        p.add_argument("--raw", default=str(DEFAULT_RAW), help="插件导出的 TempCurves_All_*.json")
        p.add_argument("--layers", default=str(DEFAULT_LAYERS), help="地层映射表 layers.json")
        p.add_argument("--api", default=str(DEFAULT_API), help="运行时 Lua 代码 api.lua")
        p.add_argument("--out", default=str(DEFAULT_OUT), help="生成的 Lua 模块路径")
        p.add_argument("--report", default=str(DEFAULT_REPORT), help="构建报告路径")

    p_build = sub.add_parser("build", help="由原始 JSON 生成 Lua 数据模块")
    common(p_build)
    p_build.add_argument("--no-stamp", action="store_true", help="不写入生成时间（便于复现）")
    p_build.set_defaults(func=cmd_build)

    p_verify = sub.add_parser("verify", help="用采样点校验算法")
    common(p_verify)
    p_verify.set_defaults(func=cmd_verify)

    p_lua = sub.add_parser("luatest", help="用 luajit 实跑生成的模块")
    common(p_lua)
    p_lua.add_argument("--tmp-lua", default=None)
    p_lua.set_defaults(func=cmd_luatest)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except SourceError as exc:
        print(f"数据错误：{exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
