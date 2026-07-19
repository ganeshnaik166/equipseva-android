import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  doa_verdict: string;
  approvals: number;
  total_amount_rupees: number;
  pct: number;
};
type EntityRow = {
  entity_name: string;
  total_approvals: number;
  compliant: number;
  breaches: number;
  within_authority_ct: number;
  incomplete_audit_trail: number;
  total_amount_rupees: number;
  compliant_pct: number;
};
type MatrixRow = {
  category: string;
  required_approver_level: string;
  approvals: number;
  breaches: number;
  avg_amount_rupees: number;
  avg_sla_days: number;
};
type TrendRow = {
  approval_date: string;
  approvals: number;
  compliant: number;
  breaches: number;
  total_amount_rupees: number;
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
  transaction_ref: string;
  category: string;
  amount_rupees: number;
  required_approver_level: string;
  actual_approver_level: string | null;
  exception_flag: string;
  doa_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    entityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3357_doa_verdict_rollup'),
    supabase.rpc('founder_r3357_entity_scorecard'),
    supabase.rpc('founder_r3357_category_approver_matrix'),
    supabase.rpc('founder_r3357_daily_approval_trend'),
    supabase.rpc('founder_r3357_capa_status_board'),
    supabase.rpc('founder_r3357_root_cause_pareto'),
    supabase.rpc('founder_r3357_regulatory_impact_digest'),
    supabase.rpc('founder_r3357_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'doa_verdict', header: 'DoA Verdict' },
    { key: 'approvals', header: 'Approvals' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity / Business Unit' },
    { key: 'total_approvals', header: 'Approvals' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'breaches', header: 'Breaches' },
    { key: 'within_authority_ct', header: 'Within Authority' },
    { key: 'incomplete_audit_trail', header: 'Audit-Trail Gaps' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'required_approver_level', header: 'Required Approver' },
    { key: 'approvals', header: 'Approvals' },
    { key: 'breaches', header: 'Breaches' },
    { key: 'avg_amount_rupees', header: 'Avg Amount (INR)' },
    { key: 'avg_sla_days', header: 'Avg SLA Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'approval_date', header: 'Date' },
    { key: 'approvals', header: 'Approvals' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'breaches', header: 'Breaches' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
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
    { key: 'transaction_ref', header: 'Txn Ref' },
    { key: 'category', header: 'Category' },
    { key: 'amount_rupees', header: 'Amount (INR)' },
    { key: 'required_approver_level', header: 'Required' },
    { key: 'actual_approver_level', header: 'Actual' },
    { key: 'exception_flag', header: 'Exception' },
    { key: 'doa_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Delegation-of-Authority &amp; Spend-Approval-Matrix Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Governance log — spend category &times; amount &times; required vs actual approver level
        &times; within-authority &times; exception flag &times; audit-trail &times; DoA verdict &amp;
        CAPA closure. Founder-gated view: verdict rollups, entity scorecards, a category &times;
        approver-level authority matrix, root-cause pareto, and a regulatory-impact digest spanning
        Companies-Act sec-188 RPT, income-tax disallowance &amp; statutory-audit surfaces. Flags
        over-limit self-approval, skip-level, post-facto &amp; split-to-avoid-limit breaches.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. DoA verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No spend approvals logged yet."
          rowKey={(r, i) => String(r.doa_verdict ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; approver-level matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No approvals by category."
          rowKey={(r, i) => `${r.category}-${r.required_approver_level}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily approval trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.approval_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk approval queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk approvals."
          rowKey={(r, i) => `${r.transaction_ref}-${i}`}
        />
      </section>
    </main>
  );
}
