import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyVisionRecommitPulsePage() {
  const supabase = await getSupabaseServerClient();

  const [pulsesRes, practicesRes, dissonanceRes, trendRes, funnelRes, monthlyRes, summaryRes] = await Promise.all([
    supabase.rpc('list_vision_r2637'),
    supabase.rpc('list_alignment_practices_r2637'),
    supabase.rpc('top_dissonance_focus_r2637'),
    supabase.rpc('clarity_score_trend_r2637'),
    supabase.rpc('status_funnel_r2637'),
    supabase.rpc('monthly_practice_summary_r2637'),
    supabase.rpc('founder_pulse_summary_r2637'),
  ]);

  const pulses = (pulsesRes.data as any[]) ?? [];
  const practices = (practicesRes.data as any[]) ?? [];
  const dissonance = (dissonanceRes.data as any[]) ?? [];
  const trend = (trendRes.data as any[]) ?? [];
  const funnel = (funnelRes.data as any[]) ?? [];
  const monthly = (monthlyRes.data as any[]) ?? [];
  const summary = ((summaryRes.data as any[]) ?? [])[0] ?? null;

  const pulseCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'vision_clarity_score', header: 'Clarity', render: (r: any) => r.vision_clarity_score },
    { key: 'conviction_score', header: 'Conviction', render: (r: any) => r.conviction_score },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'dissonance_md', header: 'Dissonance', render: (r: any) => r.dissonance_md ?? '' },
    { key: 'recommit_action_md', header: 'Recommit Action', render: (r: any) => r.recommit_action_md ?? '' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const practiceCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'practice_at', header: 'Practiced At', render: (r: any) => r.practice_at ? new Date(r.practice_at).toISOString().slice(0, 16).replace('T', ' ') : '' },
    { key: 'practice_kind', header: 'Kind', render: (r: any) => r.practice_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const dissonanceCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'vision_clarity_score', header: 'Clarity', render: (r: any) => r.vision_clarity_score },
    { key: 'conviction_score', header: 'Conviction', render: (r: any) => r.conviction_score },
    { key: 'gap', header: 'Gap to 100', render: (r: any) => r.gap },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'dissonance_md', header: 'Dissonance', render: (r: any) => r.dissonance_md ?? '' },
    { key: 'recommit_action_md', header: 'Planned Recommit', render: (r: any) => r.recommit_action_md ?? '' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'avg_clarity', header: 'Avg Clarity', render: (r: any) => r.avg_clarity },
    { key: 'avg_conviction', header: 'Avg Conviction', render: (r: any) => r.avg_conviction },
    { key: 'pulses', header: 'Pulses', render: (r: any) => r.pulses },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'pulses', header: 'Pulses', render: (r: any) => r.pulses },
    { key: 'avg_clarity', header: 'Avg Clarity', render: (r: any) => r.avg_clarity },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'practice_kind', header: 'Kind', render: (r: any) => r.practice_kind },
    { key: 'practices', header: 'Practices', render: (r: any) => r.practices },
    { key: 'positive_outcomes', header: 'Positive', render: (r: any) => r.positive_outcomes },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Monthly Vision Recommit Pulse</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Monthly clarity & conviction tracking with alignment practices & dissonance triage.
      </p>

      {summary && (
        <section style={{ marginBottom: 32, padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 12 }}>
            <div><strong>Total pulses:</strong> {summary.total_pulses}</div>
            <div><strong>Recommit done:</strong> {summary.recommit_done}</div>
            <div><strong>Monitoring:</strong> {summary.monitoring}</div>
            <div><strong>Pivots:</strong> {summary.pivots}</div>
            <div><strong>Dropped:</strong> {summary.dropped}</div>
            <div><strong>Avg clarity:</strong> {summary.avg_clarity}</div>
            <div><strong>Avg conviction:</strong> {summary.avg_conviction}</div>
            <div><strong>Total practices:</strong> {summary.total_practices}</div>
            <div><strong>Positive practices:</strong> {summary.positive_practices}</div>
          </div>
        </section>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Pulses</h2>
        <DataTable
          rows={pulses}
          columns={pulseCols}
          emptyMessage="No vision pulses logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Dissonance Focus</h2>
        <DataTable
          rows={dissonance}
          columns={dissonanceCols}
          emptyMessage="No open dissonance items."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Clarity & Conviction Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Alignment Practices</h2>
        <DataTable
          rows={practices}
          columns={practiceCols}
          emptyMessage="No alignment practices logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Practice Summary</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          emptyMessage="No monthly practice data."
          rowKey={(r: any, i: number) => `${r.month_label}-${r.practice_kind}-${i}`}
        />
      </section>
    </main>
  );
}
