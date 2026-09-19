"""Scan complete event history with a verified Gitleaks CLI, without a commit-list API.

Exit codes: 0 = clean (or an explicit branch deletion), 1 = findings, 2 = failure.
Engine/Git output is captured, never relayed: even an error can contain a secret.
"""

import argparse
from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import subprocess
import sys


VERSION = "8.24.3"
ZERO = "0" * 40
# This controls merge PATCH formatting, not traversal. Do not add --first-parent
# or --no-merges: either would hide side history or merge-resolution additions.
LOG_OPTIONS = ("--full-history", "--diff-merges=first-parent", "--no-ext-diff",
               "--no-textconv", "--no-renames")


class ScanError(RuntimeError):
    """A fixed diagnostic category, never interpolated engine/event contents."""


@dataclass(frozen=True)
class ScanPlan:
    revision_range: str | None
    commit_count: int


def process_environment():
    # Neither Git preflight nor the engine may silently read a different checkout
    # or replacement history through inherited command-level Git settings.
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(("GIT_", "GITLEAKS_"))}
    env.update(GIT_NO_REPLACE_OBJECTS="1", GIT_NO_LAZY_FETCH="1",
               GIT_TERMINAL_PROMPT="0", GIT_CONFIG_NOSYSTEM="1",
               GIT_CONFIG_GLOBAL=os.devnull)
    return env


def git(repo, *args, discard=False):
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), *args], env=process_environment(),
            stdout=subprocess.DEVNULL if discard else subprocess.PIPE,
            stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace",
            timeout=300,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ScanError("Git could not complete validation") from exc
    if result.returncode != 0:
        raise ScanError("Git history, objects, refs or checkout validation failed")
    return "" if discard else result.stdout.strip()


def sha(value, *, allow_zero=False):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{40}", value):
        raise ScanError("Event contains a missing or invalid commit SHA")
    if value == ZERO and not allow_zero:
        raise ScanError("Event requires a nonzero commit SHA")
    return value


def mapping(value):
    if not isinstance(value, dict):
        raise ScanError("Event structure is missing or invalid")
    return value


def branch_ref(repo, value):
    if not isinstance(value, str) or not value.startswith("refs/heads/"):
        raise ScanError("Event requires a branch ref")
    git(repo, "check-ref-format", value)
    return value


def validate_policy(repo):
    for name in (".gitleaks.toml", ".gitleaksignore"):
        path = repo / name
        if name == ".gitleaksignore" and not path.exists() and not path.is_symlink():
            continue
        if (not path.is_file() or path.is_symlink()
                or not path.resolve().is_relative_to(repo)):
            raise ScanError("Scanner policy must be a regular file in this checkout")
        entry = git(repo, "ls-tree", "HEAD", "--", name)
        if not entry.startswith(("100644 blob ", "100755 blob ")):
            raise ScanError("Scanner policy must be tracked at the event head")


def select_plan(repo, event_name, event):
    repo = Path(repo).resolve()
    event = mapping(event)
    if event_name == "pull_request":
        request = mapping(event.get("pull_request"))
        base = sha(mapping(request.get("base")).get("sha"))
        head = sha(mapping(request.get("head")).get("sha"))
    elif event_name == "push":
        base = sha(event.get("before"), allow_zero=True)
        head = sha(event.get("after"), allow_zero=True)
        created, deleted = event.get("created"), event.get("deleted")
        if type(created) is not bool or type(deleted) is not bool:
            raise ScanError("Push requires boolean creation and deletion flags")
        ref = branch_ref(repo, event.get("ref"))
        if deleted:
            if created or head != ZERO or base == ZERO:
                raise ScanError("Push deletion metadata is inconsistent")
            # A deleted branch has no event head to check out or scan.
            return ScanPlan(None, 0)
        if head == ZERO or created != (base == ZERO):
            raise ScanError("Push creation metadata is inconsistent")
        if created:
            default = mapping(event.get("repository")).get("default_branch")
            if not isinstance(default, str):
                raise ScanError("New branch requires a default branch baseline")
            default_ref = branch_ref(repo, "refs/heads/" + default)
            if ref == default_ref:
                raise ScanError("Default branch creation has no trusted prior baseline")
            base = sha(git(repo, "rev-parse", "--verify", "refs/remotes/origin/" + default))
    else:
        raise ScanError("Unsupported event type")

    root = Path(git(repo, "rev-parse", "--show-toplevel")).resolve()
    if root != repo or git(repo, "rev-parse", "--is-shallow-repository") != "false":
        raise ScanError("A full, nonshallow checkout at its root is required")
    if git(repo, "rev-parse", "HEAD") != head:
        raise ScanError("Checkout HEAD does not match the event head")
    for commit in (base, head):
        if git(repo, "cat-file", "-t", commit) != "commit":
            raise ScanError("Event SHA is not a commit object")
    git(repo, "diff", "--quiet", "HEAD", "--", discard=True)
    validate_policy(repo)

    revision_range = base + ".." + head
    # Check object closure and actual patch traversal before invoking the engine.
    # Patch output goes straight to the null device, never to a log/artifact.
    git(repo, "rev-list", "--objects", "--missing=error", revision_range, "--", discard=True)
    git(repo, "log", "-p", "-U0", *LOG_OPTIONS, revision_range, "--", discard=True)
    count = git(repo, "rev-list", "--count", revision_range, "--")
    if not count.isdecimal():
        raise ScanError("Git did not return a valid commit count")
    return ScanPlan(revision_range, int(count))


def engine_command(repo, plan, binary):
    if plan.revision_range is None:
        raise ScanError("A deletion has no engine range")
    repo = Path(repo).resolve()
    return [str(binary), "git", str(repo), "--no-banner", "--no-color",
            "--redact=100", "--exit-code=23", "--log-level=error",
            "--config", str(repo / ".gitleaks.toml"),
            "--gitleaks-ignore-path", str(repo / ".gitleaksignore"),
            "--log-opts", " ".join((*LOG_OPTIONS, plan.revision_range, "--"))]


def run_engine(repo, plan, binary):
    try:
        version = subprocess.run(
            [str(binary), "version"], capture_output=True, text=True,
            encoding="utf-8", errors="replace", env=process_environment(), timeout=30,
        )
        if version.returncode or version.stdout.strip() != VERSION or version.stderr.strip():
            raise ScanError("Scanner version does not match the pinned release")
        result = subprocess.run(
            engine_command(repo, plan, binary), capture_output=True, text=True,
            encoding="utf-8", errors="replace", env=process_environment(), timeout=600,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ScanError("Scanner could not complete execution") from exc
    if result.returncode == 23:
        return 1
    # At error log level, a clean engine is silent. Reject logged errors even if
    # a future/partial engine failure unexpectedly returns exit zero.
    if result.returncode != 0 or result.stdout.strip() or result.stderr.strip():
        raise ScanError("Scanner reported an operational error")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".")
    parser.add_argument("--event-name", default=os.environ.get("GITHUB_EVENT_NAME"))
    parser.add_argument("--event-path", default=os.environ.get("GITHUB_EVENT_PATH"))
    parser.add_argument("--gitleaks", required=True)
    args = parser.parse_args(argv)
    try:
        if not args.event_path:
            raise ScanError("Event file is required")
        try:
            event = json.loads(Path(args.event_path).read_text(encoding="utf-8"))
        except (OSError, ValueError):
            raise ScanError("Event file is missing or invalid") from None
        repo = Path(args.repo).resolve()
        plan = select_plan(repo, args.event_name, event)
        if plan.revision_range is None:
            print("Secret scan: explicit branch deletion; no new history.")
            return 0
        print(f"Secret scan: {plan.revision_range} ({plan.commit_count} commits).")
        result = run_engine(repo, plan, args.gitleaks)
        print("Secret scan: findings detected; release blocked." if result else "Secret scan: clean.")
        return result
    except ScanError as exc:
        print(f"Secret scan failed: {exc}.", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
