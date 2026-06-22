import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [links, topGaps, recentActions, agg] = await Promise.all([
    sb.rpc('list_skill_gap_revenue_r2214'),
    sb.rpc('top_skill_gap_revenue_r2214'),
    sb.rpc('recent_actions_skill_gap_revenue_r2214'),
    sb.rpc('aggregate_skill_gap_revenue_r2214'),
  ]);

  const linkRows: any[] = links.data ?? [];
  const topRows: any[] = topGaps.data ?? [];
  const actionRows: any[] = recentActions.data ?? [];
  const a: any = (agg.data && agg.data[0]) || {};

  const linkCols: Column<any>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'gap_type', header: 'Gap type', render: (r: any) => r.gap_type },
    { key: 'category', header: 'Category', render: (r: any) => r.gap_category },
    { key: 'modality', header: 'Modality', render: (r: any) => r.equipment_modality ?? '—' },
    { key: 'revenue_impact', header: 'Revenue impact', render: (r: any) => `Rs ${r.revenue_impact_rupees}` },
    { key: 'lost_jobs', header: 'Lost jobs', render: (r: any) => r.lost_jobs_count },
    { key: 'escalations', header: 'Escalations', render: (r: any) => r.escalation_count },
    { key: 'refunds', header: 'Refunds', render: (r: any) => r.refund_count },
    { key: 'refund_rs', header: 'Refund Rs', render: (r: any) => r.refund_rupees },
    { key: 'observed', header: 'Observed', render: (r: any) => String(r.observed_at ?? '').slice(0, 10) },
  ];

  const topCols: Column<any>[] = [
    { key: 'gap_type', header: 'Gap type', render: (r: any) => r.gap_type },
    { key: 'revenue_impact_rs', header: 'Revenue impact Rs', render: (r: any) => r.total_revenue_impact },
    { key: 'lost_jobs', header: 'Lost jobs', render: (r: any) => r.total_lost_jobs },
    { key: 'escalations', header: 'Escalations', render: (r: any) => r.total_escalations },
    { key: 'refunds', header: 'Refunds', render: (r: any) => r.total_refunds },
    { key: 'engineers_affected', header: 'Engineers affected', render: (r: any) => r.engineers_affected },
  ];

  const actionCols: Column<any>[] = [
    { key: 'link_id', header: 'Link id', render: (r: any) => String(r.link_id ?? '').slice(0, 8) },
    { key: 'action', header: 'Action', render: (r: any) => r.action_taken },
    { key: 'plan', header: 'Plan', render: (r: any) => r.remediation_plan ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'acted', header: 'Acted', render: (r: any) => String(r.acted_at ?? '').slice(0, 16) },
  ];

  return (
    <main style={{ padding: 24 }}>
      <h1>Engineer skill-gap to revenue link</h1>
      <p>
        Which engineer skill gaps cost the most revenue — tracks lost jobs, escalations
        & refunds by gap type, so training spend lands where revenue leaks are largest.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, margin: '16px 0' }}>
        <div><b>Total links</b><div>{a.total_links ?? 0}</div></div>
        <div><b>Revenue impact</b><div>Rs {a.total_revenue_impact ?? 0}</div></div>
        <div><b>Lost jobs</b><div>{a.total_lost_jobs ?? 0}</div></div>
        <div><b>Escalations</b><div>{a.total_escalations ?? 0}</div></div>
        <div><b>Refunds</b><div>{a.total_refunds ?? 0}</div></div>
        <div><b>Refund Rs</b><div>Rs {a.total_refund_rupees ?? 0}</div></div>
        <div><b>Open actions</b><div>{a.open_actions ?? 0}</div></div>
      </section>

      <h2>Top gap types by revenue impact</h2>
      <DataTable columns={topCols} rows={topRows} rowKey={(_, i) => String(i)} />

      <h2>Skill-gap revenue links</h2>
      <DataTable columns={linkCols} rows={linkRows} rowKey={(_, i) => String(i)} />

      <h2>Recent remediation actions</h2>
      <DataTable columns={actionCols} rows={actionRows} rowKey={(_, i) => String(i)} />
    </main>
  );
}
