import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  const v = Number(n);
  if (!Number.isFinite(v)) return '-';
  return '₹' + Math.round(v).toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toLocaleString('en-IN');
}

export default async function FounderInvestor12moForecastPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let scenarios: any[] = [];
  let currentState: any = null;
  let summary: any[] = [];
  let projConservative: any[] = [];
  let projBase: any[] = [];
  let projAggressive: any[] = [];
  let snapshots: any[] = [];

  try {
    const r = await sb.rpc('founder_forecast_scenarios_list');
    scenarios = (r.data as any[]) ?? [];
  } catch { scenarios = []; }

  try {
    const r = await sb.rpc('founder_forecast_current_state');
    const rows = (r.data as any[]) ?? [];
    currentState = rows[0] ?? null;
  } catch { currentState = null; }

  try {
    const r = await sb.rpc('founder_forecast_summary');
    summary = (r.data as any[]) ?? [];
  } catch { summary = []; }

  try {
    const r = await sb.rpc('founder_forecast_project', { p_scenario_code: 'conservative' });
    projConservative = (r.data as any[]) ?? [];
  } catch { projConservative = []; }

  try {
    const r = await sb.rpc('founder_forecast_project', { p_scenario_code: 'base' });
    projBase = (r.data as any[]) ?? [];
  } catch { projBase = []; }

  try {
    const r = await sb.rpc('founder_forecast_project', { p_scenario_code: 'aggressive' });
    projAggressive = (r.data as any[]) ?? [];
  } catch { projAggressive = []; }

  try {
    const r = await sb.rpc('founder_forecast_snapshots_recent', { p_limit: 25 });
    snapshots = (r.data as any[]) ?? [];
  } catch { snapshots = []; }

  const sumBy = (code: string) => summary.find((s: any) => s?.scenario_code === code) ?? {};
  const sCons = sumBy('conservative');
  const sBase = sumBy('base');
  const sAggr = sumBy('aggressive');

  const kpis: Kpi[] = [
    { label: 'Active AMC', value: fmtNum(currentState?.active_amc_count) },
    { label: 'Starting MRR', value: fmtRupees(currentState?.starting_mrr_rupees) },
    { label: 'Starting ARR', value: fmtRupees(currentState?.starting_arr_rupees) },
    { label: '90d Payouts', value: fmtRupees(currentState?.trailing_90d_payout_rupees) },
    { label: 'Est Monthly Burn', value: fmtRupees(currentState?.monthly_burn_rupees) },
    { label: 'Est Cash', value: fmtRupees(currentState?.estimated_cash_rupees) },
    { label: 'Conservative MRR m12', value: fmtRupees(sCons?.mrr_m12_rupees) },
    { label: 'Conservative ARR m12', value: fmtRupees(sCons?.arr_m12_rupees) },
    { label: 'Conservative Runway', value: fmtNum(sCons?.runway_months) + ' mo' },
    { label: 'Base MRR m12', value: fmtRupees(sBase?.mrr_m12_rupees) },
    { label: 'Base ARR m12', value: fmtRupees(sBase?.arr_m12_rupees) },
    { label: 'Base Runway', value: fmtNum(sBase?.runway_months) + ' mo' },
    { label: 'Aggressive MRR m12', value: fmtRupees(sAggr?.mrr_m12_rupees) },
    { label: 'Aggressive ARR m12', value: fmtRupees(sAggr?.arr_m12_rupees) },
    { label: 'Aggressive Runway', value: fmtNum(sAggr?.runway_months) + ' mo' },
    { label: 'Saved Snapshots', value: fmtNum(snapshots.length) },
  ];

  const scenarioCols: Column<any>[] = [
    { key: 'scenario_code', header: 'Scenario', render: (r: any) => String(r?.scenario_code ?? '-') },
    { key: 'label', header: 'Label', render: (r: any) => String(r?.label ?? '-') },
    { key: 'growth_pct_monthly', header: 'Growth %/mo', render: (r: any) => String(r?.growth_pct_monthly ?? '-') },
    { key: 'churn_pct_monthly', header: 'Churn %/mo', render: (r: any) => String(r?.churn_pct_monthly ?? '-') },
    { key: 'burn_inflation_pct_monthly', header: 'Burn infl %/mo', render: (r: any) => String(r?.burn_inflation_pct_monthly ?? '-') },
    { key: 'arpu_rupees', header: 'ARPU', render: (r: any) => fmtRupees(r?.arpu_rupees) },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r?.notes ?? '-') },
  ];

  const projCols: Column<any>[] = [
    { key: 'month_index', header: 'Month', render: (r: any) => String(r?.month_index ?? '-') },
    { key: 'mrr_rupees', header: 'MRR', render: (r: any) => fmtRupees(r?.mrr_rupees) },
    { key: 'arr_rupees', header: 'ARR', render: (r: any) => fmtRupees(r?.arr_rupees) },
    { key: 'burn_rupees', header: 'Burn', render: (r: any) => fmtRupees(r?.burn_rupees) },
    { key: 'cash_remaining_rupees', header: 'Cash', render: (r: any) => fmtRupees(r?.cash_remaining_rupees) },
    { key: 'is_runway_break', header: 'Break', render: (r: any) => (r?.is_runway_break ? 'YES' : 'no') },
  ];

  const snapshotCols: Column<any>[] = [
    { key: 'scenario_code', header: 'Scenario', render: (r: any) => String(r?.scenario_code ?? '-') },
    { key: 'picked_for_investor', header: 'Picked', render: (r: any) => (r?.picked_for_investor ? 'YES' : '-') },
    { key: 'starting_mrr_rupees', header: 'Start MRR', render: (r: any) => fmtRupees(r?.starting_mrr_rupees) },
    { key: 'monthly_burn_rupees', header: 'Burn', render: (r: any) => fmtRupees(r?.monthly_burn_rupees) },
    { key: 'runway_months', header: 'Runway mo', render: (r: any) => String(r?.runway_months ?? '-') },
    { key: 'arr_12mo_rupees', header: 'ARR m12', render: (r: any) => fmtRupees(r?.arr_12mo_rupees) },
    { key: 'created_at', header: 'Created', render: (r: any) => String(r?.created_at ?? '-') },
  ];

  return (
    <main style={{ padding: 24 }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Investor 12-Month Forecast</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Projected MRR, ARR, burn and runway under conservative, base and aggressive scenarios. Pick one to send investors.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0,1fr))', gap: 12, marginBottom: 24 }}>
        {kpis.map((k: Kpi) => (
          <div key={k.label} style={{ border: '1px solid #eee', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600 }}>{k.value ?? '-'}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Scenarios</h2>
        <DataTable
          rows={scenarios}
          columns={scenarioCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Conservative Projection</h2>
        <DataTable
          rows={projConservative}
          columns={projCols}
          rowKey={(r: any) => 'c-' + r.month_index}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Base Projection</h2>
        <DataTable
          rows={projBase}
          columns={projCols}
          rowKey={(r: any) => 'b-' + r.month_index}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Aggressive Projection</h2>
        <DataTable
          rows={projAggressive}
          columns={projCols}
          rowKey={(r: any) => 'a-' + r.month_index}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Saved Snapshots</h2>
        <DataTable
          rows={snapshots}
          columns={snapshotCols}
          rowKey={(r: any) => r.id}
        />
      </section>
    </main>
  );
}
