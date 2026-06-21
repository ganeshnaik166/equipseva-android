import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Scenario = {
  id: string;
  scenario_label: string;
  scenario_type: string;
  assumed_exit_valuation_rupees: number;
  assumed_exit_year: number;
  founder_return_pct: number;
  employee_pool_pct: number;
  investor_pool_pct: number;
  status: string;
  modeled_at: string | null;
  created_at: string;
};

type Assumption = {
  id: string;
  scenario_id: string;
  scenario_label: string;
  assumption_label: string;
  assumption_value: string;
  weight: string;
  created_at: string;
};

type Outlook = {
  scenario_type: string;
  scenarios_count: number;
  avg_valuation_rupees: number;
  avg_founder_pct: number;
  avg_employee_pct: number;
  avg_investor_pct: number;
  locked_count: number;
};

type Comparison = {
  scenario_label: string;
  scenario_type: string;
  assumed_exit_valuation_rupees: number;
  assumed_exit_year: number;
  founder_return_pct: number;
  founder_take_rupees: number;
  employee_take_rupees: number;
  investor_take_rupees: number;
  status: string;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  if (n >= 1_00_00_00_000) return '₹' + (n / 1_00_00_00_000).toFixed(2) + ' Kcr';
  if (n >= 1_00_00_000) return '₹' + (n / 1_00_00_000).toFixed(2) + ' Cr';
  if (n >= 1_00_000) return '₹' + (n / 1_00_000).toFixed(2) + ' L';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [scenariosRes, assumptionsRes, outlookRes, comparisonRes] = await Promise.all([
    sb.rpc('list_scenarios_r1845'),
    sb.rpc('list_assumptions_r1845', { p_scenario: null }),
    sb.rpc('founder_return_outlook_r1845'),
    sb.rpc('scenario_comparison_r1845'),
  ]);

  const scenarios: Scenario[] = (scenariosRes.data ?? []) as Scenario[];
  const assumptions: Assumption[] = (assumptionsRes.data ?? []) as Assumption[];
  const outlook: Outlook[] = (outlookRes.data ?? []) as Outlook[];
  const comparison: Comparison[] = (comparisonRes.data ?? []) as Comparison[];

  const scenarioCols: Column<Scenario>[] = [
    { key: 'scenario_label', header: 'Scenario', render: (r: any) => r.scenario_label ?? '-' },
    { key: 'scenario_type', header: 'Type', render: (r: any) => String(r.scenario_type ?? '-').replace('_', ' ') },
    { key: 'assumed_exit_valuation_rupees', header: 'Exit Valuation', render: (r: any) => fmtRupees(r.assumed_exit_valuation_rupees) },
    { key: 'assumed_exit_year', header: 'Exit Yr', render: (r: any) => String(r.assumed_exit_year ?? '-') },
    { key: 'founder_return_pct', header: 'Founder %', render: (r: any) => (r.founder_return_pct ?? 0) + '%' },
    { key: 'employee_pool_pct', header: 'Employee %', render: (r: any) => (r.employee_pool_pct ?? 0) + '%' },
    { key: 'investor_pool_pct', header: 'Investor %', render: (r: any) => (r.investor_pool_pct ?? 0) + '%' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'modeled_at', header: 'Modeled', render: (r: any) => r.modeled_at ? new Date(r.modeled_at).toLocaleDateString() : '-' },
  ];

  const assumptionCols: Column<Assumption>[] = [
    { key: 'scenario_label', header: 'Scenario', render: (r: any) => r.scenario_label ?? '-' },
    { key: 'assumption_label', header: 'Assumption', render: (r: any) => r.assumption_label ?? '-' },
    { key: 'assumption_value', header: 'Value', render: (r: any) => r.assumption_value ?? '-' },
    { key: 'weight', header: 'Weight', render: (r: any) => r.weight ?? '-' },
    { key: 'created_at', header: 'Logged', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleDateString() : '-' },
  ];

  const outlookCols: Column<Outlook>[] = [
    { key: 'scenario_type', header: 'Scenario Bucket', render: (r: any) => String(r.scenario_type ?? '-').replace('_', ' ') },
    { key: 'scenarios_count', header: 'Count', render: (r: any) => String(r.scenarios_count ?? 0) },
    { key: 'avg_valuation_rupees', header: 'Avg Exit Valuation', render: (r: any) => fmtRupees(Number(r.avg_valuation_rupees ?? 0)) },
    { key: 'avg_founder_pct', header: 'Avg Founder %', render: (r: any) => (r.avg_founder_pct ?? 0) + '%' },
    { key: 'avg_employee_pct', header: 'Avg Employee %', render: (r: any) => (r.avg_employee_pct ?? 0) + '%' },
    { key: 'avg_investor_pct', header: 'Avg Investor %', render: (r: any) => (r.avg_investor_pct ?? 0) + '%' },
    { key: 'locked_count', header: 'Locked', render: (r: any) => String(r.locked_count ?? 0) },
  ];

  const comparisonCols: Column<Comparison>[] = [
    { key: 'scenario_label', header: 'Scenario', render: (r: any) => r.scenario_label ?? '-' },
    { key: 'scenario_type', header: 'Type', render: (r: any) => String(r.scenario_type ?? '-').replace('_', ' ') },
    { key: 'assumed_exit_valuation_rupees', header: 'Exit Valuation', render: (r: any) => fmtRupees(r.assumed_exit_valuation_rupees) },
    { key: 'assumed_exit_year', header: 'Year', render: (r: any) => String(r.assumed_exit_year ?? '-') },
    { key: 'founder_return_pct', header: 'Founder %', render: (r: any) => (r.founder_return_pct ?? 0) + '%' },
    { key: 'founder_take_rupees', header: 'Founder Take', render: (r: any) => fmtRupees(Number(r.founder_take_rupees ?? 0)) },
    { key: 'employee_take_rupees', header: 'Employee Take', render: (r: any) => fmtRupees(Number(r.employee_take_rupees ?? 0)) },
    { key: 'investor_take_rupees', header: 'Investor Take', render: (r: any) => fmtRupees(Number(r.investor_take_rupees ?? 0)) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Investor Stress Test Scenarios</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Stress-test return scenarios across downside, base, upside & black-swan paths. Lock baselines before sharing with investors.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Founder Return Outlook</h2>
        <DataTable
          rows={outlook}
          columns={outlookCols}
          rowKey={(r: any, i: number) => String(r.scenario_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Scenario Comparison</h2>
        <DataTable
          rows={comparison}
          columns={comparisonCols}
          rowKey={(r: any, i: number) => String((r.scenario_label ?? '') + i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Scenarios</h2>
        <DataTable
          rows={scenarios}
          columns={scenarioCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Assumptions Log</h2>
        <DataTable
          rows={assumptions}
          columns={assumptionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
