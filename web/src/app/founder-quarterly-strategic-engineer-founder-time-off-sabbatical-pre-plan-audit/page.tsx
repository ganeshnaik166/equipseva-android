import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type AuditRow = {
  id: string;
  audit_quarter: string;
  audit_owner: string;
  sabbatical_candidate: string;
  planned_start_date: string;
  planned_end_date: string;
  duration_weeks: number;
  readiness_score: number;
  blast_radius: string;
  successor_named: string;
  oncall_coverage_pct: number;
  knowledge_transfer_status: string;
  audit_verdict: string;
  cost_to_business_inr_lakhs: number | null;
  reentry_plan_quality: string;
  notes: string | null;
};

type VerdictRollup = {
  audit_quarter: string;
  total_audits: number;
  green_go: number;
  yellow_conditional: number;
  red_blocked: number;
  deferred: number;
  avg_readiness: number;
};

type BlockedRow = {
  id: string;
  audit_quarter: string;
  sabbatical_candidate: string;
  planned_start_date: string;
  duration_weeks: number;
  readiness_score: number;
  blast_radius: string;
  successor_named: string;
  cost_to_business_inr_lakhs: number | null;
  notes: string | null;
};

type ReadinessRow = {
  sabbatical_candidate: string;
  audit_count: number;
  avg_readiness: number;
  avg_oncall_coverage: number;
  signed_off_kt: number;
  critical_blast: number;
};

type RiskSummary = {
  risk_area: string;
  risk_count: number;
  p0_count: number;
  p1_count: number;
  avg_likelihood: number;
  avg_residual: number;
  mitigated_count: number;
};

type CostRow = {
  audit_quarter: string;
  total_cost_inr_lakhs: number;
  avg_cost_inr_lakhs: number;
  max_cost_inr_lakhs: number;
  blocked_cost_inr_lakhs: number;
};

type HighResidualRisk = {
  id: string;
  risk_area: string;
  risk_severity: string;
  likelihood_pct: number;
  residual_score: number;
  mitigation_owner: string;
  mitigation_status: string;
  mitigation_deadline: string | null;
  escalation_path: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [audits, verdicts, blocked, readiness, risks, costs, highRisks] = await Promise.all([
    supabase.rpc('rpc_r3073_list_audits'),
    supabase.rpc('rpc_r3073_verdict_rollup'),
    supabase.rpc('rpc_r3073_blocked_sabbaticals'),
    supabase.rpc('rpc_r3073_readiness_by_candidate'),
    supabase.rpc('rpc_r3073_risk_summary'),
    supabase.rpc('rpc_r3073_cost_projection'),
    supabase.rpc('rpc_r3073_high_residual_risks'),
  ]);

  const auditRows: AuditRow[] = (audits.data as AuditRow[]) ?? [];
  const verdictRows: VerdictRollup[] = (verdicts.data as VerdictRollup[]) ?? [];
  const blockedRows: BlockedRow[] = (blocked.data as BlockedRow[]) ?? [];
  const readinessRows: ReadinessRow[] = (readiness.data as ReadinessRow[]) ?? [];
  const riskRows: RiskSummary[] = (risks.data as RiskSummary[]) ?? [];
  const costRows: CostRow[] = (costs.data as CostRow[]) ?? [];
  const highRiskRows: HighResidualRisk[] = (highRisks.data as HighResidualRisk[]) ?? [];

  const auditCols: Column<AuditRow>[] = [
    { header: 'Quarter', accessor: (r) => r.audit_quarter },
    { header: 'Candidate', accessor: (r) => r.sabbatical_candidate },
    { header: 'Owner', accessor: (r) => r.audit_owner },
    { header: 'Start', accessor: (r) => r.planned_start_date },
    { header: 'Weeks', accessor: (r) => r.duration_weeks },
    { header: 'Readiness', accessor: (r) => r.readiness_score },
    { header: 'Blast', accessor: (r) => r.blast_radius },
    { header: 'Successor', accessor: (r) => r.successor_named },
    { header: 'KT', accessor: (r) => r.knowledge_transfer_status },
    { header: 'Verdict', accessor: (r) => r.audit_verdict },
    { header: 'Cost (L)', accessor: (r) => r.cost_to_business_inr_lakhs ?? '-' },
    { header: 'Reentry', accessor: (r) => r.reentry_plan_quality },
  ];

  const verdictCols: Column<VerdictRollup>[] = [
    { header: 'Quarter', accessor: (r) => r.audit_quarter },
    { header: 'Total', accessor: (r) => r.total_audits },
    { header: 'Green', accessor: (r) => r.green_go },
    { header: 'Yellow', accessor: (r) => r.yellow_conditional },
    { header: 'Red', accessor: (r) => r.red_blocked },
    { header: 'Deferred', accessor: (r) => r.deferred },
    { header: 'Avg Readiness', accessor: (r) => r.avg_readiness },
  ];

  const blockedCols: Column<BlockedRow>[] = [
    { header: 'Quarter', accessor: (r) => r.audit_quarter },
    { header: 'Candidate', accessor: (r) => r.sabbatical_candidate },
    { header: 'Start', accessor: (r) => r.planned_start_date },
    { header: 'Weeks', accessor: (r) => r.duration_weeks },
    { header: 'Readiness', accessor: (r) => r.readiness_score },
    { header: 'Blast', accessor: (r) => r.blast_radius },
    { header: 'Successor', accessor: (r) => r.successor_named },
    { header: 'Cost (L)', accessor: (r) => r.cost_to_business_inr_lakhs ?? '-' },
    { header: 'Notes', accessor: (r) => r.notes ?? '-' },
  ];

  const readinessCols: Column<ReadinessRow>[] = [
    { header: 'Candidate', accessor: (r) => r.sabbatical_candidate },
    { header: 'Audits', accessor: (r) => r.audit_count },
    { header: 'Avg Readiness', accessor: (r) => r.avg_readiness },
    { header: 'Avg Oncall %', accessor: (r) => r.avg_oncall_coverage },
    { header: 'KT Signed-Off', accessor: (r) => r.signed_off_kt },
    { header: 'Critical Blast', accessor: (r) => r.critical_blast },
  ];

  const riskCols: Column<RiskSummary>[] = [
    { header: 'Risk Area', accessor: (r) => r.risk_area },
    { header: 'Count', accessor: (r) => r.risk_count },
    { header: 'P0', accessor: (r) => r.p0_count },
    { header: 'P1', accessor: (r) => r.p1_count },
    { header: 'Avg Likelihood', accessor: (r) => r.avg_likelihood },
    { header: 'Avg Residual', accessor: (r) => r.avg_residual },
    { header: 'Mitigated', accessor: (r) => r.mitigated_count },
  ];

  const costCols: Column<CostRow>[] = [
    { header: 'Quarter', accessor: (r) => r.audit_quarter },
    { header: 'Total (L)', accessor: (r) => r.total_cost_inr_lakhs },
    { header: 'Avg (L)', accessor: (r) => r.avg_cost_inr_lakhs },
    { header: 'Max (L)', accessor: (r) => r.max_cost_inr_lakhs },
    { header: 'Blocked (L)', accessor: (r) => r.blocked_cost_inr_lakhs },
  ];

  const highRiskCols: Column<HighResidualRisk>[] = [
    { header: 'Risk Area', accessor: (r) => r.risk_area },
    { header: 'Severity', accessor: (r) => r.risk_severity },
    { header: 'Likelihood %', accessor: (r) => r.likelihood_pct },
    { header: 'Residual', accessor: (r) => r.residual_score },
    { header: 'Owner', accessor: (r) => r.mitigation_owner },
    { header: 'Status', accessor: (r) => r.mitigation_status },
    { header: 'Deadline', accessor: (r) => r.mitigation_deadline ?? '-' },
    { header: 'Escalation', accessor: (r) => r.escalation_path },
    { header: 'Notes', accessor: (r) => r.notes ?? '-' },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>
          Founder Quarterly Strategic Engineer-Founder Time-Off Sabbatical Pre-Plan Audit
        </h1>
        <p style={{ color: '#555', marginTop: 8 }}>
          Round 3073 — quarterly audit of sabbatical readiness for engineer-founders &amp; senior eng leaders.
          Verdict gates: green_go &gt;= 80 readiness, yellow_conditional 60-79, red_blocked &lt; 60 or critical blast.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Pre-Plan Audits</h2>
        <DataTable
          rows={auditRows}
          columns={auditCols}
          emptyMessage="No pre-plan audits recorded."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Verdict Rollup by Quarter</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No verdict rollup data."
          rowKey={(r, i) => String(r.audit_quarter ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Blocked Sabbaticals (red_blocked verdict)</h2>
        <DataTable
          rows={blockedRows}
          columns={blockedCols}
          emptyMessage="No blocked sabbaticals — all clear."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Readiness by Candidate Role</h2>
        <DataTable
          rows={readinessRows}
          columns={readinessCols}
          emptyMessage="No readiness data."
          rowKey={(r, i) => String(r.sabbatical_candidate ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Risk Register Summary</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No risk register data."
          rowKey={(r, i) => String(r.risk_area ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Cost-to-Business Projection (INR Lakhs)</h2>
        <DataTable
          rows={costRows}
          columns={costCols}
          emptyMessage="No cost projection data."
          rowKey={(r, i) => String(r.audit_quarter ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>High Residual Risks (residual &gt;= 30)</h2>
        <DataTable
          rows={highRiskRows}
          columns={highRiskCols}
          emptyMessage="No high-residual risks — register is clean."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
