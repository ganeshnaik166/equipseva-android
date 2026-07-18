import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { filing_verdict: string; filings: number; pct: number };
type EntityRow = {
  entity_name: string;
  total_filings: number;
  on_time: number;
  late: number;
  pending: number;
  overdue: number;
  notices: number;
  total_tax_paid_rupees: number;
  on_time_pct: number;
};
type TypeRow = {
  filing_type: string;
  filings: number;
  on_time: number;
  late: number;
  notices: number;
  avg_days_early_late: number | null;
  total_tax_paid_rupees: number;
};
type TrendRow = {
  due_date: string;
  filings_due: number;
  filed: number;
  pending: number;
  overdue: number;
  notices: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
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
  entity_name: string;
  filing_type: string;
  filing_period: string;
  due_date: string;
  filed_date: string | null;
  filing_verdict: string;
  notice_status: string;
  penalty_risk: string;
  tax_paid_rupees: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    entityRes,
    typeRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3241_filing_verdict_rollup'),
    supabase.rpc('founder_r3241_entity_scorecard'),
    supabase.rpc('founder_r3241_filing_type_matrix'),
    supabase.rpc('founder_r3241_due_date_trend'),
    supabase.rpc('founder_r3241_capa_status_board'),
    supabase.rpc('founder_r3241_root_cause_pareto'),
    supabase.rpc('founder_r3241_regulatory_impact_digest'),
    supabase.rpc('founder_r3241_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const typeRows: TypeRow[] = (typeRes.data as TypeRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'filing_verdict', header: 'Verdict' },
    { key: 'filings', header: 'Filings' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'total_filings', header: 'Filings' },
    { key: 'on_time', header: 'On Time' },
    { key: 'late', header: 'Late' },
    { key: 'pending', header: 'Pending' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'notices', header: 'Notices' },
    { key: 'total_tax_paid_rupees', header: 'Tax Paid (INR)' },
    { key: 'on_time_pct', header: 'On-Time %' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'filing_type', header: 'Filing Type' },
    { key: 'filings', header: 'Filings' },
    { key: 'on_time', header: 'On Time' },
    { key: 'late', header: 'Late' },
    { key: 'notices', header: 'Notices' },
    { key: 'avg_days_early_late', header: 'Avg Days Early/Late' },
    { key: 'total_tax_paid_rupees', header: 'Tax Paid (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'due_date', header: 'Due Date' },
    { key: 'filings_due', header: 'Due' },
    { key: 'filed', header: 'Filed' },
    { key: 'pending', header: 'Pending' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'notices', header: 'Notices' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
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
    { key: 'entity_name', header: 'Entity' },
    { key: 'filing_type', header: 'Type' },
    { key: 'filing_period', header: 'Period' },
    { key: 'due_date', header: 'Due' },
    { key: 'filed_date', header: 'Filed' },
    { key: 'filing_verdict', header: 'Verdict' },
    { key: 'notice_status', header: 'Notice' },
    { key: 'penalty_risk', header: 'Penalty Risk' },
    { key: 'tax_paid_rupees', header: 'Tax Paid (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Tax-Compliance (GST/TDS/Advance-Tax) Filing Calendar &amp; Notice Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Statutory tax board — filing type &times; period &times; due/filed dates &times;
        days early/late &times; tax paid &times; notice status &times; penalty risk &amp; CAPA closure.
        Founder-gated view: filing verdicts, entity scorecards, root-cause pareto, and
        regulatory-impact digest across GST, TDS, advance-tax, ITR &amp; ROC surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Filing verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No filings logged yet."
          rowKey={(r, i) => String(r.filing_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity compliance scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Filing type matrix</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No filings by type."
          rowKey={(r, i) => `${r.filing_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Due-date calendar trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.due_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk filings queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk filings."
          rowKey={(r, i) => `${r.entity_name}-${r.filing_type}-${r.filing_period}-${i}`}
        />
      </section>
    </main>
  );
}
