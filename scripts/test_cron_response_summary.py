#!/usr/bin/env python3
"""Offline regression tests of the actual safe-summary CLI (Python stdlib only)."""

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import cron_response_summary as summary


CLI = Path(__file__).with_name("cron_response_summary.py")
PRIVATE = "SYNTHETIC_PRIVATE_TOKEN_321-do-not-echo"
INJECTION = "\n::error::" + PRIVATE + "\n[secret](https://private.invalid/" + PRIVATE + ")"


def good_body():
    return {"ok": True, "slot": "daily", "targets": list(summary.DAILY_SLOTS),
            "results": [{"slot": slot, "ok": True, "rows": 2, "duration_ms": 12}
                        for slot in summary.DAILY_SLOTS], "persistence": {"ok": True}}


class SummaryCliTests(unittest.TestCase):
    def invoke(self, value=None, *, raw=None, status="200", curl="0", extra=None,
               summary_directory=False, missing_body=False):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            body_path = folder / ("response-" + PRIVATE)
            summary_path = folder / ("summary-" + PRIVATE)
            if summary_directory:
                summary_path.mkdir()
            if not missing_body:
                body_path.write_bytes(raw if raw is not None else json.dumps(value).encode())
            if not summary_directory:
                summary_path.write_text("Existing step summary.\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(CLI), "--body", str(body_path),
                 "--http-status", status, "--curl-exit-code", curl,
                 "--summary", str(summary_path), *(extra or [])],
                capture_output=True, text=True, encoding="utf-8", timeout=10, check=False)
            rendered = "" if summary_directory else summary_path.read_text(encoding="utf-8")
            for output in (result.stdout, result.stderr, rendered):
                self.assertNotIn(PRIVATE, output)
                self.assertNotIn("private.invalid", output)
                self.assertNotIn("Traceback", output)
            self.assertEqual(result.stderr, "")
            return result, rendered

    def test_complete_success_appends_safe_github_summary(self):
        body = good_body()
        body["message"] = INJECTION
        body["headers"] = {"Authorization": PRIVATE}
        body["results"][0]["details"] = INJECTION
        result, rendered = self.invoke(body)
        self.assertEqual(result.returncode, 0)
        self.assertTrue(rendered.startswith("Existing step summary.\n## Daily cron result"))
        self.assertIn("Ledger persisted: true", rendered)
        self.assertIn("Daily jobs ok: true", rendered)
        self.assertEqual(sum(line.startswith("| ") for line in rendered.splitlines()), 28)
        self.assertNotIn("::warning::", result.stdout)
        self.assertNotIn("::error::", result.stdout)
        self.assertNotIn("::", rendered)

    def test_failed_snapshot_code_and_http_curl_failure_preserved(self):
        body = good_body()
        body["ok"] = False
        body["results"][-2].update(ok=False, error_code="57014", message=INJECTION)
        result, rendered = self.invoke(body, status="500", curl="22")
        self.assertEqual(result.returncode, 22)
        self.assertIn("| db-storage-snapshot | false | 12 | 2 | 57014 |", rendered)
        self.assertIn("HTTP status: 500", rendered)
        self.assertIn("::error::", result.stdout)

    def test_explicit_job_failure_even_under_http200_fails(self):
        body = good_body()
        body["ok"] = False
        body["results"][-1].update(ok=False, error_code="H500")
        result, rendered = self.invoke(body)
        self.assertEqual(result.returncode, 1)
        self.assertIn("| invoice-digest | false |", rendered)

    def test_valid_stable_codes_are_retained(self):
        for code in ("57014", "55P03", "23502", "42501", "PGRST002", "PGRST116", "H401", "H500"):
            with self.subTest(code=code):
                body = good_body()
                body["ok"] = False
                body["results"][-1].update(ok=False, error_code=code)
                result, rendered = self.invoke(body, status="500", curl="22")
                self.assertEqual(result.returncode, 22)
                self.assertIn("| " + code + " |", rendered)

    def test_missing_persistence_supports_older_edge_without_claiming_persisted(self):
        body = good_body()
        del body["persistence"]
        result, rendered = self.invoke(body)
        self.assertEqual(result.returncode, 0)
        self.assertIn("Ledger persisted: unreported", rendered)
        self.assertIn("::warning::Daily cron ledger persistence is unreported", result.stdout)

    def test_failed_persistence_warns_but_does_not_change_job_success(self):
        body = good_body()
        body["persistence"] = {"ok": False, "error_code": "PGRST002", "message": INJECTION}
        result, rendered = self.invoke(body)
        self.assertEqual(result.returncode, 0)
        self.assertIn("Ledger persisted: false", rendered)
        self.assertIn("Ledger error code: PGRST002", rendered)
        self.assertIn("Daily jobs ok: true", rendered)
        self.assertIn("::warning::Daily cron ledger persistence failed", result.stdout)

    def test_failed_persistence_cannot_hide_a_failed_slot(self):
        body = good_body()
        body["ok"] = False
        body["results"][0].update(ok=False, error_code="55P03")
        body["persistence"] = {"ok": False}
        result, rendered = self.invoke(body, status="500", curl="22")
        self.assertEqual(result.returncode, 22)
        self.assertIn("Daily jobs ok: false", rendered)
        self.assertIn("Ledger persisted: false", rendered)

    def test_gateway_non_json_empty_invalid_utf8_and_oversize_are_safe(self):
        for raw in (b"", ("<html>" + INJECTION + "</html>").encode(), b"\xff\xfe" + PRIVATE.encode(),
                    PRIVATE.encode() + b" " * summary.MAX_BODY_BYTES,
                    b"[" * 2500 + b"]" * 2500):
            with self.subTest(length=len(raw)):
                result, rendered = self.invoke(raw=raw, status="502", curl="22")
                self.assertEqual(result.returncode, 22)
                self.assertNotIn("Response: valid", rendered)

    def test_malformed_http200_response_fails_closed(self):
        for raw in (b"", b"<html>gateway</html>", b"null", b"[]", b"true", b"{invalid json}"):
            with self.subTest(raw=raw):
                result, _ = self.invoke(raw=raw)
                self.assertEqual(result.returncode, 1)

    def test_duplicate_json_keys_and_nonfinite_numbers_are_rejected(self):
        valid = json.dumps(good_body())
        for raw in (("{\"ok\": false," + valid[1:]).encode(),
                    valid.replace('"duration_ms": 12', '"duration_ms": NaN', 1).encode(),
                    valid.replace('"duration_ms": 12', '"duration_ms": Infinity', 1).encode()):
            result, rendered = self.invoke(raw=raw)
            self.assertEqual(result.returncode, 1)
            self.assertNotIn("Response: valid", rendered)

    def test_injected_or_noncanonical_codes_never_reach_outputs(self):
        for code in ("57014\n", "PGRST002\r\n", "H500\u2028", "H401 ", " H401", "h500", "H600",
                     "PGRST02", INJECTION, {"code": PRIVATE}, 57014, None):
            for field in ("slot", "persistence"):
                with self.subTest(code=code, field=field):
                    body = good_body()
                    target = body["results"][0] if field == "slot" else body["persistence"]
                    target["error_code"] = code
                    result, rendered = self.invoke(body)
                    self.assertEqual(result.returncode, 1)
                    self.assertIn("Response: invalid-shape", rendered)

    def test_unknown_injected_duplicate_missing_extra_slots_are_rejected(self):
        variants = []
        body = good_body(); body["results"][0]["slot"] = INJECTION; variants.append(body)
        body = good_body(); body["targets"][0] = INJECTION; variants.append(body)
        body = good_body(); body["results"][0] = copy.deepcopy(body["results"][1]); variants.append(body)
        body = good_body(); body["targets"][0] = body["targets"][1]; variants.append(body)
        body = good_body(); body["results"].pop(); variants.append(body)
        body = good_body(); body["targets"].pop(); variants.append(body)
        body = good_body(); body["results"].append({"slot": INJECTION}); variants.append(body)
        body = good_body(); body["targets"].append(INJECTION); variants.append(body)
        body = good_body(); body["results"][0]["slot"] = {}; variants.append(body)
        body = good_body(); body["targets"][0] = {}; variants.append(body)
        for body in variants:
            result, rendered = self.invoke(body)
            self.assertEqual(result.returncode, 1)
            self.assertIn("Response: invalid-shape", rendered)

    def test_reordered_complete_slots_remain_valid_and_render_in_fixed_order(self):
        body = good_body()
        body["targets"].reverse(); body["results"].reverse()
        result, rendered = self.invoke(body)
        self.assertEqual(result.returncode, 0)
        self.assertLess(rendered.index("| purge-notifications |"), rendered.index("| invoice-digest |"))

    def test_booleans_consistency_and_daily_group_are_validated(self):
        variants = []
        for value in ("true", 1, None):
            body = good_body(); body["ok"] = value; variants.append(body)
            body = good_body(); body["results"][0]["ok"] = value; variants.append(body)
            body = good_body(); body["persistence"]["ok"] = value; variants.append(body)
        body = good_body(); body["ok"] = False; variants.append(body)
        body = good_body(); body["results"][0]["ok"] = False; variants.append(body)
        body = good_body(); body["slot"] = INJECTION; variants.append(body)
        body = good_body(); body["slot"] = "hourly"; variants.append(body)
        body = good_body(); body["persistence"] = None; variants.append(body)
        for body in variants:
            result, _ = self.invoke(body)
            self.assertEqual(result.returncode, 1)

    def test_numeric_bounds_reject_boolean_float_string_and_out_of_range(self):
        for field, maximum in (("rows", summary.MAX_ROWS), ("duration_ms", summary.MAX_DURATION_MS)):
            for value in (-1, maximum + 1, True, False, 1.0, "12", INJECTION, None):
                with self.subTest(field=field, value=value):
                    body = good_body(); body["results"][0][field] = value
                    result, rendered = self.invoke(body)
                    self.assertEqual(result.returncode, 1)
                    self.assertIn("Response: invalid-shape", rendered)
            for value in (0, maximum):
                body = good_body(); body["results"][0][field] = value
                result, _ = self.invoke(body)
                self.assertEqual(result.returncode, 0)

    def test_optional_rows_and_error_code_can_be_absent(self):
        body = good_body()
        for record in body["results"]:
            del record["rows"]
        result, rendered = self.invoke(body)
        self.assertEqual(result.returncode, 0)
        self.assertIn("| 12 | unreported | unreported |", rendered)

    def test_transport_failures_preserve_actual_curl_exit(self):
        for curl in ("6", "22", "28", "35", "60", "255"):
            with self.subTest(curl=curl):
                result, _ = self.invoke(good_body(), status="000", curl=curl)
                self.assertEqual(result.returncode, int(curl))

    def test_non2xx_and_invalid_http_status_fail_even_if_curl_reports_success(self):
        for status in ("000", "99", "300", "401", "500", "600", "200\n" + PRIVATE, "", "0200"):
            result, _ = self.invoke(good_body(), status=status)
            self.assertEqual(result.returncode, 1)

    def test_invalid_curl_exit_is_safe_and_not_success(self):
        for curl in ("256", "-1", "0\n" + PRIVATE, "", "true"):
            result, _ = self.invoke(good_body(), curl=curl)
            self.assertNotEqual(result.returncode, 0)

    def test_missing_file_and_summary_write_failure_never_emit_exception_details(self):
        result, _ = self.invoke(good_body(), missing_body=True)
        self.assertEqual(result.returncode, 1)
        for curl, expected in (("0", 1), ("22", 22), ("28", 28)):
            result, _ = self.invoke(good_body(), summary_directory=True, curl=curl)
            self.assertEqual(result.returncode, expected)
            self.assertIn("could not be produced safely", result.stdout)

    def test_argument_errors_do_not_echo_unknown_sensitive_input(self):
        result, _ = self.invoke(good_body(), extra=["--" + PRIVATE])
        self.assertEqual(result.returncode, 2)
        self.assertIn("invalid arguments", result.stdout)


if __name__ == "__main__":
    unittest.main()
