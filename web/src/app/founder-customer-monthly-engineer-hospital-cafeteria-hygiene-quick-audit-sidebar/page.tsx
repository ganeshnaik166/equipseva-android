import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type PinnedRow = { hospital_name: string; cafeteria_name: string; city: string; audit_status: string; risk_tier: string; hygiene_score: number; findings_count: number };
type MonthlyRow = { audit_month: string; total_audits: number; completed_audits: number; avg_score: number | null; red_or_critical: number };
type RiskRow = { risk_tier: string; audit_count: number; avg_findings: number; avg_meals: number };
type EngineerRow = { engineer_name: string; audits_done: number; avg_score: number | null; avg_duration: number | null };
type FindingRow = { hospital_name: string; category: string; severity: string; finding_summary: string; remediation_days: number; cost_impact_rupees: number };
type CategoryRow = { category: string; finding_count: number; total_cost_rupees: number; critical_count: number };
type SignoffRow = { audit_status: string; total: number; signed_off: number; signoff_rate_pct: number | null };
type OverdueRow = { hospital_name: string; city: string; engineer_name: string; audit_status: string; risk_tier: string; meals_per_day: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [pinned, monthly, risk, engineers, findings, categories, signoff, overdue] = await Promise.all([
    sb.rpc('rpc_r2956_sidebar_pinned'),
    sb.rpc('rpc_r2956_monthly_summary'),
    sb.rpc('rpc_r2956_risk_tier_breakdown'),
    sb.rpc('rpc_r2956_engineer_leaderboard'),
    sb.rpc('rpc_r2956_top_open_findings'),
    sb.rpc('rpc_r2956_category_cost_rollup'),
    sb.rpc('rpc_r2956_signoff_funnel'),
    sb.rpc('rpc_r2956_overdue_escalated'),
  ]);

  const pinnedRows = (pinned.data ?? []) as PinnedRow[];
  const monthlyRows = (monthly.data ?? []) as MonthlyRow[];
  const riskRows = (risk.data ?? []) as RiskRow[];
  const engineerRows = (engineers.data ?? []) as EngineerRow[];
  const findingRows = (findings.data ?? []) as FindingRow[];
  const categoryRows = (categories.data ?? []) as CategoryRow[];
  const signoffRows = (signoff.data ?? []) as SignoffRow[];
  const overdueRows = (overdue.data ?? []) as OverdueRow[];

  const pinnedCols: Column<PinnedRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Cafeteria', accessor: (r) => r.cafeteria_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'Risk', accessor: (r) => r.risk_tier },
    { header: 'Score', accessor: (r) => r.hygiene_score },
    { header: 'Findings', accessor: (r) => r.findings_count },
  ];

  const monthlyCols: Column<MonthlyRow>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Total', accessor: (r) => r.total_audits },
    { header: 'Completed', accessor: (r) => r.completed_audits },
    { header: 'Avg Score', accessor: (r) => r.avg_score ?? '—' },
    { header: 'Red/Critical', accessor: (r) => r.red_or_critical },
  ];

  const riskCols: Column<RiskRow>[] = [
    { header: 'Risk Tier', accessor: (r) => r.risk_tier },
    { header: 'Audits', accessor: (r) => r.audit_count },
    { header: 'Avg Findings', accessor: (r) => r.avg_findings },
    { header: 'Avg Meals/day', accessor: (r) => r.avg_meals },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits Done', accessor: (r) => r.audits_done },
    { header: 'Avg Score', accessor: (r) => r.avg_score ?? '—' },
    { header: 'Avg Duration (min)', accessor: (r) => r.avg_duration ?? '—' },
  ];

  const findingCols: Column<FindingRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Summary', accessor: (r) => r.finding_summary },
    { header: 'Days', accessor: (r) => r.remediation_days },
    { header: 'Cost ₹', accessor: (r) => r.cost_impact_rupees },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Findings', accessor: (r) => r.finding_count },
    { header: 'Total Cost ₹', accessor: (r) => r.total_cost_rupees },
    { header: 'Critical', accessor: (r) => r.critical_count },
  ];

  const signoffCols: Column<SignoffRow>[] = [
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Signed Off', accessor: (r) => r.signed_off },
    { header: 'Rate %', accessor: (r) => r.signoff_rate_pct ?? '—' },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'Risk', accessor: (r) => r.risk_tier },
    { header: 'Meals/day', accessor: (r) => r.meals_per_day },
  ];

  return (
    <div style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Cafeteria Hygiene Quick-Audit Sidebar</h1>
        <p style={{ color: '#666', fontSize: 13 }}>Monthly engineer hospital-cafeteria hygiene audits — founder console r2956</p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Sidebar Pinned (priority watch)</h2>
        <DataTable rows={pinnedRows} columns={pinnedCols} emptyMessage="No pinned audits" rowKey={(r, i) => String((r as PinnedRow).hospital_name ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly Summary</h2>
        <DataTable rows={monthlyRows} columns={monthlyCols} emptyMessage="No months" rowKey={(r, i) => String((r as MonthlyRow).audit_month ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Risk-Tier Breakdown</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No risk data" rowKey={(r, i) => String((r as RiskRow).risk_tier ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer Leaderboard</h2>
        <DataTable rows={engineerRows} columns={engineerCols} emptyMessage="No engineers" rowKey={(r, i) => String((r as EngineerRow).engineer_name ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top Open Findings (severity &gt;= high prioritized)</h2>
        <DataTable rows={findingRows} columns={findingCols} emptyMessage="No open findings" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Category Cost Rollup</h2>
        <DataTable rows={categoryRows} columns={categoryCols} emptyMessage="No categories" rowKey={(r, i) => String((r as CategoryRow).category ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Customer Signoff Funnel</h2>
        <DataTable rows={signoffRows} columns={signoffCols} emptyMessage="No statuses" rowKey={(r, i) => String((r as SignoffRow).audit_status ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Overdue & Escalated</h2>
        <DataTable rows={overdueRows} columns={overdueCols} emptyMessage="No overdue audits" rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}
