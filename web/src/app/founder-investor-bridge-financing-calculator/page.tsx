import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CalcRow = {
  id: string;
  model_label: string;
  target_amount_rupees: number;
  avg_check_rupees: number;
  number_of_investors: number;
  valuation_cap_rupees: number;
  discount_pct: number;
  founder_dilution_pct: number;
  status: string;
  modeled_at: string;
  assumption_count: number;
  critical_assumption_count: number;
};

type DilutionRow = {
  status: string;
  model_count: number;
  avg_dilution_pct: number;
  min_dilution_pct: number;
  max_dilution_pct: number;
  total_target_rupees: number;
};

type ScenarioRow = {
  id: string;
  model_label: string;
  status: string;
  target_amount_rupees: number;
  valuation_cap_rupees: number;
  discount_pct: number;
  founder_dilution_pct: number;
  effective_price_per_pct: number;
  modeled_at: string;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [calcsRes, dilutionRes, scenarioRes] = await Promise.all([
    sb.rpc('list_calculations_r1893'),
    sb.rpc('founder_dilution_outlook_r1893'),
    sb.rpc('scenario_comparison_r1893'),
  ]);

  const calcs: CalcRow[] = (calcsRes.data as CalcRow[] | null) ?? [];
  const dilution: DilutionRow[] = (dilutionRes.data as DilutionRow[] | null) ?? [];
  const scenarios: ScenarioRow[] = (scenarioRes.data as ScenarioRow[] | null) ?? [];

  const fmtRupees = (n: number) => {
    if (!n) return '0';
    return new Intl.NumberFormat('en-IN').format(n);
  };

  const calcColumns: Column<CalcRow>[] = [
    { key: 'model_label', header: 'Model', render: (r: any) => <span className="font-medium">{r.model_label}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="inline-block px-2 py-0.5 rounded text-xs bg-slate-100 dark:bg-slate-800">{r.status}</span> },
    { key: 'target_amount_rupees', header: 'Target (Rs)', render: (r: any) => <span className="tabular-nums">{fmtRupees(r.target_amount_rupees)}</span> },
    { key: 'avg_check_rupees', header: 'Avg Check (Rs)', render: (r: any) => <span className="tabular-nums">{fmtRupees(r.avg_check_rupees)}</span> },
    { key: 'number_of_investors', header: 'Investors', render: (r: any) => <span className="tabular-nums">{r.number_of_investors}</span> },
    { key: 'valuation_cap_rupees', header: 'Cap (Rs)', render: (r: any) => <span className="tabular-nums">{fmtRupees(r.valuation_cap_rupees)}</span> },
    { key: 'discount_pct', header: 'Discount %', render: (r: any) => <span className="tabular-nums">{r.discount_pct}</span> },
    { key: 'founder_dilution_pct', header: 'Dilution %', render: (r: any) => <span className="tabular-nums font-medium">{r.founder_dilution_pct}</span> },
    { key: 'assumption_count', header: 'Assumptions', render: (r: any) => <span className="tabular-nums">{r.assumption_count}</span> },
    { key: 'critical_assumption_count', header: 'Critical', render: (r: any) => <span className="tabular-nums text-rose-600 dark:text-rose-400">{r.critical_assumption_count}</span> },
    { key: 'modeled_at', header: 'Modeled', render: (r: any) => <span className="text-xs text-slate-500">{r.modeled_at ? new Date(r.modeled_at).toLocaleString('en-IN') : '-'}</span> },
  ];

  const dilutionColumns: Column<DilutionRow>[] = [
    { key: 'status', header: 'Status', render: (r: any) => <span className="font-medium">{r.status}</span> },
    { key: 'model_count', header: 'Models', render: (r: any) => <span className="tabular-nums">{r.model_count}</span> },
    { key: 'avg_dilution_pct', header: 'Avg Dilution %', render: (r: any) => <span className="tabular-nums">{r.avg_dilution_pct}</span> },
    { key: 'min_dilution_pct', header: 'Min %', render: (r: any) => <span className="tabular-nums">{r.min_dilution_pct}</span> },
    { key: 'max_dilution_pct', header: 'Max %', render: (r: any) => <span className="tabular-nums">{r.max_dilution_pct}</span> },
    { key: 'total_target_rupees', header: 'Total Target (Rs)', render: (r: any) => <span className="tabular-nums">{fmtRupees(r.total_target_rupees)}</span> },
  ];

  const scenarioColumns: Column<ScenarioRow>[] = [
    { key: 'model_label', header: 'Scenario', render: (r: any) => <span className="font-medium">{r.model_label}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
    { key: 'target_amount_rupees', header: 'Target (Rs)', render: (r: any) => <span className="tabular-nums">{fmtRupees(r.target_amount_rupees)}</span> },
    { key: 'valuation_cap_rupees', header: 'Cap (Rs)', render: (r: any) => <span className="tabular-nums">{fmtRupees(r.valuation_cap_rupees)}</span> },
    { key: 'discount_pct', header: 'Discount %', render: (r: any) => <span className="tabular-nums">{r.discount_pct}</span> },
    { key: 'founder_dilution_pct', header: 'Dilution %', render: (r: any) => <span className="tabular-nums">{r.founder_dilution_pct}</span> },
    { key: 'effective_price_per_pct', header: 'Rs per 1% Dilution', render: (r: any) => <span className="tabular-nums">{fmtRupees(Math.round(r.effective_price_per_pct))}</span> },
    { key: 'modeled_at', header: 'Modeled', render: (r: any) => <span className="text-xs text-slate-500">{r.modeled_at ? new Date(r.modeled_at).toLocaleDateString('en-IN') : '-'}</span> },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Investor Bridge Financing Calculator</h1>
        <p className="text-sm text-slate-600 dark:text-slate-400">
          Model bridge financing scenarios — cash needed, founder dilution, valuation cap & discount terms.
        </p>
      </header>

      <section className="space-y-3">
        <div className="flex items-baseline justify-between">
          <h2 className="text-lg font-semibold">Modeled Scenarios</h2>
          <span className="text-xs text-slate-500">{calcs.length} models</span>
        </div>
        <p className="text-xs text-slate-500">
          All saved bridge models. Lock a model to mark it the committed baseline before sharing with the syndicate.
        </p>
        <DataTable
          rows={calcs}
          columns={calcColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Founder Dilution Outlook by Status</h2>
        <p className="text-xs text-slate-500">
          Aggregate dilution view: draft vs baseline vs locked. Helps spot if locked models drift &gt; baseline range.
        </p>
        <DataTable
          rows={dilution}
          columns={dilutionColumns}
          rowKey={(r, i) => String(r.status ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Scenario Comparison (sorted least dilutive first)</h2>
        <p className="text-xs text-slate-500">
          Effective price per 1% dilution — lower target / dilution ratio means cheaper capital. Models with dilution &lt; baseline win.
        </p>
        <DataTable
          rows={scenarios}
          columns={scenarioColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <footer className="pt-4 border-t border-slate-200 dark:border-slate-800 text-xs text-slate-500">
        Round r1893 · 2 tables · 7 RPCs · founder-only via is_founder() gate
      </footer>
    </div>
  );
}
