"use client";

import { useState, useTransition } from "react";
import { resolveGrievance, type GrievanceStatus } from "@/app/actions/dpdp";

export function DpdpActions({ grievanceId }: { grievanceId: string }) {
  const [pending, startTransition] = useTransition();
  const [done, setDone] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  function trigger(status: GrievanceStatus) {
    setErr(null);
    startTransition(async () => {
      const resolution = window.prompt("Resolution note (required)") ?? "";
      if (resolution.trim().length === 0) return;
      const res = await resolveGrievance(grievanceId, status, resolution.trim());
      if (res.ok) setDone(status);
      else setErr(res.error);
    });
  }

  if (done) return <span className="text-xs text-[var(--color-muted)]">{done}</span>;
  return (
    <div className="flex items-center gap-1.5">
      <button
        type="button"
        disabled={pending}
        onClick={() => trigger("in_progress")}
        className="rounded border border-[var(--color-border)] px-1.5 py-0.5 text-xs hover:bg-gray-50 disabled:opacity-50"
      >
        In progress
      </button>
      <button
        type="button"
        disabled={pending}
        onClick={() => trigger("resolved")}
        className="rounded border border-[var(--color-ok)] px-1.5 py-0.5 text-xs text-[var(--color-ok)] hover:bg-green-50 disabled:opacity-50"
      >
        Resolved
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
