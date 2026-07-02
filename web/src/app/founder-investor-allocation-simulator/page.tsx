import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtINR(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  const v = Number(n);
  if (!isFinite(v)) return '-';
  if (Math.abs(v) >= 1e7) return 'Rs ' + (v / 1e7).toFixed(2) + ' Cr';
  if (Math.abs(v) >= 1e5) return 'Rs ' + (v / 1e5).toFixed(2) + ' L';
  return 'Rs ' + v.toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined, d = 2): string {
  if (n === null || n === undefined) return '-';
  const v = Number(n);
  if (!isFinite(v)) return '-';
  return v.toFixed(d);
}

function fmtPct(n: number | null | undefined, d = 1): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(d) + '%';
}

export default async function FounderInvestorAllocationSimulatorPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let scenarios: any[] = [];
  let moic: any[] = [];
  let followons: any[] = [];
  let byType: any[] = [];
  let rounds: any[] = [];
  let activity: any[] = [];

  try {
    const r = await sb.rpc('rpc_founder_investor_alloc_kpis');
    kpis = r.data && r.data[0] ? r.data[0] : null;
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_investor_alloc_scenarios_list');
    scenarios = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_investor_alloc_moic_predictor');
    moic = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_investor_alloc_followon_schedule');
    followons = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_investor_alloc_by_type');
    byType = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_investor_alloc_round_rollup');
    rounds = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_investor_alloc_recent_activity');
    activity = r.data ?? [];
  } catch {}

  const cards: Kpi[] = [
    { label: 'Scenarios', value: String(kpis?.scenarios_total ?? 0) },
    { label: 'Locked', value: String(kpis?.scenarios_locked ?? 0) },
    { label: 'Investors', value: String(kpis?.investors_distinct ?? 0) },
    { label: 'Rounds modeled', value: String(kpis?.rounds_distinct ?? 0) },
    { label: 'Committed total', value: fmtINR(kpis?.total_committed_rupees) },
    { label: 'This round', value: fmtINR(kpis?.total_this_round_rupees) },
    { label: 'Reserved follow-on', value: fmtINR(kpis?.total_reserved_rupees) },
    { label: 'Reserved share', value: fmtPct(kpis?.reserved_share_pct) },
    { label: 'Avg check', value: fmtINR(kpis?.avg_check_rupees) },
    { label: 'Median check', value: fmtINR(kpis?.median_check_rupees) },
    { label: 'Largest check', value: fmtINR(kpis?.largest_check_rupees) },
    { label: 'Smallest check', value: fmtINR(kpis?.smallest_check_rupees) },
    { label: 'Avg MOIC (mid)', value: fmtNum(kpis?.avg_moic_mid) + 'x' },
    { label: 'Best MOIC (mid)', value: fmtNum(kpis?.best_moic_mid) + 'x' },
    { label: 'Worst MOIC (mid)', value: fmtNum(kpis?.worst_moic_mid) + 'x' },
    { label: 'New (7d)', value: String(kpis?.scenarios_created_7d ?? 0) },
  ];

  const scenarioCols: Column<any>[] = [
    { key: 'scenario_name', header: 'Scenario', render: (r: any) => r.scenario_name ?? '-' },
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '-' },
    { key: 'investor_type', header: 'Type', render: (r: any) => r.investor_type ?? '-' },
    { key: 'current_round_label', header: 'Round', render: (r: any) => r.current_round_label ?? '-' },
    { key: 'requested_check_rupees', header: 'Requested', render: (r: any) => fmtINR(r.requested_check_rupees) },
    { key: 'this_round_allocation_rupees', header: 'This round', render: (r: any) => fmtINR(r.this_round_allocation_rupees) },
    { key: 'reserved_followon_rupees', header: 'Reserved', render: (r: any) => fmtINR(r.reserved_followon_rupees) },
    { key: 'followon_rounds_count', header: 'Follow-ons', render: (r: any) => String(r.followon_rounds_count ?? 0) },
    { key: 'is_locked', header: 'Locked', render: (r: any) => (r.is_locked ? 'yes' : 'no') },
  ];

  const moicCols: Column<any>[] = [
    { key: 'scenario_name', header: 'Scenario', render: (r: any) => r.scenario_name ?? '-' },
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '-' },
    { key: 'entry_ownership_pct', header: 'Entry own %', render: (r: any) => fmtPct(r.entry_ownership_pct, 3) },
    { key: 'final_ownership_pct', header: 'Final own %', render: (r: any) => fmtPct(r.final_ownership_pct, 3) },
    { key: 'total_invested_rupees', header: 'Invested', render: (r: any) => fmtINR(r.total_invested_rupees) },
    { key: 'moic_low', header: 'MOIC low', render: (r: any) => fmtNum(r.moic_low) + 'x' },
    { key: 'moic_mid', header: 'MOIC mid', render: (r: any) => fmtNum(r.moic_mid) + 'x' },
    { key: 'moic_high', header: 'MOIC high', render: (r: any) => fmtNum(r.moic_high) + 'x' },
    { key: 'proceeds_mid_rupees', header: 'Proceeds (mid)', render: (r: any) => fmtINR(r.proceeds_mid_rupees) },
  ];

  const followonCols: Column<any>[] = [
    { key: 'scenario_name', header: 'Scenario', render: (r: any) => r.scenario_name ?? '-' },
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '-' },
    { key: 'followon_round_label', header: 'Follow-on round', render: (r: any) => r.followon_round_label ?? '-' },
    { key: 'followon_seq', header: 'Seq', render: (r: any) => String(r.followon_seq ?? 0) },
    { key: 'projected_round_valuation_rupees', header: 'Projected valuation', render: (r: any) => fmtINR(r.projected_round_valuation_rupees) },
    { key: 'projected_check_rupees', header: 'Projected check', render: (r: any) => fmtINR(r.projected_check_rupees) },
    { key: 'pro_rata_pct', header: 'Pro-rata %', render: (r: any) => fmtPct(r.pro_rata_pct) },
    { key: 'participate', header: 'Participate', render: (r: any) => (r.participate ? 'yes' : 'no') },
  ];

  const byTypeCols: Column<any>[] = [
    { key: 'investor_type', header: 'Type', render: (r: any) => r.investor_type ?? '-' },
    { key: 'scenarios_count', header: 'Scenarios', render: (r: any) => String(r.scenarios_count ?? 0) },
    { key: 'total_committed_rupees', header: 'Committed', render: (r: any) => fmtINR(r.total_committed_rupees) },
    { key: 'avg_check_rupees', header: 'Avg check', render: (r: any) => fmtINR(r.avg_check_rupees) },
    { key: 'avg_moic_mid', header: 'Avg MOIC', render: (r: any) => fmtNum(r.avg_moic_mid) + 'x' },
    { key: 'reserved_share_pct', header: 'Reserved share', render: (r: any) => fmtPct(r.reserved_share_pct) },
  ];

  const roundsCols: Column<any>[] = [
    { key: 'current_round_label', header: 'Round', render: (r: any) => r.current_round_label ?? '-' },
    { key: 'investors_count', header: 'Investors', render: (r: any) => String(r.investors_count ?? 0) },
    { key: 'total_this_round_rupees', header: 'This round', render: (r: any) => fmtINR(r.total_this_round_rupees) },
    { key: 'total_reserved_rupees', header: 'Reserved', render: (r: any) => fmtINR(r.total_reserved_rupees) },
    { key: 'total_round_size_rupees', header: 'Round size', render: (r: any) => fmtINR(r.total_round_size_rupees) },
    { key: 'pct_round_filled', header: 'Filled', render: (r: any) => fmtPct(r.pct_round_filled) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Investor allocation simulator</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Per-investor allocation across rounds. Slider: this round vs reserved for follow-ons. MOIC predictor at low/mid/high exit.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0,1fr))', gap: 12, marginBottom: 24 }}>
        {cards.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Scenarios</h2>
        <DataTable columns={scenarioCols} rows={scenarios} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>MOIC predictor</h2>
        <DataTable columns={moicCols} rows={moic} rowKey={(r: any) => r.scenario_id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Follow-on schedule</h2>
        <DataTable columns={followonCols} rows={followons} rowKey={(r: any) => String(r.scenario_id) + ':' + String(r.followon_seq)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By investor type</h2>
        <DataTable columns={byTypeCols} rows={byType} rowKey={(r: any) => r.investor_type} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Round rollup</h2>
        <DataTable columns={roundsCols} rows={rounds} rowKey={(r: any) => r.current_round_label} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent activity</h2>
        <ul style={{ fontSize: 14, color: '#374151' }}>
          {activity.map((a: any, i: number) => (
            <li key={i} style={{ padding: '4px 0' }}>
              {(a.created_at ?? '').slice(0, 19)} - {a.op_name ?? '-'} - {a.actor_email ?? '-'} - {a.scenario_name ?? '-'}
            </li>
          ))}
          {activity.length === 0 ? <li style={{ color: '#9ca3af' }}>No recent activity.</li> : null}
        </ul>
      </section>
    </div>
  );
}
