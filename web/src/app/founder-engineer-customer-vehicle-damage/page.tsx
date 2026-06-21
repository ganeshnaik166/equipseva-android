import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerCustomerVehicleDamagePage() {
  const sb = await getSupabaseServerClient();

  const [incidentsRes, claimsRes, byEngineerRes, recentRes] = await Promise.all([
    sb.rpc('list_incidents_r1824'),
    sb.rpc('list_claims_r1824'),
    sb.rpc('incidents_by_engineer_r1824'),
    sb.rpc('recent_settlements_r1824'),
  ]);

  const incidents: any[] = Array.isArray(incidentsRes.data) ? incidentsRes.data : [];
  const claims: any[] = Array.isArray(claimsRes.data) ? claimsRes.data : [];
  const byEngineer: any[] = Array.isArray(byEngineerRes.data) ? byEngineerRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const totalEstimated = incidents.reduce((s, r) => s + Number(r.estimated_damage_rupees ?? 0), 0);
  const totalSettled = incidents.reduce((s, r) => s + Number(r.settled_amount_rupees ?? 0), 0);
  const openCount = incidents.filter((r) => ['reported', 'investigating', 'disputed'].includes(String(r.status))).length;

  const incidentCols: Column<any>[] = [
    { key: 'incident_date', header: 'Date', render: (r: any) => String(r.incident_date ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? r.engineer_user_id ?? '') },
    { key: 'vehicle_registration', header: 'Vehicle', render: (r: any) => String(r.vehicle_registration ?? '') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '-') },
    { key: 'damage_description', header: 'Damage', render: (r: any) => String(r.damage_description ?? '').slice(0, 80) },
    { key: 'estimated_damage_rupees', header: 'Est. (Rs)', render: (r: any) => Number(r.estimated_damage_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'settled_amount_rupees', header: 'Settled (Rs)', render: (r: any) => r.settled_amount_rupees != null ? Number(r.settled_amount_rupees).toLocaleString('en-IN') : '-' },
  ];

  const claimCols: Column<any>[] = [
    { key: 'claim_filed_at', header: 'Filed', render: (r: any) => r.claim_filed_at ? new Date(r.claim_filed_at).toLocaleDateString('en-IN') : '' },
    { key: 'vehicle_registration', header: 'Vehicle', render: (r: any) => String(r.vehicle_registration ?? '') },
    { key: 'insurance_provider', header: 'Provider', render: (r: any) => String(r.insurance_provider ?? '') },
    { key: 'claim_status', header: 'Status', render: (r: any) => String(r.claim_status ?? '') },
    { key: 'payout_rupees', header: 'Payout (Rs)', render: (r: any) => r.payout_rupees != null ? Number(r.payout_rupees).toLocaleString('en-IN') : '-' },
    { key: 'payout_received_at', header: 'Received', render: (r: any) => r.payout_received_at ? new Date(r.payout_received_at).toLocaleDateString('en-IN') : '-' },
  ];

  const byEngCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? r.engineer_user_id ?? '') },
    { key: 'incident_count', header: 'Incidents', render: (r: any) => String(r.incident_count ?? 0) },
    { key: 'open_incidents', header: 'Open', render: (r: any) => String(r.open_incidents ?? 0) },
    { key: 'total_estimated_rupees', header: 'Total Est. (Rs)', render: (r: any) => Number(r.total_estimated_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'total_settled_rupees', header: 'Total Settled (Rs)', render: (r: any) => Number(r.total_settled_rupees ?? 0).toLocaleString('en-IN') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'settled_at', header: 'Settled At', render: (r: any) => r.settled_at ? new Date(r.settled_at).toLocaleString('en-IN') : '' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? r.engineer_user_id ?? '') },
    { key: 'vehicle_registration', header: 'Vehicle', render: (r: any) => String(r.vehicle_registration ?? '') },
    { key: 'estimated_damage_rupees', header: 'Est. (Rs)', render: (r: any) => Number(r.estimated_damage_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'settled_amount_rupees', header: 'Settled (Rs)', render: (r: any) => Number(r.settled_amount_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Engineer Customer Vehicle Damage</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Vehicle damage incidents at customer sites & insurance claim tracking.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Incidents</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{incidents.length}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Open Cases</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{openCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Est. Damage (Rs)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{totalEstimated.toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Settled (Rs)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{totalSettled.toLocaleString('en-IN')}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Incidents</h2>
        <DataTable rows={incidents} columns={incidentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Insurance Claims</h2>
        <DataTable rows={claims} columns={claimCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By Engineer</h2>
        <DataTable rows={byEngineer} columns={byEngCols} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Settlements</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
