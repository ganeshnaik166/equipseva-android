"use client";

import { useState, useTransition } from "react";
import { setTierSupervisedThreshold } from "@/app/actions/training";

type Row = { tier: string; min: number };

const TIER_TONE: Record<string, string> = {
  none: "bg-gray-100",
  bronze: "bg-orange-100 text-orange-800",
  silver: "bg-gray-200",
  gold: "bg-yellow-100 text-yellow-800",
};

export function ThresholdEditor({ rows }: { rows: Row[] }) {
  const [pending, startTransition] = useTransition();
  const [draft, setDraft] = useState<Record<string, string>>(
    Object.fromEntries(rows.map((r) => [r.tier, String(r.min)])),
  );
  const [msg, setMsg] = useState<{ tier: string; kind: "ok" | "err"; text: string } | null>(
    null,
  );

  function save(tier: string) {
    setMsg(null);
    const value = parseInt(draft[tier] ?? "0", 10);
    if (Number.isNaN(value) || value < 0) {
      setMsg({ tier, kind: "err", text: "non-negative integer" });
      return;
    }
    startTransition(async () => {
      const res = await setTierSupervisedThreshold(tier, value);
      if (res.ok) setMsg({ tier, kind: "ok", text: `saved (${value})` });
      else setMsg({ tier, kind: "err", text: res.error });
    });
  }

  return (
    <section className="rounded border border-[var(--color-border)] bg-white p-3">
      <h2 className="mb-2 text-sm font-semibold">
        Supervised-completion thresholds (per tier)
      </h2>
      <p className="mb-3 text-xs text-[var(--color-muted)]">
        r578 gate on{" "}
        <code>compute_engineer_certification_tier</code>. Engineers must have
        at least this many <code>completed_successful</code> supervised
        assignments to reach the tier. <strong>0 = no requirement.</strong>{" "}
        Changes take effect on the next daily compute run; manual overrides
        bypass.
      </p>
      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        {rows.map((r) => (
          <div
            key={r.tier}
            className="flex flex-col gap-1.5 rounded border border-[var(--color-border)] p-2"
          >
            <span
              className={`w-fit rounded px-1.5 py-0.5 text-xs ${TIER_TONE[r.tier] ?? "bg-gray-100"}`}
            >
              {r.tier}
            </span>
            <input
              type="number"
              min={0}
              max={100}
              value={draft[r.tier] ?? "0"}
              onChange={(e) =>
                setDraft({ ...draft, [r.tier]: e.target.value })
              }
              className="w-20 rounded border border-[var(--color-border)] px-2 py-1 text-sm tabular-nums"
            />
            <button
              type="button"
              onClick={() => save(r.tier)}
              disabled={pending}
              className="rounded border border-[var(--color-border)] px-2 py-0.5 text-xs hover:bg-gray-50 disabled:opacity-50"
            >
              Save
            </button>
            {msg && msg.tier === r.tier && (
              <span
                className={`text-xs ${msg.kind === "ok" ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]"}`}
              >
                {msg.text}
              </span>
            )}
          </div>
        ))}
      </div>
    </section>
  );
}
