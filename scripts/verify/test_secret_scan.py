"""Offline Git-history contracts; real pinned Gitleaks is required, never skipped."""

import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import secret_scan


ZERO = "0" * 40
TOKEN = "eqs_" + "test_" + "c7" * 16
CONFIG = """[extend]
useDefault = true
[[rules]]
id = "synthetic-offline-token"
description = "Synthetic offline fixture only"
regex = '''eqs_test_[a-f0-9]{32}'''
keywords = ["eqs_test_"]
"""


class Repository:
    def __init__(self):
        self.temp = tempfile.TemporaryDirectory(prefix="secret-scan-test-")
        self.path = Path(self.temp.name) / "repo"
        self.path.mkdir()
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Offline fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.autocrlf", "false")
        self.git("config", "gc.auto", "0")
        (self.path / ".gitleaks.toml").write_text(CONFIG, encoding="utf-8")
        self.base = self.commit("history.txt", "initial\n")
        self.git("update-ref", "refs/remotes/origin/main", self.base)

    def git(self, *args):
        return subprocess.run(
            ["git", "-C", str(self.path), *args], check=True,
            capture_output=True, text=True,
        ).stdout.strip()

    @property
    def head(self):
        return self.git("rev-parse", "HEAD")

    def commit(self, name="history.txt", content="clean change\n"):
        (self.path / name).write_text(content, encoding="utf-8")
        self.git("add", "--all")
        self.git("commit", "-m", "Synthetic fixture change")
        return self.head

    def pr(self, base=None, head=None):
        return {"pull_request": {"base": {"sha": self.base if base is None else base},
                                 "head": {"sha": self.head if head is None else head}}}

    def push(self, before=None, after=None, **changes):
        event = {"before": self.base if before is None else before,
                 "after": self.head if after is None else after,
                 "created": False, "deleted": False, "ref": "refs/heads/feature",
                 "repository": {"default_branch": "main"}}
        event.update(changes)
        return event


class ScanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        binary = os.environ.get("GITLEAKS_TEST_BINARY")
        if not binary or not Path(binary).is_file():
            raise RuntimeError("Set GITLEAKS_TEST_BINARY to the verified Gitleaks 8.24.3 executable")
        cls.binary = Path(binary).resolve()

    def setUp(self):
        self.repo = Repository()
        self.addCleanup(self.repo.temp.cleanup)

    def invoke(self, name, event, binary=None):
        event_file = Path(self.repo.temp.name) / "event.json"
        event_file.write_text(json.dumps(event), encoding="utf-8")
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            code = secret_scan.main([
                "--repo", str(self.repo.path), "--event-name", name,
                "--event-path", str(event_file), "--gitleaks", str(binary or self.binary),
            ])
        self.assertNotIn(TOKEN, output.getvalue())
        return code, output.getvalue()

    def old_engine(self, revision_range):
        result = subprocess.run([
            str(self.binary), "git", str(self.repo.path), "--no-banner", "--redact=100",
            "--exit-code=23", "--config", str(self.repo.path / ".gitleaks.toml"),
            "--log-opts", "--no-merges --first-parent " + revision_range + " --",
        ], capture_output=True, text=True)
        self.assertNotIn(TOKEN, result.stdout + result.stderr)
        return result.returncode

    def test_late_removed_secret_after_first_30_commits_is_detected(self):
        commits = []
        for index in range(1, 42):
            commits.append(self.repo.commit(content=TOKEN if index == 36 else f"clean {index}\n"))
        self.assertEqual(0, self.old_engine(self.repo.base + ".." + commits[29]))
        plan = secret_scan.select_plan(self.repo.path, "pull_request", self.repo.pr())
        self.assertEqual(41, plan.commit_count)
        self.assertEqual(1, self.invoke("pull_request", self.repo.pr())[0])

    def test_removed_secret_on_merged_side_branch_is_detected(self):
        self.repo.git("checkout", "-b", "side")
        self.repo.commit("side.txt", TOKEN)
        self.repo.commit("side.txt", "removed\n")
        self.repo.git("checkout", "main")
        self.repo.commit("main.txt", "parallel change\n")
        self.repo.git("merge", "--no-ff", "side", "-m", "Merge synthetic side")
        self.assertEqual(0, self.old_engine(self.repo.base + ".." + self.repo.head))
        self.assertEqual(1, self.invoke("pull_request", self.repo.pr())[0])

    def test_merge_resolution_only_secret_is_detected(self):
        self.repo.git("checkout", "-b", "side")
        self.repo.commit("side.txt", "side change\n")
        self.repo.git("checkout", "main")
        self.repo.commit("main.txt", "main change\n")
        self.repo.git("merge", "--no-ff", "--no-commit", "side")
        self.repo.commit("resolution.txt", TOKEN)
        self.assertEqual(2, len(self.repo.git("show", "-s", "--format=%P", "HEAD").split()))
        self.assertEqual(0, self.old_engine(self.repo.base + ".." + self.repo.head))
        self.assertEqual(1, self.invoke("pull_request", self.repo.pr())[0])

    def test_clean_sync_merge_does_not_reclassify_existing_first_parent_text(self):
        original = self.repo.base
        existing = self.repo.commit("existing.txt", TOKEN)
        self.repo.git("checkout", "-b", "side", original)
        self.repo.commit("side.txt", "clean side\n")
        self.repo.git("checkout", "main")
        self.repo.commit("main.txt", "clean first parent\n")
        self.repo.git("merge", "--no-ff", "side", "-m", "Clean synthetic sync merge")
        event = self.repo.pr(base=existing)
        self.assertEqual(0, self.invoke("pull_request", event)[0])
        plan = secret_scan.select_plan(self.repo.path, "pull_request", event)
        command = secret_scan.engine_command(self.repo.path, plan, self.binary)
        separate = [arg.replace("--diff-merges=first-parent", "--diff-merges=separate") for arg in command]
        result = subprocess.run(separate, capture_output=True, text=True)
        self.assertEqual(23, result.returncode, "Separate-parent patches incorrectly reintroduce old base text")
        self.assertNotIn(TOKEN, result.stdout + result.stderr)

    def test_clean_pr_and_ordinary_push_scan_successfully(self):
        self.repo.commit()
        for name, event in [("pull_request", self.repo.pr()), ("push", self.repo.push())]:
            with self.subTest(event=name):
                code, output = self.invoke(name, event)
                self.assertEqual(0, code, output)
                self.assertIn("1 commits", output)

    def test_new_feature_branch_excludes_old_default_branch_history(self):
        self.repo.commit("old.txt", TOKEN)
        default = self.repo.commit("old.txt", "historical fixture removed\n")
        self.repo.git("update-ref", "refs/remotes/origin/main", default)
        self.repo.git("checkout", "-b", "feature")
        self.repo.commit()
        event = self.repo.push(before=ZERO, created=True)
        plan = secret_scan.select_plan(self.repo.path, "push", event)
        self.assertEqual(default + ".." + self.repo.head, plan.revision_range)
        self.assertEqual(1, plan.commit_count)
        self.assertEqual(0, self.invoke("push", event)[0])

    def test_ordinary_and_new_branch_push_find_fresh_secrets(self):
        self.repo.commit("fresh.txt", TOKEN)
        for event in [self.repo.push(), self.repo.push(before=ZERO, created=True)]:
            with self.subTest(created=event["created"]):
                self.assertEqual(1, self.invoke("push", event)[0])

    def test_force_push_nonancestor_range_scans_replacement_history(self):
        before = self.repo.commit("old-line.txt", "old line of work\n")
        self.repo.git("checkout", "-b", "replacement", self.repo.base)
        self.repo.commit("new-line.txt", TOKEN)
        self.repo.commit("new-line.txt", "removed before force push\n")
        event = self.repo.push(before=before)
        plan = secret_scan.select_plan(self.repo.path, "push", event)
        self.assertEqual(2, plan.commit_count)
        self.assertEqual(before + ".." + self.repo.head, plan.revision_range)
        self.assertEqual(1, self.invoke("push", event)[0])

    def test_zero_commit_feature_branch_still_runs_engine(self):
        event = self.repo.push(before=ZERO, created=True)
        plan = secret_scan.select_plan(self.repo.path, "push", event)
        self.assertEqual(0, plan.commit_count)
        self.assertIsNotNone(plan.revision_range)
        self.assertEqual(0, self.invoke("push", event)[0])
        self.assertEqual(2, self.invoke("push", event, Path(self.repo.temp.name) / "missing-engine")[0])

    def test_well_formed_deleted_push_is_only_engine_noop(self):
        event = self.repo.push(after=ZERO, deleted=True)
        self.assertEqual(0, self.invoke("push", event, Path(self.repo.temp.name) / "missing-engine")[0])

    def test_default_branch_creation_without_exclusion_base_fails(self):
        event = self.repo.push(before=ZERO, created=True, ref="refs/heads/main")
        self.assertEqual(2, self.invoke("push", event)[0])

    def test_invalid_or_incomplete_sha_fields_fail_closed(self):
        self.repo.commit()
        for invalid in [None, "", ZERO, "f" * 39, "F" * 40, "x" * 40, "HEAD", "--all", "a" * 40 + "\n"]:
            for part in ["base", "head"]:
                with self.subTest(sha=repr(invalid), part=part):
                    event = self.repo.pr()
                    event["pull_request"][part]["sha"] = invalid
                    self.assertEqual(2, self.invoke("pull_request", event)[0])
        self.assertEqual(2, self.invoke("pull_request", {})[0])
        self.assertEqual(2, self.invoke("push", {})[0])
        self.assertEqual(2, self.invoke("workflow_dispatch", {})[0])

    def test_inconsistent_push_flags_or_missing_fields_fail_closed(self):
        for changes in [{"after": ZERO}, {"before": ZERO}, {"deleted": True},
                        {"created": True}, {"deleted": "true"}, {"created": 0},
                        {"before": ZERO, "after": ZERO, "created": True, "deleted": True},
                        {"after": ZERO, "deleted": True, "before": ""},
                        {"ref": "refs/tags/tag"}, {"ref": "refs/heads/bad\nbranch"}]:
            with self.subTest(changes=changes):
                self.assertEqual(2, self.invoke("push", self.repo.push(**changes))[0])
        event = self.repo.push()
        del event["after"]
        self.assertEqual(2, self.invoke("push", event)[0])

    def test_checkout_identity_mismatch_fails_closed(self):
        expected = self.repo.head
        self.repo.commit()
        self.assertEqual(2, self.invoke("pull_request", self.repo.pr(head=expected))[0])

    def test_missing_commit_and_missing_default_ref_fail_closed(self):
        self.repo.commit()
        self.assertEqual(2, self.invoke("pull_request", self.repo.pr(base="f" * 40))[0])
        self.repo.git("update-ref", "-d", "refs/remotes/origin/main")
        self.assertEqual(2, self.invoke("push", self.repo.push(before=ZERO, created=True))[0])

    def test_blob_cannot_be_used_as_event_commit(self):
        blob = self.repo.git("rev-parse", "HEAD:history.txt")
        self.assertEqual(2, self.invoke("pull_request", self.repo.pr(base=blob))[0])

    def test_missing_blob_cannot_silently_pass_git_scanning(self):
        self.repo.commit("missing.txt", "unique fixture blob\n")
        blob = self.repo.git("rev-parse", "HEAD:missing.txt")
        object_file = self.repo.path / ".git" / "objects" / blob[:2] / blob[2:]
        self.assertTrue(object_file.resolve().is_relative_to(self.repo.path.resolve()))
        # Git loose objects are read-only on Windows. Only mutate this verified
        # temporary fixture object, never a shared checkout's object database.
        object_file.chmod(0o600)
        object_file.unlink()
        with patch.object(secret_scan, "run_engine") as engine:
            self.assertEqual(2, self.invoke("pull_request", self.repo.pr())[0])
            engine.assert_not_called()

    def test_shallow_clone_is_rejected(self):
        self.repo.commit()
        clone = Path(self.repo.temp.name) / "shallow"
        self.repo.git("clone", "--depth=1", self.repo.path.as_uri(), str(clone))
        with self.assertRaises(secret_scan.ScanError):
            secret_scan.select_plan(clone, "pull_request", self.repo.pr())

    def test_uncommitted_config_change_is_rejected(self):
        self.repo.commit()
        (self.repo.path / ".gitleaks.toml").write_text("changed", encoding="utf-8")
        self.assertEqual(2, self.invoke("pull_request", self.repo.pr())[0])

    def test_untracked_ignore_policy_is_rejected(self):
        self.repo.commit()
        (self.repo.path / ".gitleaksignore").write_text("untrusted ignore\n", encoding="utf-8")
        self.assertEqual(2, self.invoke("pull_request", self.repo.pr())[0])

    def test_committed_symlink_policy_is_rejected_even_with_windows_link_emulation(self):
        # Represent a Git symlink as a regular working-tree file as core.symlinks
        # false does on Windows; ls-tree must reject its 120000 mode as well.
        (self.repo.path / ".gitleaks.toml").write_text("../external-policy", encoding="utf-8")
        blob = self.repo.git("hash-object", "-w", ".gitleaks.toml")
        self.repo.git("update-index", "--cacheinfo", "120000," + blob + ",.gitleaks.toml")
        self.repo.git("commit", "-m", "Synthetic symlink policy")
        with self.assertRaises(secret_scan.ScanError):
            secret_scan.validate_policy(self.repo.path)

    def test_unexpected_engine_version_is_rejected(self):
        self.repo.commit()
        plan = secret_scan.select_plan(self.repo.path, "pull_request", self.repo.pr())
        with patch.object(secret_scan.subprocess, "run", return_value=
                          subprocess.CompletedProcess([], 0, "8.0.0\n", "")) as runner:
            with self.assertRaises(secret_scan.ScanError):
                secret_scan.run_engine(self.repo.path, plan, self.binary)
            self.assertEqual(1, runner.call_count)

    def test_real_engine_failure_and_missing_executable_fail_closed(self):
        self.repo.commit(".gitleaks.toml", "invalid TOML [\n")
        code, output = self.invoke("pull_request", self.repo.pr())
        self.assertEqual(2, code, output)
        self.assertNotIn("invalid TOML", output)
        self.assertEqual(2, self.invoke("pull_request", self.repo.pr(), Path(self.repo.temp.name) / "absent")[0])

    def test_zero_exit_engine_error_output_is_not_clean(self):
        self.repo.commit()
        plan = secret_scan.select_plan(self.repo.path, "pull_request", self.repo.pr())
        with patch.object(secret_scan.subprocess, "run", side_effect=[
            subprocess.CompletedProcess([], 0, "8.24.3\n", ""),
            subprocess.CompletedProcess([], 0, "", "engine failure " + TOKEN),
        ]):
            with self.assertRaises(secret_scan.ScanError):
                secret_scan.run_engine(self.repo.path, plan, self.binary)

    def test_real_cli_output_redacts_the_synthetic_finding(self):
        self.repo.commit("leak.txt", TOKEN)
        plan = secret_scan.select_plan(self.repo.path, "pull_request", self.repo.pr())
        command = secret_scan.engine_command(self.repo.path, plan, self.binary)
        self.assertIn("--redact=100", command)
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(23, result.returncode)
        self.assertNotIn(TOKEN, result.stdout + result.stderr)
        self.assertEqual(1, self.invoke("pull_request", self.repo.pr())[0])

    def test_missing_or_malformed_event_file_fails_closed(self):
        self.repo.commit()
        event_file = Path(self.repo.temp.name) / "invalid-event.json"
        for data in [None, "not json", "[]", "null"]:
            if data is not None:
                event_file.write_text(data, encoding="utf-8")
            output = io.StringIO()
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                result = secret_scan.main(["--repo", str(self.repo.path), "--event-name", "push",
                                           "--event-path", str(event_file), "--gitleaks", str(self.binary)])
            self.assertEqual(2, result)


if __name__ == "__main__":
    unittest.main()
