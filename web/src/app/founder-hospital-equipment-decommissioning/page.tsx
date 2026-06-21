import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [decommRes, upcomingRes, replRes, winRateRes, revenueRes] = await Promise.all([
    sb.rpc('list_decommissioning_r1835'),
    sb.rpc('upcoming_decommissioning_r1835'),
    sb.rpc('list_replacements_r1835', { p_decomm_id: null }),
    sb.rpc('our_win_rate_r1835'),
    sb.rpc('replacement_revenue_r1835'),
  ]);

  const decomms: any[] = Array.isArray(decommRes.data) ? decommRes.data : [];
  const upcoming: any[] = Array.isArray(upcomingRes.data) ? upcomingRes.data : [];
  const replacements: any[] = Array.isArray(replRes.data) ? replRes.data : [];
  const winRate: any = Array.isArray(winRateRes.data) ? winRateRes.data[0] : winRateRes.data;
  const revenue: any = Array.isArray(revenueRes.data) ? revenueRes.data[0] : revenueRes.data;

  const decommColumns: Column<any>[] = [
    { key: 'decommission_date', header: 'Decomm Date', render: (r: any) => String(r.decommission_date ?? '-') },
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '-') },
    { key: 'manufacturer', header: 'Manufacturer', render: (r: any) => String(r.manufacturer ?? '-') },
    { key: 'install_year', header: 'Install Yr', render: (r: any) => String(r.install_year ?? '-') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '-') },
    { key: 'reason', header: 'Reason', render: (r: any) => String(r.reason ?? '-') },
    { key: 'our_sales_response', header: 'Sales Response', render: (r: any) => String(r.our_sales_response ?? '-') },
  ];

  const upcomingColumns: Column<any>[] = [
    { key: 'decommission_date', header: 'Planned Date', render: (r: any) => String(r.decommission_date ?? '-') },
    { key: 'days_until', header: 'Days Until', render: (r: any) => String(r.days_until ?? '-') },
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '-') },
    { key: 'manufacturer', header: 'Manufacturer', render: (r: any) => String(r.manufacturer ?? '-') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '-') },
    { key: 'reason', header: 'Reason', render: (r: any) => String(r.reason ?? '-') },
    { key: 'our_sales_response', header: 'Response', render: (r: any) => String(r.our_sales_response ?? '-') },
  ];

  const replColumns: Column<any>[] = [
    { key: 'created_at', header: 'Logged', render: (r: any) => String(r.created_at ?? '-').slice(0, 10) },
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '-') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '-') },
    { key: 'replacement_status', header: 'Status', render: (r: any) => String(r.replacement_status ?? '-') },
    { key: 'replacement_make', header: 'Replacement Make', render: (r: any) => String(r.replacement_make ?? '-') },
    { key: 'sale_value_rupees', header: 'Sale Value (Rs)', render: (r: any) => String(r.sale_value_rupees ?? 0) },
    { key: 'decided_at', header: 'Decided At', render: (r: any) => String(r.decided_at ?? '-').slice(0, 10) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto', fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>Hospital Equipment Decommissioning</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track when hospitals retire old equipment — each decommission is a buy signal. Pitch rate & win rate
        show how often we convert these events into new sales.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Sales Funnel</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
          <Stat label="Total Decommissions" value={String(winRate?.total_decommissions ?? 0)} />
          <Stat label="Pitched" value={String(winRate?.pitched_count ?? 0)} />
          <Stat label="Quoted" value={String(winRate?.quoted_count ?? 0)} />
          <Stat label="Won" value={String(winRate?.won_count ?? 0)} />
          <Stat label="Lost" value={String(winRate?.lost_count ?? 0)} />
          <Stat label="No Pitch" value={String(winRate?.no_pitch_count ?? 0)} />
          <Stat label="Win Rate %" value={String(winRate?.win_rate_pct ?? 0)} />
          <Stat label="Pitch Rate %" value={String(winRate?.pitch_rate_pct ?? 0)} />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Replacement Revenue</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <Stat label="Total Replacements" value={String(revenue?.total_replacements ?? 0)} />
          <Stat label="Ours" value={String(revenue?.ours_count ?? 0)} />
          <Stat label="Competitor" value={String(revenue?.competitor_count ?? 0)} />
          <Stat label="None" value={String(revenue?.none_count ?? 0)} />
          <Stat label="Pending" value={String(revenue?.pending_count ?? 0)} />
          <Stat label="Our Revenue (Rs)" value={String(revenue?.our_revenue_rupees ?? 0)} />
          <Stat label="Competitor Revenue (Rs)" value={String(revenue?.competitor_revenue_rupees ?? 0)} />
          <Stat label="Total Market (Rs)" value={String(revenue?.total_market_rupees ?? 0)} />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Upcoming Decommissioning (next pipeline)</h2>
        <DataTable
          rows={upcoming}
          columns={upcomingColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Decommissioning Events</h2>
        <DataTable
          rows={decomms}
          columns={decommColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Replacement Log</h2>
        <DataTable
          rows={replacements}
          columns={replColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
