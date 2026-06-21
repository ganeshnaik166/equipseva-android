import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toLocaleString('en-IN');
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (v >= 10000000) return `₹${(v / 10000000).toFixed(2)} Cr`;
  if (v >= 100000) return `₹${(v / 100000).toFixed(2)} L`;
  return `₹${v.toLocaleString('en-IN')}`;
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return `${Number(n).toFixed(2)}%`;
}

function fmtDays(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return `${Number(n).toFixed(1)} d`;
}

export default async function FounderCapTableSimulatorV4Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let scenarios: any[] = [];
  let topDilution: any[] = [];
  let topSecondary: any[] = [];
  let locked: any[] = [];
  let audit: any[] = [];

  try {
    const r = await sb.rpc('founder_cts_v4_summary_kpis');
    kpis = (r.data && r.data[0]) || null;
  } catch {
    kpis = null;
  }
  try {
    const r = await sb.rpc('founder_cts_v4_list_scenarios');
    scenarios = r.data || [];
  } catch {
    scenarios = [];
  }
  try {
    const r = await sb.rpc('founder_cts_v4_top_dilution');
    topDilution = r.data || [];
  } catch {
    topDilution = [];
  }
  try {
    const r = await sb.rpc('founder_cts_v4_top_secondary');
    topSecondary = r.data || [];
  } catch {
    topSecondary = [];
  }
  try {
    const r = await sb.rpc('founder_cts_v4_locked_scenario');
    locked = r.data || [];
  } catch {
    locked = [];
  }
  try {
    const r = await sb.rpc('founder_cts_v4_recent_audit');
    audit = r.data || [];
  } catch {
    audit = [];
  }

  const cards: Kpi[] = [
    { label: 'Total scenarios', value: fmtInt(kpis?.total_scenarios) },
    { label: 'Locked', value: fmtInt(kpis?.locked_scenarios) },
    { label: 'Unlocked', value: fmtInt(kpis?.unlocked_scenarios) },
    { label: 'Min valuation', value: fmtRupees(kpis?.min_valuation_rupees) },
    { label: 'Max valuation', value: fmtRupees(kpis?.max_valuation_rupees) },
    { label: 'Avg valuation', value: fmtRupees(kpis?.avg_valuation_rupees) },
    { label: 'Min dilution', value: fmtPct(kpis?.min_dilution_pct) },
    { label: 'Max dilution', value: fmtPct(kpis?.max_dilution_pct) },
    { label: 'Avg dilution', value: fmtPct(kpis?.avg_dilution_pct) },
    { label: 'Max secondary', value: fmtRupees(kpis?.max_secondary_rupees) },
    { label: 'Total secondary', value: fmtRupees(kpis?.total_secondary_rupees) },
    { label: 'Max ESOP refresh', value: fmtPct(kpis?.max_esop_refresh_pct) },
    { label: 'Min post-money', value: fmtPct(kpis?.min_post_money_pct) },
    { label: 'Max post-money', value: fmtPct(kpis?.max_post_money_pct) },
    { label: 'Last locked', value: kpis?.last_locked_at ? new Date(kpis.last_locked_at).toLocaleString() : '—' },
    { label: 'Last created', value: kpis?.last_created_at ? new Date(kpis.last_created_at).toLocaleString() : '—' },
  ];

  const scenarioCols: Column<any>[] = [
    { key: 'scenario_label', header: 'Scenario', render: (r: any) => r.scenario_label ?? '—' },
    { key: 'series_a_valuation_rupees', header: 'Series A val', render: (r: any) => fmtRupees(r.series_a_valuation_rupees) },
    { key: 'series_a_raise_rupees', header: 'Raise', render: (r: any) => fmtRupees(r.series_a_raise_rupees) },
    { key: 'esop_refresh_pct', header: 'ESOP refresh', render: (r: any) => fmtPct(r.esop_refresh_pct) },
    { key: 'secondary_sale_rupees', header: 'Secondary', render: (r: any) => fmtRupees(r.secondary_sale_rupees) },
    { key: 'founder_dilution_pct', header: 'Dilution', render: (r: any) => fmtPct(r.founder_dilution_pct) },
    { key: 'founder_post_money_pct', header: 'Post-money', render: (r: any) => fmtPct(r.founder_post_money_pct) },
    { key: 'is_locked_for_board', header: 'Locked', render: (r: any) => (r.is_locked_for_board ? 'YES' : 'no') },
  ];

  const dilutionCols: Column<any>[] = [
    { key: 'scenario_label', header: 'Scenario', render: (r: any) => r.scenario_label ?? '—' },
    { key: 'series_a_valuation_rupees', header: 'Val', render: (r: any) => fmtRupees(r.series_a_valuation_rupees) },
    { key: 'founder_dilution_pct', header: 'Dilution', render: (r: any) => fmtPct(r.founder_dilution_pct) },
    { key: 'founder_post_money_pct', header: 'Post-money', render: (r: any) => fmtPct(r.founder_post_money_pct) },
    { key: 'is_locked_for_board', header: 'Locked', render: (r: any) => (r.is_locked_for_board ? 'YES' : 'no') },
  ];

  const secondaryCols: Column<any>[] = [
    { key: 'scenario_label', header: 'Scenario', render: (r: any) => r.scenario_label ?? '—' },
    { key: 'secondary_sale_rupees', header: 'Secondary', render: (r: any) => fmtRupees(r.secondary_sale_rupees) },
    { key: 'founder_secondary_proceeds_rupees', header: 'Founder proceeds', render: (r: any) => fmtRupees(r.founder_secondary_proceeds_rupees) },
    { key: 'series_a_valuation_rupees', header: 'Val', render: (r: any) => fmtRupees(r.series_a_valuation_rupees) },
    { key: 'is_locked_for_board', header: 'Locked', render: (r: any) => (r.is_locked_for_board ? 'YES' : 'no') },
  ];

  const lockedCols: Column<any>[] = [
    { key: 'scenario_label', header: 'Scenario', render: (r: any) => r.scenario_label ?? '—' },
    { key: 'series_a_valuation_rupees', header: 'Val', render: (r: any) => fmtRupees(r.series_a_valuation_rupees) },
    { key: 'founder_dilution_pct', header: 'Dilution', render: (r: any) => fmtPct(r.founder_dilution_pct) },
    { key: 'esop_refresh_pct', header: 'ESOP refresh', render: (r: any) => fmtPct(r.esop_refresh_pct) },
    { key: 'secondary_sale_rupees', header: 'Secondary', render: (r: any) => fmtRupees(r.secondary_sale_rupees) },
    { key: 'age_days', header: 'Locked age', render: (r: any) => fmtDays(r.age_days) },
  ];

  const auditCols: Column<any>[] = [
    { key: 'action', header: 'Action', render: (r: any) => r.action ?? '—' },
    { key: 'acted_by_email', header: 'Actor', render: (r: any) => r.acted_by_email ?? '—' },
    { key: 'scenario_id', header: 'Scenario id', render: (r: any) => (r.scenario_id ? String(r.scenario_id).slice(0, 8) : '—') },
    { key: 'acted_at', header: 'When', render: (r: any) => (r.acted_at ? new Date(r.acted_at).toLocaleString() : '—') },
    { key: 'age_days', header: 'Age', render: (r: any) => fmtDays(r.age_days) },
  ];

  return (
    <main className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Founder cap-table simulator v4</h1>
        <p className="text-sm text-neutral-600">
          Sensitivity scenarios across Series A valuations, ESOP refresh options and secondary sales. Founder picks one and locks for board approval.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {cards.map((k) => (
          <div key={k.label} className="rounded-lg border border-neutral-200 p-3">
            <div className="text-xs uppercase tracking-wide text-neutral-500">{k.label}</div>
            <div className="text-lg font-medium mt-1">{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All scenarios</h2>
        <DataTable columns={scenarioCols} rows={scenarios} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top dilution</h2>
        <DataTable columns={dilutionCols} rows={topDilution} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top secondary</h2>
        <DataTable columns={secondaryCols} rows={topSecondary} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Locked for board</h2>
        <DataTable columns={lockedCols} rows={locked} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent audit</h2>
        <DataTable columns={auditCols} rows={audit} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
