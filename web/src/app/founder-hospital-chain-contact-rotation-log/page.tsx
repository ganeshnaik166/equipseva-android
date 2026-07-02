import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [overviewRes, openRes, tierRes, sourceRes, playRes, recentRes] = await Promise.all([
    sb.rpc('fn_hcc_rotation_overview_r2295'),
    sb.rpc('fn_hcc_rotation_open_r2295'),
    sb.rpc('fn_hcc_rotation_by_tier_r2295'),
    sb.rpc('fn_hcc_rotation_source_mix_r2295'),
    sb.rpc('fn_hcc_play_effectiveness_r2295'),
    sb.rpc('fn_hcc_rotation_recent_r2295'),
  ]);

  const overview = (overviewRes.data ?? [])[0] ?? {
    open_rotations: 0,
    bridges_secured: 0,
    bridges_lost: 0,
    arr_at_risk_total_rupees: 0,
    arr_secured_rupees: 0,
    bridge_success_pct: 0,
    avg_days_to_bridge: 0,
    strategic_chains_open: 0,
  };

  const openRows = openRes.data ?? [];
  const tierRows = tierRes.data ?? [];
  const sourceRows = sourceRes.data ?? [];
  const playRows = playRes.data ?? [];
  const recentRows = recentRes.data ?? [];

  const fmtCr = (n: number) => `Rs ${(Number(n || 0) / 1e7).toFixed(2)} Cr`;
  const fmtL = (n: number) => `Rs ${(Number(n || 0) / 1e5).toFixed(1)} L`;

  const openCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'chain_tier', header: 'Tier', render: (r) => r.chain_tier },
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'former_contact', header: 'Departed', render: (r) => r.former_contact },
    { key: 'new_contact', header: 'Incoming', render: (r) => r.new_contact },
    { key: 'arr', header: 'ARR at risk', render: (r) => fmtL(r.arr_at_risk_rupees) },
    { key: 'status', header: 'Bridge', render: (r) => r.bridge_status },
    { key: 'days', header: 'Days open', render: (r) => r.days_open },
  ];

  const tierCols: Column<any>[] = [
    { key: 'tier', header: 'Tier', render: (r) => r.chain_tier },
    { key: 'rot', header: 'Rotations', render: (r) => r.rotations },
    { key: 'sec', header: 'Secured', render: (r) => r.bridges_secured },
    { key: 'lost', header: 'Lost', render: (r) => r.bridges_lost },
    { key: 'pct', header: 'Success %', render: (r) => `${r.success_pct}%` },
    { key: 'arr', header: 'ARR at risk', render: (r) => fmtL(r.arr_at_risk_rupees) },
  ];

  const sourceCols: Column<any>[] = [
    { key: 'src', header: 'Source', render: (r) => r.rotation_source },
    { key: 'rot', header: 'Rotations', render: (r) => r.rotations },
    { key: 'sec', header: 'Secured', render: (r) => r.bridges_secured },
    { key: 'pct', header: 'Success %', render: (r) => `${r.success_pct}%` },
  ];

  const playCols: Column<any>[] = [
    { key: 'type', header: 'Play', render: (r) => r.play_type },
    { key: 'run', header: 'Run', render: (r) => r.plays_run },
    { key: 'resp', header: 'Responded', render: (r) => r.plays_responded },
    { key: 'rate', header: 'Response %', render: (r) => `${r.response_rate_pct}%` },
    { key: 'score', header: 'Avg outcome', render: (r) => r.avg_outcome_score },
  ];

  const recentCols: Column<any>[] = [
    { key: 'chain', header: 'Chain', render: (r) => r.chain_name },
    { key: 'tier', header: 'Tier', render: (r) => r.chain_tier },
    { key: 'detected', header: 'Detected', render: (r) => new Date(r.rotation_detected_at).toLocaleDateString() },
    { key: 'src', header: 'Source', render: (r) => r.rotation_source },
    { key: 'status', header: 'Status', render: (r) => r.bridge_status },
    { key: 'arr', header: 'ARR at risk', render: (r) => fmtL(r.arr_at_risk_rupees) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Key-Contact Rotation Log</h1>
        <p className="text-sm text-gray-600 mt-1">
          When chain CXOs & key contacts rotate, our re-engagement plan, success keeping the bridge.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Open rotations</div>
          <div className="text-2xl font-bold">{overview.open_rotations}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Bridges secured</div>
          <div className="text-2xl font-bold text-green-700">{overview.bridges_secured}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Bridges lost</div>
          <div className="text-2xl font-bold text-red-700">{overview.bridges_lost}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Bridge success</div>
          <div className="text-2xl font-bold">{overview.bridge_success_pct}%</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">ARR at risk (open)</div>
          <div className="text-xl font-bold">{fmtCr(overview.arr_at_risk_total_rupees)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">ARR secured</div>
          <div className="text-xl font-bold text-green-700">{fmtCr(overview.arr_secured_rupees)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Avg days to bridge</div>
          <div className="text-2xl font-bold">{overview.avg_days_to_bridge}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Strategic open</div>
          <div className="text-2xl font-bold text-amber-700">{overview.strategic_chains_open}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open rotations (top 100 by ARR)</h2>
        <DataTable columns={openCols} rows={openRows} rowKey={(r) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By chain tier</h2>
        <DataTable columns={tierCols} rows={tierRows} rowKey={(r) => r.chain_tier} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Rotation source mix</h2>
        <DataTable columns={sourceCols} rows={sourceRows} rowKey={(r) => r.rotation_source} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Re-engagement play effectiveness</h2>
        <DataTable columns={playCols} rows={playRows} rowKey={(r) => r.play_type} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent rotations (25)</h2>
        <DataTable columns={recentCols} rows={recentRows} rowKey={(r) => r.id} />
      </section>
    </div>
  );
}
