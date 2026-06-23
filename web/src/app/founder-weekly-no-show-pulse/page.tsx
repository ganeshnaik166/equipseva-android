import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderWeeklyNoShowPulsePage() {
  const supabase = await getSupabaseServerClient();

  const [noShows, metrics, topParties, reasons, trend, topImpact, repeatOffenders] = await Promise.all([
    supabase.rpc('list_no_shows_r2465'),
    supabase.rpc('list_metrics_r2465'),
    supabase.rpc('top_no_show_parties_r2465'),
    supabase.rpc('reason_breakdown_r2465'),
    supabase.rpc('weekly_rate_trend_r2465'),
    supabase.rpc('top_impact_focus_r2465'),
    supabase.rpc('repeat_offenders_focus_r2465'),
  ]);

  const fmtMoney = (v: number | null | undefined) =>
    v == null || v === 0 ? '-' : `Rs ${(v / 100000).toFixed(2)} L`;

  const noShowCols: Column<any>[] = [
    { key: 'party_label', header: 'Party', render: (r: any) => r.party_label },
    { key: 'appointment_kind', header: 'Kind', render: (r: any) => r.appointment_kind },
    { key: 'scheduled_at', header: 'When', render: (r: any) => new Date(r.scheduled_at).toLocaleDateString() },
    { key: 'no_show_reason', header: 'Reason', render: (r: any) => r.no_show_reason },
    { key: 'impact_kind', header: 'Impact', render: (r: any) => r.impact_kind },
    { key: 'impact_rupees', header: 'Rs Impact', render: (r: any) => fmtMoney(r.impact_rupees) },
    { key: 'repeat', header: 'Repeat?', render: (r: any) => r.repeat_offender ? 'Yes' : 'No' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const metricsCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => new Date(r.week_start).toLocaleDateString() },
    { key: 'total_appointments', header: 'Total Appts', render: (r: any) => r.total_appointments },
    { key: 'no_show_count', header: 'No-Shows', render: (r: any) => r.no_show_count },
    { key: 'no_show_rate_pct', header: 'Rate %', render: (r: any) => `${r.no_show_rate_pct}%` },
    { key: 'top_reason', header: 'Top Reason', render: (r: any) => r.top_reason },
    { key: 'total_impact_rupees', header: 'Rs Impact', render: (r: any) => fmtMoney(r.total_impact_rupees) },
    { key: 'repeat_offenders_count', header: 'Repeat', render: (r: any) => r.repeat_offenders_count },
    { key: 'prevention_score', header: 'Prevention', render: (r: any) => `${r.prevention_score}/100` },
  ];

  const topPartyCols: Column<any>[] = [
    { key: 'party_label', header: 'Party', render: (r: any) => r.party_label },
    { key: 'party_email', header: 'Email', render: (r: any) => r.party_email },
    { key: 'no_show_count', header: 'No-Shows', render: (r: any) => r.no_show_count },
    { key: 'total_impact_rupees', header: 'Rs Impact', render: (r: any) => fmtMoney(r.total_impact_rupees) },
    { key: 'last_no_show_at', header: 'Last', render: (r: any) => r.last_no_show_at ? new Date(r.last_no_show_at).toLocaleDateString() : '-' },
  ];

  const reasonCols: Column<any>[] = [
    { key: 'no_show_reason', header: 'Reason', render: (r: any) => r.no_show_reason },
    { key: 'appointment_kind', header: 'Kind', render: (r: any) => r.appointment_kind },
    { key: 'hit_count', header: 'Hits', render: (r: any) => r.hit_count },
    { key: 'total_impact_rupees', header: 'Rs Impact', render: (r: any) => fmtMoney(r.total_impact_rupees) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => new Date(r.week_start).toLocaleDateString() },
    { key: 'no_show_rate_pct', header: 'Rate %', render: (r: any) => `${r.no_show_rate_pct}%` },
    { key: 'no_show_count', header: 'No-Shows', render: (r: any) => r.no_show_count },
    { key: 'total_appointments', header: 'Total Appts', render: (r: any) => r.total_appointments },
    { key: 'prevention_score', header: 'Prevention', render: (r: any) => `${r.prevention_score}/100` },
  ];

  const impactCols: Column<any>[] = [
    { key: 'party_label', header: 'Party', render: (r: any) => r.party_label },
    { key: 'appointment_kind', header: 'Kind', render: (r: any) => r.appointment_kind },
    { key: 'no_show_reason', header: 'Reason', render: (r: any) => r.no_show_reason },
    { key: 'impact_kind', header: 'Impact Kind', render: (r: any) => r.impact_kind },
    { key: 'impact_rupees', header: 'Rs', render: (r: any) => fmtMoney(r.impact_rupees) },
    { key: 'scheduled_at', header: 'When', render: (r: any) => new Date(r.scheduled_at).toLocaleDateString() },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const repeatCols: Column<any>[] = [
    { key: 'party_label', header: 'Party', render: (r: any) => r.party_label },
    { key: 'party_email', header: 'Email', render: (r: any) => r.party_email },
    { key: 'appointment_kind', header: 'Kind', render: (r: any) => r.appointment_kind },
    { key: 'no_show_count', header: 'Count', render: (r: any) => r.no_show_count },
    { key: 'total_impact_rupees', header: 'Rs Impact', render: (r: any) => fmtMoney(r.total_impact_rupees) },
    { key: 'last_reason', header: 'Last Reason', render: (r: any) => r.last_reason ?? '-' },
    { key: 'last_scheduled_at', header: 'Last When', render: (r: any) => r.last_scheduled_at ? new Date(r.last_scheduled_at).toLocaleDateString() : '-' },
  ];

  const trendRows = (trend.data ?? []) as any[];
  const latest = trendRows.length > 0 ? trendRows[trendRows.length - 1] : null;
  const totalNoShows = (noShows.data ?? []).length;
  const totalImpact = ((noShows.data ?? []) as any[]).reduce((s, r) => s + (r.impact_rupees ?? 0), 0);
  const totalRepeat = ((noShows.data ?? []) as any[]).filter((r) => r.repeat_offender).length;

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Founder > Weekly No-Show Pulse</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Appointments & no-shows tracked across investor, customer, internal, event & training. Reason => impact => prevention action => repeat offender flag.
      </p>

      <section style={{ marginBottom: 32, display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total No-Shows</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalNoShows}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Rs Impact</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtMoney(totalImpact)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Repeat Offenders</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalRepeat}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Latest Rate</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{latest ? `${latest.no_show_rate_pct}%` : '-'}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Latest Prevention</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{latest ? `${latest.prevention_score}/100` : '-'}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Weekly Metrics</h2>
        <DataTable
          rows={metrics.data ?? []}
          columns={metricsCols}
          emptyMessage="No weekly metrics yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Weekly Rate Trend</h2>
        <DataTable
          rows={trend.data ?? []}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Impact Focus</h2>
        <DataTable
          rows={topImpact.data ?? []}
          columns={impactCols}
          emptyMessage="No revenue impact recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Repeat Offenders Focus</h2>
        <DataTable
          rows={repeatOffenders.data ?? []}
          columns={repeatCols}
          emptyMessage="No repeat offenders. Nice."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top No-Show Parties</h2>
        <DataTable
          rows={topParties.data ?? []}
          columns={topPartyCols}
          emptyMessage="No party data."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Reason Breakdown</h2>
        <DataTable
          rows={reasons.data ?? []}
          columns={reasonCols}
          emptyMessage="No reason data."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All No-Shows</h2>
        <DataTable
          rows={noShows.data ?? []}
          columns={noShowCols}
          emptyMessage="No no-shows logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
