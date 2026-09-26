#!/usr/bin/env python3
"""Summarize a daily cron response without printing untrusted response text.

Exit 0 means a valid, complete daily response reported all jobs successful over
a successful HTTP transport. Ledger persistence is separate and only warns.
Nonzero curl exits are retained; other invalid/failed outcomes return 1.
"""

import argparse
import json
import re
import sys
from pathlib import Path


DAILY_SLOTS = (
    "purge-notifications", "purge-content-reports", "purge-device-integrity",
    "purge-virtual-calls", "purge-phone-otp-requests", "amc-auto-renew",
    "amc-renewal-notify", "expire-amc-contracts", "purge-spot-audit-invitations",
    "purge-chat-moderation-events", "reap-stranded-repair-jobs", "daily-reconciliation",
    "schedule-kyc-renewals", "reap-expired-kyc-renewals", "daily-risk-scoring",
    "scan-collusion-pairs", "scan-duplicate-accounts", "refresh-tier-cache",
    "recompute-pm-schedules", "recompute-certifications", "evaluate-referrals",
    "purge-analytics-events", "purge-investor-share-views", "purge-nabh-export-audit",
    "db-storage-snapshot", "invoice-digest",
)
SLOT_SET = frozenset(DAILY_SLOTS)
MAX_BODY_BYTES = 64 * 1024
MAX_DURATION_MS = 3_600_000
MAX_ROWS = 2_147_483_647
STABLE_CODE = re.compile(r"(?:[0-9A-Z]{5}|PGRST[0-9]{3}|H[1-5][0-9]{2})", re.ASCII)


class SafeArguments(argparse.ArgumentParser):
    def error(self, _message):
        # argparse's default errors may echo an untrusted argument.
        raise ValueError("invalid arguments")


def bounded_integer(value, maximum):
    return type(value) is int and 0 <= value <= maximum


def safe_code(value):
    return type(value) is str and STABLE_CODE.fullmatch(value) is not None


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON field")
        result[key] = value
    return result


def reject_constant(_value):
    raise ValueError("nonfinite JSON number")


def load_body(path):
    try:
        with Path(path).open("rb") as response:
            raw = response.read(MAX_BODY_BYTES + 1)
        if len(raw) > MAX_BODY_BYTES:
            return None, "oversize"
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object,
                           parse_constant=reject_constant)
        if type(value) is not dict:
            return None, "invalid-shape"
        return value, "parsed"
    except (OSError, ValueError, RecursionError):
        return None, "unreadable-or-non-json"


def inspect_body(value):
    """Return only selected safe values; never retain raw messages or names."""
    result = {"valid": False, "ok": None, "slots": {}, "persistence": "unreported",
              "persistence_code": None}
    if value is None:
        return result
    valid = type(value.get("ok")) is bool and value.get("slot") == "daily"
    result["ok"] = value.get("ok") if type(value.get("ok")) is bool else None
    targets = value.get("targets")
    if (type(targets) is not list or len(targets) != len(DAILY_SLOTS)
            or any(type(name) is not str or name not in SLOT_SET for name in targets)
            or len(set(targets)) != len(DAILY_SLOTS)):
        valid = False

    records = value.get("results")
    if type(records) is not list or len(records) != len(DAILY_SLOTS):
        valid = False
    # Do not iterate an unbounded list or render anything but known slot names.
    if type(records) is list and len(records) <= len(DAILY_SLOTS):
        for record in records:
            if type(record) is not dict:
                valid = False
                continue
            name = record.get("slot")
            if type(name) is not str or name not in SLOT_SET or name in result["slots"]:
                valid = False
                continue
            slot_ok = record.get("ok")
            duration = record.get("duration_ms")
            if type(slot_ok) is not bool or not bounded_integer(duration, MAX_DURATION_MS):
                valid = False
                continue
            selected = {"ok": slot_ok, "duration_ms": duration, "rows": None, "code": None}
            if "rows" in record:
                if bounded_integer(record["rows"], MAX_ROWS):
                    selected["rows"] = record["rows"]
                else:
                    valid = False
            if "error_code" in record:
                if safe_code(record["error_code"]):
                    selected["code"] = record["error_code"]
                else:
                    valid = False
            result["slots"][name] = selected
    if set(result["slots"]) != SLOT_SET:
        valid = False
    elif result["ok"] is not all(record["ok"] for record in result["slots"].values()):
        valid = False

    if "persistence" in value:
        persistence = value["persistence"]
        if type(persistence) is dict and type(persistence.get("ok")) is bool:
            result["persistence"] = "true" if persistence["ok"] else "false"
            if "error_code" in persistence:
                if safe_code(persistence["error_code"]):
                    result["persistence_code"] = persistence["error_code"]
                else:
                    valid = False
        else:
            result["persistence"] = "invalid"
            valid = False
    result["valid"] = valid
    return result


def numeric_argument(value, maximum):
    if re.fullmatch(r"[0-9]{1,3}", value, flags=re.ASCII):
        parsed = int(value)
        if parsed <= maximum:
            return parsed
    return None


def render(http_status, curl_exit, body_state, selected):
    status = str(http_status) if http_status is not None else "unavailable"
    transport = str(curl_exit) if curl_exit is not None else "unavailable"
    daily_ok = "unreported" if selected["ok"] is None else str(selected["ok"]).lower()
    response_state = "valid" if selected["valid"] else (
        "invalid-shape" if body_state == "parsed" else body_state)
    persistence = selected["persistence"]
    lines = ["## Daily cron result", "", f"- HTTP status: {status}",
             f"- curl exit: {transport}", f"- Response: {response_state}",
             f"- Daily jobs ok: {daily_ok}", f"- Ledger persisted: {persistence}"]
    if selected["persistence_code"] is not None:
        lines.append(f"- Ledger error code: {selected['persistence_code']}")
    lines += ["", "| Slot | ok | Duration ms | Rows | Error code |",
              "| --- | --- | ---: | ---: | --- |"]
    for name in DAILY_SLOTS:
        record = selected["slots"].get(name)
        if record is not None:
            rows = "unreported" if record["rows"] is None else str(record["rows"])
            code = record["code"] or "unreported"
            lines.append(f"| {name} | {str(record['ok']).lower()} | {record['duration_ms']} | {rows} | {code} |")
    lines += ["", "No job was retried by this reporting step.", ""]
    return "\n".join(lines)


def main(argv=None):
    parser = SafeArguments(description=__doc__)
    parser.add_argument("--body", required=True)
    parser.add_argument("--http-status", required=True)
    parser.add_argument("--curl-exit-code", required=True)
    parser.add_argument("--summary")
    try:
        args = parser.parse_args(argv)
    except ValueError:
        print("::error::Daily cron summary received invalid arguments.")
        return 2

    curl_exit = numeric_argument(args.curl_exit_code, 255)
    try:
        http_status = numeric_argument(args.http_status, 599)
        if http_status is not None and http_status != 0 and http_status < 100:
            http_status = None
        value, body_state = load_body(args.body)
        selected = inspect_body(value)
        summary = render(http_status, curl_exit, body_state, selected)
        if args.summary:
            with Path(args.summary).open("a", encoding="utf-8", newline="\n") as destination:
                destination.write(summary)
        print(summary)
        if selected["persistence"] in ("false", "unreported"):
            message = ("Daily cron ledger persistence failed; job outcomes are unchanged."
                       if selected["persistence"] == "false" else
                       "Daily cron ledger persistence is unreported; it is not confirmed.")
            print("::warning::" + message)
        transport_ok = curl_exit == 0 and http_status is not None and 200 <= http_status < 300
        success = transport_ok and selected["valid"] and selected["ok"] is True
        if not success:
            print("::error::Daily cron transport, response validation or a job failed; inspect the safe summary.")
        return curl_exit if curl_exit else (0 if success else 1)
    except Exception:
        # Never print exception text, a traceback, a path or response fragments.
        print("::error::Daily cron summary could not be produced safely.")
        return curl_exit if curl_exit else 1


if __name__ == "__main__":
    sys.exit(main())
