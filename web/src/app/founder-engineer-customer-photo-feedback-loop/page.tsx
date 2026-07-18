import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    feedbackRes,
    actionsRes,
    concernRes,
    kindDistRes,
    statusFunnelRes,
    monthlyTrendRes,
    ownerLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_photo_feedback_r2614'),
    supabase.rpc('list_redo_actions_r2614'),
    supabase.rpc('top_concern_focus_r2614'),
    supabase.rpc('feedback_kind_distribution_r2614'),
    supabase.rpc('status_funnel_r2614'),
    supabase.rpc('monthly_feedback_trend_r2614'),
    supabase.rpc('owner_load_r2614'),
  ]);

  const feedback = (feedbackRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const concernFocus = (concernRes.data ?? []) as any[];
  const kindDist = (kindDistRes.data ?? []) as any[];
  const statusFunnel = (statusFunnelRes.data ?? []) as any[];
  const monthlyTrend = (monthlyTrendRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];

  const fmt = (v: any) => (v == null ? '' : String(v));
  const fmtTs = (v: any) => (v ? new Date(v).toLocaleString('en-IN') : '');
  const fmtMonth = (v: any) =>
    v ? new Date(v).toLocaleDateString('en-IN', { year: 'numeric', month: 'short' }) : '';

  const feedbackCols: Column<any>[] = [
    { key: 'photo_at', header: 'Photo at', render: (r: any) => fmtTs(r.photo_at) },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => fmt(r.engineer_user_id).slice(0, 8) },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => fmt(r.hospital_user_id).slice(0, 8) },
    { key: 'customer_feedback_kind', header: 'Kind', render: (r: any) => fmt(r.customer_feedback_kind) },
    { key: 'status', header: 'Status', render: (r: any) => fmt(r.status) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => fmt(r.owner_email) },
    { key: 'engineer_response_md', header: 'Engineer response', render: (r: any) => fmt(r.engineer_response_md) },
    { key: 'notes', header: 'Notes', render: (r: any) => fmt(r.notes) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'Action at', render: (r: any) => fmtTs(r.action_at) },
    { key: 'feedback_id', header: 'Feedback', render: (r: any) => fmt(r.feedback_id).slice(0, 8) },
    { key: 'action_kind', header: 'Kind', render: (r: any) => fmt(r.action_kind) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => fmt(r.outcome) },
    { key: 'status', header: 'Status', render: (r: any) => fmt(r.status) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => fmt(r.owner_email) },
    { key: 'notes', header: 'Notes', render: (r: any) => fmt(r.notes) },
  ];

  const concernCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => fmt(r.engineer_user_id).slice(0, 8) },
    { key: 'concern_count', header: 'Concerns', render: (r: any) => fmt(r.concern_count) },
    { key: 'needs_redo_count', header: 'Needs redo', render: (r: any) => fmt(r.needs_redo_count) },
    { key: 'open_count', header: 'Open', render: (r: any) => fmt(r.open_count) },
    { key: 'total_count', header: 'Total', render: (r: any) => fmt(r.total_count) },
  ];

  const kindCols: Column<any>[] = [
    { key: 'customer_feedback_kind', header: 'Kind', render: (r: any) => fmt(r.customer_feedback_kind) },
    { key: 'cnt', header: 'Count', render: (r: any) => fmt(r.cnt) },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => fmt(r.status) },
    { key: 'cnt', header: 'Count', render: (r: any) => fmt(r.cnt) },
  ];

  const monthCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtMonth(r.month_start) },
    { key: 'total_count', header: 'Total', render: (r: any) => fmt(r.total_count) },
    { key: 'praise_count', header: 'Praise', render: (r: any) => fmt(r.praise_count) },
    { key: 'concern_count', header: 'Concern', render: (r: any) => fmt(r.concern_count) },
    { key: 'needs_redo_count', header: 'Needs redo', render: (r: any) => fmt(r.needs_redo_count) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => fmt(r.owner_email) },
    { key: 'feedback_total', header: 'Feedback total', render: (r: any) => fmt(r.feedback_total) },
    { key: 'feedback_open', header: 'Feedback open', render: (r: any) => fmt(r.feedback_open) },
    { key: 'action_total', header: 'Action total', render: (r: any) => fmt(r.action_total) },
    { key: 'action_open', header: 'Action open', render: (r: any) => fmt(r.action_open) },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Engineer & Customer Photo Feedback Loop</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Close the loop between engineer site photos and hospital reactions &gt; track redo actions until signoff.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Photo feedback</h2>
        <DataTable
          rows={feedback}
          columns={feedbackCols}
          emptyMessage="No photo feedback yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Redo actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No redo actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top concern focus by engineer</h2>
        <DataTable
          rows={concernFocus}
          columns={concernCols}
          emptyMessage="No concern data yet"
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Feedback kind distribution</h2>
        <DataTable
          rows={kindDist}
          columns={kindCols}
          emptyMessage="No distribution data"
          rowKey={(r: any, i: number) => String(r.customer_feedback_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Status funnel</h2>
        <DataTable
          rows={statusFunnel}
          columns={statusCols}
          emptyMessage="No status data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly feedback trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={monthCols}
          emptyMessage="No monthly trend yet"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Owner load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owner load yet"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
