"use client";

import { useState, useTransition } from "react";
import {
  resolveCollusionFlag,
  resolveDuplicateFlag,
  type ResolveStatus,
} from "@/app/actions/risk";

type Kind = "collusion" | "duplicate";

export function RiskActions({ kind, flagId }: { kind: Kind; flagId: string }) {
  const [pending, startTransition] = useTransition();
  const [done, setDone] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  function trigger(status: ResolveStatus) {
    setErr(null);
    startTransition(async () => {
      const note = window.prompt(`Reason for marking as ${status}?`) ?? "";
      if (note.trim().length === 0) return;
      const fn = kind === "collusion" ? resolveCollusionFlag : resolveDuplicateFlag;
      const res = await fn(flagId, status, note.trim());
      if (res.ok) setDone(status);
      else setErr(res.error);
    });
  }

  if (done) {
    return (
      <span className="text-xs text-[var(--color-muted)]">marked {done}</span>
    );
  }

  return (
    <div className="flex items-center gap-2">
      <button
        type="button"
        disabled={pending}
        onClick={() => trigger("confirmed")}
        className="rounded border border-[var(--color-danger)] px-2 py-0.5 text-xs text-[var(--color-danger)] hover:bg-red-50 disabled:opacity-50"
      >
        Confirm fraud
      </button>
      <button
        type="button"
        disabled={pending}
        onClick={() => trigger("false_positive")}
        className="rounded border border-[var(--color-border)] px-2 py-0.5 text-xs hover:bg-gray-50 disabled:opacity-50"
      >
        False positive
      </button>
      {err && <span className="text-xs text-[var(--color-danger)]">{err}</span>}
    </div>
  );
}
