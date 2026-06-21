import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type LeaderRow = {
  engineer_user_id: string;
  engineer_name: string | null;
  current_tier: string | null;
  jobs_90d: number | null;
  avg_rating: number | null;
  nps_trend: number | null;
  peer_mentions: number | null;
  payouts_90d_rupees: number | null;
  readiness_score: number | null;
  promotion_band: string | null;
};

type NpsRow = {
  tier: string | null;
  engineers_count: number | null;
  avg_rating_30d: number | null;
  avg_rating_90d: number | null;
  delta: number | null;
};

type MentionRow = {
  engineer_user_id: string;
  engineer_name: string | null;
  mentions_count: number | null;
  total_weight: number | null;
  last_mention_at: string | null;
};

type CadenceRow = {
  band: string | null;
  engineers_count: number | null;
  median_jobs_to_promo: number | null;
  avg_rating: number | null;
};

type SnapshotRow = {
  id: string;
  engineer_user_id: string;
  engineer_name: string | null;
  snapshot_date: string | null;
  readiness_score: number | null;
  promotion_band: string | null;
  peer_mention_count: number | null;
  notes: string | null;
};

type SummaryRow = {
  total_engineers: number | null;
  ready_now_count: number | null;
  near_ready_count: number | null;
  developing_count: number | null;
  peer_mentions_30d: number | null;
  avg_readiness: number | null;
};

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toLocaleString('en-IN');
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

function bandLabel(b: string | null | undefined): string {
  if (b === 'ready_now') return 'Ready now';
  if (b === 'near_ready') return 'Near ready';
  if (b === 'developing') return 'Developing';
  return b ?? '—';
}

export default async function FounderEngineerEscapeVelocityPage() {
  const sb = await getSupabaseServerClient();

  const [leaderRes, npsRes, mentionRes, cadenceRes, snapRes, summaryRes] = await Promise.all([
    sb.rpc('founder_fev_readiness_leaderboard', { p_limit: 50 }),
    sb.rpc('founder_fev_nps_trend_by_tier'),
    sb.rpc('founder_fev_peer_mention_top', { p_days: 90 }),
    sb.rpc('founder_fev_tier_climb_cadence'),
    sb.rpc('founder_fev_recent_snapshots', { p_limit: 25 }),
    sb.rpc('founder_fev_summary'),
  ]);

  const leaders: LeaderRow[] = Array.isArray(leaderRes.data) ? (leaderRes.data as LeaderRow[]) : [];
  const nps: NpsRow[] = Array.isArray(npsRes.data) ? (npsRes.data as NpsRow[]) : [];
  const mentions: MentionRow[] = Array.isArray(mentionRes.data) ? (mentionRes.data as MentionRow[]) : [];
  const cadence: CadenceRow[] = Array.isArray(cadenceRes.data) ? (cadenceRes.data as CadenceRow[]) : [];
  const snaps: SnapshotRow[] = Array.isArray(snapRes.data) ? (snapRes.data as SnapshotRow[]) : [];
  const summaryArr: SummaryRow[] = Array.isArray(summaryRes.data) ? (summaryRes.data as SummaryRow[]) : [];
  const summary: SummaryRow | null = summaryArr.length > 0 ? summaryArr[0] : null;

  const errs: string[] = [];
  if (leaderRes.error) errs.push('leaderboard: ' + leaderRes.error.message);
  if (npsRes.error) errs.push('nps: ' + npsRes.error.message);
  if (mentionRes.error) errs.push('mentions: ' + mentionRes.error.message);
  if (cadenceRes.error) errs.push('cadence: ' + cadenceRes.error.message);
  if (snapRes.error) errs.push('snapshots: ' + snapRes.error.message);
  if (summaryRes.error) errs.push('summary: ' + summaryRes.error.message);

  const leaderCols: Column<LeaderRow>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name ?? '—' },
    { key: 'current_tier', header: 'Tier', render: (r) => r.current_tier ?? '—' },
    { key: 'jobs_90d', header: 'Jobs 90d', render: (r) => fmtInt(r.jobs_90d) },
    { key: 'avg_rating', header: 'Avg rating', render: (r) => (r.avg_rating ?? '—').toString() },
    { key: 'nps_trend', header: 'NPS trend', render: (r) => (r.nps_trend ?? '—').toString() },
    { key: 'peer_mentions', header: 'Peer mentions', render: (r) => fmtInt(r.peer_mentions) },
    { key: 'payouts_90d_rupees', header: 'Payouts 90d', render: (r) => fmtRupees(r.payouts_90d_rupees) },
    { key: 'readiness_score', header: 'Readiness', render: (r) => fmtInt(r.readiness_score) },
    { key: 'promotion_band', header: 'Band', render: (r) => bandLabel(r.promotion_band) },
  ];

  const npsCols: Column<NpsRow>[] = [
    { key: 'tier', header: 'Tier', render: (r) => r.tier ?? '—' },
    { key: 'engineers_count', header: 'Engineers', render: (r) => fmtInt(r.engineers_count) },
    { key: 'avg_rating_30d', header: 'Avg 30d', render: (r) => (r.avg_rating_30d ?? '—').toString() },
    { key: 'avg_rating_90d', header: 'Avg 90d', render: (r) => (r.avg_rating_90d ?? '—').toString() },
    { key: 'delta', header: 'Delta', render: (r) => (r.delta ?? '—').toString() },
  ];

  const mentionCols: Column<MentionRow>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name ?? '—' },
    { key: 'mentions_count', header: 'Mentions', render: (r) => fmtInt(r.mentions_count) },
    { key: 'total_weight', header: 'Weight', render: (r) => fmtInt(r.total_weight) },
    { key: 'last_mention_at', header: 'Last mention', render: (r) => fmtDate(r.last_mention_at) },
  ];

  const cadenceCols: Column<CadenceRow>[] = [
    { key: 'band', header: 'Tier', render: (r) => r.band ?? '—' },
    { key: 'engineers_count', header: 'Engineers', render: (r) => fmtInt(r.engineers_count) },
    { key: 'median_jobs_to_promo', header: 'Median jobs', render: (r) => fmtInt(r.median_jobs_to_promo) },
    { key: 'avg_rating', header: 'Avg rating', render: (r) => (r.avg_rating ?? '—').toString() },
  ];

  const snapCols: Column<SnapshotRow>[] = [
    { key: 'snapshot_date', header: 'Date', render: (r) => r.snapshot_date ?? '—' },
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name ?? '—' },
    { key: 'readiness_score', header: 'Score', render: (r) => fmtInt(r.readiness_score) },
    { key: 'promotion_band', header: 'Band', render: (r) => bandLabel(r.promotion_band) },
    { key: 'peer_mention_count', header: 'Mentions', render: (r) => fmtInt(r.peer_mention_count) },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '24px', fontWeight: 700, margin: 0 }}>Engineer Career Escape Velocity</h1>
        <p style={{ color: '#555', marginTop: '4px' }}>
          Per-engineer readiness scores driven by NPS rise, tier climb cadence, peer mentions, and payout velocity.
        </p>
      </header>

      {errs.length > 0 ? (
        <div style={{ background: '#fff3cd', border: '1px solid #f0c34c', padding: '12px', borderRadius: '6px', marginBottom: '16px', fontSize: '13px' }}>
          <strong>Diagnostics:</strong>
          <ul style={{ margin: '8px 0 0 18px' }}>
            {errs.map((e, i) => (
              <li key={i}>{e}</li>
            ))}
          </ul>
        </div>
      ) : null}

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <div style={{ background: '#f7f9fc', padding: '14px', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total engineers</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{fmtInt(summary?.total_engineers ?? null)}</div>
        </div>
        <div style={{ background: '#e8f5ee', padding: '14px', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#1a6b3a' }}>Ready now</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{fmtInt(summary?.ready_now_count ?? null)}</div>
        </div>
        <div style={{ background: '#fff8e6', padding: '14px', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#7a5a00' }}>Near ready</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{fmtInt(summary?.near_ready_count ?? null)}</div>
        </div>
        <div style={{ background: '#f1f1f5', padding: '14px', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#555' }}>Developing</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{fmtInt(summary?.developing_count ?? null)}</div>
        </div>
        <div style={{ background: '#eef4ff', padding: '14px', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#1a3a6b' }}>Peer mentions 30d</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{fmtInt(summary?.peer_mentions_30d ?? null)}</div>
        </div>
        <div style={{ background: '#f7f9fc', padding: '14px', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Avg readiness</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{(summary?.avg_readiness ?? '—').toString()}</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600 }}>Readiness leaderboard</h2>
        <DataTable<LeaderRow>
          rows={leaders}
          columns={leaderCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600 }}>NPS trend by tier</h2>
        <DataTable<NpsRow>
          rows={nps}
          columns={npsCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600 }}>Peer mention top recipients (90d)</h2>
        <DataTable<MentionRow>
          rows={mentions}
          columns={mentionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600 }}>Tier climb cadence</h2>
        <DataTable<CadenceRow>
          rows={cadence}
          columns={cadenceCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600 }}>Recent readiness snapshots</h2>
        <DataTable<SnapshotRow>
          rows={snaps}
          columns={snapCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
