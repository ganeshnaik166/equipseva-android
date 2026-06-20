import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function inr(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  const v = Math.round(Number(n));
  return "₹" + v.toLocaleString('en-IN');
}

function num(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toLocaleString('en-IN');
}

function pct(bps: number | null | undefined): string {
  if (bps === null || bps === undefined) return "—";
  return (Number(bps) / 100).toFixed(2) + "%";
}

export default async function HospitalContractNpvPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let summary: any = null;
  let ladder: any[] = [];
  let negatives: any[] = [];
  let byTier: any[] = [];
  let actions: any[] = [];
  let topLifts: any[] = [];
  let preview: any = null;

  try {
    const { data } = await sb.rpc('founder_npv_summary');
    summary = Array.isArray(data) ? data[0] : data;
  } catch (_) {}
  try {
    const { data } = await sb.rpc('founder_npv_ladder');
    ladder = (data ?? []) as any[];
  } catch (_) {}
  try {
    const { data } = await sb.rpc('founder_npv_negative_contracts');
    negatives = (data ?? []) as any[];
  } catch (_) {}
  try {
    const { data } = await sb.rpc('founder_npv_by_tier');
    byTier = (data ?? []) as any[];
  } catch (_) {}
  try {
    const { data } = await sb.rpc('founder_npv_renegotiation_actions');
    actions = (data ?? []) as any[];
  } catch (_) {}
  try {
    const { data } = await sb.rpc('founder_npv_top_lifts');
    topLifts = (data ?? []) as any[];
  } catch (_) {}
  try {
    const { data } = await sb.rpc('founder_npv_recompute_preview');
    preview = Array.isArray(data) ? data[0] : data;
  } catch (_) {}

  const kpis: Kpi[] = [
    { label: 'Total Contracts', value: num(summary?.total_contracts) },
    { label: 'Positive NPV', value: num(summary?.positive_npv_count) },
    { label: 'Negative NPV', value: num(summary?.negative_npv_count) },
    { label: 'Zero NPV', value: num(summary?.zero_npv_count) },
    { label: 'Total NPV', value: inr(summary?.total_npv_rupees) },
    { label: 'Avg NPV', value: inr(summary?.avg_npv_rupees) },
    { label: 'Median NPV', value: inr(summary?.median_npv_rupees) },
    { label: 'Worst NPV', value: inr(summary?.worst_npv_rupees) },
    { label: 'Best NPV', value: inr(summary?.best_npv_rupees) },
    { label: 'Gross Revenue (PV)', value: inr(summary?.total_revenue_rupees) },
    { label: 'Gross Cost (PV)', value: inr(summary?.total_cost_rupees) },
    { label: 'Total Discount', value: inr(summary?.total_discount_rupees) },
    { label: 'Pending Actions', value: num(summary?.pending_actions) },
    { label: 'Flagged', value: num(summary?.flagged_count) },
    { label: 'Renegotiated', value: num(summary?.renegotiated_count) },
    { label: 'No Snapshot Yet', value: num(preview?.amc_with_no_snapshot) },
  ];

  const ladderCols: Column<any>[] = [
    { key: 'rank_pos', header: 'Rank', render: (r: any) => num(r.rank_pos) },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? "—" },
    { key: 'amc_tier', header: 'Tier', render: (r: any) => r.amc_tier ?? "—" },
    { key: 'monthly_fee_rupees', header: 'Monthly Fee', render: (r: any) => inr(r.monthly_fee_rupees) },
    { key: 'gross_revenue_rupees', header: 'Rev (PV)', render: (r: any) => inr(r.gross_revenue_rupees) },
    { key: 'gross_cost_rupees', header: 'Cost (PV)', render: (r: any) => inr(r.gross_cost_rupees) },
    { key: 'upfront_discount_rupees', header: 'Discount', render: (r: any) => inr(r.upfront_discount_rupees) },
    { key: 'npv_rupees', header: 'NPV', render: (r: any) => inr(r.npv_rupees) },
  ];

  const negativeCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? "—" },
    { key: 'amc_tier', header: 'Tier', render: (r: any) => r.amc_tier ?? "—" },
    { key: 'monthly_fee_rupees', header: 'Monthly Fee', render: (r: any) => inr(r.monthly_fee_rupees) },
    { key: 'gross_cost_rupees', header: 'Cost (PV)', render: (r: any) => inr(r.gross_cost_rupees) },
    { key: 'upfront_discount_rupees', header: 'Discount', render: (r: any) => inr(r.upfront_discount_rupees) },
    { key: 'npv_rupees', header: 'NPV', render: (r: any) => inr(r.npv_rupees) },
    { key: 'loss_per_month', header: 'Loss / Mo', render: (r: any) => inr(r.loss_per_month) },
  ];

  const tierCols: Column<any>[] = [
    { key: 'amc_tier', header: 'Tier', render: (r: any) => r.amc_tier ?? "—" },
    { key: 'contract_count', header: 'Contracts', render: (r: any) => num(r.contract_count) },
    { key: 'avg_npv_rupees', header: 'Avg NPV', render: (r: any) => inr(r.avg_npv_rupees) },
    { key: 'total_npv_rupees', header: 'Total NPV', render: (r: any) => inr(r.total_npv_rupees) },
    { key: 'negative_count', header: 'Negative', render: (r: any) => num(r.negative_count) },
    { key: 'avg_monthly_fee', header: 'Avg Fee', render: (r: any) => inr(r.avg_monthly_fee) },
    { key: 'avg_discount', header: 'Avg Discount', render: (r: any) => inr(r.avg_discount) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'amc_contract_id', header: 'Contract', render: (r: any) => String(r.amc_contract_id ?? "—").slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? "—" },
    { key: 'proposed_fee_rupees', header: 'Proposed Fee', render: (r: any) => inr(r.proposed_fee_rupees) },
    { key: 'expected_npv_lift_rupees', header: 'Lift', render: (r: any) => inr(r.expected_npv_lift_rupees) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? "—" },
    { key: 'days_open', header: 'Days Open', render: (r: any) => (r.days_open !== null && r.days_open !== undefined) ? Number(r.days_open).toFixed(1) : "—" },
    { key: 'acted_at', header: 'Acted At', render: (r: any) => r.acted_at ? new Date(r.acted_at).toLocaleDateString() : "—" },
  ];

  const liftCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? "—" },
    { key: 'current_npv_rupees', header: 'Current NPV', render: (r: any) => inr(r.current_npv_rupees) },
    { key: 'expected_npv_lift_rupees', header: 'Expected Lift', render: (r: any) => inr(r.expected_npv_lift_rupees) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? "—" },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? "—" },
  ];

  return (
    <main className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Contract NPV Ladder</h1>
        <p className="text-sm text-neutral-600">Per-AMC NPV (revenue minus cost minus discount over 3-yr term, discounted at WACC). Negative-NPV contracts surfaced for renegotiation.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-lg border p-3">
            <div className="text-xs text-neutral-500">{k.label}</div>
            <div className="text-lg font-semibold mt-1">{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">NPV Ladder (worst-first)</h2>
        <DataTable<any> columns={ladderCols} rows={ladder} rowKey={(r: any) => r.amc_contract_id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Negative-NPV Contracts (renegotiate)</h2>
        <DataTable<any> columns={negativeCols} rows={negatives} rowKey={(r: any) => r.amc_contract_id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">NPV by Tier</h2>
        <DataTable<any> columns={tierCols} rows={byTier} rowKey={(r: any) => r.amc_tier ?? 'unknown'} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Renegotiation Actions</h2>
        <DataTable<any> columns={actionCols} rows={actions} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Expected NPV Lifts</h2>
        <DataTable<any> columns={liftCols} rows={topLifts} rowKey={(r: any) => (r.amc_contract_id ?? '') + ':' + (r.acted_at ?? '')} />
      </section>

      <footer className="text-xs text-neutral-500">
        WACC default 15% · term 36 months · oldest snapshot age (days): {preview?.oldest_snapshot_age_days !== undefined ? Number(preview.oldest_snapshot_age_days).toFixed(1) : "—"} · default WACC bps shown as {pct(1500)}
      </footer>
    </main>
  );
}
