import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [chainsRes, vendorRes, blockedRes, milestonesRes] = await Promise.all([
    sb.rpc('list_chain_tech_stacks_r2279'),
    sb.rpc('ehr_vendor_summary_r2279'),
    sb.rpc('blocked_chain_integrations_r2279'),
    sb.rpc('list_chain_milestones_r2279', { p_chain_id: null }),
  ]);

  const chains: any[] = Array.isArray(chainsRes.data) ? chainsRes.data : [];
  const vendors: any[] = Array.isArray(vendorRes.data) ? vendorRes.data : [];
  const blocked: any[] = Array.isArray(blockedRes.data) ? blockedRes.data : [];
  const milestones: any[] = Array.isArray(milestonesRes.data) ? milestonesRes.data : [];

  const liveCount = chains.filter((c) => c.integration_status === 'live').length;
  const pilotCount = chains.filter((c) => c.integration_status === 'pilot').length;
  const scopingCount = chains.filter((c) => c.integration_status === 'scoping').length;
  const blockedCount = chains.filter((c) => c.integration_status === 'blocked').length;
  const totalArr = chains.reduce((s, c) => s + Number(c.estimated_arr_rupees ?? 0), 0);
  const liveArr = chains
    .filter((c) => c.integration_status === 'live' || c.integration_status === 'pilot')
    .reduce((s, c) => s + Number(c.estimated_arr_rupees ?? 0), 0);
  const totalBeds = chains.reduce((s, c) => s + Number(c.bed_count ?? 0), 0);
  const totalHospitals = chains.reduce((s, c) => s + Number(c.hospital_count ?? 0), 0);

  const fmtRupees = (n: number | bigint | null | undefined) => {
    const v = Number(n ?? 0);
    if (v >= 10000000) return '₹' + (v / 10000000).toFixed(2) + ' Cr';
    if (v >= 100000) return '₹' + (v / 100000).toFixed(2) + ' L';
    return '₹' + v.toLocaleString('en-IN');
  };

  const chainColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'chain_tier', header: 'Tier', render: (r: any) => r.chain_tier },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => String(r.hospital_count ?? 0) },
    { key: 'bed_count', header: 'Beds', render: (r: any) => Number(r.bed_count ?? 0).toLocaleString('en-IN') },
    { key: 'ehr_vendor', header: 'EHR', render: (r: any) => (r.ehr_product ? `${r.ehr_vendor} (${r.ehr_product})` : r.ehr_vendor) },
    { key: 'his_vendor', header: 'HIS', render: (r: any) => r.his_vendor ?? '—' },
    { key: 'pacs_vendor', header: 'PACS', render: (r: any) => r.pacs_vendor ?? '—' },
    { key: 'cmms_vendor', header: 'CMMS', render: (r: any) => r.cmms_vendor ?? '—' },
    { key: 'cloud_or_onprem', header: 'Deploy', render: (r: any) => r.cloud_or_onprem },
    { key: 'integration_status', header: 'Status', render: (r: any) => r.integration_status },
    { key: 'integration_method', header: 'Method', render: (r: any) => r.integration_method ?? '—' },
    { key: 'estimated_arr_rupees', header: 'Est. ARR', render: (r: any) => fmtRupees(r.estimated_arr_rupees) },
    { key: 'milestone_count', header: 'Milestones', render: (r: any) => `${r.done_milestone_count ?? 0}/${r.milestone_count ?? 0}` },
    { key: 'last_verified_at', header: 'Verified', render: (r: any) => (r.last_verified_at ? new Date(r.last_verified_at).toLocaleDateString() : '—') },
  ];

  const vendorColumns: Column<any>[] = [
    { key: 'ehr_vendor', header: 'EHR Vendor', render: (r: any) => r.ehr_vendor },
    { key: 'chain_count', header: 'Chains', render: (r: any) => String(r.chain_count ?? 0) },
    { key: 'total_hospitals', header: 'Hospitals', render: (r: any) => String(r.total_hospitals ?? 0) },
    { key: 'total_beds', header: 'Beds', render: (r: any) => Number(r.total_beds ?? 0).toLocaleString('en-IN') },
    { key: 'live_count', header: 'Live', render: (r: any) => String(r.live_count ?? 0) },
    { key: 'pilot_count', header: 'Pilot', render: (r: any) => String(r.pilot_count ?? 0) },
    { key: 'blocked_count', header: 'Blocked', render: (r: any) => String(r.blocked_count ?? 0) },
    { key: 'estimated_arr_rupees', header: 'Est. ARR', render: (r: any) => fmtRupees(r.estimated_arr_rupees) },
  ];

  const blockedColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'chain_tier', header: 'Tier', render: (r: any) => r.chain_tier },
    { key: 'ehr_vendor', header: 'EHR', render: (r: any) => r.ehr_vendor },
    { key: 'integration_status', header: 'Status', render: (r: any) => r.integration_status },
    { key: 'integration_method', header: 'Method', render: (r: any) => r.integration_method ?? '—' },
    { key: 'estimated_arr_rupees', header: 'Est. ARR', render: (r: any) => fmtRupees(r.estimated_arr_rupees) },
    { key: 'open_blocker_count', header: 'Open Blockers', render: (r: any) => String(r.open_blocker_count ?? 0) },
    { key: 'latest_blocker_note', header: 'Latest Blocker', render: (r: any) => (r.latest_blocker_note ?? '').slice(0, 160) },
  ];

  const milestoneColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'milestone_name', header: 'Milestone', render: (r: any) => r.milestone_name },
    { key: 'milestone_type', header: 'Type', render: (r: any) => r.milestone_type },
    { key: 'target_date', header: 'Target', render: (r: any) => (r.target_date ? new Date(r.target_date).toLocaleDateString() : '—') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'blocker_note', header: 'Blocker', render: (r: any) => (r.blocker_note ?? '').slice(0, 120) },
    { key: 'completed_at', header: 'Completed', render: (r: any) => (r.completed_at ? new Date(r.completed_at).toLocaleDateString() : '—') },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Tech-Stack Mapping</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        EHR/HIS/PACS/CMMS inventory per hospital chain, with our integration status, method (HL7 v2 / FHIR R4 / API / CSV), milestones, and ARR exposure. Use to prioritize the next wedge.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Chains tracked</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{chains.length}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Hospitals</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalHospitals.toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Beds</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalBeds.toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Live</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#0a7d2b' }}>{liveCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Pilot</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{pilotCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Scoping</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{scopingCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Blocked</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#b00020' }}>{blockedCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Live+Pilot ARR</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtRupees(liveArr)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Est. ARR</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtRupees(totalArr)}</div>
        </div>
      </section>

      <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Chains & tech stack</h2>
      <DataTable columns={chainColumns} rows={chains} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 20, fontWeight: 600, margin: '32px 0 12px' }}>EHR vendor concentration</h2>
      <p style={{ color: '#666', marginBottom: 12 }}>
        Where vendor share is &gt;= 40% of tracked ARR, build a reusable connector — that one integration unlocks multiple chains.
      </p>
      <DataTable columns={vendorColumns} rows={vendors} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 20, fontWeight: 600, margin: '32px 0 12px' }}>Blocked integrations</h2>
      <DataTable columns={blockedColumns} rows={blocked} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 20, fontWeight: 600, margin: '32px 0 12px' }}>Integration milestones</h2>
      <DataTable columns={milestoneColumns} rows={milestones} rowKey={(_, i) => String(i)} />
    </main>
  );
}
