import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  commitment_status: string;
  commitments: number;
  total_open_rupees: number;
  pct: number;
};
type UnitRow = {
  business_unit: string;
  total_commitments: number;
  contracted_rupees: number;
  executed_rupees: number;
  open_rupees: number;
  over_committed: number;
  budget_gap: number;
  avg_budget_covered_pct: number;
};
type MatrixRow = {
  po_type: string;
  commitment_status: string;
  commitments: number;
  total_open_rupees: number;
  avg_aging_days: number;
};
type TrendRow = {
  period_month: string;
  commitments: number;
  contracted_rupees: number;
  executed_rupees: number;
  open_rupees: number;
  over_committed: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  po_type: string;
  commitments: number;
  total_open_rupees: number;
  avg_budget_covered_pct: number;
  delayed: number;
};
type RiskRow = {
  commitment_ref: string;
  business_unit: string;
  po_type: string;
  period_month: string;
  contracted_value_rupees: number;
  open_commitment_rupees: number;
  budget_covered_pct: number | null;
  aging_days: number | null;
  commitment_status: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    unitRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3620_commitment_status_rollup'),
    supabase.rpc('founder_r3620_business_unit_scorecard'),
    supabase.rpc('founder_r3620_po_type_status_matrix'),
    supabase.rpc('founder_r3620_monthly_commitment_trend'),
    supabase.rpc('founder_r3620_capa_status_board'),
    supabase.rpc('founder_r3620_root_cause_pareto'),
    supabase.rpc('founder_r3620_open_commitment_digest'),
    supabase.rpc('founder_r3620_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const unitRows: UnitRow[] = (unitRes.data as UnitRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'commitment_status', header: 'Status' },
    { key: 'commitments', header: 'Commitments' },
    { key: 'total_open_rupees', header: 'Open (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const unitCols: Column<UnitRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'total_commitments', header: 'Commitments' },
    { key: 'contracted_rupees', header: 'Contracted (INR)' },
    { key: 'executed_rupees', header: 'Executed (INR)' },
    { key: 'open_rupees', header: 'Open (INR)' },
    { key: 'over_committed', header: 'Over-Committed' },
    { key: 'budget_gap', header: 'Budget Gap' },
    { key: 'avg_budget_covered_pct', header: 'Avg Budget Cover %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'po_type', header: 'PO Type' },
    { key: 'commitment_status', header: 'Status' },
    { key: 'commitments', header: 'Commitments' },
    { key: 'total_open_rupees', header: 'Open (INR)' },
    { key: 'avg_aging_days', header: 'Avg Aging Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'commitments', header: 'Commitments' },
    { key: 'contracted_rupees', header: 'Contracted (INR)' },
    { key: 'executed_rupees', header: 'Executed (INR)' },
    { key: 'open_rupees', header: 'Open (INR)' },
    { key: 'over_committed', header: 'Over-Committed' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'po_type', header: 'PO Type' },
    { key: 'commitments', header: 'Commitments' },
    { key: 'total_open_rupees', header: 'Open (INR)' },
    { key: 'avg_budget_covered_pct', header: 'Avg Budget Cover %' },
    { key: 'delayed', header: 'At-Risk' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'commitment_ref', header: 'Ref' },
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'po_type', header: 'PO Type' },
    { key: 'period_month', header: 'Month' },
    { key: 'contracted_value_rupees', header: 'Contracted (INR)' },
    { key: 'open_commitment_rupees', header: 'Open (INR)' },
    { key: 'budget_covered_pct', header: 'Budget Cover %' },
    { key: 'aging_days', header: 'Aging Days' },
    { key: 'commitment_status', header: 'Status' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Capital-Commitment / Open-Purchase-Commitment Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated view of contracted-not-executed (open purchase) commitments per business unit
        &mdash; commitment ref &times; business unit &times; period &times; contracted / executed /
        open value &times; budget coverage &times; expected completion &times; aging &times; PO type
        (capex, opex, project, AMC, inventory) &times; commitment status &amp; trend, with CAPA
        remediation closure. Rollups cover status distribution, business-unit scorecards, PO-type
        &times; status matrix, monthly trend, root-cause pareto, open-commitment digest, and the
        high-risk (over-committed &amp; budget-gap) queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Commitment status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No commitments logged yet."
          rowKey={(r, i) => String(r.commitment_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit scorecard</h2>
        <DataTable
          rows={unitRows}
          columns={unitCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. PO type &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No commitments by PO type."
          rowKey={(r, i) => `${r.po_type}-${r.commitment_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly commitment trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Open-commitment digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No open-commitment rollups."
          rowKey={(r, i) => String(r.po_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk commitment queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk commitments."
          rowKey={(r, i) => `${r.commitment_ref}-${i}`}
        />
      </section>
    </main>
  );
}
