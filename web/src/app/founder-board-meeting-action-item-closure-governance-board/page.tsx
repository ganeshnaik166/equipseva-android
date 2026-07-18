import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { verdict: string; actions: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_actions: number;
  closed_on_time: number;
  closed_late: number;
  open_overdue: number;
  carried_over: number;
  avg_days_to_close: number | null;
  on_time_pct: number;
};
type CatRow = {
  category: string;
  priority: string;
  actions: number;
  closed: number;
  avg_days_to_close: number | null;
};
type TrendRow = {
  board_meeting_date: string;
  actions: number;
  closed: number;
  overdue: number;
  avg_carry_over: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  escalated_or_overdue: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  action_code: string;
  action_item: string;
  owner_name: string;
  category: string;
  priority: string;
  due_date: string;
  verdict: string;
  carry_over_count: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    catRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3209_verdict_rollup'),
    supabase.rpc('founder_r3209_hospital_scorecard'),
    supabase.rpc('founder_r3209_category_matrix'),
    supabase.rpc('founder_r3209_meeting_trend'),
    supabase.rpc('founder_r3209_capa_status_board'),
    supabase.rpc('founder_r3209_root_cause_pareto'),
    supabase.rpc('founder_r3209_regulatory_impact_digest'),
    supabase.rpc('founder_r3209_high_risk_actions'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const catRows: CatRow[] = (catRes.data as CatRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'verdict', header: 'Verdict' },
    { key: 'actions', header: 'Actions' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital / Entity' },
    { key: 'total_actions', header: 'Actions' },
    { key: 'closed_on_time', header: 'On Time' },
    { key: 'closed_late', header: 'Late' },
    { key: 'open_overdue', header: 'Overdue' },
    { key: 'carried_over', header: 'Carried Over' },
    { key: 'avg_days_to_close', header: 'Avg Days to Close' },
    { key: 'on_time_pct', header: 'On-Time %' },
  ];

  const catCols: Column<CatRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'priority', header: 'Priority' },
    { key: 'actions', header: 'Actions' },
    { key: 'closed', header: 'Closed' },
    { key: 'avg_days_to_close', header: 'Avg Days to Close' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'board_meeting_date', header: 'Meeting Date' },
    { key: 'actions', header: 'Actions' },
    { key: 'closed', header: 'Closed' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'avg_carry_over', header: 'Avg Carry-Over' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'escalated_or_overdue', header: 'Escalated / Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital / Entity' },
    { key: 'action_code', header: 'Code' },
    { key: 'action_item', header: 'Action Item' },
    { key: 'owner_name', header: 'Owner' },
    { key: 'category', header: 'Category' },
    { key: 'priority', header: 'Priority' },
    { key: 'due_date', header: 'Due' },
    { key: 'verdict', header: 'Verdict' },
    { key: 'carry_over_count', header: 'Carry-Overs' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Board-Meeting Action-Item Closure &amp; Governance Cadence Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Board governance log &mdash; meeting date &times; action item &times; owner &times;
        due/closed dates &times; days-to-close &times; overdue flag &times; category &times;
        carry-over count &times; verdict, plus follow-up CAPA actions. Founder-gated view:
        verdict rollups, entity scorecards, category matrix, meeting cadence trend,
        root-cause pareto, and regulatory-impact digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Action-item verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No board actions logged yet."
          rowKey={(r, i) => String(r.verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital / entity governance scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; priority matrix</h2>
        <DataTable
          rows={catRows}
          columns={catCols}
          emptyMessage="No actions by category."
          rowKey={(r, i) => `${r.category}-${r.priority}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Board meeting cadence trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.board_meeting_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk action-item queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk action items."
          rowKey={(r, i) => `${r.action_code}-${r.due_date}-${i}`}
        />
      </section>
    </main>
  );
}
