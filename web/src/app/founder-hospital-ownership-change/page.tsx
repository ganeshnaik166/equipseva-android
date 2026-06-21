import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string | number };

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function FounderHospitalOwnershipChangePage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpiRow: any = {};
  let recent: any[] = [];
  let atRisk: any[] = [];
  let outreach: any[] = [];
  let byType: any[] = [];

  try {
    const r = await sb.rpc('founder_ownership_kpis');
    kpiRow = (r.data && r.data[0]) || {};
  } catch { kpiRow = {}; }

  try {
    const r = await sb.rpc('founder_ownership_events_recent');
    recent = r.data || [];
  } catch { recent = []; }

  try {
    const r = await sb.rpc('founder_ownership_at_risk_amcs');
    atRisk = r.data || [];
  } catch { atRisk = []; }

  try {
    const r = await sb.rpc('founder_ownership_outreach_queue');
    outreach = r.data || [];
  } catch { outreach = []; }

  try {
    const r = await sb.rpc('founder_ownership_by_event_type');
    byType = r.data || [];
  } catch { byType = []; }

  const kpis: Kpi[] = [
    { label: 'Total events', value: kpiRow.total_events ?? 0 },
    { label: 'Events 30d', value: kpiRow.events_30d ?? 0 },
    { label: 'Events 90d', value: kpiRow.events_90d ?? 0 },
    { label: 'Unique hospitals', value: kpiRow.unique_hospitals ?? 0 },
    { label: 'Critical risk', value: kpiRow.critical_risk ?? 0 },
    { label: 'High risk', value: kpiRow.high_risk ?? 0 },
    { label: 'Medium risk', value: kpiRow.medium_risk ?? 0 },
    { label: 'Low risk', value: kpiRow.low_risk ?? 0 },
    { label: 'Unknown risk', value: kpiRow.unknown_risk ?? 0 },
    { label: 'At-risk AMC value', value: fmtRupees(kpiRow.at_risk_amc_value_rupees) },
    { label: 'Outreach queued', value: kpiRow.outreach_queued ?? 0 },
    { label: 'Outreach sent', value: kpiRow.outreach_sent ?? 0 },
    { label: 'Outreach responded', value: kpiRow.outreach_responded ?? 0 },
    { label: 'Outreach no-response', value: kpiRow.outreach_no_response ?? 0 },
    { label: 'AMC renewed', value: kpiRow.outreach_renewed ?? 0 },
    { label: 'AMC lost', value: kpiRow.outreach_lost ?? 0 },
  ];

  const recentCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'event_type', header: 'Event', render: (r: any) => r.event_type ?? '—' },
    { key: 'previous_owner_name', header: 'Prev owner', render: (r: any) => r.previous_owner_name ?? '—' },
    { key: 'new_owner_name', header: 'New owner', render: (r: any) => r.new_owner_name ?? '—' },
    { key: 'effective_date', header: 'Effective', render: (r: any) => r.effective_date ?? '—' },
    { key: 'amc_continuation_risk', header: 'Risk', render: (r: any) => r.amc_continuation_risk ?? '—' },
    { key: 'active_amc_count', header: 'AMCs', render: (r: any) => r.active_amc_count ?? 0 },
    { key: 'active_amc_value_rupees', header: 'AMC value', render: (r: any) => fmtRupees(r.active_amc_value_rupees) },
    { key: 'source', header: 'Source', render: (r: any) => r.source ?? '—' },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'event_type', header: 'Event', render: (r: any) => r.event_type ?? '—' },
    { key: 'effective_date', header: 'Effective', render: (r: any) => r.effective_date ?? '—' },
    { key: 'amc_continuation_risk', header: 'Risk', render: (r: any) => r.amc_continuation_risk ?? '—' },
    { key: 'active_amc_count', header: 'AMCs', render: (r: any) => r.active_amc_count ?? 0 },
    { key: 'active_amc_value_rupees', header: 'AMC value', render: (r: any) => fmtRupees(r.active_amc_value_rupees) },
    { key: 'new_owner_name', header: 'New owner', render: (r: any) => r.new_owner_name ?? '—' },
    { key: 'new_owner_email', header: 'Email', render: (r: any) => r.new_owner_email ?? '—' },
    { key: 'new_owner_phone', header: 'Phone', render: (r: any) => r.new_owner_phone ?? '—' },
  ];

  const outreachCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'new_owner_name', header: 'New owner', render: (r: any) => r.new_owner_name ?? '—' },
    { key: 'outreach_channel', header: 'Channel', render: (r: any) => r.outreach_channel ?? '—' },
    { key: 'outreach_status', header: 'Status', render: (r: any) => r.outreach_status ?? '—' },
    { key: 'contacted_at', header: 'Contacted', render: (r: any) => r.contacted_at ?? '—' },
    { key: 'responded_at', header: 'Responded', render: (r: any) => r.responded_at ?? '—' },
    { key: 'next_step', header: 'Next step', render: (r: any) => r.next_step ?? '—' },
    { key: 'next_step_due', header: 'Due', render: (r: any) => r.next_step_due ?? '—' },
    { key: 'amc_renewed', header: 'Renewed', render: (r: any) => (r.amc_renewed ? 'yes' : 'no') },
  ];

  const typeCols: Column<any>[] = [
    { key: 'event_type', header: 'Event type', render: (r: any) => r.event_type ?? '—' },
    { key: 'n', header: 'Count', render: (r: any) => r.n ?? 0 },
    { key: 'total_amc_value_rupees', header: 'AMC value', render: (r: any) => fmtRupees(r.total_amc_value_rupees) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital Ownership Change Tracker</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Log hospital ownership/management transitions, surface AMC continuation risk, and queue founder reach-out to new decision makers.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '16px 0 8px' }}>Recent ownership events</h2>
      <DataTable rows={recent} columns={recentCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>At-risk AMCs</h2>
      <DataTable rows={atRisk} columns={atRiskCols} rowKey={(r: any) => r.event_id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Founder outreach queue</h2>
      <DataTable rows={outreach} columns={outreachCols} rowKey={(r: any) => r.outreach_id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>By event type</h2>
      <DataTable rows={byType} columns={typeCols} rowKey={(r: any) => r.event_type} />
    </main>
  );
}
