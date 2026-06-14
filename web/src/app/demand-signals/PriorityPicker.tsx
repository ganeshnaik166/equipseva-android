"use client";

import { useState, useTransition } from "react";
import { setDemandSignalPriority } from "@/app/actions/demandSignals";

const LEVELS = ["low", "med", "high"] as const;

export function PriorityPicker({
  signalId,
  current,
}: {
  signalId: string;
  current: string | null;
}) {
  const [pending, startTransition] = useTransition();
  const [value, setValue] = useState<string>(current ?? "");
  const [err, setErr] = useState<string | null>(null);

  function pick(level: string) {
    setErr(null);
    setValue(level);
    startTransition(async () => {
      const res = await setDemandSignalPriority(signalId, level);
      if (!res.ok) {
        setErr(res.error);
        setValue(current ?? "");
      }
    });
  }

  return (
    <div className="flex items-center gap-1">
      {LEVELS.map((l) => {
        const tone =
          l === "high"
            ? "bg-red-100 text-[var(--color-danger)]"
            : l === "med"
              ? "bg-yellow-100 text-[var(--color-warn)]"
              : "bg-gray-100";
        const isCurrent = value === l;
        return (
          <button
            key={l}
            type="button"
            disabled={pending}
            onClick={() => pick(l)}
            className={`rounded px-1.5 py-0.5 text-xs ${tone} ${
              isCurrent ? "ring-1 ring-[var(--color-fg)]" : "opacity-60 hover:opacity-100"
            }`}
            title={`Set priority ${l} (bulk on group)`}
          >
            {l}
          </button>
        );
      })}
      {err && <span className="ml-1 text-xs text-[var(--color-danger)]">{err}</span>}
    </div>
  );
}
