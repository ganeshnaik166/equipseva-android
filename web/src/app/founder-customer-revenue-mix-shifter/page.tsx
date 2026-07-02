import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_snapshots: number;
  total_customers: number;
  total_quarters: number;
  latest_quarter: string | null;
  total_revenue_tracked_rupees: number;
  avg_amc_share_pct: number;
  avg_repair_share_pct: number;
  avg_parts_share_pct: number;
  avg_install_share_pct: number;
};

type QuarterRow = {
  quarter_label: string;
  customers: number;
  total_revenue_rupees: number;
  amc_share_pct: number;
  repair_share_pct: number;
  parts_share_pct: number;
  install_share_pct: number;
};

type TopCustomerRow = {
  customer_name: string;
  customer_org_id: string;
  quarters_tracked: number;
  total_revenue_rupees: number;
  avg_amc_share_pct: number;
  avg_repair_share_pct: number;
  avg_parts_share_pct: number;
  avg_install_share_pct: number;
  dominant_stream_latest: string;
};

type SignalRow = {
  customer_name: string;
  from_quarter: string;
  to_quarter: string;
  shift_type: string;
  delta_pct: number;
  severity: string;
  strategic_implication: string;
  recommended_action: string;
  acknowledged: boolean;
  created_at: string;
};

type SignalCounts = {
  total_signals: number;
  act_now_count: number;
  watch_count: number;
  info_count: number;
  acknowledged_count: number;
  pending_count: number;
};

type DominantRow = {
  dominant_stream: string;
  snapshots: number;
  customers: number;
  revenue_rupees: number;
  share_of_total_pct: number;
};

function fmtRupees(n: number): string {
  if (!n) return '₹0';
  if (n >= 10000000) return '₹' + (n / 10000000).toFixed(2) + ' Cr';
  if (n >= 100000) return '₹' + (n / 100000).toFixed(2) + ' L';
  return '₹' + n.toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, quartersRes, topRes, signalsRes, signalCountsRes, dominantRes] = await Promise.all([
    sb.rpc('founder_revmix_snapshot_summary_r2268'),
    sb.rpc('founder_revmix_by_quarter_r2268'),
    sb.rpc('founder_revmix_top_customers_r2268'),
    sb.rpc('founder_revmix_shift_signals_r2268'),
    sb.rpc('founder_revmix_signal_counts_r2268'),
    sb.rpc('founder_revmix_dominant_distribution_r2268'),
  ]);

  const summary: Summary | null = (summaryRes.data?.[0] as Summary) ?? null;
  const quarters: QuarterRow[] = (quartersRes.data as QuarterRow[]) ?? [];
  const topCustomers: TopCustomerRow[] = (topRes.data as TopCustomerRow[]) ?? [];
  const signals: SignalRow[] = (signalsRes.data as SignalRow[]) ?? [];
  const signalCounts: SignalCounts | null = (signalCountsRes.data?.[0] as SignalCounts) ?? null;
  const dominant: DominantRow[] = (dominantRes.data as DominantRow[]) ?? [];

  const quarterCols: Column<QuarterRow>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r) => r.quarter_label },
    { key: 'customers', header: 'Customers', render: (r) => r.customers },
    { key: 'total_revenue_rupees', header: 'Total Revenue', render: (r) => fmtRupees(r.total_revenue_rupees) },
    { key: 'amc_share_pct', header: 'AMC %', render: (r) => r.amc_share_pct + '%' },
    { key: 'repair_share_pct', header: 'Repair %', render: (r) => r.repair_share_pct + '%' },
    { key: 'parts_share_pct', header: 'Parts %', render: (r) => r.parts_share_pct + '%' },
    { key: 'install_share_pct', header: 'Install %', render: (r) => r.install_share_pct + '%' },
  ];

  const topCols: Column<TopCustomerRow>[] = [
    { key: 'customer_name', header: 'Customer', render: (r) => r.customer_name },
    { key: 'quarters_tracked', header: 'Qtrs', render: (r) => r.quarters_tracked },
    { key: 'total_revenue_rupees', header: 'Total Revenue', render: (r) => fmtRupees(r.total_revenue_rupees) },
    { key: 'avg_amc_share_pct', header: 'AMC %', render: (r) => r.avg_amc_share_pct + '%' },
    { key: 'avg_repair_share_pct', header: 'Repair %', render: (r) => r.avg_repair_share_pct + '%' },
    { key: 'avg_parts_share_pct', header: 'Parts %', render: (r) => r.avg_parts_share_pct + '%' },
    { key: 'avg_install_share_pct', header: 'Install %', render: (r) => r.avg_install_share_pct + '%' },
    { key: 'dominant_stream_latest', header: 'Dominant (latest)', render: (r) => r.dominant_stream_latest ?? '—' },
  ];

  const signalCols: Column<SignalRow>[] = [
    { key: 'customer_name', header: 'Customer', render: (r) => r.customer_name },
    { key: 'from_quarter', header: 'From', render: (r) => r.from_quarter },
    { key: 'to_quarter', header: 'To', render: (r) => r.to_quarter },
    { key: 'shift_type', header: 'Shift Type', render: (r) => r.shift_type },
    { key: 'delta_pct', header: 'Delta %', render: (r) => r.delta_pct + '%' },
    { key: 'severity', header: 'Severity', render: (r) => (
      <span style={{
        padding: '2px 8px', borderRadius: 4, fontSize: 11, fontWeight: 600,
        background: r.severity === 'act_now' ? '#fee2e2' : r.severity === 'watch' ? '#fef3c7' : '#e0f2fe',
        color: r.severity === 'act_now' ? '#991b1b' : r.severity === 'watch' ? '#92400e' : '#075985',
      }}>{r.severity}</span>
    )},
    { key: 'strategic_implication', header: 'Strategic Implication', render: (r) => r.strategic_implication },
    { key: 'recommended_action', header: 'Recommended Action', render: (r) => r.recommended_action },
    { key: 'acknowledged', header: 'Ack', render: (r) => (r.acknowledged ? 'yes' : 'pending') },
  ];

  const dominantCols: Column<DominantRow>[] = [
    { key: 'dominant_stream', header: 'Dominant Stream', render: (r) => r.dominant_stream },
    { key: 'snapshots', header: 'Snapshots', render: (r) => r.snapshots },
    { key: 'customers', header: 'Customers', render: (r) => r.customers },
    { key: 'revenue_rupees', header: 'Revenue', render: (r) => fmtRupees(r.revenue_rupees) },
    { key: 'share_of_total_pct', header: 'Share of Total', render: (r) => r.share_of_total_pct + '%' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'ui-sans-serif, system-ui' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Customer Revenue Mix Shifter</h1>
        <p style={{ color: '#64748b', fontSize: 14 }}>
          How AMC, Repair, Parts & Install shares shift each quarter per customer — strategic resource allocation lens.
        </p>
      </header>

      {summary && (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 24 }}>
          <Stat label="Snapshots" value={String(summary.total_snapshots)} />
          <Stat label="Customers" value={String(summary.total_customers)} />
          <Stat label="Quarters" value={String(summary.total_quarters)} />
          <Stat label="Latest Quarter" value={summary.latest_quarter ?? '—'} />
          <Stat label="Revenue Tracked" value={fmtRupees(summary.total_revenue_tracked_rupees)} />
          <Stat label="Avg AMC %" value={summary.avg_amc_share_pct + '%'} />
          <Stat label="Avg Repair %" value={summary.avg_repair_share_pct + '%'} />
          <Stat label="Avg Parts %" value={summary.avg_parts_share_pct + '%'} />
          <Stat label="Avg Install %" value={summary.avg_install_share_pct + '%'} />
        </section>
      )}

      {signalCounts && (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 12, marginBottom: 24 }}>
          <Stat label="Total Signals" value={String(signalCounts.total_signals)} />
          <Stat label="Act Now" value={String(signalCounts.act_now_count)} tone="danger" />
          <Stat label="Watch" value={String(signalCounts.watch_count)} tone="warn" />
          <Stat label="Info" value={String(signalCounts.info_count)} />
          <Stat label="Acknowledged" value={String(signalCounts.acknowledged_count)} />
          <Stat label="Pending" value={String(signalCounts.pending_count)} />
        </section>
      )}

      <Section title="Revenue Mix by Quarter">
        <DataTable columns={quarterCols} rows={quarters} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Dominant Stream Distribution">
        <DataTable columns={dominantCols} rows={dominant} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Top Customers by Revenue Tracked">
        <DataTable columns={topCols} rows={topCustomers} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Shift Signals (act-now first)">
        <DataTable columns={signalCols} rows={signals} rowKey={(_, i) => String(i)} />
      </Section>
    </main>
  );
}

function Stat({ label, value, tone }: { label: string; value: string; tone?: 'danger' | 'warn' }) {
  const bg = tone === 'danger' ? '#fee2e2' : tone === 'warn' ? '#fef3c7' : '#f8fafc';
  const color = tone === 'danger' ? '#991b1b' : tone === 'warn' ? '#92400e' : '#0f172a';
  return (
    <div style={{ background: bg, padding: 12, borderRadius: 8, border: '1px solid #e2e8f0' }}>
      <div style={{ fontSize: 11, color: '#64748b', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 600, color, marginTop: 2 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>{title}</h2>
      <div style={{ background: 'white', border: '1px solid #e2e8f0', borderRadius: 8, overflowX: 'auto' }}>
        {children}
      </div>
    </section>
  );
}
