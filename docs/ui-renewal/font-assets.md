# UI-01 bundled font assets

Prepared from project base `667f134a72d747c78a11a10544c2cdf929b649bb` on 12 September 2026. This change adds ten **static TrueType** resources and their source licences/provenance. Kotlin family selection, Compose mapping, Android loading, script shaping and visual acceptance belong to the coordinator's UI-01 checks.

## Sources and licences

All four source fonts, `METADATA.pb` files and OFL notices come from the same pinned [official Google Fonts revision](https://github.com/google/fonts/tree/809e4d8b8d7e9364a914909bb777679606c178b8), `809e4d8b8d7e9364a914909bb777679606c178b8`. Immutable download URLs and SHA-256 values for all twelve input files are in `app/src/main/assets/font_licenses/provenance.json`.

| Source at `ofl/` | Embedded version | Axis pins | Input SHA-256 |
| --- | --- | --- | --- |
| `spacegrotesk/SpaceGrotesk[wght].ttf` | 2.000 | `wght=600` | `acad6de1fc93436f5c0f1f4137751ef04f1aea3063e7036535970ffcfbd79f72` |
| `inter/Inter[opsz,wght].ttf` | 4.001; git-66647c0bb | `opsz=14`, `wght=400/500/600` | `29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031` |
| `notosansdevanagari/NotoSansDevanagari[wdth,wght].ttf` | 2.007 | `wdth=100`, `wght=400/500/600` | `14ec4af41f27482216d1c2229f417ff9b1425e1babb014e57d1d40d03229853e` |
| `notosanstelugu/NotoSansTelugu[wdth,wght].ttf` | 2.005 | `wdth=100`, `wght=400/500/600` | `e618af7bf999df192ed4f388eba2e563f2b5015034e9cbb317b5bd793bd7334d` |

The full SIL OFL 1.1 notices are retained byte-for-byte as `space_grotesk_OFL.txt`, `inter_OFL.txt`, `noto_sans_devanagari_OFL.txt` and `noto_sans_telugu_OFL.txt` under `app/src/main/assets/font_licenses/`. The pinned notices and embedded copyright headers declare no Reserved Font Names. Original embedded copyrights are preserved, including Inter's 2016 embedded notice and its upstream 2020 OFL-file notice; these are not silently rewritten to agree.

These resources are derived static instances, not byte-identical upstream static releases. No glyphs were subsetted or intentionally dropped. Inter's optical size is fixed at its source default 14 for the body/control family. Noto width is fixed at the normal-width source default 100. Every variation axis is pinned; the app does not need variable-font interpolation or a font download provider.

Space Grotesk requires an explicit naming step: its upstream STAT table has no 600 name, and `updateFontNames=True` correctly rejects that position. Its outlines were first interpolated at **actual `wght=600`**. The derived result then received accurate SemiBold family/style/PostScript names (IDs 1, 2, 3, 4, 6, 16, 17, shown in the manifest). It is not the 500 or 700 file renamed to 600. Other families use `updateFontNames=True` from their upstream STAT data.

## Resources

All filenames are under `app/src/main/res/font/`; use the basename as the Android resource name. Declare the recorded weight explicitly when the coordinator maps each resource.

| Resource | Weight | Bytes | SHA-256 |
| --- | --- | --- | --- |
| `space_grotesk_semibold.ttf` | 600 | 88,484 | `628aa7932313932bf2eb26cac27dd7e49dd6147f026d389ba0298c6eed2d115c` |
| `inter_regular.ttf` | 400 | 341,396 | `0b59f6b6fc9e8a9ad8032802d1797c4237d9288a3e7b7661517070627b577060` |
| `inter_medium.ttf` | 500 | 342,004 | `8999f916eb8d3c9c7094ad352846801099d5736287065ef1e87cb49c204df10d` |
| `inter_semibold.ttf` | 600 | 342,688 | `b5996a92e34bb74df9080bf429c33cbed0d3b911926659fcf8b8871ac15ca8a4` |
| `noto_sans_devanagari_regular.ttf` | 400 | 218,236 | `c08b31cb15937175a62a2ad3a2659b78a0330395213f0e9c424b3b0c3635336a` |
| `noto_sans_devanagari_medium.ttf` | 500 | 218,828 | `9534686897d72379dd59016943d52254f5bf4bfda0c1d2793bd34c23035ed0af` |
| `noto_sans_devanagari_semibold.ttf` | 600 | 218,928 | `ae09f52a9d72d2c1dc78debb0875acfa897b3f126688fd1261e2a3ab19f3a7c7` |
| `noto_sans_telugu_regular.ttf` | 400 | 208,876 | `a31abec3733818aa43af99dd3814aa59ad9780bd6cdba2bb2b4805a1f9c25753` |
| `noto_sans_telugu_medium.ttf` | 500 | 209,584 | `dda46ac5bebff2b5d5054431908020c42b7c4a8ab5042ccd38fd057f1274f617` |
| `noto_sans_telugu_semibold.ttf` | 600 | 209,644 | `2e6c8e9f2e7dbe74892b95bd9ebc34ed6dcd1e1c21e639a2359fd07e97bc0847` |

Font binaries total **2,398,668 bytes** before APK compression. Sources and build tooling remain outside the app; only fonts, four notices and a provenance manifest are bundled.

## Pinned build process

The laptop's existing Python runtime lacked fontTools. The coordinator authorized one isolated task installation under `C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/font-build-tools/`; no global Python package or Android dependency was changed.

- Python: **3.12.14**.
- [fontTools](https://pypi.org/project/fonttools/4.65.0/): **4.65.0**, pure Python wheel `fonttools-4.65.0-py3-none-any.whl`.
- Wheel SHA-256: `3060b8c1fc2329fa20265b7c138614143ea7c1624e26c5c180c76aeb74deae6f`.
- Wheel URL: `https://files.pythonhosted.org/packages/e6/35/f894ceb867118c0261d0f69a9bd516b045a3754238f76c88a49513ac7a83/fonttools-4.65.0-py3-none-any.whl`.
- Installer flags: `--target <task-tool-root>/fonttools-4.65.0 --no-deps --no-compile --require-hashes --only-binary=:all: --disable-pip-version-check --no-cache-dir`.
- Requirements line: the exact wheel URL above using `fonttools @ <URL> --hash=sha256:<wheel hash>`.

The executed task commands were:

```powershell
$fontPython = 'C:/Users/lokes/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$fontToolsRoot = 'C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/font-build-tools'
& $fontPython -m pip install --target "$fontToolsRoot/fonttools-4.65.0" --no-deps --no-compile --require-hashes --only-binary=:all: --disable-pip-version-check --no-cache-dir -r "$fontToolsRoot/requirements-fonttools.txt"
& $fontPython "$fontToolsRoot/prepare_font_assets.py" inspect
& $fontPython "$fontToolsRoot/prepare_font_assets.py" build
& $fontPython "$fontToolsRoot/prepare_font_assets.py" publish
```

`inspect` downloaded and checked the source notices, names, axes and cmap samples. `build` made staged instances and validated them; `publish` repeated the deterministic build and copied only validated files after the coordinator released the build freeze. Local JSON reports are under the task-tool root. The build uses the [fontTools static instancer](https://fonttools.readthedocs.io/en/latest/varLib/instancer.html), `inplace=False`, `optimize=True`, and `recalcTimestamp=False`; source timestamps are retained for byte reproducibility.

For a portable reproduction, save the following as a **task-only** `rebuild_fonts.py`. Supply the checkout path, the pinned fontTools installation path and an output directory outside the checkout. It downloads only manifest-pinned inputs, verifies hashes, reproduces every static font and compares output hashes; it does not replace app files.

```python
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path
import sys
from urllib.request import Request, urlopen

repo, tool_path, output = map(Path, sys.argv[1:4])
sys.path.insert(0, str(tool_path))
import fontTools
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

assert fontTools.__version__ == "4.65.0"
manifest = json.loads((repo / "app/src/main/assets/font_licenses/provenance.json").read_text(encoding="utf-8"))
assert manifest["google_fonts_revision"] == "809e4d8b8d7e9364a914909bb777679606c178b8"
output.mkdir(parents=True, exist_ok=True)
inputs = {}
for source in manifest["source_files"]:
    with urlopen(Request(source["url"], headers={"User-Agent": "EquipSeva-font-reproduction"}), timeout=30) as response:
        data = response.read()
    assert sha256(data).hexdigest() == source["sha256"]
    inputs[(source["family"], source["file"])] = data

for row in manifest["static_fonts"]:
    source = inputs[(row["family"], row["source_file"])]
    manual_name = row["file"] == "space_grotesk_semibold.ttf"
    with TTFont(BytesIO(source), checkChecksums=2, recalcTimestamp=False) as variable:
        assert set(row["source_axes"]) == {a.axisTag for a in variable["fvar"].axes}
        instance = instantiateVariableFont(
            variable, row["source_axes"], inplace=False,
            optimize=True, updateFontNames=not manual_name,
        )
        if manual_name:
            names = {
                1: "Space Grotesk SemiBold",
                2: "Regular",
                3: "2.000;FK;SpaceGrotesk-SemiBold;EquipSevaStatic-600",
                4: "Space Grotesk SemiBold",
                6: "SpaceGrotesk-SemiBold",
                16: "Space Grotesk",
                17: "SemiBold",
            }
            instance["name"].names = [n for n in instance["name"].names if n.nameID not in names]
            for name_id, value in names.items():
                instance["name"].setName(value, name_id, 3, 1, 0x0409)
                instance["name"].setName(value, name_id, 1, 0, 0)
        assert instance.getBestCmap() == variable.getBestCmap()
        assert instance["OS/2"].usWeightClass == row["weight"]
        assert "fvar" not in instance
        instance.recalcTimestamp = False
        path = output / row["file"]
        instance.save(path)
    assert sha256(path.read_bytes()).hexdigest() == row["sha256"], row["file"]
    print(row["file"], "SHA-256 matches")
```

Example command after creating that task-only script:

```powershell
& $fontPython "$fontToolsRoot/rebuild_fonts.py" 'C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-auth-integration-20260911' "$fontToolsRoot/fonttools-4.65.0" "$fontToolsRoot/reproduced"
```

## Asset checks and limits

All ten generated files passed sfnt signature, table decompilation/checksums, whole-file checksum (`0xB1B0AFBA`), actual OS/2 weight, normal width, upright flags and absence of remaining variation tables. GSUB/GPOS and cmap tables are retained; source cmap mappings match before serialization. The manifest records per-file glyph/codepoint counts, script tags, names, table lists and output hashes.

**16 applicable sample-coverage checks passed, zero missing codepoints**:

- Every font: `EquipSeva Ravi Kumar Job #123 0123456789 ₹1,234.50 – — ’ •`.
- Each Devanagari weight: `EquipSeva गणेश शर्मा सेवा अस्पताल इंजीनियर ₹१२३.४५ 123`.
- Each Telugu weight: `EquipSeva గణేశ్ నాయిక్ సేవ ఆసుపత్రి ఇంజినీర్ ₹౧౨౩.౪౫ 123`.

These checks establish asset structure, metadata and the listed glyph mappings. They do **not** establish Indic shaping, conjunct placement, bidirectional behavior, fallback order, clipping, line height, TalkBack, Android API-26 Typeface loading, or rendered Compose quality. Bundling two same-weight families does not prove automatic cross-script fallback. A Hindi or Telugu family may cover the Latin portion of its mixed sample; that does not mean Inter or Space Grotesk covers Indic text, or that either Noto font covers the other Indic script.

No Gradle/device work or real-account test was run by this font-assets task. The coordinator owns real resource loading, locale/mixed-script mapping, screenshots and independent critic/QA acceptance. No app release score is claimed here.
