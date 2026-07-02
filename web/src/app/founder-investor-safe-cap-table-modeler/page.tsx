import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ModelRow = {
  id: string;
  model_name: string | null;
  modeled_valuation_rupees: number | null;
  total_safe_amount_rupees: number | null;
  conversion_share_count: number | null;
  founder_ownership_after_pct: number | null;
  modeled_at: string | null;
  status: string | null;
};

type ScenarioRow = {
  id: string;
  model_id: string | null;
  scenario_label: string | null;
  assumption_md: string | null;
  founder_pct_after: number | null;
  employee_pool_after_pct: number | null;
  investor_pct_after: number | null;
  created_at: string | null;
};

type ComparisonRow = {
  scenario_label: string | null;
  founder_pct_after: number | null;
  employee_pool_after_pct: number | null;
  investor_pct_after: number | null;
  total_pct: number | null;
};

type Outlook = {
  total_models: number | null;
  locked_models: number | null;
  baseline_models: number | null;
  avg_founder_pct: number | null;
  min_founder_pct: number | null;
  total_safe_amount_rupees: number | null;
};

function fmtRupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return v.toFixed(2) + '%';
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleString('en-IN');
  } catch {
    return String(s);
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [modelsRes, scenariosRes, outlookRes, comparisonRes] = await Promise.all([
    sb.rpc('list_safe_models_r1785'),
    sb.rpc('list_safe_scenarios_r1785', { p_model_id: null }),
    sb.rpc('founder_dilution_outlook_r1785'),
    sb.rpc('safe_scenario_comparison_r1785', { p_model_id: null }),
  ]);

  const models: ModelRow[] = Array.isArray(modelsRes.data) ? (modelsRes.data as ModelRow[]) : [];
  const scenarios: ScenarioRow[] = Array.isArray(scenariosRes.data) ? (scenariosRes.data as ScenarioRow[]) : [];
  const comparison: ComparisonRow[] = Array.isArray(comparisonRes.data) ? (comparisonRes.data as ComparisonRow[]) : [];
  const outlookArr = Array.isArray(outlookRes.data) ? (outlookRes.data as Outlook[]) : [];
  const outlook: Outlook = outlookArr[0] ?? {
    total_models: 0,
    locked_models: 0,
    baseline_models: 0,
    avg_founder_pct: 0,
    min_founder_pct: 0,
    total_safe_amount_rupees: 0,
  };

  const modelCols: Column<ModelRow>[] = [
    { key: 'model_name', header: 'Model', render: (r: any) => <span>{r.model_name ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? '—'}</span> },
    { key: 'modeled_valuation_rupees', header: 'Valuation', render: (r: any) => <span>{fmtRupees(r.modeled_valuation_rupees)}</span> },
    { key: 'total_safe_amount_rupees', header: 'SAFE Total', render: (r: any) => <span>{fmtRupees(r.total_safe_amount_rupees)}</span> },
    { key: 'conversion_share_count', header: 'Shares', render: (r: any) => <span>{Number(r.conversion_share_count ?? 0).toLocaleString('en-IN')}</span> },
    { key: 'founder_ownership_after_pct', header: 'Founder %', render: (r: any) => <span>{fmtPct(r.founder_ownership_after_pct)}</span> },
    { key: 'modeled_at', header: 'Modeled', render: (r: any) => <span>{fmtDate(r.modeled_at)}</span> },
  ];

  const scenarioCols: Column<ScenarioRow>[] = [
    { key: 'scenario_label', header: 'Scenario', render: (r: any) => <span>{r.scenario_label ?? '—'}</span> },
    { key: 'founder_pct_after', header: 'Founder %', render: (r: any) => <span>{fmtPct(r.founder_pct_after)}</span> },
    { key: 'employee_pool_after_pct', header: 'ESOP %', render: (r: any) => <span>{fmtPct(r.employee_pool_after_pct)}</span> },
    { key: 'investor_pct_after', header: 'Investor %', render: (r: any) => <span>{fmtPct(r.investor_pct_after)}</span> },
    { key: 'assumption_md', header: 'Assumption', render: (r: any) => <span>{(r.assumption_md ?? '').slice(0, 80)}</span> },
    { key: 'created_at', header: 'Logged', render: (r: any) => <span>{fmtDate(r.created_at)}</span> },
  ];

  const comparisonCols: Column<ComparisonRow>[] = [
    { key: 'scenario_label', header: 'Scenario', render: (r: any) => <span>{r.scenario_label ?? '—'}</span> },
    { key: 'founder_pct_after', header: 'Founder %', render: (r: any) => <span>{fmtPct(r.founder_pct_after)}</span> },
    { key: 'employee_pool_after_pct', header: 'ESOP %', render: (r: any) => <span>{fmtPct(r.employee_pool_after_pct)}</span> },
    { key: 'investor_pct_after', header: 'Investor %', render: (r: any) => <span>{fmtPct(r.investor_pct_after)}</span> },
    { key: 'total_pct', header: 'Sum %', render: (r: any) => <span>{fmtPct(r.total_pct)}</span> },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor SAFE Cap Table Modeler</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Model future cap table given existing SAFEs converting — founder dilution outlook & scenario comparison.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Founder Dilution Outlook</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Total Models</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{outlook.total_models ?? 0}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Locked</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{outlook.locked_models ?? 0}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Baseline</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{outlook.baseline_models ?? 0}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Avg Founder %</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtPct(outlook.avg_founder_pct)}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Min Founder %</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtPct(outlook.min_founder_pct)}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#888' }}>SAFE Total</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtRupees(outlook.total_safe_amount_rupees)}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Conversion Models</h2>
        <DataTable rows={models} columns={modelCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Scenarios</h2>
        <DataTable rows={scenarios} columns={scenarioCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Scenario Comparison</h2>
        <DataTable rows={comparison} columns={comparisonCols} rowKey={(r: any, i: number) => String(r.scenario_label ?? i)} />
      </section>
    </div>
  );
}
