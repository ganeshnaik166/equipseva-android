"use client";

import { useState, useTransition } from "react";
import { setAmcTier } from "@/app/actions/amc";

const TIERS = ["basic", "bronze", "silver", "gold"] as const;

export function SetTierAction({
  contractId,
  currentTier,
}: {
  contractId: string;
  currentTier: string;
}) {
  const [pending, startTransition] = useTransition();
  const [target, setTarget] = useState<string>(currentTier);
  const [done, setDone] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  function trigger() {
    setErr(null);
    if (target === currentTier) {
      setErr("Target matches current — nothing to do.");
      return;
    }
    startTransition(async () => {
      const reason = window.prompt(
        `Reason for setting tier=${target} (min 10 chars — logged forever):`,
      );
      if (!reason || reason.trim().length < 10) {
        setErr("Cancelled or reason too short.");
        return;
      }
      const res = await setAmcTier(contractId, target, reason.trim());
      if (res.ok) setDone(target);
      else setErr(res.error);
    });
  }

  if (done) return <span className="text-xs text-[var(--color-muted)]">{done}</span>;

  return (
    <div className="flex items-center gap-1.5">
      <select
        value={target}
        onChange={(e) => setTarget(e.target.value)}
        className="rounded border border-[var(--color-border)] px-1 py-0.5 text-xs"
      >
        {TIERS.map((t) => (
          <option key={t} value={t}>
            {t}
          </option>
        ))}
      </select>
      <button
        type="button"
        disabled={pending}
        onClick={trigger}
        className="rounded border border-[var(--color-accent)] px-1.5 py-0.5 text-xs text-[var(--color-accent)] hover:bg-green-50 disabled:opacity-50"
      >
        Set tier
      </button>
      {err && <span className="text-xs text-[var(--color-danger)]">{err}</span>}
    </div>
  );
}
