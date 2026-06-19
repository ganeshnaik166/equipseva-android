import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Reconciliation + tax snapshot — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  recon_runs_today: number;
  recon_anomalies_open: number;
  recon_drift_runs_30d: number;
  recon_last_run_status: string;
  recon_inflow_mtd_rupees: number;
  recon_outflow_mtd_rupees: number;
  tds_deducted_mtd_rupees: number;
  tds_deductions_mtd_count: number;
  tds_undeposited_rupees: number;
  tds_certificate_backlog: number;
  tds_fy_gross_rupees: number;
  tds_fy_rupees: number;
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

function formatRupees(n: number): string {
  return `₹${formatNumber(Math.round(Number(n) || 0))}`;
}

export default async function ReconciliationTaxSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_reconciliation_tax_snapshot_summary");
  if (error) throw new Error(`founder_reconciliation_tax_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Reconciliation + tax snapshot</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI finance-ops dashboard · r489 three-way recon + r490 §194-O TDS · pair with /recon-health + /tds-health</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Recon runs today" val={formatNumber(r.recon_runs_today)} sub="IST day" danger={r.recon_runs_today === 0} ok={r.recon_runs_today > 0} />
          <Card title="Anomalies open" val={formatNumber(r.recon_anomalies_open)} sub="open + investigating" danger={r.recon_anomalies_open > 0} />
          <Card title="Drift runs 30d" val={formatNumber(r.recon_drift_runs_30d)} sub="recon failures" danger={r.recon_drift_runs_30d > 0} />
          <Card title="Last run status" val={r.recon_last_run_status ?? "never_ran"} danger={r.recon_last_run_status !== "clean"} ok={r.recon_last_run_status === "clean"} />
          <Card title="Inflow MTD" val={formatRupees(r.recon_inflow_mtd_rupees)} sub="Razorpay total" />
          <Card title="Outflow MTD" val={formatRupees(r.recon_outflow_mtd_rupees)} sub="Cashfree payouts" />
          <Card title="TDS deducted MTD" val={formatRupees(r.tds_deducted_mtd_rupees)} sub={`${formatNumber(r.tds_deductions_mtd_count)} deductions`} />
          <Card title="TDS undeposited" val={formatRupees(r.tds_undeposited_rupees)} sub="owed to govt" danger={r.tds_undeposited_rupees > 0} />
          <Card title="Cert backlog" val={formatNumber(r.tds_certificate_backlog)} sub="Form 16A pending" danger={r.tds_certificate_backlog > 0} />
          <Card title="FY gross to engineers" val={formatRupees(r.tds_fy_gross_rupees)} sub="26Q base" />
          <Card title="FY TDS deducted" val={formatRupees(r.tds_fy_rupees)} sub="194-O year-to-date" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}