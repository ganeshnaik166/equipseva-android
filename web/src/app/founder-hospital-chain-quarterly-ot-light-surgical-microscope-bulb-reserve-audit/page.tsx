import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChainSummary = { id?: string; chain_name: string; sites: number; critical_count: number; short_count: number; healthy_count: number; total_gap: number };
type CriticalFixture = { id?: string; chain_name: string; hospital_site: string; ot_room_code: string; fixture_type: string; bulb_model: string; reserve_gap: number; mean_burn_hours: number };
type FixtureMix = { id?: string; fixture_type: string; audits: number; avg_burn_hours: number; short_or_worse: number };
type OpenSignal = { id?: string; chain_name: string; hospital_site: string; bulb_sku: string; signal_kind: string; urgency: string; recommended_qty: number; unit_cost_rupees: number; lead_time_days: number; vendor_name: string };
type SpendForecast = { id?: string; chain_name: string; open_signals: number; projected_rupees: number; max_lead_days: number };
type VendorConc = { id?: string; vendor_name: string; skus: number; open_signals: number; total_rupees: number };
type AgingRisk = { id?: string; chain_name: string; hospital_site: string; bulb_model: string; days_since_replace: number; mean_burn_hours: number; status: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [s1, s2, s3, s4, s5, s6, s7] = await Promise.all([
    supabase.rpc('founder_r2971_chain_summary'),
    supabase.rpc('founder_r2971_critical_fixtures'),
    supabase.rpc('founder_r2971_fixture_mix'),
    supabase.rpc('founder_r2971_open_signals'),
    supabase.rpc('founder_r2971_spend_forecast'),
    supabase.rpc('founder_r2971_vendor_concentration'),
    supabase.rpc('founder_r2971_aging_risk'),
  ]);

  const chainSummary = (s1.data ?? []) as ChainSummary[];
  const critical = (s2.data ?? []) as CriticalFixture[];
  const fixtureMix = (s3.data ?? []) as FixtureMix[];
  const openSignals = (s4.data ?? []) as OpenSignal[];
  const spend = (s5.data ?? []) as SpendForecast[];
  const vendors = (s6.data ?? []) as VendorConc[];
  const aging = (s7.data ?? []) as AgingRisk[];

  const chainCols: Column<ChainSummary>[] = [
    { header: 'Chain', cell: (r) => r.chain_name },
    { header: 'Sites', cell: (r) => r.sites },
    { header: 'Critical', cell: (r) => r.critical_count },
    { header: 'Short', cell: (r) => r.short_count },
    { header: 'Healthy', cell: (r) => r.healthy_count },
    { header: 'Total Gap', cell: (r) => r.total_gap },
  ];

  const critCols: Column<CriticalFixture>[] = [
    { header: 'Chain', cell: (r) => r.chain_name },
    { header: 'Site', cell: (r) => r.hospital_site },
    { header: 'OT', cell: (r) => r.ot_room_code },
    { header: 'Fixture', cell: (r) => r.fixture_type },
    { header: 'Model', cell: (r) => r.bulb_model },
    { header: 'Gap', cell: (r) => r.reserve_gap },
    { header: 'Burn hrs', cell: (r) => r.mean_burn_hours },
  ];

  const mixCols: Column<FixtureMix>[] = [
    { header: 'Fixture', cell: (r) => r.fixture_type },
    { header: 'Audits', cell: (r) => r.audits },
    { header: 'Avg Burn hrs', cell: (r) => r.avg_burn_hours },
    { header: 'Short+', cell: (r) => r.short_or_worse },
  ];

  const sigCols: Column<OpenSignal>[] = [
    { header: 'Chain', cell: (r) => r.chain_name },
    { header: 'Site', cell: (r) => r.hospital_site },
    { header: 'SKU', cell: (r) => r.bulb_sku },
    { header: 'Kind', cell: (r) => r.signal_kind },
    { header: 'Urgency', cell: (r) => r.urgency },
    { header: 'Qty', cell: (r) => r.recommended_qty },
    { header: 'Unit ₹', cell: (r) => r.unit_cost_rupees },
    { header: 'Lead d', cell: (r) => r.lead_time_days },
    { header: 'Vendor', cell: (r) => r.vendor_name },
  ];

  const spendCols: Column<SpendForecast>[] = [
    { header: 'Chain', cell: (r) => r.chain_name },
    { header: 'Open', cell: (r) => r.open_signals },
    { header: 'Projected ₹', cell: (r) => r.projected_rupees },
    { header: 'Max Lead d', cell: (r) => r.max_lead_days },
  ];

  const vendCols: Column<VendorConc>[] = [
    { header: 'Vendor', cell: (r) => r.vendor_name },
    { header: 'SKUs', cell: (r) => r.skus },
    { header: 'Open', cell: (r) => r.open_signals },
    { header: 'Total ₹', cell: (r) => r.total_rupees },
  ];

  const agingCols: Column<AgingRisk>[] = [
    { header: 'Chain', cell: (r) => r.chain_name },
    { header: 'Site', cell: (r) => r.hospital_site },
    { header: 'Model', cell: (r) => r.bulb_model },
    { header: 'Days since replace', cell: (r) => r.days_since_replace },
    { header: 'Burn hrs', cell: (r) => r.mean_burn_hours },
    { header: 'Status', cell: (r) => r.status },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 28 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Hospital Chain Quarterly OT-Light & Surgical-Microscope Bulb Reserve Audit</h1>
        <p style={{ color: '#666', marginTop: 4 }}>Round r2971 — reserve gaps, reorder signals & vendor concentration across OT fixtures.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Chain Summary</h2>
        <DataTable rows={chainSummary} columns={chainCols} emptyMessage="No chain rows" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Critical & Expired Fixtures</h2>
        <DataTable rows={critical} columns={critCols} emptyMessage="No critical fixtures" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Fixture Type Mix</h2>
        <DataTable rows={fixtureMix} columns={mixCols} emptyMessage="No mix data" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Open Reorder Signals</h2>
        <DataTable rows={openSignals} columns={sigCols} emptyMessage="No open signals" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Spend Forecast by Chain</h2>
        <DataTable rows={spend} columns={spendCols} emptyMessage="No forecast" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Vendor Concentration</h2>
        <DataTable rows={vendors} columns={vendCols} emptyMessage="No vendors" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Aging Risk (Burn hrs &gt;= 800)</h2>
        <DataTable rows={aging} columns={agingCols} emptyMessage="No aging risk" rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}