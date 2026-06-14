"use client";

import { useState, useTransition } from "react";
import { setEngineerVerification, type VerificationStatus } from "@/app/actions/onboarding";

export function VerifyActions({ userId }: { userId: string }) {
  const [pending, startTransition] = useTransition();
  const [done, setDone] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  function trigger(status: VerificationStatus) {
    setErr(null);
    startTransition(async () => {
      const reason =
        status === "verified"
          ? window.prompt("Approval note (optional)") ?? null
          : window.prompt("Rejection reason (required)") ?? "";
      if (status !== "verified" && (reason ?? "").trim().length === 0) return;
      const rejectedDocs =
        status === "rejected"
          ? (window.prompt(
              "Rejected doc types (comma-separated, optional): aadhaar / pan / certificates / selfie",
            ) ?? "")
              .split(",")
              .map((s) => s.trim())
              .filter(Boolean)
          : null;
      const res = await setEngineerVerification(
        userId,
        status,
        (reason ?? "").trim() || null,
        rejectedDocs && rejectedDocs.length > 0 ? rejectedDocs : null,
      );
      if (res.ok) setDone(status);
      else setErr(res.error);
    });
  }

  if (done) {
    return <span className="text-xs text-[var(--color-muted)]">{done}</span>;
  }
  return (
    <div className="flex items-center gap-1.5">
      <button
        type="button"
        disabled={pending}
        onClick={() => trigger("verified")}
        className="rounded border border-[var(--color-ok)] px-1.5 py-0.5 text-xs text-[var(--color-ok)] hover:bg-green-50 disabled:opacity-50"
      >
        Approve
      </button>
      <button
        type="button"
        disabled={pending}
        onClick={() => trigger("rejected")}
        className="rounded border border-[var(--color-danger)] px-1.5 py-0.5 text-xs text-[var(--color-danger)] hover:bg-red-50 disabled:opacity-50"
      >
        Reject
      </button>
      {err && <span className="text-xs text-[var(--color-danger)]">{err}</span>}
    </div>
  );
}
