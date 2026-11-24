"""构建产物与 Lua 实现的测试。"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

from wikilayertemp import lua as lua_writer
from wikilayertemp.cli import analyse, render_module
from wikilayertemp.sources import build_curves, load_layer_meta, load_raw

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw" / "TempCurves_All_20261122_001326.json"
LAYERS = ROOT / "data" / "layers.json"
API = ROOT / "lua" / "runtime" / "api.lua"
GENERATED = ROOT / "lua" / "generated" / "Module_Data_Layer_Temperature.lua"


@pytest.fixture(scope="module")
def rendered() -> str:
    text, _ = render_module(RAW, LAYERS, API, stamp=None)
    return text


def test_all_layers_present(rendered: str):
    meta = load_layer_meta(LAYERS)
    for row in meta.values():
        assert f'id = "{row["id"]}"' in rendered
    assert len(re.findall(r'^        id = "', rendered, re.M)) == len(meta)


def test_key_counts(rendered: str):
    curves = build_curves(load_raw(RAW))
    meta = load_layer_meta(LAYERS)
    for curve in curves:
        block = rendered.split(f'id = "{meta[curve.layer]["id"]}"', 1)[1].split("    },", 1)[0]
        keys = re.findall(r"^            \{ .* \},$", block, re.M)
        assert len(keys) == len(curve.keys)


def test_report_has_no_errors():
    rows, notes = analyse(build_curves(load_raw(RAW)), load_layer_meta(LAYERS))
    assert len(rows) == 12
    assert all(r["sampleMaxDeviation"] < 0.01 for r in rows)
    assert any("samples.count" in note for note in notes)


def test_generated_file_is_up_to_date(rendered: str):
    """仓库里的生成物必须与当前源码一致（改代码后忘记 build 会在这里失败）。"""
    if not GENERATED.exists():
        pytest.skip("还没有生成物")
    current = GENERATED.read_text(encoding="utf-8")
    strip = lambda text: re.sub(r"-- 生成时间：.*\n", "", text)  # noqa: E731
    assert strip(current) == strip(rendered)


@pytest.mark.skipif(not shutil.which("luajit"), reason="没有 luajit")
def test_lua_module_runs():
    if not GENERATED.exists():
        pytest.skip("还没有生成物")
    probe = ROOT / ".probe.lua"
    probe.write_text(
        """
local mod = dofile(arg[1])
local out = {}
for _, curve in ipairs(mod.all()) do
  out[#out + 1] = string.format("%s %.4f %d %d %d",
    curve.id, mod.eval(curve.id, 0),
    #mod.series(curve.id, {count = 12, extremes = false}),
    #mod.series(curve.id, {count = 12}),
    #mod.rows(curve.id))
end
print(table.concat(out, "\\n"))
""",
        encoding="utf-8",
    )
    try:
        proc = subprocess.run(
            ["luajit", str(probe), str(GENERATED)], capture_output=True, text=True, check=True
        )
    finally:
        probe.unlink(missing_ok=True)

    lines = proc.stdout.strip().splitlines()
    assert len(lines) == 12
    curves = {c.layer: c for c in build_curves(load_raw(RAW))}
    meta = load_layer_meta(LAYERS)
    by_id = {row["id"]: curves[row["layer"]] for row in meta.values()}
    for line in lines:
        layer_id, value, plain_len, with_ext, rows_len = line.split()
        assert float(value) == pytest.approx(by_id[layer_id].eval(0.0), abs=1e-3)
        assert int(plain_len) == 13  # count + 1，不含极值点
        # 非恒定曲线会额外插入 1~2 个真实极值点
        assert 13 <= int(with_ext) <= 15
        assert int(rows_len) >= 1
