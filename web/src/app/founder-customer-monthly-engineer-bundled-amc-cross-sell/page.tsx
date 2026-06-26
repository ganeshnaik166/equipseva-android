import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  active_opportunities: number;
  total_pipeline_value_rupees: number;
  weighted_pipeline_value_rupees: number;
  avg_close_probability_pct: number;
  won_count: number;
  lost_count: number;
};

type Opportunity = {
  id: string;
  customer_name: string;
  engineer_name: string;
  bundle_name: string;
  device_count: number;
  proposed_amc_value_rupees: number;
  close_probability_pct: number;
  opportunity_stage: string;
  cross_sell_status: string;
  refine_action: string;
};

type StageRow = {
  opportunity_stage: string;
  opp_count: number;
  stage_pipeline_value_rupees: number;
  avg_close_probability_pct: number;
};

type EngineerRow = {
  engineer_code: string;
  engineer_name: string;
  opp_count: number;
  weighted_pipeline_value_rupees: number;
  best_stage: string;
};

type ForecastRow = {
  forecast_month: string;
  play_count: number;
  expected_value_rupees: number;
  weighted_value_rupees: number;
  avg_renew_probability_pct: number;
};

type PlayRow = {
  customer_name: string;
  refine_play: string;
  expected_renew_value_rupees: number;
  renew_probability_pct: number;
  play_owner: string;
  play_status: string;
  play_notes: string;
};

type BundleRoiRow = {
  bundle_code: string;
  bundle_name: string;
  opp_count: number;
  total_devices: number;
  monthly_bundle_value_rupees: number;
  proposed_amc_value_rupees: number;
  amc_to_bundle_multiple: number;
};

function formatRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function formatPct(n: number | null | undefined): string {
  if (n == null) return '-';
  return Number(n).toFixed(1) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpiRes,
    oppsRes,
    funnelRes,
    engineerRes,
    forecastRes,
    playsRes,
    bundleRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2856_kpis'),
    supabase.rpc('founder_r2856_list_opportunities'),
    supabase.rpc('founder_r2856_stage_funnel'),
    supabase.rpc('founder_r2856_engineer_leaderboard'),
    supabase.rpc('founder_r2856_renewal_forecast'),
    supabase.rpc('founder_r2856_refine_plays'),
    supabase.rpc('founder_r2856_bundle_roi'),
  ]);

  const kpi: Kpi | null = (kpiRes.data && kpiRes.data[0]) || null;
  const opps: Opportunity[] = oppsRes.data || [];
  const funnel: StageRow[] = funnelRes.data || [];
  const engineers: EngineerRow[] = engineerRes.data || [];
  const forecast: ForecastRow[] = forecastRes.data || [];
  const plays: PlayRow[] = playsRes.data || [];
  const bundles: BundleRoiRow[] = bundleRes.data || [];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, margin: 0 }}>
          Customer Monthly Engineer Bundled AMC Cross-Sell
        </h1>
        <p style={{ color: '#555', marginTop: '6px' }}>
          Round 2856 · Customer × Bundle × Engineer × Close × Value × Renew × Refine
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: '12px',
          marginBottom: '28px',
        }}
      >
        <KpiCard label="Active Opportunities" value={kpi ? String(kpi.active_opportunities) : '-'} />
        <KpiCard label="Total Pipeline" value={formatRupees(kpi?.total_pipeline_value_rupees)} />
        <KpiCard label="Weighted Pipeline" value={formatRupees(kpi?.weighted_pipeline_value_rupees)} />
        <KpiCard label="Avg Close Probability" value={formatPct(kpi?.avg_close_probability_pct)} />
        <KpiCard label="Won" value={kpi ? String(kpi.won_count) : '-'} />
        <KpiCard label="Lost" value={kpi ? String(kpi.lost_count) : '-'} />
      </section>

      <Section title="Opportunities (Customer x Bundle x Engineer)">
        <DataTable
          rows={opps}
          columns={[
            { key: 'customer_name', header: 'Customer', render: (r: Opportunity) => r.customer_name },
            { key: 'bundle_name', header: 'Bundle', render: (r: Opportunity) => r.bundle_name },
            { key: 'engineer_name', header: 'Engineer', render: (r: Opportunity) => r.engineer_name },
            { key: 'device_count', header: 'Devices', render: (r: Opportunity) => String(r.device_count) },
            {
              key: 'proposed_amc_value_rupees',
              header: 'Proposed AMC',
              render: (r: Opportunity) => formatRupees(r.proposed_amc_value_rupees),
            },
            {
              key: 'close_probability_pct',
              header: 'Close %',
              render: (r: Opportunity) => formatPct(r.close_probability_pct),
            },
            { key: 'opportunity_stage', header: 'Stage', render: (r: Opportunity) => r.opportunity_stage },
            { key: 'cross_sell_status', header: 'Status', render: (r: Opportunity) => r.cross_sell_status },
            { key: 'refine_action', header: 'Refine Action', render: (r: Opportunity) => r.refine_action },
          ]}
          emptyMessage="No data"
          rowKey={(r: Opportunity, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Stage Funnel">
        <DataTable
          rows={funnel}
          columns={[
            { key: 'opportunity_stage', header: 'Stage', render: (r: StageRow) => r.opportunity_stage },
            { key: 'opp_count', header: 'Count', render: (r: StageRow) => String(r.opp_count) },
            {
              key: 'stage_pipeline_value_rupees',
              header: 'Pipeline Value',
              render: (r: StageRow) => formatRupees(r.stage_pipeline_value_rupees),
            },
            {
              key: 'avg_close_probability_pct',
              header: 'Avg Close %',
              render: (r: StageRow) => formatPct(r.avg_close_probability_pct),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: StageRow, i: number) => String(r.opportunity_stage ?? i)}
        />
      </Section>

      <Section title="Engineer Leaderboard">
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: EngineerRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => r.engineer_name },
            { key: 'opp_count', header: 'Opportunities', render: (r: EngineerRow) => String(r.opp_count) },
            {
              key: 'weighted_pipeline_value_rupees',
              header: 'Weighted Pipeline',
              render: (r: EngineerRow) => formatRupees(r.weighted_pipeline_value_rupees),
            },
            { key: 'best_stage', header: 'Top Stage', render: (r: EngineerRow) => r.best_stage },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer_code ?? i)}
        />
      </Section>

      <Section title="Renewal Forecast">
        <DataTable
          rows={forecast}
          columns={[
            { key: 'forecast_month', header: 'Month', render: (r: ForecastRow) => r.forecast_month },
            { key: 'play_count', header: 'Plays', render: (r: ForecastRow) => String(r.play_count) },
            {
              key: 'expected_value_rupees',
              header: 'Expected',
              render: (r: ForecastRow) => formatRupees(r.expected_value_rupees),
            },
            {
              key: 'weighted_value_rupees',
              header: 'Weighted',
              render: (r: ForecastRow) => formatRupees(r.weighted_value_rupees),
            },
            {
              key: 'avg_renew_probability_pct',
              header: 'Avg Renew %',
              render: (r: ForecastRow) => formatPct(r.avg_renew_probability_pct),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: ForecastRow, i: number) => String(r.forecast_month ?? i)}
        />
      </Section>

      <Section title="Refine Plays">
        <DataTable
          rows={plays}
          columns={[
            { key: 'customer_name', header: 'Customer', render: (r: PlayRow) => r.customer_name },
            { key: 'refine_play', header: 'Play', render: (r: PlayRow) => r.refine_play },
            {
              key: 'expected_renew_value_rupees',
              header: 'Expected Renew',
              render: (r: PlayRow) => formatRupees(r.expected_renew_value_rupees),
            },
            {
              key: 'renew_probability_pct',
              header: 'Renew %',
              render: (r: PlayRow) => formatPct(r.renew_probability_pct),
            },
            { key: 'play_owner', header: 'Owner', render: (r: PlayRow) => r.play_owner },
            { key: 'play_status', header: 'Status', render: (r: PlayRow) => r.play_status },
            { key: 'play_notes', header: 'Notes', render: (r: PlayRow) => r.play_notes },
          ]}
          emptyMessage="No data"
          rowKey={(r: PlayRow, i: number) => String(i)}
        />
      </Section>

      <Section title="Bundle ROI (AMC vs Monthly Bundle)">
        <DataTable
          rows={bundles}
          columns={[
            { key: 'bundle_code', header: 'Code', render: (r: BundleRoiRow) => r.bundle_code },
            { key: 'bundle_name', header: 'Bundle', render: (r: BundleRoiRow) => r.bundle_name },
            { key: 'opp_count', header: 'Opps', render: (r: BundleRoiRow) => String(r.opp_count) },
            { key: 'total_devices', header: 'Devices', render: (r: BundleRoiRow) => String(r.total_devices) },
            {
              key: 'monthly_bundle_value_rupees',
              header: 'Monthly Value',
              render: (r: BundleRoiRow) => formatRupees(r.monthly_bundle_value_rupees),
            },
            {
              key: 'proposed_amc_value_rupees',
              header: 'AMC Value',
              render: (r: BundleRoiRow) => formatRupees(r.proposed_amc_value_rupees),
            },
            {
              key: 'amc_to_bundle_multiple',
              header: 'AMC x Bundle',
              render: (r: BundleRoiRow) => Number(r.amc_to_bundle_multiple).toFixed(2) + 'x',
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: BundleRoiRow, i: number) => String(r.bundle_code ?? i)}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        background: '#fff',
        border: '1px solid #e5e7eb',
        borderRadius: '10px',
        padding: '14px 16px',
        boxShadow: '0 1px 2px rgba(0,0,0,0.04)',
      }}
    >
      <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
        {label}
      </div>
      <div style={{ fontSize: '22px', fontWeight: 700, marginTop: '6px' }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '28px' }}>
      <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '10px' }}>{title}</h2>
      {children}
    </section>
  );
}
