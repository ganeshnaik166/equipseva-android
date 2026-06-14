"use client";

import { useState, useTransition } from "react";
import { promoteEngineerTier } from "@/app/actions/tiers";

const TIERS = ["none", "bronze", "silver", "gold"] as const;

export function PromoteTierAction({
  engineerUserId,
  currentTier,
}: {
  engineerUserId: string;
  currentTier: string | null;
}) {
  const [pending, startTransition] = useTransition();
  const [done, setDone] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [target, setTarget] = useState<string>(currentTier ?? "none");

  function trigger() {
    setErr(null);
    if (target === currentTier) {
      setErr("Target tier matches current — nothing to do.");
      return;
    }
    startTransition(async () => {
      const reason = window.prompt(
        `Reason for setting tier=${target} (min 10 chars — logged to founder_action_log forever):`,
      );
      if (!reason || reason.trim().length < 10) {
        setErr("Cancelled or reason too short.");
        return;
      }
      const res = await promoteEngineerTier(engineerUserId, target, reason.trim());
      if (res.ok) setDone(target);
      else setErr(res.error);
    });
  }

  if (done) {
    return (
      <div className="text-xs text-[var(--color-muted)]">
        Pinned at <span className="font-medium">{done}</span> · refresh to confirm.
      </div>
    );
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      <label className="block text-xs">
        <span className="text-[var(--color-muted)]">Set tier</span>
        <select
          value={target}
          onChange={(e) => setTarget(e.target.value)}
          className="ml-1 rounded border border-[var(--color-border)] px-2 py-0.5 text-xs"
        >
          {TIERS.map((t) => (
            <option key={t} value={t}>
              {t}
            </option>
          ))}
        </select>
      </label>
      <button
        type="button"
        disabled={pending}
        onClick={trigger}
        className="rounded border border-[var(--color-accent)] px-2 py-0.5 text-xs text-[var(--color-accent)] hover:bg-green-50 disabled:opacity-50"
      >
        Promote (override)
      </button>
      {err && <span className="text-xs text-[var(--color-danger)]">{err}</span>}
    </div>
  );
}
