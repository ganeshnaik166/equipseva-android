import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type Summary = { total_engineers: number; total_parts_installed: number; total_parts_scanned: number; overall_compliance_pct: number; counterfeit_flagged: number; critical_count: number; breach_count: number; compliant_count: number };
type LatestMonth = { engineer_name: string; customer_org_name: string; engineer_tier: string; parts_installed_count: number; parts_scanned_count: number; scan_compliance_pct: number; status: string; escalated: boolean };
type Tier = { engineer_tier: string; engineer_count: number; avg_compliance_pct: number; breach_count: number; critical_count: number };
type Counterfeit = { engineer_name: string; customer_org_name: string; scan_month: string; counterfeit_flagged_count: number; status: string };
type Escalated = { engineer_name: string; customer_org_name: string; engineer_tier: string; scan_compliance_pct: number; status: string; scan_month: string };
type Action = { action_type: string; action_owner: string; notes: string | null; resolved: boolean; action_taken_at: string; engineer_name: string };
type Trend = { scan_month: string; total_engineers: number; avg_compliance_pct: number; total_counterfeit: number; escalated_count: number };
type ActionBreakdown = { action_type: string; action_count: number; resolved_count: number; pending_count: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [summary, latest, tier, counterfeit, escalated, actions, trend, actionTypes] = await Promise.all([
    sb.rpc('r2968_summary'),
    sb.rpc('r2968_latest_month'),
    sb.rpc('r2968_tier_breakdown'),
    sb.rpc('r2968_counterfeit_alerts'),
    sb.rpc('r2968_escalated_engineers'),
    sb.rpc('r2968_audit_actions'),
    sb.rpc('r2968_monthly_trend'),
    sb.rpc('r2968_action_type_breakdown'),
  ]);

  const s: Summary | null = (summary.data?.[0] ?? null) as Summary | null;
  const latestRows: LatestMonth[] = (latest.data ?? []) as LatestMonth[];
  const tierRows: Tier[] = (tier.data ?? []) as Tier[];
  const counterfeitRows: Counterfeit[] = (counterfeit.data ?? []) as Counterfeit[];
  const escalatedRows: Escalated[] = (escalated.data ?? []) as Escalated[];
  const actionRows: Action[] = (actions.data ?? []) as Action[];
  const trendRows: Trend[] = (trend.data ?? []) as Trend[];
  const actionTypeRows: ActionBreakdown[] = (actionTypes.data ?? []) as ActionBreakdown[];

  const latestCols: Column<LatestMonth>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Customer', accessor: (r) => r.customer_org_name },
    { header: 'Tier', accessor: (r) => r.engineer_tier },
    { header: 'Installed', accessor: (r) => r.parts_installed_count },
    { header: 'Scanned', accessor: (r) => r.parts_scanned_count },
    { header: 'Compliance %', accessor: (r) => r.scan_compliance_pct },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Escalated', accessor: (r) => (r.escalated ? 'Yes' : 'No') },
  ];

  const tierCols: Column<Tier>[] = [
    { header: 'Tier', accessor: (r) => r.engineer_tier },
    { header: 'Engineers', accessor: (r) => r.engineer_count },
    { header: 'Avg Compliance %', accessor: (r) => r.avg_compliance_pct },
    { header: 'Breach', accessor: (r) => r.breach_count },
    { header: 'Critical', accessor: (r) => r.critical_count },
  ];

  const counterfeitCols: Column<Counterfeit>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Customer', accessor: (r) => r.customer_org_name },
    { header: 'Month', accessor: (r) => r.scan_month },
    { header: 'Counterfeit Flagged', accessor: (r) => r.counterfeit_flagged_count },
    { header: 'Status', accessor: (r) => r.status },
  ];

  const escalatedCols: Column<Escalated>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Customer', accessor: (r) => r.customer_org_name },
    { header: 'Tier', accessor: (r) => r.engineer_tier },
    { header: 'Compliance %', accessor: (r) => r.scan_compliance_pct },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Month', accessor: (r) => r.scan_month },
  ];

  const actionCols: Column<Action>[] = [
    { header: 'Action', accessor: (r) => r.action_type },
    { header: 'Owner', accessor: (r) => r.action_owner },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Notes', accessor: (r) => r.notes ?? '' },
    { header: 'Resolved', accessor: (r) => (r.resolved ? 'Yes' : 'No') },
    { header: 'Taken At', accessor: (r) => new Date(r.action_taken_at).toLocaleDateString() },
  ];

  const trendCols: Column<Trend>[] = [
    { header: 'Month', accessor: (r) => r.scan_month },
    { header: 'Engineers', accessor: (r) => r.total_engineers },
    { header: 'Avg Compliance %', accessor: (r) => r.avg_compliance_pct },
    { header: 'Counterfeit', accessor: (r) => r.total_counterfeit },
    { header: 'Escalated', accessor: (r) => r.escalated_count },
  ];

  const actionTypeCols: Column<ActionBreakdown>[] = [
    { header: 'Action', accessor: (r) => r.action_type },
    { header: 'Count', accessor: (r) => r.action_count },
    { header: 'Resolved', accessor: (r) => r.resolved_count },
    { header: 'Pending', accessor: (r) => r.pending_count },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <h1 style={{ fontSize: 22, fontWeight: 700 }}>Customer Monthly Engineer Spare-Part Authenticity QR-Scan Compliance</h1>
      <p style={{ color: '#666' }}>Round 2968 · Monthly QR-scan audit per engineer per customer org. SLA target &gt;= 95% scan rate. Counterfeit flags &amp; escalations tracked.</p>

      {s && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 11, color: '#6b7280' }}>Engineers</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{s.total_engineers}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 11, color: '#6b7280' }}>Overall Compliance %</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{s.overall_compliance_pct}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 11, color: '#6b7280' }}>Counterfeit Flagged</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{s.counterfeit_flagged}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 11, color: '#6b7280' }}>Critical / Breach</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{s.critical_count} / {s.breach_count}</div>
          </div>
        </div>
      )}

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Latest Month — Per-Engineer Compliance</h2>
        <DataTable rows={latestRows} columns={latestCols} emptyMessage="No data" rowKey={(r, i) => String((r as { engineer_name?: string }).engineer_name ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Tier Breakdown</h2>
        <DataTable rows={tierRows} columns={tierCols} emptyMessage="No data" rowKey={(r, i) => String((r as { engineer_tier?: string }).engineer_tier ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Counterfeit Alerts</h2>
        <DataTable rows={counterfeitRows} columns={counterfeitCols} emptyMessage="No counterfeit incidents" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Escalated Engineers</h2>
        <DataTable rows={escalatedRows} columns={escalatedCols} emptyMessage="None escalated" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Audit Action Log</h2>
        <DataTable rows={actionRows} columns={actionCols} emptyMessage="No actions" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly Trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data" rowKey={(r, i) => String((r as { scan_month?: string }).scan_month ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Action Type Breakdown</h2>
        <DataTable rows={actionTypeRows} columns={actionTypeCols} emptyMessage="No actions" rowKey={(r, i) => String((r as { action_type?: string }).action_type ?? i)} />
      </section>
    </div>
  );
}
