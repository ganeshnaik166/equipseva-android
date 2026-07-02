import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerWageEquityAuditPage() {
  const sb = await getSupabaseServerClient();

  const [auditsRes, concerningRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_audits_r2144'),
    sb.rpc('concerning_gaps_r2144'),
    sb.rpc('recent_actions_r2144'),
  ]);

  const audits: any[] = Array.isArray(auditsRes.data) ? auditsRes.data : [];
  const concerning: any[] = Array.isArray(concerningRes.data) ? concerningRes.data : [];
  const actions: any[] = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const auditCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'region_label', header: 'Region', render: (r: any) => String(r.region_label ?? '') },
    { key: 'tier_label', header: 'Tier', render: (r: any) => String(r.tier_label ?? '') },
    { key: 'avg_wage_rupees', header: 'Avg Wage', render: (r: any) => `Rs ${Number(r.avg_wage_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'gender_wage_gap_pct', header: 'Gender Gap pct', render: (r: any) => `${Number(r.gender_wage_gap_pct ?? 0).toFixed(2)}` },
    { key: 'tenure_wage_gap_pct', header: 'Tenure Gap pct', render: (r: any) => `${Number(r.tenure_wage_gap_pct ?? 0).toFixed(2)}` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString('en-IN') : '' },
  ];

  const concerningCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'region_label', header: 'Region', render: (r: any) => String(r.region_label ?? '') },
    { key: 'tier_label', header: 'Tier', render: (r: any) => String(r.tier_label ?? '') },
    { key: 'gender_wage_gap_pct', header: 'Gender Gap pct', render: (r: any) => `${Number(r.gender_wage_gap_pct ?? 0).toFixed(2)}` },
    { key: 'tenure_wage_gap_pct', header: 'Tenure Gap pct', render: (r: any) => `${Number(r.tenure_wage_gap_pct ?? 0).toFixed(2)}` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString('en-IN') : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'audit_id', header: 'Audit', render: (r: any) => String(r.audit_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString('en-IN') : '' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Wage Equity Audit</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Audit engineer wage equity across roles, regions, and tiers. Track gender and tenure pay gaps.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Audits ({audits.length})</h2>
        <DataTable rows={audits} columns={auditCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Concerning Gaps ({concerning.length})</h2>
        <p style={{ color: '#666', marginBottom: 12 }}>
          Audits flagged as concerning or critical require founder attention.
        </p>
        <DataTable rows={concerning} columns={concerningCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions ({actions.length})</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
