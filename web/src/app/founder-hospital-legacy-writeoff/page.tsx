import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return new Intl.NumberFormat('en-IN').format(Math.round(Number(n)));
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + new Intl.NumberFormat('en-IN').format(Math.round(Number(n)));
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpiRes, recentRes, ratesRes, riskRes, catRes, reasonRes] = await Promise.all([
    supabase.rpc('founder_writeoff_kpis'),
    supabase.rpc('founder_writeoff_recent_events', { p_limit: 50 }),
    supabase.rpc('founder_writeoff_hospital_rates'),
    supabase.rpc('founder_writeoff_churn_risk'),
    supabase.rpc('founder_writeoff_by_category'),
    supabase.rpc('founder_writeoff_by_reason'),
  ]);

  const k = (kpiRes.data?.[0] ?? {}) as any;
  const recent = (recentRes.data ?? []) as any[];
  const rates = (ratesRes.data ?? []) as any[];
  const risk = (riskRes.data ?? []) as any[];
  const cats = (catRes.data ?? []) as any[];
  const reasons = (reasonRes.data ?? []) as any[];

  const kpis: Kpi[] = [
    { label: 'Total events', value: fmtInt(k.total_events) },
    { label: 'Events 90d', value: fmtInt(k.events_90d) },
    { label: 'Events 30d', value: fmtInt(k.events_30d) },
    { label: 'Events 7d', value: fmtInt(k.events_7d) },
    { label: 'Total value', value: fmtRupees(k.total_value_rupees) },
    { label: 'Value 90d', value: fmtRupees(k.value_90d_rupees) },
    { label: 'Hospitals affected', value: fmtInt(k.hospitals_with_writeoffs) },
    { label: 'AMC-stopped events', value: fmtInt(k.amc_stopped_events) },
    { label: 'Retired', value: fmtInt(k.retired_events) },
    { label: 'Obsolete', value: fmtInt(k.obsolete_events) },
    { label: 'Beyond repair', value: fmtInt(k.beyond_repair_events) },
    { label: 'Critical risk hospitals', value: fmtInt(k.critical_risk_hospitals) },
    { label: 'High risk hospitals', value: fmtInt(k.high_risk_hospitals) },
    { label: 'Medium risk hospitals', value: fmtInt(k.medium_risk_hospitals) },
    { label: 'Avg write-off value', value: fmtRupees(k.avg_writeoff_value_rupees) },
    { label: 'Max write-off value', value: fmtRupees(k.max_writeoff_value_rupees) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'asset_label', header: 'Asset', render: (r: any) => r.asset_label ?? '—' },
    { key: 'asset_category', header: 'Category', render: (r: any) => r.asset_category ?? '—' },
    { key: 'depreciated_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.depreciated_value_rupees) },
    { key: 'writeoff_reason', header: 'Reason', render: (r: any) => r.writeoff_reason ?? '—' },
    { key: 'amc_was_active', header: 'AMC active', render: (r: any) => (r.amc_was_active ? 'Yes' : 'No') },
    { key: 'days_ago', header: 'Days ago', render: (r: any) => fmtInt(r.days_ago) },
  ];

  const ratesCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'events_total', header: 'Events total', render: (r: any) => fmtInt(r.events_total) },
    { key: 'events_90d', header: 'Events 90d', render: (r: any) => fmtInt(r.events_90d) },
    { key: 'value_total_rupees', header: 'Total value', render: (r: any) => fmtRupees(r.value_total_rupees) },
    { key: 'value_90d_rupees', header: 'Value 90d', render: (r: any) => fmtRupees(r.value_90d_rupees) },
    { key: 'amc_stopped_count', header: 'AMC stopped', render: (r: any) => fmtInt(r.amc_stopped_count) },
    { key: 'rate_per_month', header: 'Rate per month', render: (r: any) => fmtInt(r.rate_per_month) },
  ];

  const riskCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'risk_band', header: 'Band', render: (r: any) => r.risk_band ?? '—' },
    { key: 'risk_score', header: 'Score', render: (r: any) => fmtInt(r.risk_score) },
    { key: 'writeoff_count_90d', header: 'Events 90d', render: (r: any) => fmtInt(r.writeoff_count_90d) },
    { key: 'writeoff_value_rupees_90d', header: 'Value 90d', render: (r: any) => fmtRupees(r.writeoff_value_rupees_90d) },
    { key: 'amc_stopped_count', header: 'AMC stopped', render: (r: any) => fmtInt(r.amc_stopped_count) },
  ];

  const catCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'events', header: 'Events', render: (r: any) => fmtInt(r.events) },
    { key: 'total_value_rupees', header: 'Total value', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'amc_stopped_count', header: 'AMC stopped', render: (r: any) => fmtInt(r.amc_stopped_count) },
    { key: 'avg_value_rupees', header: 'Avg value', render: (r: any) => fmtRupees(r.avg_value_rupees) },
  ];

  const reasonCols: Column<any>[] = [
    { key: 'reason', header: 'Reason', render: (r: any) => r.reason ?? '—' },
    { key: 'events', header: 'Events', render: (r: any) => fmtInt(r.events) },
    { key: 'pct_of_total', header: 'Pct of total', render: (r: any) => (r.pct_of_total ?? '—') + '%' },
    { key: 'total_value_rupees', header: 'Total value', render: (r: any) => fmtRupees(r.total_value_rupees) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-10">
      <header className="mb-8">
        <h1 className="text-3xl font-semibold tracking-tight text-slate-900">Hospital Legacy-Equipment Write-Off</h1>
        <p className="mt-2 text-sm text-slate-600">Log retired equipment, watch per-hospital write-off rate, surface churn-risk accounts.</p>
      </header>

      <section className="mb-10 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        {kpis.map((kp) => (
          <div key={kp.label} className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
            <div className="text-xs uppercase tracking-wide text-slate-500">{kp.label}</div>
            <div className="mt-2 text-2xl font-semibold text-slate-900">{kp.value}</div>
          </div>
        ))}
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">Recent write-offs (50)</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">Per-hospital write-off rate</h2>
        <DataTable columns={ratesCols} rows={rates} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">Churn-risk hospitals</h2>
        <DataTable columns={riskCols} rows={risk} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">By category</h2>
        <DataTable columns={catCols} rows={cats} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">By reason</h2>
        <DataTable columns={reasonCols} rows={reasons} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
