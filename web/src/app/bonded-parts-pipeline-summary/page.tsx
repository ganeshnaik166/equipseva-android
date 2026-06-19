import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bonded parts pipeline summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  active_suppliers: number;
  oem_supplier_pct: number;
  intake_lots_total: number;
  units_in_bond: number;
  units_dispatched_total: number;
  units_installed_total: number;
  dispatched_pending_install: number;
  dispatched_not_installed_7d: number;
  install_evidence_pct: number;
  unmatched_qr_scans: number;
  units_lost_total: number;
  intake_value_in_bond_inr: number;
};

function Card({ title, val, sub, danger, ok }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

const inr = (n: number) => `₹${Number(n).toLocaleString("en-IN")}`;

export default async function BondedPartsPipelineSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bonded_parts_pipeline_summary");
  if (error) throw new Error(`founder_bonded_parts_pipeline_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Bonded parts pipeline summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI provenance chain · intake → dispatch → install evidence + supplier mix · r500 counterfeit-defense ledger</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Active suppliers" val={formatNumber(r.active_suppliers)} sub="OEM + AUTHORIZED + VERIFIED" />
          <Card title="OEM supplier %" val={`${Number(r.oem_supplier_pct).toFixed(1)}%`} ok={r.oem_supplier_pct >= 50} danger={r.oem_supplier_pct < 20} sub="manufacturer-direct share" />
          <Card title="Intake lots total" val={formatNumber(r.intake_lots_total)} sub="vendor-invoice receipts" />
          <Card title="Units in bond" val={formatNumber(r.units_in_bond)} sub="received minus dispatched" />
          <Card title="Units dispatched" val={formatNumber(r.units_dispatched_total)} sub="pulled to repair jobs" />
          <Card title="Units installed" val={formatNumber(r.units_installed_total)} ok={r.units_installed_total > 0} sub="QR-scan confirmed" />
          <Card title="Pending install" val={formatNumber(r.dispatched_pending_install)} danger={r.dispatched_pending_install > 0} sub="dispatched, not yet installed" />
          <Card title="Stuck ≥7d" val={formatNumber(r.dispatched_not_installed_7d)} danger={r.dispatched_not_installed_7d > 0} sub="dispatch aged past SLA" />
          <Card title="Install evidence %" val={`${Number(r.install_evidence_pct).toFixed(1)}%`} ok={r.install_evidence_pct >= 90} danger={r.install_evidence_pct < 70} sub="installed / dispatched" />
          <Card title="Unmatched QR scans" val={formatNumber(r.unmatched_qr_scans)} danger={r.unmatched_qr_scans > 0} sub="suspected-substitution flags" />
          <Card title="Units lost" val={formatNumber(r.units_lost_total)} danger={r.units_lost_total > 0} sub="chain-of-custody breaks" />
          <Card title="Value in bond" val={inr(r.intake_value_in_bond_inr)} sub="warehouse inventory ₹" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
