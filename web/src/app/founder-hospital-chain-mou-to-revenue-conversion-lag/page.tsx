import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_chains: number;
  chains_with_revenue: number;
  chains_no_revenue: number;
  chains_churned: number;
  avg_lag_days: number;
  median_lag_days: number;
  p90_lag_days: number;
  total_mou_value_rupees: number;
  total_first_revenue_rupees: number;
};

type ChainRow = {
  id: string;
  chain_name: string;
  hospital_count: number;
  region: string;
  mou_signed_at: string;
  lag_days: number;
  mou_value_rupees: number;
  first_revenue_amount_rupees: number;
  status: string;
};

type DistRow = { bucket: string; chain_count: number; pct_of_revenue_chains: number };
type OutlierRow = { id: string; chain_name: string; region: string; lag_days: number; mou_value_rupees: number; status: string; notes: string };
type RegionRow = { region: string; chain_count: number; avg_lag_days: number; signed_no_revenue: number; total_mou_value_rupees: number };
type StalledRow = { id: string; chain_name: string; region: string; days_since_mou: number; mou_value_rupees: number; notes: string };
type EventRow = { event_id: string; chain_name: string; event_type: string; event_at: string; note: string };

function fmtINR(rupees: number): string {
  if (!rupees) return '₹0';
  if (rupees >= 10000000) return `₹${(rupees / 10000000).toFixed(2)} Cr`;
  if (rupees >= 100000) return `₹${(rupees / 100000).toFixed(2)} L`;
  return `₹${rupees.toLocaleString('en-IN')}`;
}

function statusLabel(s: string): string {
  switch (s) {
    case 'signed_no_revenue': return 'Signed, no revenue';
    case 'first_revenue_received': return 'First revenue received';
    case 'churned_pre_revenue': return 'Churned pre-revenue';
    default: return s;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [{ data: sumRaw }, { data: chainsRaw }, { data: distRaw }, { data: outRaw }, { data: regionRaw }, { data: stalledRaw }, { data: eventsRaw }] = await Promise.all([
    sb.rpc('r2347_lag_summary'),
    sb.rpc('r2347_by_chain'),
    sb.rpc('r2347_distribution'),
    sb.rpc('r2347_outliers'),
    sb.rpc('r2347_by_region'),
    sb.rpc('r2347_stalled'),
    sb.rpc('r2347_recent_events'),
  ]);

  const sum: Summary = (sumRaw?.[0] ?? {
    total_chains: 0, chains_with_revenue: 0, chains_no_revenue: 0, chains_churned: 0,
    avg_lag_days: 0, median_lag_days: 0, p90_lag_days: 0,
    total_mou_value_rupees: 0, total_first_revenue_rupees: 0,
  }) as Summary;
  const chains: ChainRow[] = (chainsRaw ?? []) as ChainRow[];
  const dist: DistRow[] = (distRaw ?? []) as DistRow[];
  const outliers: OutlierRow[] = (outRaw ?? []) as OutlierRow[];
  const regions: RegionRow[] = (regionRaw ?? []) as RegionRow[];
  const stalled: StalledRow[] = (stalledRaw ?? []) as StalledRow[];
  const events: EventRow[] = (eventsRaw ?? []) as EventRow[];

  const chainCols: Column<ChainRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'hospital_count', header: 'Hospitals', render: (r) => r.hospital_count },
    { key: 'mou_signed_at', header: 'MoU signed', render: (r) => new Date(r.mou_signed_at).toLocaleDateString('en-IN') },
    { key: 'lag_days', header: 'Lag (days)', render: (r) => `${r.lag_days}d` },
    { key: 'mou_value_rupees', header: 'MoU value', render: (r) => fmtINR(r.mou_value_rupees) },
    { key: 'first_revenue_amount_rupees', header: 'First revenue', render: (r) => fmtINR(r.first_revenue_amount_rupees) },
    { key: 'status', header: 'Status', render: (r) => statusLabel(r.status) },
  ];

  const distCols: Column<DistRow>[] = [
    { key: 'bucket', header: 'Lag bucket', render: (r) => r.bucket },
    { key: 'chain_count', header: 'Chains', render: (r) => r.chain_count },
    { key: 'pct_of_revenue_chains', header: '% of revenue chains', render: (r) => `${r.pct_of_revenue_chains}%` },
  ];

  const outCols: Column<OutlierRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'lag_days', header: 'Lag (days)', render: (r) => `${r.lag_days}d` },
    { key: 'mou_value_rupees', header: 'MoU value', render: (r) => fmtINR(r.mou_value_rupees) },
    { key: 'status', header: 'Status', render: (r) => statusLabel(r.status) },
    { key: 'notes', header: 'Notes', render: (r) => r.notes },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'chain_count', header: 'Chains', render: (r) => r.chain_count },
    { key: 'avg_lag_days', header: 'Avg lag (days)', render: (r) => `${r.avg_lag_days}d` },
    { key: 'signed_no_revenue', header: 'No revenue yet', render: (r) => r.signed_no_revenue },
    { key: 'total_mou_value_rupees', header: 'Total MoU value', render: (r) => fmtINR(r.total_mou_value_rupees) },
  ];

  const stalledCols: Column<StalledRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'days_since_mou', header: 'Days since MoU', render: (r) => `${r.days_since_mou}d` },
    { key: 'mou_value_rupees', header: 'MoU value', render: (r) => fmtINR(r.mou_value_rupees) },
    { key: 'notes', header: 'Notes', render: (r) => r.notes },
  ];

  const eventCols: Column<EventRow>[] = [
    { key: 'event_at', header: 'When', render: (r) => new Date(r.event_at).toLocaleString('en-IN') },
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'event_type', header: 'Event', render: (r) => r.event_type.replace(/_/g, ' ') },
    { key: 'note', header: 'Note', render: (r) => r.note },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Hospital Chain MoU-to-Revenue Conversion Lag</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Time from MoU signed to first revenue, by chain. Distribution &amp; outliers flagged.
        Target: first revenue &lt;= 60 days post-MoU. Chains stalled &gt;= 90 days surface for escalation.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 14, marginBottom: 28 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>Total chains</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{sum.total_chains}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>With first revenue</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{sum.chains_with_revenue}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #fde68a', borderRadius: 8, background: '#fffbeb' }}>
          <div style={{ fontSize: 12, color: '#92400e', marginBottom: 4 }}>Signed, no revenue</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#92400e' }}>{sum.chains_no_revenue}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #fecaca', borderRadius: 8, background: '#fef2f2' }}>
          <div style={{ fontSize: 12, color: '#991b1b', marginBottom: 4 }}>Churned pre-revenue</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#991b1b' }}>{sum.chains_churned}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>Avg lag</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{sum.avg_lag_days}d</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>Median lag</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{sum.median_lag_days}d</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>P90 lag</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{sum.p90_lag_days}d</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>Total MoU value</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtINR(sum.total_mou_value_rupees)}</div>
        </div>
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Lag distribution (chains with revenue)</h2>
        <DataTable columns={distCols} rows={dist} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>By chain (sorted longest lag first)</h2>
        <DataTable columns={chainCols} rows={chains} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Outliers (&gt;= 120d converted or &gt;= 60d stalled)</h2>
        <DataTable columns={outCols} rows={outliers} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>By region</h2>
        <DataTable columns={regionCols} rows={regions} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Stalled — signed but no revenue yet</h2>
        <DataTable columns={stalledCols} rows={stalled} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Recent onboarding events</h2>
        <DataTable columns={eventCols} rows={events} rowKey={(r) => r.event_id} />
      </section>
    </div>
  );
}
