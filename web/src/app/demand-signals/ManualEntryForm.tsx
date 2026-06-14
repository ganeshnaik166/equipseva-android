"use client";

import { useState, useTransition } from "react";
import { createManualDemandSignal } from "@/app/actions/demandSignals";

export function ManualEntryForm() {
  const [pending, startTransition] = useTransition();
  const [brand, setBrand] = useState("");
  const [model, setModel] = useState("");
  const [partNumber, setPartNumber] = useState("");
  const [description, setDescription] = useState("");
  const [urgency, setUrgency] = useState("standard");
  const [msg, setMsg] = useState<{ kind: "ok" | "err"; text: string } | null>(null);

  function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setMsg(null);
    startTransition(async () => {
      const res = await createManualDemandSignal({
        brand,
        model,
        partNumber,
        description,
        urgency,
      });
      if (res.ok) {
        setMsg({ kind: "ok", text: `Logged. id=${res.id.slice(0, 8)}…` });
        setBrand("");
        setModel("");
        setPartNumber("");
        setDescription("");
        setUrgency("standard");
      } else {
        setMsg({ kind: "err", text: res.error });
      }
    });
  }

  return (
    <form
      onSubmit={submit}
      className="flex flex-wrap items-end gap-3 rounded border border-[var(--color-border)] bg-white p-3 text-sm"
    >
      <h2 className="w-full text-sm font-semibold">Founder manual entry</h2>
      <p className="-mt-2 w-full text-xs text-[var(--color-muted)]">
        Use this when you hear demand offline (calls / WhatsApp / conferences / engineer reports).
        Source is auto-tagged <code>manual_founder</code> (founder-only per r572 gate).
      </p>

      <label className="block">
        <span className="text-xs text-[var(--color-muted)]">Brand</span>
        <input
          type="text"
          value={brand}
          onChange={(e) => setBrand(e.target.value)}
          placeholder="Mindray"
          maxLength={120}
          className="mt-1 w-40 rounded border border-[var(--color-border)] px-2 py-1 text-sm"
        />
      </label>

      <label className="block">
        <span className="text-xs text-[var(--color-muted)]">Model</span>
        <input
          type="text"
          value={model}
          onChange={(e) => setModel(e.target.value)}
          placeholder="BeneView T5"
          maxLength={120}
          className="mt-1 w-44 rounded border border-[var(--color-border)] px-2 py-1 text-sm"
        />
      </label>

      <label className="block">
        <span className="text-xs text-[var(--color-muted)]">Part number</span>
        <input
          type="text"
          value={partNumber}
          onChange={(e) => setPartNumber(e.target.value)}
          placeholder="115-006080-00"
          maxLength={200}
          className="mt-1 w-44 rounded border border-[var(--color-border)] px-2 py-1 text-sm font-mono"
        />
      </label>

      <label className="block">
        <span className="text-xs text-[var(--color-muted)]">Urgency</span>
        <select
          value={urgency}
          onChange={(e) => setUrgency(e.target.value)}
          className="mt-1 w-32 rounded border border-[var(--color-border)] px-2 py-1 text-sm"
        >
          <option value="standard">standard</option>
          <option value="urgent">urgent</option>
          <option value="critical">critical</option>
        </select>
      </label>

      <label className="block flex-1 min-w-[16rem]">
        <span className="text-xs text-[var(--color-muted)]">Description / source (free text)</span>
        <input
          type="text"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Hospital A asked over WhatsApp; out-of-warranty"
          maxLength={500}
          className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
        />
      </label>

      <button
        type="submit"
        disabled={pending}
        className="rounded bg-[var(--color-accent)] px-3 py-1 text-sm font-medium text-white disabled:opacity-50"
      >
        {pending ? "Logging…" : "Log demand signal"}
      </button>

      {msg && (
        <span
          className={`text-xs ${
            msg.kind === "ok" ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]"
          }`}
        >
          {msg.text}
        </span>
      )}
    </form>
  );
}
