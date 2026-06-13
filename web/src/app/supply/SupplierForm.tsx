"use client";

import { useState, useTransition } from "react";
import { registerBondedSupplier } from "@/app/actions/supply";

const TIERS = ["OEM", "AUTHORIZED", "VERIFIED"] as const;

export function SupplierForm() {
  const [pending, startTransition] = useTransition();
  const [name, setName] = useState("");
  const [gstin, setGstin] = useState("");
  const [tier, setTier] = useState<(typeof TIERS)[number]>("AUTHORIZED");
  const [brandsRaw, setBrandsRaw] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [msg, setMsg] = useState<{ kind: "ok" | "err"; text: string } | null>(null);

  function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setMsg(null);
    const brands = brandsRaw
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
    startTransition(async () => {
      const res = await registerBondedSupplier({
        name,
        gstin,
        tier,
        brands,
        email: email || undefined,
        phone: phone || undefined,
      });
      if (res.ok) {
        setMsg({ kind: "ok", text: `Registered. id=${res.id.slice(0, 8)}…` });
        setName("");
        setGstin("");
        setBrandsRaw("");
        setEmail("");
        setPhone("");
      } else {
        setMsg({ kind: "err", text: res.error });
      }
    });
  }

  return (
    <form onSubmit={onSubmit} className="space-y-3 rounded border border-[var(--color-border)] bg-white p-4">
      <h3 className="text-sm font-semibold">Register bonded supplier</h3>
      <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">Legal name</span>
          <input
            type="text"
            required
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
            placeholder="ACME Medical Devices Pvt Ltd"
          />
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">GSTIN</span>
          <input
            type="text"
            required
            value={gstin}
            onChange={(e) => setGstin(e.target.value.toUpperCase())}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm uppercase"
            placeholder="29ABCDE1234F1Z5"
            maxLength={15}
          />
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">Tier</span>
          <select
            value={tier}
            onChange={(e) => setTier(e.target.value as (typeof TIERS)[number])}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
          >
            {TIERS.map((t) => (
              <option key={t} value={t}>
                {t}
              </option>
            ))}
          </select>
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">OEM brands (comma-separated)</span>
          <input
            type="text"
            required
            value={brandsRaw}
            onChange={(e) => setBrandsRaw(e.target.value)}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
            placeholder="Philips, GE, Mindray"
          />
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">Contact email (optional)</span>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
          />
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">Contact phone (optional)</span>
          <input
            type="tel"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
            placeholder="+91…"
          />
        </label>
      </div>
      {msg && (
        <div
          className={
            msg.kind === "ok"
              ? "text-sm text-[var(--color-ok)]"
              : "text-sm text-[var(--color-danger)]"
          }
        >
          {msg.text}
        </div>
      )}
      <button
        type="submit"
        disabled={pending}
        className="rounded bg-[var(--color-accent)] px-3 py-1 text-sm font-medium text-white disabled:opacity-50"
      >
        {pending ? "Registering…" : "Register supplier"}
      </button>
    </form>
  );
}
