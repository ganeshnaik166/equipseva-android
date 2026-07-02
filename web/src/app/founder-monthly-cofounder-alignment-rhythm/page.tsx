import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [alignmentRes, actionsRes, tensionRes, trendRes, funnelRes, actionSummaryRes, pulseRes] = await Promise.all([
    supabase.rpc('list_alignment_r2641'),
    supabase.rpc('list_recovery_actions_r2641'),
    supabase.rpc('top_tension_focus_r2641'),
    supabase.rpc('alignment_score_trend_r2641'),
    supabase.rpc('status_funnel_r2641'),
    supabase.rpc('monthly_recovery_action_summary_r2641'),
    supabase.rpc('founder_pulse_summary_r2641'),
  ]);

  const alignmentRows = (alignmentRes.data ?? []) as any[];
  const actionRows = (actionsRes.data ?? []) as any[];
  const tensionRows = (tensionRes.data ?? []) as any[];
  const trendRows = (trendRes.data ?? []) as any[];
  const funnelRows = (funnelRes.data ?? []) as any[];
  const actionSummaryRows = (actionSummaryRes.data ?? []) as any[];
  const pulseRows = (pulseRes.data ?? []) as any[];
  const pulse = pulseRows[0] ?? {};

  const alignmentCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'alignment_score', header: 'Score', render: (r: any) => String(r.alignment_score) },
    { key: 'decisions_in_sync', header: 'In Sync', render: (r: any) => String(r.decisions_in_sync) },
    { key: 'decisions_diverged', header: 'Diverged', render: (r: any) => String(r.decisions_diverged) },
    { key: 'tension_kind', header: 'Tension', render: (r: any) => r.tension_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleDateString() },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const tensionCols: Column<any>[] = [
    { key: 'tension_kind', header: 'Tension Kind', render: (r: any) => r.tension_kind },
    { key: 'months_count', header: 'Months', render: (r: any) => String(r.months_count) },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => String(r.avg_score) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'alignment_score', header: 'Score', render: (r: any) => String(r.alignment_score) },
    { key: 'decisions_in_sync', header: 'In Sync', render: (r: any) => String(r.decisions_in_sync) },
    { key: 'decisions_diverged', header: 'Diverged', render: (r: any) => String(r.decisions_diverged) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'months_count', header: 'Months', render: (r: any) => String(r.months_count) },
  ];

  const actionSummaryCols: Column<any>[] = [
    { key: 'action_kind', header: 'Action Kind', render: (r: any) => r.action_kind },
    { key: 'actions_count', header: 'Total', render: (r: any) => String(r.actions_count) },
    { key: 'positive_count', header: 'Positive', render: (r: any) => String(r.positive_count) },
    { key: 'pending_count', header: 'Pending', render: (r: any) => String(r.pending_count) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder & Co-founder Monthly Alignment Rhythm</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track monthly alignment scores between founders & recovery actions when tension shows up.
      </p>

      <section style={{ marginBottom: 24, padding: 16, background: '#f6f8fa', borderRadius: 8 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Founder Pulse</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
          <div><div style={{ color: '#777', fontSize: 12 }}>Months tracked</div><div style={{ fontSize: 20, fontWeight: 600 }}>{String(pulse.months_tracked ?? 0)}</div></div>
          <div><div style={{ color: '#777', fontSize: 12 }}>Avg alignment</div><div style={{ fontSize: 20, fontWeight: 600 }}>{String(pulse.avg_alignment ?? 0)}</div></div>
          <div><div style={{ color: '#777', fontSize: 12 }}>Strained months</div><div style={{ fontSize: 20, fontWeight: 600 }}>{String(pulse.strained_months ?? 0)}</div></div>
          <div><div style={{ color: '#777', fontSize: 12 }}>Open actions</div><div style={{ fontSize: 20, fontWeight: 600 }}>{String(pulse.open_actions ?? 0)}</div></div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Alignment</h2>
        <DataTable
          rows={alignmentRows}
          columns={alignmentCols}
          emptyMessage="No alignment months recorded yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Score Trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Tension Focus</h2>
        <DataTable
          rows={tensionRows}
          columns={tensionCols}
          emptyMessage="No tension data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status Funnel</h2>
        <DataTable
          rows={funnelRows}
          columns={funnelCols}
          emptyMessage="No status rows"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recovery Actions</h2>
        <DataTable
          rows={actionRows}
          columns={actionCols}
          emptyMessage="No recovery actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recovery Action Summary</h2>
        <DataTable
          rows={actionSummaryRows}
          columns={actionSummaryCols}
          emptyMessage="No action summary"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
