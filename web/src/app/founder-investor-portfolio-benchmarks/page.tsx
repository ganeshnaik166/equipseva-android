import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  if (n >= 10000000) return `₹${(n/10000000).toFixed(2)} Cr`;
  if (n >= 100000) return `₹${(n/100000).toFixed(2)} L`;
  return `₹${n.toLocaleString('en-IN')}`;
}

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return n.toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  const sign = n >= 0 ? '+' : '';
  return `${sign}${n.toFixed(1)}%`;
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let roster: any[] = [];
  let latest: any[] = [];
  let trajectory: any[] = [];
  let stages: any[] = [];
  let gaps: any[] = [];
  let history: any[] = [];
  let efficiency: any[] = [];

  try {
    const r = await sb.rpc('founder_peer_roster');
    roster = (r.data as any[]) ?? [];
  } catch { roster = []; }
  try {
    const r = await sb.rpc('founder_peer_latest_snapshots');
    latest = (r.data as any[]) ?? [];
  } catch { latest = []; }
  try {
    const r = await sb.rpc('founder_our_trajectory');
    trajectory = (r.data as any[]) ?? [];
  } catch { trajectory = []; }
  try {
    const r = await sb.rpc('founder_peer_stage_distribution');
    stages = (r.data as any[]) ?? [];
  } catch { stages = []; }
  try {
    const r = await sb.rpc('founder_peer_benchmark_gaps');
    gaps = (r.data as any[]) ?? [];
  } catch { gaps = []; }
  try {
    const r = await sb.rpc('founder_peer_snapshot_history', { p_limit: 50 });
    history = (r.data as any[]) ?? [];
  } catch { history = []; }
  try {
    const r = await sb.rpc('founder_peer_capital_efficiency');
    efficiency = (r.data as any[]) ?? [];
  } catch { efficiency = []; }

  const trajMap: Record<string, any> = {};
  for (const t of trajectory) trajMap[t.metric] = t;

  const ourGmv = trajMap['gmv_30d']?.value_rupees ?? 0;
  const ourMrr = trajMap['mrr_active_amc']?.value_rupees ?? 0;
  const ourHosp = trajMap['hospital_count']?.value_count ?? 0;
  const ourEng = trajMap['engineer_count']?.value_count ?? 0;
  const ourAmc = trajMap['active_amc_count']?.value_count ?? 0;

  const trackedPeers = roster.filter((p: any) => p.is_tracked).length;
  const totalPeers = roster.length;
  const totalSnaps = roster.reduce((s: number, p: any) => s + Number(p.snapshot_count ?? 0), 0);

  const gapGmv = gaps.find((g: any) => g.metric === 'gmv_30d');
  const gapHosp = gaps.find((g: any) => g.metric === 'hospital_count');
  const gapEng = gaps.find((g: any) => g.metric === 'engineer_count');

  const peerMedianRaise = stages.reduce((s: number, x: any) => s + Number(x.total_raised_rupees ?? 0), 0);
  const topStage = stages[0]?.fundraise_stage ?? '—';
  const effLeader = efficiency[0]?.peer_name ?? '—';
  const effLeaderRatio = efficiency[0]?.gmv_per_rupee_raised ?? null;

  const kpis: Kpi[] = [
    { label: 'Peers tracked', value: `${trackedPeers}/${totalPeers}` },
    { label: 'Snapshots captured', value: fmtNum(totalSnaps) },
    { label: 'Our GMV 30d', value: fmtRupees(ourGmv) },
    { label: 'Our MRR (active AMC)', value: fmtRupees(ourMrr) },
    { label: 'Our hospitals', value: fmtNum(ourHosp) },
    { label: 'Our engineers', value: fmtNum(ourEng) },
    { label: 'Our active AMC', value: fmtNum(ourAmc) },
    { label: 'Peer GMV median', value: fmtRupees(gapGmv?.peer_median) },
    { label: 'Peer GMV p75', value: fmtRupees(gapGmv?.peer_p75) },
    { label: 'GMV gap to median', value: fmtPct(gapGmv?.gap_to_median_pct) },
    { label: 'Hospital gap to median', value: fmtPct(gapHosp?.gap_to_median_pct) },
    { label: 'Engineer gap to median', value: fmtPct(gapEng?.gap_to_median_pct) },
    { label: 'Total peer raises', value: fmtRupees(peerMedianRaise) },
    { label: 'Modal stage', value: topStage },
    { label: 'Capital-efficient leader', value: effLeader },
    { label: 'Leader GMV per ₹ raised', value: effLeaderRatio !== null && effLeaderRatio !== undefined ? Number(effLeaderRatio).toFixed(3) : '—' },
  ];

  const rosterCols: Column<any>[] = [
    { key: 'peer_name', header: 'Peer', render: (r: any) => r.peer_name ?? '—' },
    { key: 'peer_country', header: 'Country', render: (r: any) => r.peer_country ?? '—' },
    { key: 'peer_segment', header: 'Segment', render: (r: any) => r.peer_segment ?? '—' },
    { key: 'founded_year', header: 'Founded', render: (r: any) => r.founded_year ?? '—' },
    { key: 'hq_city', header: 'HQ', render: (r: any) => r.hq_city ?? '—' },
    { key: 'is_tracked', header: 'Tracked', render: (r: any) => (r.is_tracked ? 'yes' : 'no') },
    { key: 'snapshot_count', header: 'Snapshots', render: (r: any) => fmtNum(Number(r.snapshot_count ?? 0)) },
    { key: 'latest_snapshot_at', header: 'Latest', render: (r: any) => r.latest_snapshot_at ? new Date(r.latest_snapshot_at).toLocaleDateString() : '—' },
  ];

  const latestCols: Column<any>[] = [
    { key: 'peer_name', header: 'Peer', render: (r: any) => r.peer_name ?? '—' },
    { key: 'snapshot_at', header: 'As of', render: (r: any) => r.snapshot_at ? new Date(r.snapshot_at).toLocaleDateString() : '—' },
    { key: 'gmv_rupees', header: 'GMV', render: (r: any) => fmtRupees(r.gmv_rupees) },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => fmtNum(r.hospital_count) },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => fmtNum(r.engineer_count) },
    { key: 'monthly_revenue_rupees', header: 'MRR', render: (r: any) => fmtRupees(r.monthly_revenue_rupees) },
    { key: 'fundraise_stage', header: 'Stage', render: (r: any) => r.fundraise_stage ?? '—' },
    { key: 'total_raised_rupees', header: 'Raised', render: (r: any) => fmtRupees(r.total_raised_rupees) },
    { key: 'valuation_rupees', header: 'Valuation', render: (r: any) => fmtRupees(r.valuation_rupees) },
    { key: 'confidence', header: 'Conf', render: (r: any) => r.confidence ?? '—' },
  ];

  const gapsCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r: any) => r.metric ?? '—' },
    { key: 'our_value', header: 'Us', render: (r: any) => (r.metric === 'gmv_30d') ? fmtRupees(r.our_value) : fmtNum(r.our_value) },
    { key: 'peer_median', header: 'Peer median', render: (r: any) => (r.metric === 'gmv_30d') ? fmtRupees(r.peer_median) : fmtNum(r.peer_median) },
    { key: 'peer_p75', header: 'Peer p75', render: (r: any) => (r.metric === 'gmv_30d') ? fmtRupees(r.peer_p75) : fmtNum(r.peer_p75) },
    { key: 'peer_max', header: 'Peer max', render: (r: any) => (r.metric === 'gmv_30d') ? fmtRupees(r.peer_max) : fmtNum(r.peer_max) },
    { key: 'gap_to_median_pct', header: 'Gap', render: (r: any) => fmtPct(r.gap_to_median_pct) },
  ];

  const efficiencyCols: Column<any>[] = [
    { key: 'peer_name', header: 'Peer', render: (r: any) => r.peer_name ?? '—' },
    { key: 'total_raised_rupees', header: 'Raised', render: (r: any) => fmtRupees(r.total_raised_rupees) },
    { key: 'gmv_rupees', header: 'GMV', render: (r: any) => fmtRupees(r.gmv_rupees) },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => fmtNum(r.hospital_count) },
    { key: 'rupees_per_hospital', header: '₹ per hospital', render: (r: any) => fmtRupees(r.rupees_per_hospital) },
    { key: 'gmv_per_rupee_raised', header: 'GMV per ₹ raised', render: (r: any) => r.gmv_per_rupee_raised !== null && r.gmv_per_rupee_raised !== undefined ? Number(r.gmv_per_rupee_raised).toFixed(3) : '—' },
  ];

  const historyCols: Column<any>[] = [
    { key: 'snapshot_at', header: 'As of', render: (r: any) => r.snapshot_at ? new Date(r.snapshot_at).toLocaleDateString() : '—' },
    { key: 'peer_name', header: 'Peer', render: (r: any) => r.peer_name ?? '—' },
    { key: 'gmv_rupees', header: 'GMV', render: (r: any) => fmtRupees(r.gmv_rupees) },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => fmtNum(r.hospital_count) },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => fmtNum(r.engineer_count) },
    { key: 'fundraise_stage', header: 'Stage', render: (r: any) => r.fundraise_stage ?? '—' },
    { key: 'total_raised_rupees', header: 'Raised', render: (r: any) => fmtRupees(r.total_raised_rupees) },
    { key: 'source_type', header: 'Source', render: (r: any) => r.source_type ?? '—' },
    { key: 'confidence', header: 'Conf', render: (r: any) => r.confidence ?? '—' },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Investor portfolio benchmarks</h1>
        <p className="text-sm text-gray-500">Peer biomedical AMC startup metrics — GMV, hospital count, engineer count, fundraise stage. Benchmark our trajectory.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpis.map((k: Kpi) => (
          <div key={k.label} className="rounded-lg border p-3">
            <div className="text-xs uppercase text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold mt-1">{k.value}</div>
          </div>
        ))}
      </div>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Benchmark gaps (us vs peer median)</h2>
        <p className="text-xs text-gray-500">Positive gap means we are above median; negative means we trail.</p>
        <DataTable
          rows={gaps}
          columns={gapsCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Peer roster</h2>
        <DataTable
          rows={roster}
          columns={rosterCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Latest peer snapshots</h2>
        <DataTable
          rows={latest}
          columns={latestCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Capital efficiency leaderboard</h2>
        <p className="text-xs text-gray-500">GMV per ₹ raised — higher {">"} more capital efficient.</p>
        <DataTable
          rows={efficiency}
          columns={efficiencyCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Snapshot history (recent 50)</h2>
        <DataTable
          rows={history}
          columns={historyCols}
          rowKey={(r: any) => r.id}
        />
      </section>
    </div>
  );
}
