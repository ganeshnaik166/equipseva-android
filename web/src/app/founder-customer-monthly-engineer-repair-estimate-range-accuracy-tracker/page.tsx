import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type EstimateRow = {
  id: string;
  cycle_month: string;
  customer_org_label: string;
  engineer_label: string;
  engineer_tier: string;
  estimate_low_rupees: number;
  estimate_high_rupees: number;
  actual_billed_rupees: number;
  job_kind: string;
  within_range: boolean;
  delta_pct: number;
  notes: string | null;
};

type AlertRow = {
  id: string;
  cycle_month: string;
  engineer_label: string;
  alert_kind: string;
  severity: string;
  estimates_count: number;
  breach_count: number;
  median_delta_pct: number;
  action_taken: string | null;
  resolved: boolean;
};

type BreachRow = { engineer_label: string; total_jobs: number; breaches: number; breach_pct: number | null };
type TierRow = { engineer_tier: string; jobs: number; within: number; accuracy_pct: number | null };
type UnderRow = { engineer_label: string; under_count: number; median_delta: number | null };
type CustomerRow = { customer_org_label: string; jobs: number; breaches: number; breach_pct: number | null };
type KpiRow = { total_jobs: number; within_range_pct: number | null; median_delta: number | null; open_alerts: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [estimates, alerts, breach, tier, under, cust, kpis] = await Promise.all([
    supabase.rpc('rpc_r2928_recent_estimates'),
    supabase.rpc('rpc_r2928_open_alerts'),
    supabase.rpc('rpc_r2928_breach_summary'),
    supabase.rpc('rpc_r2928_tier_accuracy'),
    supabase.rpc('rpc_r2928_top_underestimators'),
    supabase.rpc('rpc_r2928_customer_pain'),
    supabase.rpc('rpc_r2928_kpis'),
  ]);

  const estRows = (estimates.data ?? []) as EstimateRow[];
  const alertRows = (alerts.data ?? []) as AlertRow[];
  const breachRows = (breach.data ?? []) as BreachRow[];
  const tierRows = (tier.data ?? []) as TierRow[];
  const underRows = (under.data ?? []) as UnderRow[];
  const custRows = (cust.data ?? []) as CustomerRow[];
  const kpiRows = (kpis.data ?? []) as KpiRow[];
  const k = kpiRows[0];

  const estCols: Column<EstimateRow>[] = [
    { key: 'cycle_month', header: 'Cycle', render: (r) => r.cycle_month?.slice(0, 7) ?? '' },
    { key: 'customer', header: 'Customer', render: (r) => r.customer_org_label },
    { key: 'engineer', header: 'Engineer', render: (r) => r.engineer_label },
    { key: 'tier', header: 'Tier', render: (r) => r.engineer_tier },
    { key: 'range', header: 'Estimate Range', render: (r) => `₹${r.estimate_low_rupees} – ₹${r.estimate_high_rupees}` },
    { key: 'actual', header: 'Actual', render: (r) => `₹${r.actual_billed_rupees}` },
    { key: 'kind', header: 'Kind', render: (r) => r.job_kind },
    { key: 'within', header: 'In Range?', render: (r) => (r.within_range ? 'yes' : 'NO') },
    { key: 'delta', header: 'Δ %', render: (r) => `${r.delta_pct}%` },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '' },
  ];

  const alertCols: Column<AlertRow>[] = [
    { key: 'cycle', header: 'Cycle', render: (r) => r.cycle_month?.slice(0, 7) ?? '' },
    { key: 'engineer', header: 'Engineer', render: (r) => r.engineer_label },
    { key: 'kind', header: 'Kind', render: (r) => r.alert_kind },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'estimates_count', header: 'Estimates', render: (r) => String(r.estimates_count) },
    { key: 'breach_count', header: 'Breaches', render: (r) => String(r.breach_count) },
    { key: 'median_delta_pct', header: 'Median Δ %', render: (r) => `${r.median_delta_pct}%` },
    { key: 'action', header: 'Action', render: (r) => r.action_taken ?? '—' },
    { key: 'resolved', header: 'Resolved', render: (r) => (r.resolved ? 'yes' : 'no') },
  ];

  const breachCols: Column<BreachRow>[] = [
    { key: 'engineer', header: 'Engineer', render: (r) => r.engineer_label },
    { key: 'total_jobs', header: 'Jobs', render: (r) => String(r.total_jobs) },
    { key: 'breaches', header: 'Breaches', render: (r) => String(r.breaches) },
    { key: 'pct', header: 'Breach %', render: (r) => (r.breach_pct == null ? '—' : `${r.breach_pct}%`) },
  ];

  const tierCols: Column<TierRow>[] = [
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier },
    { key: 'jobs', header: 'Jobs', render: (r) => String(r.jobs) },
    { key: 'within', header: 'Within Range', render: (r) => String(r.within) },
    { key: 'accuracy_pct', header: 'Accuracy %', render: (r) => (r.accuracy_pct == null ? '—' : `${r.accuracy_pct}%`) },
  ];

  const underCols: Column<UnderRow>[] = [
    { key: 'engineer_label', header: 'Engineer', render: (r) => r.engineer_label },
    { key: 'under_count', header: 'Under-estimates', render: (r) => String(r.under_count) },
    { key: 'median_delta', header: 'Median Δ %', render: (r) => (r.median_delta == null ? '—' : `${r.median_delta}%`) },
  ];

  const custCols: Column<CustomerRow>[] = [
    { key: 'customer_org_label', header: 'Customer', render: (r) => r.customer_org_label },
    { key: 'jobs', header: 'Jobs', render: (r) => String(r.jobs) },
    { key: 'breaches', header: 'Breaches', render: (r) => String(r.breaches) },
    { key: 'pct', header: 'Breach %', render: (r) => (r.breach_pct == null ? '—' : `${r.breach_pct}%`) },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 28 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Customer Monthly Engineer Repair Estimate-Range Accuracy Tracker</h1>
        <p style={{ color: '#666', fontSize: 13 }}>Round r2928 · HEAVY & founder-only. Tracks whether actual billed amount lands inside the quoted estimate range.</p>
      </header>

      {k ? (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0,1fr))', gap: 12 }}>
          <Kpi label="Total Jobs" value={String(k.total_jobs)} />
          <Kpi label="Within Range %" value={k.within_range_pct == null ? '—' : `${k.within_range_pct}%`} />
          <Kpi label="Median Δ (breaches)" value={k.median_delta == null ? '—' : `${k.median_delta}%`} />
          <Kpi label="Open Alerts" value={String(k.open_alerts)} />
        </section>
      ) : null}

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent Estimates & Actuals</h2>
        <DataTable rows={estRows} columns={estCols} emptyMessage="No estimate rows yet." rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Open Accuracy Alerts</h2>
        <DataTable rows={alertRows} columns={alertCols} emptyMessage="No open alerts." rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Per-Engineer Breach Rate</h2>
        <DataTable rows={breachRows} columns={breachCols} emptyMessage="No breach data." rowKey={(r, i) => String(r.engineer_label ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Accuracy By Tier</h2>
        <DataTable rows={tierRows} columns={tierCols} emptyMessage="No tier data." rowKey={(r, i) => String(r.engineer_tier ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top Under-Estimators (actual &gt; high)</h2>
        <DataTable rows={underRows} columns={underCols} emptyMessage="No under-estimators." rowKey={(r, i) => String(r.engineer_label ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Customer Pain (breach % by org)</h2>
        <DataTable rows={custRows} columns={custCols} emptyMessage="No customer data." rowKey={(r, i) => String(r.customer_org_label ?? i)} />
      </section>
    </main>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
