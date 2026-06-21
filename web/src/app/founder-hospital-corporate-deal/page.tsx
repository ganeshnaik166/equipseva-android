import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function inr(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  if (v >= 10000000) return '₹' + (v / 10000000).toFixed(2) + ' Cr';
  if (v >= 100000) return '₹' + (v / 100000).toFixed(2) + ' L';
  return '₹' + v.toLocaleString('en-IN');
}

function num(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toFixed(1) + '%';
}

function dt(s: string | null | undefined): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleDateString('en-IN'); } catch { return String(s); }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let deals: any[] = [];
  let members: any[] = [];
  let expiring: any[] = [];
  let tiers: any[] = [];
  let missing: any[] = [];
  let audit: any[] = [];

  try { const r = await sb.rpc('founder_hcd_kpis'); kpis = r.data ?? {}; } catch { kpis = {}; }
  try { const r = await sb.rpc('founder_hcd_list_deals'); deals = (r.data as any[]) ?? []; } catch { deals = []; }
  try { const r = await sb.rpc('founder_hcd_list_members'); members = (r.data as any[]) ?? []; } catch { members = []; }
  try { const r = await sb.rpc('founder_hcd_expiring_soon'); expiring = (r.data as any[]) ?? []; } catch { expiring = []; }
  try { const r = await sb.rpc('founder_hcd_tier_breakdown'); tiers = (r.data as any[]) ?? []; } catch { tiers = []; }
  try { const r = await sb.rpc('founder_hcd_missing_contacts'); missing = (r.data as any[]) ?? []; } catch { missing = []; }
  try { const r = await sb.rpc('founder_hcd_recent_audit'); audit = (r.data as any[]) ?? []; } catch { audit = []; }

  const kpiCards: Kpi[] = [
    { label: 'Total Deals', value: num(kpis.total_deals) },
    { label: 'Active Deals', value: num(kpis.active_deals) },
    { label: 'Platinum', value: num(kpis.platinum) },
    { label: 'Gold', value: num(kpis.gold) },
    { label: 'Silver', value: num(kpis.silver) },
    { label: 'Bronze', value: num(kpis.bronze) },
    { label: 'Draft', value: num(kpis.draft) },
    { label: 'Paused', value: num(kpis.paused) },
    { label: 'Expired', value: num(kpis.expired) },
    { label: 'Terminated', value: num(kpis.terminated) },
    { label: 'Total AMC Value', value: inr(kpis.total_amc_value_rupees) },
    { label: 'Total MRR', value: inr(kpis.total_mrr_rupees) },
    { label: 'Hospitals Covered', value: num(kpis.total_hospitals) },
    { label: 'Avg Discount', value: pct(kpis.avg_discount_pct) },
    { label: 'Expiring 30d', value: num(kpis.expiring_30d) },
    { label: 'Missing Contact', value: num(kpis.missing_contact) },
  ];

  const dealCols: Column<any>[] = [
    { key: 'deal_code', header: 'Code', render: (r: any) => r.deal_code ?? '—' },
    { key: 'corporate_name', header: 'Corporate', render: (r: any) => r.corporate_name ?? '—' },
    { key: 'parent_group', header: 'Group', render: (r: any) => r.parent_group ?? '—' },
    { key: 'deal_tier', header: 'Tier', render: (r: any) => r.deal_tier ?? '—' },
    { key: 'deal_status', header: 'Status', render: (r: any) => r.deal_status ?? '—' },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => num(r.hospital_count) },
    { key: 'amc_value_rupees', header: 'AMC Value', render: (r: any) => inr(r.amc_value_rupees) },
    { key: 'monthly_recurring_rupees', header: 'MRR', render: (r: any) => inr(r.monthly_recurring_rupees) },
    { key: 'contract_end', header: 'Ends', render: (r: any) => dt(r.contract_end) },
    { key: 'discount_pct', header: 'Discount', render: (r: any) => pct(r.discount_pct) },
    { key: 'key_contact_name', header: 'Contact', render: (r: any) => r.key_contact_name ?? '—' },
  ];

  const memberCols: Column<any>[] = [
    { key: 'deal_code', header: 'Deal', render: (r: any) => r.deal_code ?? '—' },
    { key: 'corporate_name', header: 'Corporate', render: (r: any) => r.corporate_name ?? '—' },
    { key: 'hospital_name_snapshot', header: 'Hospital', render: (r: any) => r.hospital_name_snapshot ?? '—' },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'state', header: 'State', render: (r: any) => r.state ?? '—' },
    { key: 'beds_count', header: 'Beds', render: (r: any) => num(r.beds_count) },
    { key: 'joined_at', header: 'Joined', render: (r: any) => dt(r.joined_at) },
    { key: 'active', header: 'Active', render: (r: any) => (r.active ? 'yes' : 'no') },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'deal_code', header: 'Code', render: (r: any) => r.deal_code ?? '—' },
    { key: 'corporate_name', header: 'Corporate', render: (r: any) => r.corporate_name ?? '—' },
    { key: 'deal_tier', header: 'Tier', render: (r: any) => r.deal_tier ?? '—' },
    { key: 'contract_end', header: 'Ends', render: (r: any) => dt(r.contract_end) },
    { key: 'days_remaining', header: 'Days Left', render: (r: any) => num(r.days_remaining) },
    { key: 'amc_value_rupees', header: 'AMC Value', render: (r: any) => inr(r.amc_value_rupees) },
    { key: 'key_contact_name', header: 'Contact', render: (r: any) => r.key_contact_name ?? '—' },
    { key: 'key_contact_email', header: 'Email', render: (r: any) => r.key_contact_email ?? '—' },
  ];

  const tierCols: Column<any>[] = [
    { key: 'deal_tier', header: 'Tier', render: (r: any) => r.deal_tier ?? '—' },
    { key: 'deal_count', header: 'Deals', render: (r: any) => num(r.deal_count) },
    { key: 'hospital_count_sum', header: 'Hospitals', render: (r: any) => num(r.hospital_count_sum) },
    { key: 'amc_value_sum', header: 'AMC Total', render: (r: any) => inr(r.amc_value_sum) },
    { key: 'mrr_sum', header: 'MRR Total', render: (r: any) => inr(r.mrr_sum) },
    { key: 'avg_discount_pct', header: 'Avg Discount', render: (r: any) => pct(r.avg_discount_pct) },
  ];

  const missingCols: Column<any>[] = [
    { key: 'deal_code', header: 'Code', render: (r: any) => r.deal_code ?? '—' },
    { key: 'corporate_name', header: 'Corporate', render: (r: any) => r.corporate_name ?? '—' },
    { key: 'deal_tier', header: 'Tier', render: (r: any) => r.deal_tier ?? '—' },
    { key: 'deal_status', header: 'Status', render: (r: any) => r.deal_status ?? '—' },
    { key: 'amc_value_rupees', header: 'AMC Value', render: (r: any) => inr(r.amc_value_rupees) },
    { key: 'has_name', header: 'Name', render: (r: any) => (r.has_name ? 'yes' : 'NO') },
    { key: 'has_email', header: 'Email', render: (r: any) => (r.has_email ? 'yes' : 'NO') },
    { key: 'has_phone', header: 'Phone', render: (r: any) => (r.has_phone ? 'yes' : 'NO') },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital Corporate-Deal Master</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>Enterprise multi-hospital corporate agreements — terms, revenue, contacts.</p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpiCards.map((k, i) => (
          <div key={i} style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase' }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '16px 0 8px' }}>All Corporate Deals</h2>
      <DataTable columns={dealCols} rows={deals} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Tier Revenue Breakdown</h2>
      <DataTable columns={tierCols} rows={tiers} rowKey={(r: any) => r.deal_tier} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Expiring in 90 Days</h2>
      <DataTable columns={expiringCols} rows={expiring} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Member Hospitals</h2>
      <DataTable columns={memberCols} rows={members} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Missing Contacts (Action Needed)</h2>
      <DataTable columns={missingCols} rows={missing} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Recent Audit</h2>
      <pre style={{ background: '#f9fafb', padding: 12, borderRadius: 8, fontSize: 12, overflow: 'auto', maxHeight: 300 }}>
        {JSON.stringify(audit, null, 2)}
      </pre>
    </div>
  );
}
