import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    movesRes,
    threatRes,
    byCompRes,
    topThreatsRes,
    counterDueRes,
    digestHistRes,
    digestPreviewRes,
  ] = await Promise.all([
    sb.rpc('list_moves_r2413', { p_limit: 50 }),
    sb.rpc('threat_breakdown_r2413', { p_weeks: 12 }),
    sb.rpc('by_competitor_r2413', { p_weeks: 12 }),
    sb.rpc('top_threats_r2413', { p_limit: 20 }),
    sb.rpc('counter_actions_due_r2413'),
    sb.rpc('weekly_digest_history_r2413', { p_limit: 26 }),
    sb.rpc('generate_weekly_digest_r2413', { p_week_start: null }),
  ]);

  const moves = (movesRes.data ?? []) as any[];
  const threats = (threatRes.data ?? []) as any[];
  const byComp = (byCompRes.data ?? []) as any[];
  const topThreats = (topThreatsRes.data ?? []) as any[];
  const counterDue = (counterDueRes.data ?? []) as any[];
  const digestHist = (digestHistRes.data ?? []) as any[];
  const preview = ((digestPreviewRes.data ?? []) as any[])[0] ?? null;

  const fmtDate = (v: any) =>
    v ? new Date(v).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '-';
  const fmtDay = (v: any) =>
    v ? new Date(v).toLocaleDateString('en-IN', { dateStyle: 'medium' }) : '-';

  const threatBadge = (t: string) => {
    const colors: Record<string, string> = {
      critical: '#b91c1c',
      high: '#c2410c',
      medium: '#a16207',
      low: '#15803d',
    };
    return (
      <span
        style={{
          background: colors[t] ?? '#475569',
          color: 'white',
          padding: '2px 8px',
          borderRadius: 999,
          fontSize: 12,
          fontWeight: 600,
          textTransform: 'uppercase',
        }}
      >
        {t}
      </span>
    );
  };

  const statusBadge = (s: string) => {
    const colors: Record<string, string> = {
      none: '#94a3b8',
      planned: '#0ea5e9',
      in_progress: '#a855f7',
      done: '#22c55e',
      dropped: '#64748b',
    };
    return (
      <span
        style={{
          background: colors[s] ?? '#475569',
          color: 'white',
          padding: '2px 8px',
          borderRadius: 6,
          fontSize: 12,
        }}
      >
        {s}
      </span>
    );
  };

  const movesCols: Column<any>[] = [
    { key: 'observed_at', header: 'Observed', render: (r: any) => fmtDate(r.observed_at) },
    { key: 'competitor_name', header: 'Competitor', render: (r: any) => r.competitor_name },
    { key: 'move_kind', header: 'Kind', render: (r: any) => r.move_kind },
    { key: 'threat_level', header: 'Threat', render: (r: any) => threatBadge(r.threat_level) },
    { key: 'insight_category', header: 'Insight', render: (r: any) => r.insight_category },
    { key: 'summary', header: 'Summary', render: (r: any) => r.summary },
    { key: 'counter_status', header: 'Counter', render: (r: any) => statusBadge(r.counter_status) },
    { key: 'age_days', header: 'Age (d)', render: (r: any) => String(Number(r.age_days ?? 0)) },
    {
      key: 'source_url',
      header: 'Source',
      render: (r: any) =>
        r.source_url ? (
          <a href={r.source_url} target="_blank" rel="noreferrer" style={{ color: '#2563eb' }}>
            link
          </a>
        ) : (
          '-'
        ),
    },
  ];

  const threatCols: Column<any>[] = [
    { key: 'threat_level', header: 'Threat', render: (r: any) => threatBadge(r.threat_level) },
    { key: 'move_count', header: 'Moves', render: (r: any) => String(Number(r.move_count ?? 0)) },
    {
      key: 'with_counter',
      header: 'With counter',
      render: (r: any) => String(Number(r.with_counter ?? 0)),
    },
    {
      key: 'counter_done',
      header: 'Counter done',
      render: (r: any) => String(Number(r.counter_done ?? 0)),
    },
    {
      key: 'share_pct',
      header: 'Share %',
      render: (r: any) => `${Number(r.share_pct ?? 0).toFixed(1)}%`,
    },
  ];

  const byCompCols: Column<any>[] = [
    { key: 'competitor_name', header: 'Competitor', render: (r: any) => r.competitor_name },
    { key: 'move_count', header: 'Moves', render: (r: any) => String(Number(r.move_count ?? 0)) },
    {
      key: 'critical_count',
      header: 'Critical',
      render: (r: any) => String(Number(r.critical_count ?? 0)),
    },
    {
      key: 'high_count',
      header: 'High',
      render: (r: any) => String(Number(r.high_count ?? 0)),
    },
    { key: 'top_kind', header: 'Top kind', render: (r: any) => r.top_kind ?? '-' },
    {
      key: 'open_counters',
      header: 'Open counters',
      render: (r: any) => String(Number(r.open_counters ?? 0)),
    },
    {
      key: 'last_observed_at',
      header: 'Last seen',
      render: (r: any) => fmtDate(r.last_observed_at),
    },
  ];

  const topThreatCols: Column<any>[] = [
    { key: 'observed_at', header: 'Observed', render: (r: any) => fmtDate(r.observed_at) },
    { key: 'competitor_name', header: 'Competitor', render: (r: any) => r.competitor_name },
    { key: 'threat_level', header: 'Threat', render: (r: any) => threatBadge(r.threat_level) },
    { key: 'move_kind', header: 'Kind', render: (r: any) => r.move_kind },
    { key: 'insight_category', header: 'Insight', render: (r: any) => r.insight_category },
    { key: 'summary', header: 'Summary', render: (r: any) => r.summary },
    {
      key: 'counter_status',
      header: 'Counter',
      render: (r: any) => statusBadge(r.counter_status),
    },
  ];

  const counterCols: Column<any>[] = [
    { key: 'competitor_name', header: 'Competitor', render: (r: any) => r.competitor_name },
    { key: 'threat_level', header: 'Threat', render: (r: any) => threatBadge(r.threat_level) },
    { key: 'counter_action', header: 'Action', render: (r: any) => r.counter_action ?? '-' },
    { key: 'counter_owner_email', header: 'Owner', render: (r: any) => r.counter_owner_email ?? '-' },
    { key: 'counter_due_at', header: 'Due', render: (r: any) => fmtDate(r.counter_due_at) },
    {
      key: 'days_until_due',
      header: 'Days',
      render: (r: any) =>
        r.days_until_due === null || r.days_until_due === undefined
          ? '-'
          : String(Number(r.days_until_due)),
    },
    {
      key: 'is_overdue',
      header: 'Overdue?',
      render: (r: any) =>
        r.is_overdue ? (
          <span style={{ color: '#b91c1c', fontWeight: 600 }}>OVERDUE</span>
        ) : (
          'on track'
        ),
    },
    { key: 'counter_status', header: 'Status', render: (r: any) => statusBadge(r.counter_status) },
  ];

  const digestCols: Column<any>[] = [
    { key: 'week_start', header: 'Week start', render: (r: any) => fmtDay(r.week_start) },
    { key: 'total_moves', header: 'Moves', render: (r: any) => String(Number(r.total_moves ?? 0)) },
    {
      key: 'critical_threat_count',
      header: 'Critical',
      render: (r: any) => String(Number(r.critical_threat_count ?? 0)),
    },
    {
      key: 'high_threat_count',
      header: 'High',
      render: (r: any) => String(Number(r.high_threat_count ?? 0)),
    },
    { key: 'top_competitor', header: 'Top competitor', render: (r: any) => r.top_competitor ?? '-' },
    {
      key: 'top_threat_level',
      header: 'Top threat',
      render: (r: any) => (r.top_threat_level ? threatBadge(r.top_threat_level) : '-'),
    },
    { key: 'sent_at', header: 'Sent at', render: (r: any) => fmtDate(r.sent_at) },
  ];

  const totalMoves = moves.length;
  const criticalNow = moves.filter((m: any) => m.threat_level === 'critical').length;
  const highNow = moves.filter((m: any) => m.threat_level === 'high').length;
  const openCounters = counterDue.length;
  const overdue = counterDue.filter((c: any) => c.is_overdue).length;

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
          Founder weekly competitor watch log
        </h1>
        <p style={{ color: '#475569' }}>
          Competitor moves observed × threat level × counter-action × insight category. Logged
          weekly, surfaced any time.
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
          gap: 12,
          marginBottom: 24,
        }}
      >
        {[
          { label: 'Moves (recent)', value: totalMoves },
          { label: 'Critical now', value: criticalNow },
          { label: 'High now', value: highNow },
          { label: 'Open counters', value: openCounters },
          { label: 'Overdue counters', value: overdue },
        ].map((k) => (
          <div
            key={k.label}
            style={{
              border: '1px solid #e2e8f0',
              borderRadius: 10,
              padding: 14,
              background: 'white',
            }}
          >
            <div style={{ fontSize: 12, color: '#64748b' }}>{k.label}</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{k.value}</div>
          </div>
        ))}
      </section>

      {preview && (
        <section
          style={{
            border: '1px solid #c7d2fe',
            background: '#eef2ff',
            borderRadius: 10,
            padding: 16,
            marginBottom: 24,
          }}
        >
          <h2 style={{ fontSize: 16, fontWeight: 700, marginBottom: 6 }}>
            This-week digest preview ({fmtDay(preview.week_start)} =&gt; {fmtDay(preview.week_end)})
          </h2>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))',
              gap: 10,
            }}
          >
            <div>
              <div style={{ fontSize: 12, color: '#475569' }}>Total moves</div>
              <div style={{ fontSize: 20, fontWeight: 700 }}>
                {String(Number(preview.total_moves ?? 0))}
              </div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#475569' }}>Critical</div>
              <div style={{ fontSize: 20, fontWeight: 700 }}>
                {String(Number(preview.critical_threat_count ?? 0))}
              </div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#475569' }}>High</div>
              <div style={{ fontSize: 20, fontWeight: 700 }}>
                {String(Number(preview.high_threat_count ?? 0))}
              </div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#475569' }}>Top competitor</div>
              <div style={{ fontSize: 16, fontWeight: 600 }}>{preview.top_competitor ?? '-'}</div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#475569' }}>Top threat</div>
              <div>{preview.top_threat_level ? threatBadge(preview.top_threat_level) : '-'}</div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#475569' }}>With counter</div>
              <div style={{ fontSize: 20, fontWeight: 700 }}>
                {String(Number(preview.with_counter_count ?? 0))}
              </div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#475569' }}>Counter done</div>
              <div style={{ fontSize: 20, fontWeight: 700 }}>
                {String(Number(preview.done_counter_count ?? 0))}
              </div>
            </div>
          </div>
        </section>
      )}

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>
          Top threats (high & critical)
        </h2>
        <DataTable
          rows={topThreats}
          columns={topThreatCols}
          emptyMessage="No high or critical threats logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>
          Counter-actions due (planned & in-progress)
        </h2>
        <DataTable
          rows={counterDue}
          columns={counterCols}
          emptyMessage="No outstanding counter-actions."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>Threat breakdown</h2>
        <DataTable
          rows={threats}
          columns={threatCols}
          emptyMessage="No moves in window."
          rowKey={(r: any, i: number) => String(r.threat_level ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>By competitor</h2>
        <DataTable
          rows={byComp}
          columns={byCompCols}
          emptyMessage="No competitor activity in window."
          rowKey={(r: any, i: number) => String(r.competitor_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>Recent moves (full log)</h2>
        <DataTable
          rows={moves}
          columns={movesCols}
          emptyMessage="No competitor moves logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>Weekly digest history</h2>
        <DataTable
          rows={digestHist}
          columns={digestCols}
          emptyMessage="No digests sent yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <footer style={{ fontSize: 12, color: '#94a3b8', marginTop: 32 }}>
        r2413 founder weekly competitor watch log =&gt; threat triage &amp; counter-move discipline.
      </footer>
    </main>
  );
}
