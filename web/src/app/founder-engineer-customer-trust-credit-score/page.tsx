import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerCustomerTrustCreditScorePage() {
  const supabase = await getSupabaseServerClient();

  const [
    creditsRes,
    eventsRes,
    topTrustRes,
    brokenFocusRes,
    kindBreakdownRes,
    trendRes,
    hospitalSummaryRes,
  ] = await Promise.all([
    supabase.rpc('list_trust_credit_r2574'),
    supabase.rpc('list_event_log_r2574'),
    supabase.rpc('top_trust_engineers_r2574'),
    supabase.rpc('broken_focus_r2574'),
    supabase.rpc('event_kind_breakdown_r2574'),
    supabase.rpc('trust_score_trend_r2574'),
    supabase.rpc('hospital_trust_summary_r2574'),
  ]);

  const credits = (creditsRes.data ?? []) as any[];
  const events = (eventsRes.data ?? []) as any[];
  const topTrust = (topTrustRes.data ?? []) as any[];
  const brokenFocus = (brokenFocusRes.data ?? []) as any[];
  const kindBreakdown = (kindBreakdownRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const hospitalSummary = (hospitalSummaryRes.data ?? []) as any[];

  const creditCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '-').slice(0, 8) },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id ?? '-').slice(0, 8) },
    { key: 'trust_score', header: 'Score', render: (r: any) => r.trust_score },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'promise_made_count', header: 'Made', render: (r: any) => r.promise_made_count },
    { key: 'promise_kept_count', header: 'Kept', render: (r: any) => r.promise_kept_count },
    { key: 'promise_broken_count', header: 'Broken', render: (r: any) => r.promise_broken_count },
    { key: 'decay_rate_per_week', header: 'Decay/wk', render: (r: any) => r.decay_rate_per_week },
    { key: 'last_event_at', header: 'Last Event', render: (r: any) => (r.last_event_at ? new Date(r.last_event_at).toLocaleString() : '-') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const eventCols: Column<any>[] = [
    { key: 'event_at', header: 'When', render: (r: any) => new Date(r.event_at).toLocaleString() },
    { key: 'event_kind', header: 'Kind', render: (r: any) => r.event_kind },
    { key: 'impact_score', header: 'Impact', render: (r: any) => r.impact_score },
    { key: 'trust_score', header: 'Trust', render: (r: any) => r.trust_score },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topTrustCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '-').slice(0, 8) },
    { key: 'account_count', header: 'Accounts', render: (r: any) => r.account_count },
    { key: 'avg_trust_score', header: 'Avg Trust', render: (r: any) => (r.avg_trust_score == null ? '-' : Number(r.avg_trust_score).toFixed(1)) },
    { key: 'total_promises_kept', header: 'Kept', render: (r: any) => r.total_promises_kept },
    { key: 'total_promises_broken', header: 'Broken', render: (r: any) => r.total_promises_broken },
  ];

  const brokenFocusCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '-').slice(0, 8) },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id ?? '-').slice(0, 8) },
    { key: 'trust_score', header: 'Score', render: (r: any) => r.trust_score },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'promise_broken_count', header: 'Broken', render: (r: any) => r.promise_broken_count },
    { key: 'last_event_at', header: 'Last Event', render: (r: any) => (r.last_event_at ? new Date(r.last_event_at).toLocaleString() : '-') },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const kindCols: Column<any>[] = [
    { key: 'event_kind', header: 'Kind', render: (r: any) => r.event_kind },
    { key: 'event_count', header: 'Count', render: (r: any) => r.event_count },
    { key: 'total_impact', header: 'Total Impact', render: (r: any) => r.total_impact },
    { key: 'avg_impact', header: 'Avg Impact', render: (r: any) => (r.avg_impact == null ? '-' : Number(r.avg_impact).toFixed(2)) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_label', header: 'Week', render: (r: any) => r.week_label },
    { key: 'events_logged', header: 'Events', render: (r: any) => r.events_logged },
    { key: 'total_impact', header: 'Total Impact', render: (r: any) => r.total_impact },
    { key: 'positive_events', header: 'Positive', render: (r: any) => r.positive_events },
    { key: 'negative_events', header: 'Negative', render: (r: any) => r.negative_events },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id ?? '-').slice(0, 8) },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
    { key: 'avg_trust_score', header: 'Avg Trust', render: (r: any) => (r.avg_trust_score == null ? '-' : Number(r.avg_trust_score).toFixed(1)) },
    { key: 'min_trust_score', header: 'Min', render: (r: any) => r.min_trust_score },
    { key: 'max_trust_score', header: 'Max', render: (r: any) => r.max_trust_score },
    { key: 'total_broken_promises', header: 'Broken', render: (r: any) => r.total_broken_promises },
    { key: 'strained_or_broken_count', header: 'At Risk', render: (r: any) => r.strained_or_broken_count },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Engineer x Customer Trust Credit Score
      </h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Per engineer & hospital trust ledger. Promises made/kept/broken, decay-per-week score 0..100, status
        (building => strong => champion or strained => broken). Event log shows extra-mile boosts & missed-callback
        debits. Broken focus pane drives weekly CSM saves.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Trust Credits</h2>
        <DataTable
          rows={credits}
          columns={creditCols}
          emptyMessage="No trust credits tracked yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Event Log</h2>
        <DataTable
          rows={events}
          columns={eventCols}
          emptyMessage="No events logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top Trust Engineers</h2>
        <DataTable
          rows={topTrust}
          columns={topTrustCols}
          emptyMessage="No top trust data yet"
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Broken & Strained Focus</h2>
        <DataTable
          rows={brokenFocus}
          columns={brokenFocusCols}
          emptyMessage="No broken accounts - all healthy"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Event Kind Breakdown</h2>
        <DataTable
          rows={kindBreakdown}
          columns={kindCols}
          emptyMessage="No event kinds yet"
          rowKey={(r: any, i: number) => String(r.event_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Weekly Trust Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No weekly trend data yet"
          rowKey={(r: any, i: number) => String(r.week_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Hospital Trust Summary</h2>
        <DataTable
          rows={hospitalSummary}
          columns={hospitalCols}
          emptyMessage="No hospital summary yet"
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>
    </div>
  );
}
