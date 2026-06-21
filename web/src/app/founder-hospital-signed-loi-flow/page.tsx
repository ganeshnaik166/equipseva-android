import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

function fmtInr(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  if (v >= 10000000) return `${(v / 10000000).toFixed(2)} Cr`;
  if (v >= 100000) return `${(v / 100000).toFixed(2)} L`;
  return v.toLocaleString('en-IN');
}

export default async function FounderHospitalSignedLoiFlowPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = null;
  let activeList: any[] = [];
  let followupDue: any[] = [];
  let lostBreakdown: any[] = [];
  let funnel: any[] = [];
  let recentTouchpoints: any[] = [];
  let agingBuckets: any[] = [];

  try {
    const r = await sb.rpc('founder_loi_pipeline_overview');
    overview = (r.data ?? [])[0] ?? null;
  } catch {}
  try {
    const r = await sb.rpc('founder_loi_active_list');
    activeList = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_loi_followup_due');
    followupDue = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_loi_lost_reason_breakdown');
    lostBreakdown = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_loi_conversion_funnel');
    funnel = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_loi_recent_touchpoints');
    recentTouchpoints = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_loi_aging_buckets');
    agingBuckets = r.data ?? [];
  } catch {}

  const kpis: Kpi[] = [
    { label: 'Total LOIs', value: String(overview?.total_lois ?? 0) },
    { label: 'Signed', value: String(overview?.signed_count ?? 0) },
    { label: 'In Discussion', value: String(overview?.in_discussion_count ?? 0) },
    { label: 'Contract Drafted', value: String(overview?.contract_drafted_count ?? 0) },
    { label: 'Awaiting Payment', value: String(overview?.awaiting_payment_count ?? 0) },
    { label: 'Converted', value: String(overview?.converted_count ?? 0) },
    { label: 'Lost', value: String(overview?.lost_count ?? 0) },
    { label: 'Expired', value: String(overview?.expired_count ?? 0) },
    { label: 'Pipeline ARR', value: `Rs ${fmtInr(overview?.total_intended_arr_rupees)}` },
    { label: 'Converted ARR', value: `Rs ${fmtInr(overview?.converted_arr_rupees)}` },
    { label: 'Conversion %', value: `${overview?.conversion_rate_pct ?? 0}%` },
    { label: 'Followups Due', value: String(followupDue.length ?? 0) },
    { label: 'Active LOIs', value: String(activeList.length ?? 0) },
    { label: 'Lost Reasons', value: String(lostBreakdown.length ?? 0) },
    { label: 'Recent Touchpoints', value: String(recentTouchpoints.length ?? 0) },
    { label: 'Aging Buckets', value: String(agingBuckets.length ?? 0) },
  ];

  const activeCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'intended_amc_tier', header: 'Tier', render: (r: any) => r.intended_amc_tier ?? '—' },
    { key: 'intended_monthly_fee_rupees', header: 'Monthly Fee', render: (r: any) => `Rs ${fmtInr(r.intended_monthly_fee_rupees)}` },
    { key: 'signed_at', header: 'Signed', render: (r: any) => r.signed_at ? new Date(r.signed_at).toLocaleDateString() : '—' },
    { key: 'signatory_name', header: 'Signatory', render: (r: any) => r.signatory_name ?? '—' },
  ];

  const followupCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'next_followup_at', header: 'Due At', render: (r: any) => r.next_followup_at ? new Date(r.next_followup_at).toLocaleString() : '—' },
    { key: 'hours_overdue', header: 'Hrs Overdue', render: (r: any) => Number(r.hours_overdue ?? 0).toFixed(1) },
    { key: 'intended_monthly_fee_rupees', header: 'Monthly Fee', render: (r: any) => `Rs ${fmtInr(r.intended_monthly_fee_rupees)}` },
  ];

  const lostCols: Column<any>[] = [
    { key: 'lost_reason', header: 'Reason', render: (r: any) => r.lost_reason ?? '—' },
    { key: 'loi_count', header: 'LOIs', render: (r: any) => String(r.loi_count ?? 0) },
    { key: 'lost_arr_rupees', header: 'Lost ARR', render: (r: any) => `Rs ${fmtInr(r.lost_arr_rupees)}` },
    { key: 'pct_of_lost', header: '% of Lost', render: (r: any) => `${r.pct_of_lost ?? 0}%` },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'loi_count', header: 'Count', render: (r: any) => String(r.loi_count ?? 0) },
    { key: 'arr_rupees', header: 'ARR', render: (r: any) => `Rs ${fmtInr(r.arr_rupees)}` },
  ];

  const touchpointCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'touched_at', header: 'When', render: (r: any) => r.touched_at ? new Date(r.touched_at).toLocaleString() : '—' },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
    { key: 'next_step', header: 'Next Step', render: (r: any) => r.next_step ?? '—' },
    { key: 'logged_by_email', header: 'By', render: (r: any) => r.logged_by_email ?? '—' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Signed-LOI Flow</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track signed LOIs through to AMC contract conversion. Per-LOI status, founder follow-up SLA, lost-LOI reasons.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active LOIs</h2>
        <DataTable rows={activeList} columns={activeCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Follow-up SLA Breach</h2>
        <DataTable rows={followupDue} columns={followupCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Conversion Funnel</h2>
        <DataTable rows={funnel} columns={funnelCols} rowKey={(r: any) => r.stage} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Lost-LOI Reasons</h2>
        <DataTable rows={lostBreakdown} columns={lostCols} rowKey={(r: any) => r.lost_reason} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Touchpoints</h2>
        <DataTable rows={recentTouchpoints} columns={touchpointCols} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
