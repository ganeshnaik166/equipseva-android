import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalSupplyChainVisibilityPage() {
  const sb = await getSupabaseServerClient();

  const [visRes, atRiskRes, recentRes] = await Promise.all([
    sb.rpc('list_supply_visibilities_r2039'),
    sb.rpc('at_risk_supply_hospitals_r2039'),
    sb.rpc('recent_supply_actions_r2039'),
  ]);

  const visibilities: any[] = Array.isArray(visRes.data) ? visRes.data : [];
  const atRisk: any[] = Array.isArray(atRiskRes.data) ? atRiskRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const visColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'supply_category', header: 'Category', render: (r: any) => String(r.supply_category ?? '') },
    { key: 'inventory_days_remaining', header: 'Days Left', render: (r: any) => String(r.inventory_days_remaining ?? 0) },
    { key: 'supplier_count', header: 'Suppliers', render: (r: any) => String(r.supplier_count ?? 0) },
    { key: 'alternate_suppliers_count', header: 'Alternates', render: (r: any) => String(r.alternate_suppliers_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const atRiskColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'at_risk_categories', header: 'At Risk Categories', render: (r: any) => String(r.at_risk_categories ?? 0) },
    { key: 'min_days_remaining', header: 'Min Days Remaining', render: (r: any) => String(r.min_days_remaining ?? 0) },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'supply_category', header: 'Category', render: (r: any) => String(r.supply_category ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>Hospital Supply Chain Visibility</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track inventory days remaining, supplier diversity, and category resilience across hospital partners. Surface at-risk
        hospitals before stockouts impact uptime or patient care.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Supply Visibility Snapshots</h2>
        <DataTable
          rows={visibilities}
          columns={visColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>At-Risk Hospitals</h2>
        <p style={{ color: '#666', fontSize: 14, marginBottom: 8 }}>
          Hospitals with any category in at-risk or critical status, ranked by lowest days remaining.
        </p>
        <DataTable
          rows={atRisk}
          columns={atRiskColumns}
          rowKey={(r: any, i: number) => String(r.hospital_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Supply Actions</h2>
        <DataTable
          rows={recent}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
