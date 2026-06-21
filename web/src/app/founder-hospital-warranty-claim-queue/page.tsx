import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalWarrantyClaimQueuePage() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, pendingRes, awaitingRes, disputedRes, byOemRes, topHospitalsRes, trendRes] = await Promise.all([
    sb.rpc('founder_hospital_oem_warranty_summary'),
    sb.rpc('founder_hospital_oem_warranty_pending_review'),
    sb.rpc('founder_hospital_oem_warranty_awaiting_reimbursement'),
    sb.rpc('founder_hospital_oem_warranty_disputed'),
    sb.rpc('founder_hospital_oem_warranty_by_oem'),
    sb.rpc('founder_hospital_oem_warranty_top_hospitals'),
    sb.rpc('founder_hospital_oem_warranty_daily_trend'),
  ]);

  const summary = (summaryRes.data ?? [])[0] ?? {};
  const pending = pendingRes.data ?? [];
  const awaiting = awaitingRes.data ?? [];
  const disputed = disputedRes.data ?? [];
  const byOem = byOemRes.data ?? [];
  const topHospitals = topHospitalsRes.data ?? [];
  const trend = trendRes.data ?? [];

  const pendingCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'oem_name', header: 'OEM', render: (r: any) => r.oem_name ?? '—' },
    { key: 'equipment_model', header: 'Equipment', render: (r: any) => r.equipment_model ?? '—' },
    { key: 'claim_amount_rupees', header: 'Claim', render: (r: any) => `₹${Number(r.claim_amount_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'age_days', header: 'Age (d)', render: (r: any) => r.age_days ?? '—' },
  ];

  const awaitingCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'oem_name', header: 'OEM', render: (r: any) => r.oem_name ?? '—' },
    { key: 'approved_amount_rupees', header: 'Approved', render: (r: any) => `₹${Number(r.approved_amount_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'age_days', header: 'Days waiting', render: (r: any) => r.age_days ?? '—' },
  ];

  const disputedCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'oem_name', header: 'OEM', render: (r: any) => r.oem_name ?? '—' },
    { key: 'claim_amount_rupees', header: 'Claim', render: (r: any) => `₹${Number(r.claim_amount_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'oem_response', header: 'OEM response', render: (r: any) => r.oem_response ?? '—' },
  ];

  const oemCols: Column<any>[] = [
    { key: 'oem_name', header: 'OEM', render: (r: any) => r.oem_name ?? '—' },
    { key: 'claim_count', header: 'Claims', render: (r: any) => r.claim_count ?? 0 },
    { key: 'approved_count', header: 'Approved', render: (r: any) => r.approved_count ?? 0 },
    { key: 'rejected_count', header: 'Rejected', render: (r: any) => r.rejected_count ?? 0 },
    { key: 'disputed_count', header: 'Disputed', render: (r: any) => r.disputed_count ?? 0 },
    { key: 'approval_rate_pct', header: 'Approval %', render: (r: any) => `${r.approval_rate_pct ?? 0}%` },
    { key: 'total_claim_value_rupees', header: 'Claim ₹', render: (r: any) => `₹${Number(r.total_claim_value_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const hospCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'state', header: 'State', render: (r: any) => r.state ?? '—' },
    { key: 'claim_count', header: 'Claims', render: (r: any) => r.claim_count ?? 0 },
    { key: 'total_claim_value_rupees', header: 'Claim ₹', render: (r: any) => `₹${Number(r.total_claim_value_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'total_reimbursed_rupees', header: 'Reimbursed ₹', render: (r: any) => `₹${Number(r.total_reimbursed_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const trendCols: Column<any>[] = [
    { key: 'filed_day', header: 'Day', render: (r: any) => r.filed_day ?? '—' },
    { key: 'claims_filed', header: 'Filed', render: (r: any) => r.claims_filed ?? 0 },
    { key: 'claims_approved', header: 'Approved', render: (r: any) => r.claims_approved ?? 0 },
    { key: 'claims_rejected', header: 'Rejected', render: (r: any) => r.claims_rejected ?? 0 },
    { key: 'total_value_rupees', header: 'Value ₹', render: (r: any) => `₹${Number(r.total_value_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital → OEM Warranty Claim Queue</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>Hospital-side warranty claims filed against OEMs. Founder reviews, approves, and reimburses pending OEM resolution.</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 32 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total claims</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{summary.total_claims ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Submitted</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{summary.submitted_count ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Under review</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{summary.under_review_count ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Approved</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{summary.approved_count ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Reimbursed</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{summary.reimbursed_count ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>OEM disputed</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#dc2626' }}>{summary.oem_disputed_count ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total claim value</div>
          <div style={{ fontSize: 20, fontWeight: 700 }}>₹{Number(summary.total_claim_value_rupees ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Pending reimbursement</div>
          <div style={{ fontSize: 20, fontWeight: 700, color: '#d97706' }}>₹{Number(summary.pending_reimbursement_rupees ?? 0).toLocaleString('en-IN')}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Pending review</h2>
        <DataTable columns={pendingCols} rows={pending} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Approved — awaiting reimbursement</h2>
        <DataTable columns={awaitingCols} rows={awaiting} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>OEM disputed</h2>
        <DataTable columns={disputedCols} rows={disputed} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>OEM breakdown</h2>
        <DataTable columns={oemCols} rows={byOem} rowKey={(r: any, i: number) => String(r.oem_name ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top hospitals by claim volume</h2>
        <DataTable columns={hospCols} rows={topHospitals} rowKey={(r: any, i: number) => String(r.hospital_org_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>30-day daily trend</h2>
        <DataTable columns={trendCols} rows={trend} rowKey={(r: any, i: number) => String(r.filed_day ?? i)} />
      </section>
    </main>
  );
}
