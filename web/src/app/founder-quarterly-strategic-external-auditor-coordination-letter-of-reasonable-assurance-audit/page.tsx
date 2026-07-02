import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/data-table';

export const dynamic = 'force-dynamic';

type Engagement = {
  id: string;
  quarter_label: string;
  audit_firm: string;
  lead_partner_name: string;
  engagement_status: string;
  scope_summary: string;
  fee_rupees: number;
  kickoff_date: string;
  target_signoff_date: string;
  open_pbc_items: number;
  closed_pbc_items: number;
  material_findings: number;
  assurance_letter_status: string;
  founder_priority: string;
};

type Clause = {
  id: string;
  engagement_id: string;
  clause_ref: string;
  clause_topic: string;
  reasonable_assurance_level: string;
  evidence_completeness_pct: number;
  risk_rating: string;
  remediation_owner: string;
  remediation_due_date: string;
  clause_status: string;
  founder_sign_required: boolean;
};

type StatusSummary = { engagement_status: string; n: number; avg_fee_rupees: number; total_open_pbc: number };
type RiskBreakdown = { risk_rating: string; n: number; avg_evidence_pct: number; founder_sign_count: number };
type PbcRow = { quarter_label: string; audit_firm: string; closed_pbc_items: number; open_pbc_items: number; completion_pct: number };
type FeeTotal = { total_engagements: number; total_fee_rupees: number; signed_off_count: number; critical_open_count: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [engagementsRes, statusRes, criticalRes, clausesRes, riskRes, pbcRes, signoffRes, feeRes] = await Promise.all([
    supabase.rpc('r2993_list_engagements'),
    supabase.rpc('r2993_engagement_status_summary'),
    supabase.rpc('r2993_critical_engagements'),
    supabase.rpc('r2993_assurance_clauses_open'),
    supabase.rpc('r2993_risk_rating_breakdown'),
    supabase.rpc('r2993_pbc_completion'),
    supabase.rpc('r2993_founder_signoff_queue'),
    supabase.rpc('r2993_fee_spend_total'),
  ]);

  const engagements: Engagement[] = engagementsRes.data ?? [];
  const statuses: StatusSummary[] = statusRes.data ?? [];
  const critical: Engagement[] = criticalRes.data ?? [];
  const clauses: Clause[] = clausesRes.data ?? [];
  const risks: RiskBreakdown[] = riskRes.data ?? [];
  const pbc: PbcRow[] = pbcRes.data ?? [];
  const signoff: Clause[] = signoffRes.data ?? [];
  const fee: FeeTotal[] = feeRes.data ?? [];

  const engagementCols: Column<Engagement>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter_label },
    { header: 'Firm', accessor: (r) => r.audit_firm },
    { header: 'Partner', accessor: (r) => r.lead_partner_name },
    { header: 'Status', accessor: (r) => r.engagement_status },
    { header: 'Fee (Rs)', accessor: (r) => r.fee_rupees.toLocaleString('en-IN') },
    { header: 'Target Signoff', accessor: (r) => r.target_signoff_date },
    { header: 'Open PBC', accessor: (r) => r.open_pbc_items },
    { header: 'Findings', accessor: (r) => r.material_findings },
    { header: 'Letter', accessor: (r) => r.assurance_letter_status },
    { header: 'Priority', accessor: (r) => r.founder_priority },
  ];

  const statusCols: Column<StatusSummary>[] = [
    { header: 'Status', accessor: (r) => r.engagement_status },
    { header: 'Count', accessor: (r) => r.n },
    { header: 'Avg Fee (Rs)', accessor: (r) => r.avg_fee_rupees.toLocaleString('en-IN') },
    { header: 'Open PBC Total', accessor: (r) => r.total_open_pbc },
  ];

  const criticalCols: Column<Engagement>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter_label },
    { header: 'Firm', accessor: (r) => r.audit_firm },
    { header: 'Scope', accessor: (r) => r.scope_summary },
    { header: 'Target', accessor: (r) => r.target_signoff_date },
    { header: 'Priority', accessor: (r) => r.founder_priority },
    { header: 'Status', accessor: (r) => r.engagement_status },
  ];

  const clauseCols: Column<Clause>[] = [
    { header: 'Ref', accessor: (r) => r.clause_ref },
    { header: 'Topic', accessor: (r) => r.clause_topic },
    { header: 'Assurance', accessor: (r) => r.reasonable_assurance_level },
    { header: 'Evidence %', accessor: (r) => r.evidence_completeness_pct },
    { header: 'Risk', accessor: (r) => r.risk_rating },
    { header: 'Owner', accessor: (r) => r.remediation_owner },
    { header: 'Due', accessor: (r) => r.remediation_due_date },
    { header: 'Status', accessor: (r) => r.clause_status },
    { header: 'Founder Sign', accessor: (r) => (r.founder_sign_required ? 'Yes' : 'No') },
  ];

  const riskCols: Column<RiskBreakdown>[] = [
    { header: 'Risk', accessor: (r) => r.risk_rating },
    { header: 'Count', accessor: (r) => r.n },
    { header: 'Avg Evidence %', accessor: (r) => r.avg_evidence_pct },
    { header: 'Founder Sign Required', accessor: (r) => r.founder_sign_count },
  ];

  const pbcCols: Column<PbcRow>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter_label },
    { header: 'Firm', accessor: (r) => r.audit_firm },
    { header: 'Closed', accessor: (r) => r.closed_pbc_items },
    { header: 'Open', accessor: (r) => r.open_pbc_items },
    { header: 'Completion %', accessor: (r) => r.completion_pct },
  ];

  const signoffCols: Column<Clause>[] = [
    { header: 'Ref', accessor: (r) => r.clause_ref },
    { header: 'Topic', accessor: (r) => r.clause_topic },
    { header: 'Risk', accessor: (r) => r.risk_rating },
    { header: 'Due', accessor: (r) => r.remediation_due_date },
    { header: 'Status', accessor: (r) => r.clause_status },
  ];

  const feeCols: Column<FeeTotal>[] = [
    { header: 'Total Engagements', accessor: (r) => r.total_engagements },
    { header: 'Total Fee (Rs)', accessor: (r) => Number(r.total_fee_rupees).toLocaleString('en-IN') },
    { header: 'Signed Off', accessor: (r) => r.signed_off_count },
    { header: 'Critical Open', accessor: (r) => r.critical_open_count },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Strategic External-Auditor Coordination</h1>
        <p className="text-sm text-gray-600">
          Letter-of-Reasonable-Assurance audit tracker — engagements, PBC progress & clause-level risk.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Spend & Pipeline Summary</h2>
        <DataTable
          rows={fee}
          columns={feeCols}
          emptyMessage="No spend data."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Engagements</h2>
        <DataTable
          rows={engagements}
          columns={engagementCols}
          emptyMessage="No engagements."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Summary</h2>
        <DataTable
          rows={statuses}
          columns={statusCols}
          emptyMessage="No status data."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical / High-Priority Open Engagements</h2>
        <DataTable
          rows={critical}
          columns={criticalCols}
          emptyMessage="None critical open."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Assurance-Letter Clauses</h2>
        <DataTable
          rows={clauses}
          columns={clauseCols}
          emptyMessage="No open clauses."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Risk-Rating Breakdown</h2>
        <DataTable
          rows={risks}
          columns={riskCols}
          emptyMessage="No risk data."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">PBC Completion by Engagement</h2>
        <DataTable
          rows={pbc}
          columns={pbcCols}
          emptyMessage="No PBC data."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Founder Sign-Off Queue</h2>
        <DataTable
          rows={signoff}
          columns={signoffCols}
          emptyMessage="Queue clear."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
