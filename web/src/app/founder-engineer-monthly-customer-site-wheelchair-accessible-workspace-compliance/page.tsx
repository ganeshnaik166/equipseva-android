import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [overview, sites, engineers, cities, funnel, p0, dims, recent] = await Promise.all([
    sb.rpc('r2942_monthly_compliance_overview'),
    sb.rpc('r2942_site_leaderboard'),
    sb.rpc('r2942_engineer_compliance'),
    sb.rpc('r2942_blockers_by_city'),
    sb.rpc('r2942_action_funnel'),
    sb.rpc('r2942_open_p0_actions'),
    sb.rpc('r2942_dimension_failures'),
    sb.rpc('r2942_recent_audits'),
  ]);

  type Ovr = { audit_month: string; total_sites: number; compliant_sites: number; partial_sites: number; non_compliant_sites: number; blocked_sites: number; avg_score: number };
  const ovrCols: Column<Ovr>[] = [
    { key: 'audit_month', header: 'Month', render: (r) => r.audit_month },
    { key: 'total_sites', header: 'Sites', render: (r) => r.total_sites },
    { key: 'compliant_sites', header: 'Compliant', render: (r) => r.compliant_sites },
    { key: 'partial_sites', header: 'Partial', render: (r) => r.partial_sites },
    { key: 'non_compliant_sites', header: 'Non-Compliant', render: (r) => r.non_compliant_sites },
    { key: 'blocked_sites', header: 'Blocked', render: (r) => r.blocked_sites },
    { key: 'avg_score', header: 'Avg Score', render: (r) => r.avg_score },
  ];

  type Site = { site_org_name: string; site_city: string; audits: number; avg_score: number; last_status: string };
  const siteCols: Column<Site>[] = [
    { key: 'site_org_name', header: 'Site', render: (r) => r.site_org_name },
    { key: 'site_city', header: 'City', render: (r) => r.site_city },
    { key: 'audits', header: 'Audits', render: (r) => r.audits },
    { key: 'avg_score', header: 'Avg', render: (r) => r.avg_score },
    { key: 'last_status', header: 'Last', render: (r) => r.last_status },
  ];

  type Eng = { engineer_name: string; audits: number; avg_score: number; compliant_pct: number };
  const engCols: Column<Eng>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'audits', header: 'Audits', render: (r) => r.audits },
    { key: 'avg_score', header: 'Avg', render: (r) => r.avg_score },
    { key: 'compliant_pct', header: 'Compliant %', render: (r) => r.compliant_pct },
  ];

  type City = { site_city: string; blockers: number; non_compliant: number; audits: number };
  const cityCols: Column<City>[] = [
    { key: 'site_city', header: 'City', render: (r) => r.site_city },
    { key: 'blockers', header: 'Blockers', render: (r) => r.blockers },
    { key: 'non_compliant', header: 'Non-Compliant', render: (r) => r.non_compliant },
    { key: 'audits', header: 'Audits', render: (r) => r.audits },
  ];

  type Fun = { status: string; actions: number; total_cost_rupees: number };
  const funCols: Column<Fun>[] = [
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'actions', header: 'Actions', render: (r) => r.actions },
    { key: 'total_cost_rupees', header: 'Total Cost', render: (r) => r.total_cost_rupees },
  ];

  type P0 = { action_type: string; priority: string; assigned_to: string; due_date: string; cost_estimate_rupees: number };
  const p0Cols: Column<P0>[] = [
    { key: 'action_type', header: 'Action', render: (r) => r.action_type },
    { key: 'priority', header: 'Pri', render: (r) => r.priority },
    { key: 'assigned_to', header: 'Owner', render: (r) => r.assigned_to },
    { key: 'due_date', header: 'Due', render: (r) => r.due_date },
    { key: 'cost_estimate_rupees', header: 'Cost', render: (r) => r.cost_estimate_rupees },
  ];

  type Dim = { dimension: string; failures: number; total: number };
  const dimCols: Column<Dim>[] = [
    { key: 'dimension', header: 'Dimension', render: (r) => r.dimension },
    { key: 'failures', header: 'Failures', render: (r) => r.failures },
    { key: 'total', header: 'Total', render: (r) => r.total },
  ];

  type Rec = { audit_date: string; engineer_name: string; site_org_name: string; site_city: string; overall_score: number; compliance_status: string; blockers_count: number };
  const recCols: Column<Rec>[] = [
    { key: 'audit_date', header: 'Date', render: (r) => r.audit_date },
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'site_org_name', header: 'Site', render: (r) => r.site_org_name },
    { key: 'site_city', header: 'City', render: (r) => r.site_city },
    { key: 'overall_score', header: 'Score', render: (r) => r.overall_score },
    { key: 'compliance_status', header: 'Status', render: (r) => r.compliance_status },
    { key: 'blockers_count', header: 'Blockers', render: (r) => r.blockers_count },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Customer-Site Wheelchair-Accessible Workspace Compliance</h1>
        <p className="text-sm text-gray-600">Round 2942 — site accessibility audits & remediation actions</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Overview</h2>
        <DataTable<Ovr> rows={(overview.data ?? []) as Ovr[]} columns={ovrCols} emptyMessage="no months" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Site Leaderboard</h2>
        <DataTable<Site> rows={(sites.data ?? []) as Site[]} columns={siteCols} emptyMessage="no sites" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Compliance</h2>
        <DataTable<Eng> rows={(engineers.data ?? []) as Eng[]} columns={engCols} emptyMessage="no engineers" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Blockers by City</h2>
        <DataTable<City> rows={(cities.data ?? []) as City[]} columns={cityCols} emptyMessage="no cities" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Action Funnel</h2>
        <DataTable<Fun> rows={(funnel.data ?? []) as Fun[]} columns={funCols} emptyMessage="no actions" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open P0/P1 Actions</h2>
        <DataTable<P0> rows={(p0.data ?? []) as P0[]} columns={p0Cols} emptyMessage="no p0" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Dimension Failures</h2>
        <DataTable<Dim> rows={(dims.data ?? []) as Dim[]} columns={dimCols} emptyMessage="no dims" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Audits</h2>
        <DataTable<Rec> rows={(recent.data ?? []) as Rec[]} columns={recCols} emptyMessage="no audits" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>
    </div>
  );
}
