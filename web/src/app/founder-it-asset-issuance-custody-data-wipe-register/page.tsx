import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { custody_verdict: string; assets: number; pct: number };
type DeptRow = {
  department: string;
  total_assets: number;
  compliant: number;
  at_risk: number;
  overdue_or_lost: number;
  mdm_enrolled_count: number;
  encryption_ok_count: number;
  total_purchase_cost_rupees: number;
  compliant_pct: number;
};
type MatrixRow = {
  asset_type: string;
  data_wipe_status: string;
  assets: number;
  total_cost_rupees: number;
};
type TrendRow = {
  issue_date: string;
  issued: number;
  returned: number;
  lost: number;
  total_cost_rupees: number;
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
type RiskDigestRow = {
  data_risk_level: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type QueueRow = {
  asset_tag: string;
  asset_type: string;
  assigned_to: string;
  department: string;
  issue_date: string;
  condition_status: string;
  mdm_status: string;
  encryption_status: string;
  data_wipe_status: string;
  custody_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    deptRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    riskDigestRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3253_custody_verdict_rollup'),
    supabase.rpc('founder_r3253_department_scorecard'),
    supabase.rpc('founder_r3253_asset_wipe_matrix'),
    supabase.rpc('founder_r3253_issuance_trend'),
    supabase.rpc('founder_r3253_capa_status_board'),
    supabase.rpc('founder_r3253_root_cause_pareto'),
    supabase.rpc('founder_r3253_data_risk_digest'),
    supabase.rpc('founder_r3253_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const riskDigestRows: RiskDigestRow[] = (riskDigestRes.data as RiskDigestRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'custody_verdict', header: 'Custody Verdict' },
    { key: 'assets', header: 'Assets' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'total_assets', header: 'Assets' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'overdue_or_lost', header: 'Overdue / Lost' },
    { key: 'mdm_enrolled_count', header: 'MDM Enrolled' },
    { key: 'encryption_ok_count', header: 'Encryption OK' },
    { key: 'total_purchase_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'asset_type', header: 'Asset Type' },
    { key: 'data_wipe_status', header: 'Data-Wipe Status' },
    { key: 'assets', header: 'Assets' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'issue_date', header: 'Issue Date' },
    { key: 'issued', header: 'Issued' },
    { key: 'returned', header: 'Returned' },
    { key: 'lost', header: 'Lost' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
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

  const riskDigestCols: Column<RiskDigestRow>[] = [
    { key: 'data_risk_level', header: 'Data-Risk Level' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'asset_tag', header: 'Asset Tag' },
    { key: 'asset_type', header: 'Type' },
    { key: 'assigned_to', header: 'Assigned To' },
    { key: 'department', header: 'Department' },
    { key: 'issue_date', header: 'Issued' },
    { key: 'condition_status', header: 'Condition' },
    { key: 'mdm_status', header: 'MDM' },
    { key: 'encryption_status', header: 'Encryption' },
    { key: 'data_wipe_status', header: 'Data Wipe' },
    { key: 'custody_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder IT-Asset Issuance, Custody &amp; Data-Wipe Register
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Company IT-asset register — asset type &times; department &times; issuance &times; MDM
        enrolment &times; disk encryption &times; patch check &times; return &times; end-of-life
        data-wipe status &times; custody verdict &amp; CAPA closure. Founder-gated view: custody
        verdicts, department scorecards, asset-type &times; wipe matrix, root-cause pareto, and
        data-risk digest for laptops, phones, SIMs and field tablets issued to engineers &amp;
        staff.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Custody verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No assets registered yet."
          rowKey={(r, i) => String(r.custody_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department custody scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Asset type &times; data-wipe matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No assets by type."
          rowKey={(r, i) => `${r.asset_type}-${r.data_wipe_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Issuance-date trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.issue_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Data-risk digest</h2>
        <DataTable
          rows={riskDigestRows}
          columns={riskDigestCols}
          emptyMessage="No data-risk rollups."
          rowKey={(r, i) => String(r.data_risk_level ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk custody queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk assets."
          rowKey={(r, i) => `${r.asset_tag}-${r.issue_date}-${i}`}
        />
      </section>
    </main>
  );
}
