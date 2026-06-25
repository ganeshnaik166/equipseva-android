import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [scoresRes, logRes, focusRes, funnelRes, trendRes, blurRes, ownerRes] = await Promise.all([
    supabase.rpc('list_photo_scores_r2666'),
    supabase.rpc('list_action_log_r2666'),
    supabase.rpc('top_low_score_focus_r2666'),
    supabase.rpc('status_funnel_r2666'),
    supabase.rpc('monthly_score_trend_r2666'),
    supabase.rpc('blur_rate_summary_r2666'),
    supabase.rpc('owner_load_r2666'),
  ]);

  const scores = (scoresRes.data ?? []) as any[];
  const log = (logRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const blur = (blurRes.data?.[0] ?? null) as any;
  const owner = (ownerRes.data ?? []) as any[];

  const scoresCols: Column<any>[] = [
    { key: 'scored_at', header: 'Scored', render: (r: any) => new Date(r.scored_at).toLocaleString() },
    { key: 'photo_url', header: 'Photo URL', render: (r: any) => r.photo_url },
    { key: 'ai_quality_score', header: 'Score', render: (r: any) => String(r.ai_quality_score) },
    { key: 'blur_detected', header: 'Blur', render: (r: any) => r.blur_detected ? 'yes' : 'no' },
    { key: 'patient_data_detected', header: 'Patient PII', render: (r: any) => r.patient_data_detected ? 'yes' : 'no' },
    { key: 'equipment_visible', header: 'Equipment', render: (r: any) => r.equipment_visible ? 'yes' : 'no' },
    { key: 'suggested_redo', header: 'Redo?', render: (r: any) => r.suggested_redo ? 'yes' : 'no' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const logCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString() },
    { key: 'photo_url', header: 'Photo URL', render: (r: any) => r.photo_url },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'scored_at', header: 'Scored', render: (r: any) => new Date(r.scored_at).toLocaleString() },
    { key: 'photo_url', header: 'Photo URL', render: (r: any) => r.photo_url },
    { key: 'ai_quality_score', header: 'Score', render: (r: any) => String(r.ai_quality_score) },
    { key: 'blur_detected', header: 'Blur', render: (r: any) => r.blur_detected ? 'yes' : 'no' },
    { key: 'patient_data_detected', header: 'Patient PII', render: (r: any) => r.patient_data_detected ? 'yes' : 'no' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'photo_count', header: 'Photos', render: (r: any) => String(r.photo_count) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'total_photos', header: 'Photos', render: (r: any) => String(r.total_photos) },
    { key: 'avg_score', header: 'Avg score', render: (r: any) => String(r.avg_score) },
    { key: 'blur_count', header: 'Blur', render: (r: any) => String(r.blur_count) },
    { key: 'patient_data_count', header: 'Patient PII', render: (r: any) => String(r.patient_data_count) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'total_photos', header: 'Total', render: (r: any) => String(r.total_photos) },
    { key: 'pending_photos', header: 'Pending', render: (r: any) => String(r.pending_photos) },
    { key: 'redo_photos', header: 'Needs redo', render: (r: any) => String(r.redo_photos) },
    { key: 'rejected_photos', header: 'Rejected', render: (r: any) => String(r.rejected_photos) },
    { key: 'approved_photos', header: 'Approved', render: (r: any) => String(r.approved_photos) },
    { key: 'avg_score', header: 'Avg score', render: (r: any) => String(r.avg_score) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>Engineer Customer Photo AI Quality Scorer</h1>
      <p style={{ color: '#555', marginBottom: 18 }}>
        AI scores every engineer-uploaded job photo for sharpness, equipment visibility, and patient-PII leaks.
        Low scores =&gt; auto redo request. Patient data =&gt; redact. Approved shots feed invoices &amp; marketing.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Total photos</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{blur?.total_photos ?? 0}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Blur %</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{blur?.blur_pct ?? 0}%</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Patient PII %</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{blur?.patient_data_pct ?? 0}%</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Suggested redo</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{blur?.suggested_redo_photos ?? 0}</div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Low-score focus (score &lt;= 60)</h2>
        <DataTable
          rows={focus}
          columns={focusCols}
          emptyMessage="No low-score photos right now. AI happy."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All photo scores</h2>
        <DataTable
          rows={scores}
          columns={scoresCols}
          emptyMessage="No photos scored yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Action log</h2>
        <DataTable
          rows={log}
          columns={logCols}
          emptyMessage="No actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly score trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No monthly data yet."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner load</h2>
        <DataTable
          rows={owner}
          columns={ownerCols}
          emptyMessage="No owner assignments yet."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </div>
  );
}
