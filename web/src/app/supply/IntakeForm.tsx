"use client";

import { useMemo, useState, useTransition } from "react";
import { recordBondedIntake } from "@/app/actions/supply";

type Supplier = {
  id: string;
  supplier_name: string;
  supplier_tier: string;
  oem_brands: string[] | null;
};

export function IntakeForm({ suppliers }: { suppliers: Supplier[] }) {
  const [pending, startTransition] = useTransition();
  const [supplierId, setSupplierId] = useState(suppliers[0]?.id ?? "");
  const [invoiceNo, setInvoiceNo] = useState("");
  const [invoiceDate, setInvoiceDate] = useState("");
  const [invoiceUrl, setInvoiceUrl] = useState("");
  const [oemBrand, setOemBrand] = useState("");
  const [partNumber, setPartNumber] = useState("");
  const [partDescription, setPartDescription] = useState("");
  const [quantity, setQuantity] = useState(1);
  const [unitCost, setUnitCost] = useState(0);
  const [qrRaw, setQrRaw] = useState("");
  const [msg, setMsg] = useState<{ kind: "ok" | "err"; text: string } | null>(null);

  const selectedSupplier = suppliers.find((s) => s.id === supplierId);
  const qrCodes = useMemo(
    () =>
      qrRaw
        .split(/\r?\n/)
        .map((c) => c.trim())
        .filter(Boolean),
    [qrRaw],
  );
  const qrMismatch = qrCodes.length !== quantity;

  function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setMsg(null);
    startTransition(async () => {
      const res = await recordBondedIntake({
        supplierId,
        invoiceNo,
        invoiceDate,
        invoiceUrl,
        oemBrand,
        partNumber,
        partDescription,
        quantity,
        unitCostRupees: unitCost,
        tamperQrCodes: qrCodes,
      });
      if (res.ok) {
        setMsg({ kind: "ok", text: `Intake logged. id=${res.id.slice(0, 8)}…` });
        setInvoiceNo("");
        setInvoiceUrl("");
        setPartNumber("");
        setPartDescription("");
        setQuantity(1);
        setUnitCost(0);
        setQrRaw("");
      } else {
        setMsg({ kind: "err", text: res.error });
      }
    });
  }

  if (suppliers.length === 0) {
    return (
      <div className="rounded border border-dashed border-[var(--color-border)] bg-white p-4 text-sm text-[var(--color-muted)]">
        Register at least one supplier above before recording intake.
      </div>
    );
  }

  return (
    <form onSubmit={onSubmit} className="space-y-3 rounded border border-[var(--color-border)] bg-white p-4">
      <h3 className="text-sm font-semibold">Record bonded intake lot</h3>
      <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
        <label className="block text-sm md:col-span-2">
          <span className="text-xs text-[var(--color-muted)]">Supplier</span>
          <select
            value={supplierId}
            onChange={(e) => setSupplierId(e.target.value)}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
            required
          >
            {suppliers.map((s) => (
              <option key={s.id} value={s.id}>
                {s.supplier_name} · {s.supplier_tier}
                {s.oem_brands && s.oem_brands.length > 0 ? ` · ${s.oem_brands.join(", ")}` : ""}
              </option>
            ))}
          </select>
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">Vendor invoice no</span>
          <input
            type="text"
            required
            value={invoiceNo}
            onChange={(e) => setInvoiceNo(e.target.value)}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
          />
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">Invoice date</span>
          <input
            type="date"
            required
            value={invoiceDate}
            onChange={(e) => setInvoiceDate(e.target.value)}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
          />
        </label>
        <label className="block text-sm md:col-span-2">
          <span className="text-xs text-[var(--color-muted)]">Invoice URL (PDF, must be reachable for §65B evidence)</span>
          <input
            type="url"
            required
            value={invoiceUrl}
            onChange={(e) => setInvoiceUrl(e.target.value)}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
            placeholder="https://supplier.example/inv/12345.pdf"
          />
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">OEM brand</span>
          <input
            type="text"
            required
            value={oemBrand}
            onChange={(e) => setOemBrand(e.target.value)}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
            placeholder="Philips"
          />
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">Part number</span>
          <input
            type="text"
            required
            value={partNumber}
            onChange={(e) => setPartNumber(e.target.value)}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
          />
        </label>
        <label className="block text-sm md:col-span-2">
          <span className="text-xs text-[var(--color-muted)]">Part description</span>
          <input
            type="text"
            required
            value={partDescription}
            onChange={(e) => setPartDescription(e.target.value)}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
            placeholder="X-ray tube assembly, 100kV"
          />
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">Quantity received</span>
          <input
            type="number"
            required
            min={1}
            value={quantity}
            onChange={(e) => setQuantity(Math.max(1, Number.parseInt(e.target.value || "0", 10)))}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm tabular-nums"
          />
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">Unit cost (₹)</span>
          <input
            type="number"
            required
            min={1}
            step="0.01"
            value={unitCost}
            onChange={(e) => setUnitCost(Number.parseFloat(e.target.value || "0"))}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm tabular-nums"
          />
        </label>
        <label className="block text-sm md:col-span-2">
          <span className="text-xs text-[var(--color-muted)]">
            Tamper QR codes (one per line — must total {quantity}; you have {qrCodes.length})
          </span>
          <textarea
            required
            rows={Math.min(8, Math.max(3, quantity))}
            value={qrRaw}
            onChange={(e) => setQrRaw(e.target.value)}
            className={`mt-1 w-full rounded border px-2 py-1 font-mono text-xs ${
              qrMismatch ? "border-[var(--color-warn)]" : "border-[var(--color-border)]"
            }`}
            placeholder={`QR-PHL-001\nQR-PHL-002\n…`}
          />
        </label>
      </div>
      <div className="text-xs text-[var(--color-muted)]">
        Lot total: <span className="font-medium">₹{(quantity * unitCost).toFixed(2)}</span>
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
        disabled={pending || qrMismatch}
        className="rounded bg-[var(--color-accent)] px-3 py-1 text-sm font-medium text-white disabled:opacity-50"
      >
        {pending ? "Recording…" : "Record intake lot"}
      </button>
    </form>
  );
}
