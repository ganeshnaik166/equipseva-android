import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";
import { SupplierForm } from "./SupplierForm";

export const metadata = { title: "Bonded supply — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SupplyKpis = {
  total_suppliers: number | null;
  total_intake_lots: number | null;
  total_units_received: number | null;
  total_units_dispatched: number | null;
  total_units_installed: number | null;
  total_units_lost: number | null;
  unmatched_qr_scans: number | null;
};

export default async function SupplyPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bonded_parts_dashboard");
  if (error) throw new Error(`founder_bonded_parts_dashboard: ${error.message}`);
  const k: SupplyKpis = (Array.isArray(data) ? data[0] : data) ?? ({} as SupplyKpis);

  const lostPct =
    k.total_units_received && k.total_units_received > 0 && k.total_units_lost != null
      ? (k.total_units_lost / k.total_units_received) * 100
      : 0;

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Bonded parts provenance</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          OEM / authorized / verified supplier chain from r500. Closes the counterfeit-parts
          CRITICAL (BNS §304A liability). Every intake → dispatch → install is tracked via
          tamper-evident QR codes.
        </p>
      </header>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Ledger state
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Suppliers" value={formatNumber(k.total_suppliers)} />
          <StatCard label="Intake lots" value={formatNumber(k.total_intake_lots)} />
          <StatCard label="Units received" value={formatNumber(k.total_units_received)} />
          <StatCard label="Units installed" value={formatNumber(k.total_units_installed)} />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Flow + integrity
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Units dispatched" value={formatNumber(k.total_units_dispatched)} />
          <StatCard
            label="Units lost / shrink"
            value={formatNumber(k.total_units_lost)}
            subtext={lostPct > 0 ? `${lostPct.toFixed(2)}% of received` : undefined}
            tone={lostPct > 1 ? "warn" : "neutral"}
          />
          <StatCard
            label="Unmatched QR scans"
            value={formatNumber(k.unmatched_qr_scans)}
            tone={(k.unmatched_qr_scans ?? 0) > 0 ? "danger" : "ok"}
          />
          <StatCard
            label="Counterfeit hit-rate"
            value={
              k.total_units_dispatched && k.total_units_dispatched > 0
                ? `${(((k.unmatched_qr_scans ?? 0) / k.total_units_dispatched) * 100).toFixed(2)}%`
                : "—"
            }
          />
        </div>
      </section>

      <SupplierForm />

      <section className="rounded border border-[var(--color-border)] bg-white p-4 text-sm">
        <h2 className="font-semibold">Still unwired</h2>
        <p className="mt-1 text-[var(--color-muted)]">
          <code>founder_record_bonded_intake(supplier_id, invoice_no, invoice_date, invoice_url, brand, part_no, qty, unit_cost, qr_codes[])</code> —
          log a parts receipt lot with tamper QR. Form wiring deferred until the first supplier onboards.
          Call from the Supabase SQL editor for now.
        </p>
      </section>
    </div>
  );
}
