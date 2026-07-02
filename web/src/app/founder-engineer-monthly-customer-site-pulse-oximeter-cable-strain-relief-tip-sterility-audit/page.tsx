import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type MonthlyRow = { audit_month: string; audits_count: number; pass_count: number; fail_count: number; escalated_count: number; avg_risk_score: number; total_repair_cost: number };
type EngineerRow = { engineer_name: string; audits: number; passes: number; escalations: number; avg_risk: number; avg_duration_minutes: number };
type StrainRow = { cable_strain_relief_grade: string; units: number; cables_replaced: number; avg_flex_resistance: number };
type TipRow = { tip_sterility_status: string; units: number; tips_replaced: number; avg_atp: number };
type SeverityRow = { severity: string; findings: number; resolved: number; total_cost: number };
type TopRiskRow = { audit_code: string; customer_site: string; engineer_name: string; risk_score: number; audit_outcome: string; finding_count: number };
type ActionRow = { corrective_action: string; occurrences: number; distinct_audits: number; avg_cost: number };
type UnresolvedRow = { audit_code: string; customer_site: string; finding_category: string; severity: string; finding_summary: string; corrective_action: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [monthly, engineers, strain, tip, severity, topRisk, actions, unresolved] = await Promise.all([
    supabase.rpc('rpc_pulseox_r3038_monthly_summary'),
    supabase.rpc('rpc_pulseox_r3038_engineer_leaderboard'),
    supabase.rpc('rpc_pulseox_r3038_strain_relief_distribution'),
    supabase.rpc('rpc_pulseox_r3038_tip_sterility_distribution'),
    supabase.rpc('rpc_pulseox_r3038_findings_by_severity'),
    supabase.rpc('rpc_pulseox_r3038_top_risk_audits'),
    supabase.rpc('rpc_pulseox_r3038_corrective_action_mix'),
    supabase.rpc('rpc_pulseox_r3038_unresolved_findings'),
  ]);

  const monthlyRows: MonthlyRow[] = (monthly.data as MonthlyRow[]) ?? [];
  const engineerRows: EngineerRow[] = (engineers.data as EngineerRow[]) ?? [];
  const strainRows: StrainRow[] = (strain.data as StrainRow[]) ?? [];
  const tipRows: TipRow[] = (tip.data as TipRow[]) ?? [];
  const severityRows: SeverityRow[] = (severity.data as SeverityRow[]) ?? [];
  const topRiskRows: TopRiskRow[] = (topRisk.data as TopRiskRow[]) ?? [];
  const actionRows: ActionRow[] = (actions.data as ActionRow[]) ?? [];
  const unresolvedRows: UnresolvedRow[] = (unresolved.data as UnresolvedRow[]) ?? [];

  const monthlyCols: Column<MonthlyRow>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Audits', accessor: (r) => r.audits_count },
    { header: 'Pass', accessor: (r) => r.pass_count },
    { header: 'Fail', accessor: (r) => r.fail_count },
    { header: 'Escalated', accessor: (r) => r.escalated_count },
    { header: 'Avg Risk', accessor: (r) => r.avg_risk_score },
    { header: 'Repair Cost', accessor: (r) => `Rs ${r.total_repair_cost}` },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Passes', accessor: (r) => r.passes },
    { header: 'Escalations', accessor: (r) => r.escalations },
    { header: 'Avg Risk', accessor: (r) => r.avg_risk },
    { header: 'Avg Mins', accessor: (r) => r.avg_duration_minutes },
  ];

  const strainCols: Column<StrainRow>[] = [
    { header: 'Strain Grade', accessor: (r) => r.cable_strain_relief_grade },
    { header: 'Units', accessor: (r) => r.units },
    { header: 'Cables Replaced', accessor: (r) => r.cables_replaced },
    { header: 'Avg Flex Ohm', accessor: (r) => r.avg_flex_resistance },
  ];

  const tipCols: Column<TipRow>[] = [
    { header: 'Tip Status', accessor: (r) => r.tip_sterility_status },
    { header: 'Units', accessor: (r) => r.units },
    { header: 'Tips Replaced', accessor: (r) => r.tips_replaced },
    { header: 'Avg ATP RLU', accessor: (r) => r.avg_atp },
  ];

  const severityCols: Column<SeverityRow>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Findings', accessor: (r) => r.findings },
    { header: 'Resolved', accessor: (r) => r.resolved },
    { header: 'Total Cost', accessor: (r) => `Rs ${r.total_cost}` },
  ];

  const topRiskCols: Column<TopRiskRow>[] = [
    { header: 'Audit', accessor: (r) => r.audit_code },
    { header: 'Site', accessor: (r) => r.customer_site },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Risk', accessor: (r) => r.risk_score },
    { header: 'Outcome', accessor: (r) => r.audit_outcome },
    { header: 'Findings', accessor: (r) => r.finding_count },
  ];

  const actionCols: Column<ActionRow>[] = [
    { header: 'Corrective Action', accessor: (r) => r.corrective_action },
    { header: 'Occurrences', accessor: (r) => r.occurrences },
    { header: 'Distinct Audits', accessor: (r) => r.distinct_audits },
    { header: 'Avg Cost', accessor: (r) => `Rs ${r.avg_cost}` },
  ];

  const unresolvedCols: Column<UnresolvedRow>[] = [
    { header: 'Audit', accessor: (r) => r.audit_code },
    { header: 'Site', accessor: (r) => r.customer_site },
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Summary', accessor: (r) => r.finding_summary },
    { header: 'Action', accessor: (r) => r.corrective_action },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Monthly Pulse-Oximeter Cable & Tip Audit</h1>
        <p className="text-sm text-gray-600">Round r3038 — strain-relief grade & tip sterility across customer sites.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Monthly Summary</h2>
        <DataTable rows={monthlyRows} columns={monthlyCols} emptyMessage="No months yet" rowKey={(r, i) => String(r.audit_month ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Engineer Leaderboard</h2>
        <DataTable rows={engineerRows} columns={engineerCols} emptyMessage="No engineers" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Strain-Relief Grade Distribution</h2>
        <DataTable rows={strainRows} columns={strainCols} emptyMessage="No data" rowKey={(r, i) => String(r.cable_strain_relief_grade ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Tip Sterility Distribution</h2>
        <DataTable rows={tipRows} columns={tipCols} emptyMessage="No data" rowKey={(r, i) => String(r.tip_sterility_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Findings by Severity</h2>
        <DataTable rows={severityRows} columns={severityCols} emptyMessage="No findings" rowKey={(r, i) => String(r.severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top Risk Audits</h2>
        <DataTable rows={topRiskRows} columns={topRiskCols} emptyMessage="No risk audits" rowKey={(r, i) => String(r.audit_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Corrective Action Mix</h2>
        <DataTable rows={actionRows} columns={actionCols} emptyMessage="No actions" rowKey={(r, i) => String(r.corrective_action ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Unresolved Findings</h2>
        <DataTable rows={unresolvedRows} columns={unresolvedCols} emptyMessage="All findings resolved" rowKey={(r, i) => String(`${r.audit_code}-${i}`)} />
      </section>
    </div>
  );
}
