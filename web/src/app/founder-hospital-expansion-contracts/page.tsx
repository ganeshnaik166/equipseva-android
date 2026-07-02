import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type Kpi = { label: string; value: string };

function inr(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return 'Rs ' + v.toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  try { return new Date(s).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }); } catch { return String(s); }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let pending: any[] = [];
  let decisions: any[] = [];
  let byHospital: any[] = [];
  let ledger: any[] = [];

  try {
    const r = await sb.rpc('founder_expansion_kpis');
    kpis = (r.data as any) ?? {};
  } catch { kpis = {}; }

  try {
    const r = await sb.rpc('founder_expansion_pending_queue');
    pending = (r.data as any[]) ?? [];
  } catch { pending = []; }

  try {
    const r = await sb.rpc('founder_expansion_recent_decisions');
    decisions = (r.data as any[]) ?? [];
  } catch { decisions = []; }

  try {
    const r = await sb.rpc('founder_expansion_uplift_by_hospital');
    byHospital = (r.data as any[]) ?? [];
  } catch { byHospital = []; }

  try {
    const r = await sb.rpc('founder_expansion_uplift_ledger_recent');
    ledger = (r.data as any[]) ?? [];
  } catch { ledger = []; }

  const cards: Kpi[] = [
    { label: 'Total events', value: String(kpis.total_events ?? 0) },
    { label: 'Pending', value: String(kpis.pending ?? 0) },
    { label: 'Approved', value: String(kpis.approved ?? 0) },
    { label: 'Rejected', value: String(kpis.rejected ?? 0) },
    { label: 'Contract issued', value: String(kpis.contract_issued ?? 0) },
    { label: 'Pipeline uplift / mo', value: inr(kpis.pipeline_uplift_rupees) },
    { label: 'Approved uplift / mo', value: inr(kpis.approved_uplift_rupees) },
    { label: 'Realized uplift (cum)', value: inr(kpis.realized_uplift_rupees) },
    { label: 'New wings', value: String(kpis.new_wing_count ?? 0) },
    { label: 'New branches', value: String(kpis.new_branch_count ?? 0) },
    { label: 'New floors', value: String(kpis.new_floor_count ?? 0) },
    { label: 'New specialties', value: String(kpis.new_specialty_count ?? 0) },
    { label: 'Hospitals expanding', value: String(kpis.distinct_hospitals ?? 0) },
    { label: 'Beds added (declared)', value: String(kpis.declared_beds_added ?? 0) },
    { label: 'Equipment added', value: String(kpis.declared_equipment_added ?? 0) },
    { label: 'Avg decision hrs', value: String(kpis.avg_decision_hours ?? 0) },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'type', header: 'Type', render: (r: any) => r.expansion_type ?? '-' },
    { key: 'label', header: 'Label', render: (r: any) => r.expansion_label ?? '-' },
    { key: 'beds', header: 'Beds', render: (r: any) => String(r.declared_beds_added ?? 0) },
    { key: 'equipment', header: 'Equip', render: (r: any) => String(r.declared_equipment_count ?? 0) },
    { key: 'uplift', header: 'Uplift/mo', render: (r: any) => inr(r.expected_monthly_uplift_rupees) },
    { key: 'tier', header: 'Proposed tier', render: (r: any) => r.proposed_amc_tier ?? '-' },
    { key: 'golive', header: 'Go-live', render: (r: any) => fmtDate(r.go_live_target_at) },
    { key: 'waiting', header: 'Hrs waiting', render: (r: any) => String(r.hours_waiting ?? 0) },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'type', header: 'Type', render: (r: any) => r.expansion_type ?? '-' },
    { key: 'label', header: 'Label', render: (r: any) => r.expansion_label ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'uplift', header: 'Uplift/mo', render: (r: any) => inr(r.expected_monthly_uplift_rupees) },
    { key: 'decision', header: 'Decision', render: (r: any) => r.founder_decision ?? '-' },
    { key: 'at', header: 'Decided at', render: (r: any) => fmtDate(r.founder_decided_at) },
    { key: 'hrs', header: 'Decision hrs', render: (r: any) => String(r.decision_hours ?? 0) },
  ];

  const hospCols: Column<any>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'state', header: 'State', render: (r: any) => r.hospital_state ?? '-' },
    { key: 'count', header: 'Expansions', render: (r: any) => String(r.expansion_count ?? 0) },
    { key: 'pipe', header: 'Pipeline uplift', render: (r: any) => inr(r.pipeline_uplift_rupees) },
    { key: 'appr', header: 'Approved uplift', render: (r: any) => inr(r.approved_uplift_rupees) },
    { key: 'real', header: 'Realized uplift', render: (r: any) => inr(r.realized_uplift_rupees) },
  ];

  const ledgerCols: Column<any>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'label', header: 'Expansion', render: (r: any) => r.expansion_label ?? '-' },
    { key: 'period', header: 'Month', render: (r: any) => r.period_month ?? '-' },
    { key: 'baseline', header: 'Baseline', render: (r: any) => inr(r.baseline_monthly_rupees) },
    { key: 'expanded', header: 'Expanded', render: (r: any) => inr(r.expanded_monthly_rupees) },
    { key: 'uplift', header: 'Uplift', render: (r: any) => inr(r.uplift_rupees) },
    { key: 'pct', header: 'Realized %', render: (r: any) => String(r.uplift_realized_pct ?? 0) },
    { key: 'created', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital expansion contracts</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Hospitals expanding (new wing, branch, floor, specialty) trigger AMC contract expansion. Founder approves uplift per event.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 12, marginBottom: 24 }}>
        {cards.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pending approval ({pending.length})</h2>
      <DataTable<any> rows={pending} columns={pendingCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Recent decisions</h2>
      <DataTable<any> rows={decisions} columns={decisionCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Uplift by hospital</h2>
      <DataTable<any> rows={byHospital} columns={hospCols} rowKey={(r: any) => r.hospital_org_id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Uplift ledger (recent)</h2>
      <DataTable<any> rows={ledger} columns={ledgerCols} rowKey={(r: any) => r.id} />
    </div>
  );
}
