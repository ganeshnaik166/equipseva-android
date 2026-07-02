import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function rupees(paise: number | null | undefined): string {
  if (paise == null) return "—";
  return "₹" + (Number(paise) / 100).toLocaleString('en-IN', { maximumFractionDigits: 2 });
}

function num(v: any): string {
  if (v == null) return "—";
  return Number(v).toLocaleString('en-IN');
}

export default async function Founder409ATrackerPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let history: any[] = [];
  let vendors: any[] = [];
  let ratio: any[] = [];
  let repricing: any[] = [];
  let methodology: any[] = [];
  let expiry: any[] = [];

  try {
    const r = await sb.rpc('founder_409a_summary_kpis');
    kpis = (r.data && r.data[0]) || {};
  } catch {}
  try {
    const r = await sb.rpc('founder_409a_valuation_history');
    history = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_409a_per_vendor_breakdown');
    vendors = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_409a_ratio_review');
    ratio = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_409a_repricing_queue');
    repricing = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_409a_methodology_split');
    methodology = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_409a_expiry_radar');
    expiry = r.data || [];
  } catch {}

  const kpiCards: Kpi[] = [
    { label: 'Total Valuations', value: num(kpis.total_valuations) },
    { label: 'Approved', value: num(kpis.approved_count) },
    { label: 'Draft', value: num(kpis.draft_count) },
    { label: 'Under Review', value: num(kpis.under_review_count) },
    { label: 'Superseded', value: num(kpis.superseded_count) },
    { label: 'Current Common', value: rupees(kpis.current_common_paise) },
    { label: 'Current Preferred', value: rupees(kpis.current_preferred_paise) },
    { label: 'Common/Preferred Ratio', value: (kpis.current_ratio_pct ?? "—") + '%' },
    { label: 'Enterprise Value', value: rupees(kpis.current_enterprise_value_paise) },
    { label: 'Current Vendor', value: kpis.current_vendor ?? "—" },
    { label: 'Methodology', value: kpis.current_methodology ?? "—" },
    { label: 'Safe Harbor', value: kpis.current_safe_harbor === true ? 'Yes' : kpis.current_safe_harbor === false ? 'No' : "—" },
    { label: 'Days To Expiry', value: kpis.days_until_expiry == null ? "—" : String(kpis.days_until_expiry) },
    { label: 'Pending Repricing', value: num(kpis.pending_repricing_triggers) },
    { label: 'Affected Options (pending)', value: num(kpis.affected_options_total) },
    { label: 'Repriced Options (executed)', value: num(kpis.total_repriced_options) },
  ];

  const historyCols: Column<any>[] = [
    { key: 'valuation_date', header: 'Val Date', render: (r: any) => r.valuation_date ?? "—" },
    { key: 'effective_date', header: 'Effective', render: (r: any) => r.effective_date ?? "—" },
    { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor ?? "—" },
    { key: 'methodology', header: 'Method', render: (r: any) => r.methodology ?? "—" },
    { key: 'common_paise', header: 'Common', render: (r: any) => rupees(r.common_paise) },
    { key: 'preferred_paise', header: 'Preferred', render: (r: any) => rupees(r.preferred_paise) },
    { key: 'ratio_pct', header: 'Ratio %', render: (r: any) => (r.ratio_pct ?? "—") + '%' },
    { key: 'enterprise_value_paise', header: 'EV', render: (r: any) => rupees(r.enterprise_value_paise) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? "—" },
    { key: 'safe_harbor', header: 'Safe Harbor', render: (r: any) => r.safe_harbor ? 'Yes' : 'No' },
    { key: 'days_to_expiry', header: 'Days Left', render: (r: any) => r.days_to_expiry == null ? "—" : String(r.days_to_expiry) },
  ];

  const vendorCols: Column<any>[] = [
    { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor ?? "—" },
    { key: 'valuation_count', header: 'Count', render: (r: any) => num(r.valuation_count) },
    { key: 'approved_count', header: 'Approved', render: (r: any) => num(r.approved_count) },
    { key: 'avg_common_paise', header: 'Avg Common', render: (r: any) => rupees(r.avg_common_paise) },
    { key: 'avg_preferred_paise', header: 'Avg Preferred', render: (r: any) => rupees(r.avg_preferred_paise) },
    { key: 'avg_ratio_pct', header: 'Avg Ratio %', render: (r: any) => (r.avg_ratio_pct ?? "—") + '%' },
    { key: 'last_valuation_date', header: 'Last Val', render: (r: any) => r.last_valuation_date ?? "—" },
    { key: 'safe_harbor_pct', header: 'Safe Harbor %', render: (r: any) => (r.safe_harbor_pct ?? "—") + '%' },
  ];

  const ratioCols: Column<any>[] = [
    { key: 'valuation_date', header: 'Date', render: (r: any) => r.valuation_date ?? "—" },
    { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor ?? "—" },
    { key: 'common_paise', header: 'Common', render: (r: any) => rupees(r.common_paise) },
    { key: 'preferred_paise', header: 'Preferred', render: (r: any) => rupees(r.preferred_paise) },
    { key: 'ratio_pct', header: 'Ratio %', render: (r: any) => (r.ratio_pct ?? "—") + '%' },
    { key: 'ratio_band', header: 'Band', render: (r: any) => r.ratio_band ?? "—" },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? "—" },
    { key: 'needs_review', header: 'Flagged', render: (r: any) => r.needs_review ? 'YES' : 'no' },
  ];

  const repricingCols: Column<any>[] = [
    { key: 'valuation_date', header: 'Val Date', render: (r: any) => r.valuation_date ?? "—" },
    { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor ?? "—" },
    { key: 'trigger_type', header: 'Trigger', render: (r: any) => r.trigger_type ?? "—" },
    { key: 'affected_grants_count', header: 'Grants', render: (r: any) => num(r.affected_grants_count) },
    { key: 'affected_options', header: 'Options', render: (r: any) => num(r.affected_options) },
    { key: 'old_strike_paise', header: 'Old Strike', render: (r: any) => rupees(r.old_strike_paise) },
    { key: 'new_strike_paise', header: 'New Strike', render: (r: any) => rupees(r.new_strike_paise) },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision ?? "—" },
  ];

  const expiryCols: Column<any>[] = [
    { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor ?? "—" },
    { key: 'effective_date', header: 'Effective', render: (r: any) => r.effective_date ?? "—" },
    { key: 'expires_on', header: 'Expires', render: (r: any) => r.expires_on ?? "—" },
    { key: 'days_remaining', header: 'Days Left', render: (r: any) => r.days_remaining == null ? "—" : String(r.days_remaining) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? "—" },
    { key: 'urgency', header: 'Urgency', render: (r: any) => r.urgency ?? "—" },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Investor 409A Valuation Tracker</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>r1564 — log 409A valuations per vendor, review common/preferred ratio, trigger ESOP repricing.</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpiCards.map((k, i) => (
          <div key={i} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Valuation History</h2>
        <DataTable rows={history} columns={historyCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Per-Vendor Breakdown</h2>
        <DataTable rows={vendors} columns={vendorCols} rowKey={(r: any) => r.vendor} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Common/Preferred Ratio Review</h2>
        <DataTable rows={ratio} columns={ratioCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>ESOP Repricing Queue</h2>
        <DataTable rows={repricing} columns={repricingCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Expiry Radar</h2>
        <DataTable rows={expiry} columns={expiryCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Methodology Split</h2>
        <ul style={{ listStyle: 'none', padding: 0 }}>
          {methodology.map((m: any, i: number) => (
            <li key={i} style={{ padding: 8, borderBottom: '1px solid #f3f4f6' }}>
              <strong>{m.methodology ?? "—"}</strong> — {num(m.count)} valuations, avg common {rupees(m.avg_common_paise)}, avg ratio {(m.avg_ratio_pct ?? "—")}%, safe-harbor {num(m.safe_harbor_count)}, approved {num(m.approved_count)}
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
