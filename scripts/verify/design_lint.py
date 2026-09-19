#!/usr/bin/env python3
"""Design-lint ratchet for the EquipSeva Android app.

Counts design-system "negative" signals (raw dp/sp, raw Material3 widgets,
legacy colour tokens, hardcoded UI text, ...) across
``app/src/main/kotlin/com/equipseva/app/features`` and compares them to a
committed baseline. A negative count that rises above its baseline fails the
check; the design system is meant to be adopted file by file, and this stops
new raw usages from sneaking into files that were already migrated.

"Positive" signals (Es* components, Spacing/EsType/EsRadius tokens, motion,
skeletons, previews) are counted too, for the progress table only; they never
fail the check.

Comments are stripped before matching so commented-out code is not counted.
String contents are kept, so ``Text("...")`` literals still register.

Usage (repo root is resolved from this file, so any cwd works):

    python3 scripts/verify/design_lint.py                  # check vs baseline
    python3 scripts/verify/design_lint.py --write-baseline # refresh baseline
    python3 scripts/verify/design_lint.py --markdown       # table for the docs
    python3 scripts/verify/design_lint.py --json           # current counts
    python3 scripts/verify/design_lint.py --baseline-file PATH

Refresh the baseline only in the same commit that lowers the numbers, and say
so in the commit body. Never refresh it to make a regression pass.

Exit codes:
    0  every negative signal is at or below its baseline
       (also: --write-baseline / --json completed)
    1  at least one negative signal rose above its baseline
    2  baseline file missing or unreadable (run --write-baseline first)
"""

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
APP_PACKAGE_DIR = REPO_ROOT / "app" / "src" / "main" / "kotlin" / "com" / "equipseva" / "app"
FEATURES_DIR = APP_PACKAGE_DIR / "features"
DESIGNSYSTEM_DIR = APP_PACKAGE_DIR / "designsystem"
DEFAULT_BASELINE_PATH = Path(__file__).resolve().parent / "design_lint.baseline.json"

THEME_IMPORT_PREFIX = r"^import com\.equipseva\.app\.designsystem\.theme\."

# The pre-Seva palette from designsystem/theme/Color.kt. Any import of these
# from a feature file means that file still speaks the old visual language.
LEGACY_TOKEN_NAMES = [
    "BrandGreen", "BrandGreenDark", "BrandGreenLight", "BrandGreen50", "BrandGreen100",
    "BrandGreenDeep", "AccentLime", "AccentLimeBright", "AccentLimeSoft", "Color98Green",
    "Ink900", "Ink800", "Ink700", "Ink500", "Ink400", "Ink300",
    "Surface0", "Surface50", "Surface100", "Surface200", "Outline", "InkSurface",
    "Success", "SuccessBg", "Warning", "WarningBg", "Info", "InfoBg", "ErrorRed", "ErrorBg",
]
LEGACY_IMPORT = re.compile(
    THEME_IMPORT_PREFIX + r"(?:" + "|".join(LEGACY_TOKEN_NAMES) + r")\s*$", re.MULTILINE
)
MODERN_TOKEN_IMPORT = re.compile(
    THEME_IMPORT_PREFIX + r"(?:Seva\w*|Paper\w*|Border\w*|EsType|EsRadius|Spacing)\s*$",
    re.MULTILINE,
)

# Raw Material3 Button( / TextField( must not match the design-system wrappers
# or the other M3 variants (IconButton, FilledTonalButton, OutlinedTextField,
# BasicTextField ...). A plain identifier boundary does that; the second
# lookbehind keeps fully-qualified androidx.compose.material3.X( calls, which
# some screens use to dodge an import clash with the Es* wrapper.
M3_UNQUALIFIED_OR_MATERIAL3 = r"(?:(?<![A-Za-z0-9_.])|(?<=material3\.))"

NEGATIVE_SIGNALS = {
    "raw_dp": re.compile(r"\b\d+(?:\.\d+)?\.dp\b"),
    "raw_sp": re.compile(r"\b\d+(?:\.\d+)?\.sp\b"),
    "font_size_assign": re.compile(r"\bfontSize\s*="),
    "raw_color_hex": re.compile(r"\bColor\(0x"),
    "raw_rounded_corner": re.compile(r"\bRoundedCornerShape\("),
    "m3_button": re.compile(M3_UNQUALIFIED_OR_MATERIAL3 + r"Button\("),
    "m3_text_button": re.compile(r"\bTextButton\("),
    "m3_outlined_button": re.compile(r"\bOutlinedButton\("),
    "m3_text_field": re.compile(M3_UNQUALIFIED_OR_MATERIAL3 + r"TextField\("),
    "m3_outlined_text_field": re.compile(r"\bOutlinedTextField\("),
    "spinner": re.compile(r"\bCircularProgressIndicator\("),
    "legacy_token_imports": LEGACY_IMPORT,
}
# Derived negative signals that count files rather than occurrences.
FILE_COUNT_SIGNALS = ["legacy_token_files", "legacy_only_files"]
# Needs per-line context (a stringResource( on the same line excuses it).
HARDCODED_TEXT_SIGNAL = "hardcoded_text"
HARDCODED_TEXT = re.compile(r"\bText\(\s*\"")

NEGATIVE_SIGNAL_ORDER = list(NEGATIVE_SIGNALS) + FILE_COUNT_SIGNALS + [HARDCODED_TEXT_SIGNAL]

POSITIVE_SIGNALS = {
    "motion_tokens": re.compile(r"\bMotion(?:Duration|Easing)\."),
    "es_btn": re.compile(r"\bEsBtn\("),
    "es_field": re.compile(r"\bEsField\("),
    "spacing_tokens": re.compile(r"\bSpacing\."),
    "es_radius": re.compile(r"\bEsRadius\."),
    "es_type": re.compile(r"\bEsType\."),
    "animated_visibility": re.compile(r"\bAnimatedVisibility\("),
    "animate_content_size": re.compile(r"\banimateContentSize\("),
    "animated_content": re.compile(r"\bAnimatedContent\("),
    "skeletons": re.compile(r"\b(?:ListSkeleton|ShimmerBox|ShimmerLine|ShimmerListItem)\("),
    # Whitespace lives inside the lookahead: with `=\s*(?!null)` the \s* can
    # match zero characters and the lookahead then sees " null", so every
    # null description would be counted as meaningful.
    "content_description_meaningful": re.compile(r"contentDescription\s*=(?!\s*null\b)"),
    "content_description_null": re.compile(r"contentDescription\s*=\s*null"),
    "test_tags": re.compile(r"\.testTag\("),
}
# Counted over designsystem/ instead of features/: previews belong on components.
DESIGNSYSTEM_POSITIVE_SIGNALS = {
    "previews": re.compile(r"@Preview\b"),
}
POSITIVE_SIGNAL_ORDER = list(POSITIVE_SIGNALS) + list(DESIGNSYSTEM_POSITIVE_SIGNALS)


def strip_comments(source):
    """Blank out // and /* */ comments, preserving length and newlines.

    Strings, raw strings, char literals and ${...} templates are tracked so a
    "//" inside a URL literal or a '"' char literal does not derail the scan.
    Kotlin block comments nest, so depth is tracked rather than stopping at
    the first */.
    """
    output = []
    position = 0
    length = len(source)
    # Each entry is [kind, brace_depth]; templates push a nested "code" frame.
    frames = [["code", 0]]

    while position < length:
        kind = frames[-1][0]
        char = source[position]
        next_char = source[position + 1] if position + 1 < length else ""

        if kind == "code":
            if char == "/" and next_char == "/":
                end = source.find("\n", position)
                if end == -1:
                    end = length
                output.append(" " * (end - position))
                position = end
            elif char == "/" and next_char == "*":
                depth = 1
                end = position + 2
                while end < length and depth:
                    if source.startswith("/*", end):
                        depth += 1
                        end += 2
                    elif source.startswith("*/", end):
                        depth -= 1
                        end += 2
                    else:
                        end += 1
                output.append("".join("\n" if c == "\n" else " " for c in source[position:end]))
                position = end
            elif char == '"':
                if source.startswith('"""', position):
                    frames.append(["raw_string", 0])
                    output.append('"""')
                    position += 3
                else:
                    frames.append(["string", 0])
                    output.append(char)
                    position += 1
            elif char == "'":
                end = position + 1
                if end < length and source[end] == "\\":
                    end += 2
                    if source[end - 1] == "u":
                        end += 4
                else:
                    end += 1
                if end < length and source[end] == "'":
                    end += 1
                output.append(source[position:end])
                position = end
            else:
                if char == "{":
                    frames[-1][1] += 1
                elif char == "}":
                    if frames[-1][1] == 0 and len(frames) > 1:
                        frames.pop()  # closes a ${...} template, back to the string
                    elif frames[-1][1] > 0:
                        frames[-1][1] -= 1
                output.append(char)
                position += 1

        elif kind == "string":
            if char == "\\":
                output.append(source[position:position + 2])
                position += 2
            elif char == '"':
                frames.pop()
                output.append(char)
                position += 1
            elif char == "$" and next_char == "{":
                frames.append(["code", 0])
                output.append("${")
                position += 2
            else:
                if char == "\n":
                    frames.pop()  # unterminated literal; resync at the line break
                output.append(char)
                position += 1

        else:  # raw_string
            if char == '"' and source.startswith('"""', position):
                end = position
                while end < length and source[end] == '"':
                    end += 1
                output.append(source[position:end])
                position = end
                frames.pop()
            elif char == "$" and next_char == "{":
                frames.append(["code", 0])
                output.append("${")
                position += 2
            else:
                output.append(char)
                position += 1

    return "".join(output)


def count_hardcoded_text(code):
    return sum(
        len(HARDCODED_TEXT.findall(line))
        for line in code.splitlines()
        if "stringResource(" not in line
    )


def scan_feature_file(path):
    code = strip_comments(path.read_text(encoding="utf-8"))
    counts = {name: len(pattern.findall(code)) for name, pattern in NEGATIVE_SIGNALS.items()}
    has_legacy = counts["legacy_token_imports"] > 0
    counts["legacy_token_files"] = int(has_legacy)
    counts["legacy_only_files"] = int(has_legacy and not MODERN_TOKEN_IMPORT.search(code))
    counts[HARDCODED_TEXT_SIGNAL] = count_hardcoded_text(code)
    positives = {name: len(pattern.findall(code)) for name, pattern in POSITIVE_SIGNALS.items()}
    return counts, positives


def kotlin_files(directory):
    return sorted(directory.rglob("*.kt"))


def git_short_sha():
    try:
        result = subprocess.run(
            ["git", "-C", str(REPO_ROOT), "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True, check=True,
        )
        return result.stdout.strip() or "unknown"
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def take_snapshot():
    negative_totals = {name: 0 for name in NEGATIVE_SIGNAL_ORDER}
    positive_totals = {name: 0 for name in POSITIVE_SIGNAL_ORDER}
    per_feature = {}
    legacy_only_files = []

    for path in kotlin_files(FEATURES_DIR):
        counts, positives = scan_feature_file(path)
        relative = path.relative_to(FEATURES_DIR)
        feature_dir = relative.parts[0] if len(relative.parts) > 1 else "(root)"
        feature_counts = per_feature.setdefault(feature_dir, {name: 0 for name in NEGATIVE_SIGNAL_ORDER})
        for name, value in counts.items():
            negative_totals[name] += value
            feature_counts[name] += value
        for name, value in positives.items():
            positive_totals[name] += value
        if counts["legacy_only_files"]:
            legacy_only_files.append(relative.as_posix())

    for path in kotlin_files(DESIGNSYSTEM_DIR):
        code = strip_comments(path.read_text(encoding="utf-8"))
        for name, pattern in DESIGNSYSTEM_POSITIVE_SIGNALS.items():
            positive_totals[name] += len(pattern.findall(code))

    return {
        "generated_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "git_commit": git_short_sha(),
        "negative": negative_totals,
        "positive": positive_totals,
        "per_feature": {name: per_feature[name] for name in sorted(per_feature)},
        "legacy_only_files": legacy_only_files,
    }


def load_baseline(baseline_path):
    if not baseline_path.is_file():
        print(f"design-lint: baseline not found at {baseline_path}", file=sys.stderr)
        print("design-lint: run `python3 scripts/verify/design_lint.py --write-baseline` "
              "and commit the result.", file=sys.stderr)
        sys.exit(2)
    try:
        with baseline_path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError) as error:
        print(f"design-lint: cannot read baseline {baseline_path}: {error}", file=sys.stderr)
        sys.exit(2)


def build_rows(baseline, current):
    """One row per signal: (name, baseline, current, delta, status, is_negative)."""
    rows = []
    for kind, order, is_negative in (
        ("negative", NEGATIVE_SIGNAL_ORDER, True),
        ("positive", POSITIVE_SIGNAL_ORDER, False),
    ):
        baseline_counts = baseline.get(kind, {})
        for name in order:
            current_value = current[kind][name]
            baseline_value = baseline_counts.get(name)
            if baseline_value is None:
                rows.append((name, None, current_value, None, "new", is_negative))
                continue
            delta = current_value - baseline_value
            if is_negative:
                status = "✗" if delta > 0 else "✓"
            else:
                status = "↓" if delta < 0 else "✓"
            rows.append((name, baseline_value, current_value, delta, status, is_negative))
    return rows


def format_delta(delta):
    if delta is None:
        return "—"
    return f"{delta:+d}" if delta else "0"


def print_text_report(baseline, current, rows):
    name_width = max(len(row[0]) for row in rows)
    header = f"{'signal':<{name_width}}  {'baseline':>8}  {'current':>8}  {'delta':>6}  status"
    print(f"design-lint ratchet — baseline {baseline.get('git_commit', '?')} "
          f"({baseline.get('generated_at', '?')}) vs {current['git_commit']}")
    for title, want_negative in (("Negative signals (must never rise)", True),
                                 ("Positive signals (informational)", False)):
        print()
        print(title)
        print(header)
        print("-" * len(header))
        for name, base, cur, delta, status, is_negative in rows:
            if is_negative != want_negative:
                continue
            base_text = "—" if base is None else str(base)
            print(f"{name:<{name_width}}  {base_text:>8}  {cur:>8}  {format_delta(delta):>6}  {status}")
    print()
    print_legacy_only_files(current, line_format="  {}")


def print_legacy_only_files(current, line_format):
    files = current["legacy_only_files"]
    print(f"Legacy-only files ({len(files)}):" + ("" if files else " none"))
    for name in files:
        print(line_format.format(name))


def print_markdown_report(baseline, current, rows):
    print(f"Design-lint ratchet — baseline `{baseline.get('git_commit', '?')}` "
          f"({baseline.get('generated_at', '?')}) vs `{current['git_commit']}`. "
          "Negative signals must never rise (✗ = regression); positive rows are informational.")
    print()
    print("| Signal | Baseline | Current | Δ | Status |")
    print("|---|---:|---:|---:|:---:|")
    for name, base, cur, delta, status, is_negative in rows:
        base_text = "—" if base is None else str(base)
        label = f"`{name}`" if is_negative else f"`{name}` (+)"
        print(f"| {label} | {base_text} | {cur} | {format_delta(delta)} | {status} |")
    print()
    print_legacy_only_files(current, line_format="- `{}`")


def regressions(rows):
    return [(name, delta) for name, _, _, delta, _, is_negative in rows
            if is_negative and delta is not None and delta > 0]


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write-baseline", action="store_true",
                      help="recount and overwrite the baseline JSON")
    mode.add_argument("--markdown", action="store_true",
                      help="print the comparison table as GitHub markdown")
    mode.add_argument("--json", action="store_true",
                      help="print current counts as JSON (no baseline needed)")
    parser.add_argument("--baseline-file", type=Path, default=DEFAULT_BASELINE_PATH,
                        help=f"baseline path (default: {DEFAULT_BASELINE_PATH.relative_to(REPO_ROOT)})")
    args = parser.parse_args()

    if not FEATURES_DIR.is_dir():
        print(f"design-lint: features dir not found: {FEATURES_DIR}", file=sys.stderr)
        return 2

    current = take_snapshot()

    if args.json:
        print(json.dumps(current, indent=2, ensure_ascii=False))
        return 0

    if args.write_baseline:
        args.baseline_file.parent.mkdir(parents=True, exist_ok=True)
        args.baseline_file.write_text(json.dumps(current, indent=2, ensure_ascii=False) + "\n",
                                      encoding="utf-8")
        print(f"design-lint: baseline written to {args.baseline_file} "
              f"(commit {current['git_commit']})")
        return 0

    baseline = load_baseline(args.baseline_file)
    rows = build_rows(baseline, current)
    if args.markdown:
        print_markdown_report(baseline, current, rows)
    else:
        print_text_report(baseline, current, rows)

    failed = regressions(rows)
    print()
    if failed:
        summary = ", ".join(f"{name} {delta:+d}" for name, delta in failed)
        print(f"RATCHET FAILED — negative signals rose above baseline: {summary}")
        print("Fix the regression, or lower the numbers and refresh the baseline in the same commit.")
        return 1
    print("RATCHET OK — no negative signal rose above its baseline.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
