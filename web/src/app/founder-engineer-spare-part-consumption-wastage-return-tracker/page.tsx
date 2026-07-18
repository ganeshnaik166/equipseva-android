import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { consumption_verdict: string; logs: number; pct: number };
type EngRow = {
  engineer_name: string;
  hospital_name: string;
  logs: number;
  parts_issued: number;
  parts_used: number;
  parts_returned: number;
  avg_wastage_pct: number;
  wrong_part_orders: number;
  misuse_flags: number;
  cost_consumed_rupees: number;
};
type MatrixRow = {
  part_category: string;
  issue_channel: string;
  logs: number;
  parts_issued: number;
  avg_wastage_pct: number;
  cost_consumed_rupees: number;
};
type TrendRow = {
  audit_date: string;
  logs: number;
  parts_issued: number;
  parts_used: number;
  parts_returned: number;
  avg_wastage_pct: number;
  cost_consumed_rupees: number;
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
  hospital_name: string;
  engineer_name: string;
  issue_slip_no: string;
  part_category: string;
  audit_date: string;
  wastage_pct: number;
  wrong_part_orders: number;
  warranty_misuse: string;
  consumption_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3192_verdict_rollup'),
    supabase.rpc('founder_r3192_engineer_scorecard'),
    supabase.rpc('founder_r3192_category_channel_matrix'),
    supabase.rpc('founder_r3192_daily_consumption_trend'),
    supabase.rpc('founder_r3192_capa_status_board'),
    supabase.rpc('founder_r3192_root_cause_pareto'),
    supabase.rpc('founder_r3192_regulatory_impact_digest'),
    supabase.rpc('founder_r3192_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'consumption_verdict', header: 'Verdict' },
    { key: 'logs', header: 'Logs' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'logs', header: 'Logs' },
    { key: 'parts_issued', header: 'Issued' },
    { key: 'parts_used', header: 'Used' },
    { key: 'parts_returned', header: 'Returned' },
    { key: 'avg_wastage_pct', header: 'Avg Wastage %' },
    { key: 'wrong_part_orders', header: 'Wrong Orders' },
    { key: 'misuse_flags', header: 'Misuse Flags' },
    { key: 'cost_consumed_rupees', header: 'Cost Consumed (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'part_category', header: 'Part Category' },
    { key: 'issue_channel', header: 'Issue Channel' },
    { key: 'logs', header: 'Logs' },
    { key: 'parts_issued', header: 'Issued' },
    { key: 'avg_wastage_pct', header: 'Avg Wastage %' },
    { key: 'cost_consumed_rupees', header: 'Cost Consumed (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'logs', header: 'Logs' },
    { key: 'parts_issued', header: 'Issued' },
    { key: 'parts_used', header: 'Used' },
    { key: 'parts_returned', header: 'Returned' },
    { key: 'avg_wastage_pct', header: 'Avg Wastage %' },
    { key: 'cost_consumed_rupees', header: 'Cost Consumed (INR)' },
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
    { key: 'regulatory_impact', header: 'Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'issue_slip_no', header: 'Slip' },
    { key: 'part_category', header: 'Category' },
    { key: 'audit_date', header: 'Date' },
    { key: 'wastage_pct', header: 'Wastage %' },
    { key: 'wrong_part_orders', header: 'Wrong Orders' },
    { key: 'warranty_misuse', header: 'Warranty Misuse' },
    { key: 'consumption_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Spare-Part Consumption, Wastage &amp; Return-Rate Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Parts discipline log — engineer &times; part category &times; issued/used/returned &times;
        wastage % &times; wrong-part orders &times; warranty-misuse flags &amp; CAPA closure.
        Founder-gated view: consumption verdicts, engineer scorecards, root-cause pareto,
        and cost-impact digest across store &amp; boot-stock channels.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Consumption verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No consumption logs yet."
          rowKey={(r, i) => String(r.consumption_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer parts-discipline scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => `${r.engineer_name}-${r.hospital_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Part category &times; issue channel matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => `${r.part_category}-${r.issue_channel}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily consumption trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.audit_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Warranty &amp; commercial impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk consumption queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk consumption logs."
          rowKey={(r, i) => `${r.issue_slip_no}-${i}`}
        />
      </section>
    </main>
  );
}
