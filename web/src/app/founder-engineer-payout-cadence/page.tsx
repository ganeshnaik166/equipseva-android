import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string | number };

export const dynamic = 'force-dynamic';

export default async function FounderEngineerPayoutCadencePage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let roster: any[] = [];
  let mismatches: any[] = [];
  let recent: any[] = [];

  try {
    const r = await sb.rpc('founder_payout_cadence_kpis');
    kpis = Array.isArray(r.data) ? r.data[0] : r.data;
  } catch {
    kpis = null;
  }
  try {
    const r = await sb.rpc('founder_payout_cadence_roster');
    roster = (r.data as any[]) ?? [];
  } catch {
    roster = [];
  }
  try {
    const r = await sb.rpc('founder_payout_cadence_mismatches');
    mismatches = (r.data as any[]) ?? [];
  } catch {
    mismatches = [];
  }
  try {
    const r = await sb.rpc('founder_payout_cadence_recent_snapshots');
    recent = (r.data as any[]) ?? [];
  } catch {
    recent = [];
  }

  const k = kpis ?? {};
  const cards: Kpi[] = [
    { label: 'Total engineers', value: k.total_engineers ?? 0 },
    { label: 'With preference', value: k.with_preference ?? 0 },
    { label: 'Weekly', value: k.weekly_count ?? 0 },
    { label: 'Biweekly', value: k.biweekly_count ?? 0 },
    { label: 'Monthly', value: k.monthly_count ?? 0 },
    { label: 'On-demand', value: k.on_demand_count ?? 0 },
    { label: 'Pending payouts', value: k.total_pending_payouts ?? 0 },
    { label: 'Pending Rs', value: k.total_pending_rupees ?? 0 },
    { label: 'Paid 90d Rs', value: k.total_paid_90d_rupees ?? 0 },
    { label: 'Median gap days', value: k.median_gap_days ?? '—' },
    { label: 'Avg match score', value: k.avg_match_score ?? '—' },
    { label: 'Engineers overdue', value: k.engineers_overdue ?? 0 },
    { label: 'Below min payout', value: k.engineers_below_min ?? 0 },
    { label: 'Snapshots total', value: k.snapshots_total ?? 0 },
    { label: 'Snapshots 7d', value: k.snapshots_last_7d ?? 0 },
    { label: 'Avg min payout Rs', value: k.avg_min_payout_rupees ?? '—' },
  ];

  const rosterCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'preferred_cadence', header: 'Preferred', render: (r: any) => r.preferred_cadence ?? 'unset' },
    { key: 'min_payout_rupees', header: 'Min Rs', render: (r: any) => r.min_payout_rupees ?? 0 },
    { key: 'pending_count', header: 'Pending #', render: (r: any) => r.pending_count ?? 0 },
    { key: 'pending_rupees', header: 'Pending Rs', render: (r: any) => r.pending_rupees ?? 0 },
    { key: 'days_since_last', header: 'Days since last', render: (r: any) => (r.days_since_last != null ? Number(r.days_since_last).toFixed(1) : '—') },
    { key: 'cached_tier', header: 'Tier', render: (r: any) => r.cached_tier ?? 'none' },
  ];

  const mismatchCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'preferred_cadence', header: 'Preferred', render: (r: any) => r.preferred_cadence ?? '—' },
    { key: 'observed_cadence', header: 'Observed', render: (r: any) => r.observed_cadence ?? '—' },
    { key: 'median_gap_days', header: 'Median gap days', render: (r: any) => (r.median_gap_days != null ? Number(r.median_gap_days).toFixed(1) : '—') },
    { key: 'match_score', header: 'Score', render: (r: any) => r.match_score ?? '—' },
    { key: 'snapshot_at', header: 'At', render: (r: any) => (r.snapshot_at ? new Date(r.snapshot_at).toLocaleString() : '—') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'snapshot_at', header: 'At', render: (r: any) => (r.snapshot_at ? new Date(r.snapshot_at).toLocaleString() : '—') },
    { key: 'observed_cadence', header: 'Observed', render: (r: any) => r.observed_cadence ?? '—' },
    { key: 'median_gap_days', header: 'Median gap', render: (r: any) => (r.median_gap_days != null ? Number(r.median_gap_days).toFixed(1) : '—') },
    { key: 'avg_balance_rupees', header: 'Avg balance Rs', render: (r: any) => r.avg_balance_rupees ?? 0 },
    { key: 'payouts_last_90d', header: 'Payouts 90d', render: (r: any) => r.payouts_last_90d ?? 0 },
    { key: 'match_score', header: 'Score', render: (r: any) => r.match_score ?? '—' },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Engineer Payout Cadence Optimizer</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>r1533 — Preferred payout cadence per engineer vs observed gap behavior.</p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0,1fr))', gap: 12, marginBottom: 24 }}>
        {cards.map((c) => (
          <div key={c.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase' }}>{c.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{String(c.value ?? '—')}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer roster ({roster.length})</h2>
        <DataTable columns={rosterCols} rows={roster} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Cadence mismatches ({mismatches.length})</h2>
        <DataTable columns={mismatchCols} rows={mismatches} rowKey={(r: any) => r.engineer_id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent snapshots ({recent.length})</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
