import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };
type KpiRow = {
  kpi_key: string;
  kpi_label: string;
  kpi_value: number | null;
  kpi_text: string | null;
  status_color: string | null;
};
type DrillCard = {
  id: string;
  domain: string;
  title: string;
  headline_value: number | null;
  headline_label: string;
  drill_route: string;
  status_color: string | null;
};
type SnapshotRow = {
  id: string;
  snapshot_date: string;
  domain: string;
  kpi_key: string;
  kpi_label: string;
  kpi_value: number | null;
  status_color: string | null;
  computed_at: string;
};
type PinRow = {
  id: string;
  domain: string;
  kpi_key: string;
  display_order: number;
  note: string | null;
  pinned_at: string;
};

function fmtNum(v: number | null | undefined): string {
  if (v === null || v === undefined) return '—';
  if (Math.abs(v) >= 100000) return v.toLocaleString('en-IN');
  return String(v);
}

export default async function FounderExecutive360V3Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let engineering: KpiRow[] = [];
  let revenue: KpiRow[] = [];
  let capital: KpiRow[] = [];
  let ops: KpiRow[] = [];
  let compliance: KpiRow[] = [];
  let growth: KpiRow[] = [];
  let drillCards: DrillCard[] = [];
  let snapshots: SnapshotRow[] = [];
  let pins: PinRow[] = [];

  try {
    const { data } = await sb.rpc('exec_360_v3_engineering_kpis');
    engineering = (data as KpiRow[]) ?? [];
  } catch {}
  try {
    const { data } = await sb.rpc('exec_360_v3_revenue_kpis');
    revenue = (data as KpiRow[]) ?? [];
  } catch {}
  try {
    const { data } = await sb.rpc('exec_360_v3_capital_kpis');
    capital = (data as KpiRow[]) ?? [];
  } catch {}
  try {
    const { data } = await sb.rpc('exec_360_v3_ops_kpis');
    ops = (data as KpiRow[]) ?? [];
  } catch {}
  try {
    const { data } = await sb.rpc('exec_360_v3_compliance_kpis');
    compliance = (data as KpiRow[]) ?? [];
  } catch {}
  try {
    const { data } = await sb.rpc('exec_360_v3_growth_kpis');
    growth = (data as KpiRow[]) ?? [];
  } catch {}
  try {
    const { data } = await sb.rpc('exec_360_v3_drill_cards');
    drillCards = (data as DrillCard[]) ?? [];
  } catch {}
  try {
    const { data } = await sb
      .from('founder_exec_360_snapshots_v3')
      .select('id, snapshot_date, domain, kpi_key, kpi_label, kpi_value, status_color, computed_at')
      .order('snapshot_date', { ascending: false })
      .order('domain', { ascending: true })
      .limit(48);
    snapshots = (data as SnapshotRow[]) ?? [];
  } catch {}
  try {
    const { data } = await sb
      .from('founder_exec_360_pins_v3')
      .select('id, domain, kpi_key, display_order, note, pinned_at')
      .order('display_order', { ascending: true })
      .limit(20);
    pins = (data as PinRow[]) ?? [];
  } catch {}

  const headlineKpis: Kpi[] = [
    ...engineering.slice(0, 4).map((r) => ({ label: r.kpi_label, value: fmtNum(r.kpi_value) })),
    ...revenue.slice(0, 4).map((r) => ({ label: r.kpi_label, value: fmtNum(r.kpi_value) })),
    ...capital.slice(0, 4).map((r) => ({ label: r.kpi_label, value: fmtNum(r.kpi_value) })),
    ...ops.slice(0, 4).map((r) => ({ label: r.kpi_label, value: fmtNum(r.kpi_value) })),
  ];

  const drillColumns: Column<DrillCard>[] = [
    { key: 'domain', header: 'Domain', render: (r: any) => r.domain ?? '—' },
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? '—' },
    { key: 'headline_value', header: 'Value', render: (r: any) => fmtNum(r.headline_value) },
    { key: 'headline_label', header: 'Label', render: (r: any) => r.headline_label ?? '—' },
    { key: 'drill_route', header: 'Drill', render: (r: any) => (r.drill_route ? <a href={r.drill_route}>{r.drill_route}</a> : '—') },
    { key: 'status_color', header: 'Status', render: (r: any) => r.status_color ?? '—' },
  ];

  const complianceColumns: Column<KpiRow>[] = [
    { key: 'kpi_label', header: 'KPI', render: (r: any) => r.kpi_label ?? '—' },
    { key: 'kpi_value', header: 'Value', render: (r: any) => fmtNum(r.kpi_value) },
    { key: 'status_color', header: 'Status', render: (r: any) => r.status_color ?? '—' },
  ];

  const growthColumns: Column<KpiRow>[] = [
    { key: 'kpi_label', header: 'KPI', render: (r: any) => r.kpi_label ?? '—' },
    { key: 'kpi_value', header: 'Value', render: (r: any) => fmtNum(r.kpi_value) },
    { key: 'status_color', header: 'Status', render: (r: any) => r.status_color ?? '—' },
  ];

  const snapshotColumns: Column<SnapshotRow>[] = [
    { key: 'snapshot_date', header: 'Date', render: (r: any) => r.snapshot_date ?? '—' },
    { key: 'domain', header: 'Domain', render: (r: any) => r.domain ?? '—' },
    { key: 'kpi_label', header: 'KPI', render: (r: any) => r.kpi_label ?? '—' },
    { key: 'kpi_value', header: 'Value', render: (r: any) => fmtNum(r.kpi_value) },
    { key: 'status_color', header: 'Status', render: (r: any) => r.status_color ?? '—' },
    { key: 'computed_at', header: 'Computed', render: (r: any) => (r.computed_at ? new Date(r.computed_at).toLocaleString() : '—') },
  ];

  const pinColumns: Column<PinRow>[] = [
    { key: 'display_order', header: '#', render: (r: any) => String(r.display_order ?? 0) },
    { key: 'domain', header: 'Domain', render: (r: any) => r.domain ?? '—' },
    { key: 'kpi_key', header: 'KPI key', render: (r: any) => r.kpi_key ?? '—' },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? '—' },
    { key: 'pinned_at', header: 'Pinned', render: (r: any) => (r.pinned_at ? new Date(r.pinned_at).toLocaleString() : '—') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Executive 360 v3 — r1500 MILESTONE</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        One morning landing screen. 24 KPIs across engineering, revenue, capital, ops,
        compliance, growth. Six click-through drill cards.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Headline KPIs (16)</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
          {headlineKpis.map((k, i) => (
            <div key={i} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 14 }}>
              <div style={{ fontSize: 12, color: '#666' }}>{k.label}</div>
              <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{k.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Drill cards (6 domains)</h2>
        <DataTable
          columns={drillColumns}
          rows={drillCards}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Compliance KPIs</h2>
        <DataTable
          columns={complianceColumns}
          rows={compliance}
          rowKey={(r: any) => r.kpi_key}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Growth KPIs</h2>
        <DataTable
          columns={growthColumns}
          rows={growth}
          rowKey={(r: any) => r.kpi_key}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent snapshots</h2>
        <DataTable
          columns={snapshotColumns}
          rows={snapshots}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Pinned KPIs</h2>
        <DataTable
          columns={pinColumns}
          rows={pins}
          rowKey={(r: any) => r.id}
        />
      </section>
    </main>
  );
}
