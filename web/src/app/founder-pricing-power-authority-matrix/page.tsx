import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type OverviewRow = {
  sku_code: string;
  service_category: string;
  customer_tier: string;
  list_price_rupees: number;
  ceiling_price_rupees: number;
  floor_price_rupees: number;
  avg_realized_price_rupees: number | null;
  leakage_vs_list_pct: number | null;
  pricing_power_score: number | null;
  win_rate_pct: number;
  notes: string | null;
};

type LeakageByCatRow = {
  service_category: string;
  sku_count: number;
  avg_list_price: number;
  avg_realized_price: number;
  avg_leakage_pct: number;
  total_quotes_issued: number;
  total_quotes_won: number;
  category_win_rate_pct: number;
};

type PowerByTierRow = {
  customer_tier: string;
  sku_count: number;
  avg_pricing_power_score: number;
  avg_leakage_pct: number;
  avg_win_rate_pct: number;
  total_realized_rupees: number;
};

type EnvelopeRow = {
  sku_code: string;
  service_category: string;
  customer_tier: string;
  floor_price_rupees: number;
  list_price_rupees: number;
  ceiling_price_rupees: number;
  ceiling_premium_pct: number;
  floor_discount_pct: number;
  cogs_rupees: number;
  floor_margin_pct: number;
};

type BreachLogRow = {
  quote_reference: string;
  sku_code: string;
  requested_discount_pct: number;
  approved_discount_pct: number | null;
  authority_level_required: string;
  authority_level_used: string;
  breach_severity: string;
  margin_impact_rupees: number;
  resolution_status: string;
  decided_at: string | null;
};

type SeverityRollupRow = {
  breach_severity: string;
  breach_count: number;
  total_margin_impact_rupees: number;
  avg_requested_discount_pct: number;
  pending_count: number;
  writeoff_count: number;
};

type AuthorityRow = {
  authority_level_required: string;
  total_breaches: number;
  within_authority_count: number;
  out_of_authority_count: number;
  compliance_pct: number | null;
  total_margin_loss_rupees: number;
};

type TopLeakageRow = {
  sku_code: string;
  service_category: string;
  customer_tier: string;
  leakage_vs_list_pct: number;
  margin_lost_rupees: number;
  quotes_won_qty: number;
  pricing_power_score: number | null;
  notes: string | null;
};

const inr = (n: number | null | undefined) =>
  n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');

const pct = (n: number | null | undefined) =>
  n == null ? '-' : Number(n).toFixed(2) + '%';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    overviewRes,
    leakageCatRes,
    powerTierRes,
    envelopeRes,
    breachLogRes,
    severityRes,
    authorityRes,
    topLeakageRes,
  ] = await Promise.all([
    supabase.rpc('pricing_power_matrix_overview_r3127'),
    supabase.rpc('pricing_leakage_by_category_r3127'),
    supabase.rpc('pricing_power_by_tier_r3127'),
    supabase.rpc('floor_ceiling_envelope_r3127'),
    supabase.rpc('discount_breach_log_r3127'),
    supabase.rpc('breach_severity_rollup_r3127'),
    supabase.rpc('authority_ladder_compliance_r3127'),
    supabase.rpc('pricing_power_top_leakage_skus_r3127'),
  ]);

  const overview = (overviewRes.data ?? []) as OverviewRow[];
  const leakageCat = (leakageCatRes.data ?? []) as LeakageByCatRow[];
  const powerTier = (powerTierRes.data ?? []) as PowerByTierRow[];
  const envelope = (envelopeRes.data ?? []) as EnvelopeRow[];
  const breachLog = (breachLogRes.data ?? []) as BreachLogRow[];
  const severity = (severityRes.data ?? []) as SeverityRollupRow[];
  const authority = (authorityRes.data ?? []) as AuthorityRow[];
  const topLeakage = (topLeakageRes.data ?? []) as TopLeakageRow[];

  const overviewCols: Column<OverviewRow>[] = [
    { key: 'sku_code', header: 'SKU' },
    { key: 'service_category', header: 'Category' },
    { key: 'customer_tier', header: 'Tier' },
    { key: 'list_price_rupees', header: 'List', render: (r) => inr(r.list_price_rupees) },
    { key: 'avg_realized_price_rupees', header: 'Realized', render: (r) => inr(r.avg_realized_price_rupees) },
    { key: 'leakage_vs_list_pct', header: 'Leakage', render: (r) => pct(r.leakage_vs_list_pct) },
    { key: 'win_rate_pct', header: 'Win', render: (r) => pct(r.win_rate_pct) },
    { key: 'pricing_power_score', header: 'Power', render: (r) => (r.pricing_power_score ?? 0).toFixed(1) },
  ];

  const leakageCatCols: Column<LeakageByCatRow>[] = [
    { key: 'service_category', header: 'Category' },
    { key: 'sku_count', header: 'SKUs' },
    { key: 'avg_list_price', header: 'Avg List', render: (r) => inr(r.avg_list_price) },
    { key: 'avg_realized_price', header: 'Avg Realized', render: (r) => inr(r.avg_realized_price) },
    { key: 'avg_leakage_pct', header: 'Avg Leakage', render: (r) => pct(r.avg_leakage_pct) },
    { key: 'category_win_rate_pct', header: 'Win Rate', render: (r) => pct(r.category_win_rate_pct) },
  ];

  const powerTierCols: Column<PowerByTierRow>[] = [
    { key: 'customer_tier', header: 'Tier' },
    { key: 'sku_count', header: 'SKUs' },
    { key: 'avg_pricing_power_score', header: 'Avg Power', render: (r) => r.avg_pricing_power_score?.toFixed(1) ?? '-' },
    { key: 'avg_leakage_pct', header: 'Avg Leakage', render: (r) => pct(r.avg_leakage_pct) },
    { key: 'avg_win_rate_pct', header: 'Avg Win', render: (r) => pct(r.avg_win_rate_pct) },
    { key: 'total_realized_rupees', header: 'Realized', render: (r) => inr(r.total_realized_rupees) },
  ];

  const envelopeCols: Column<EnvelopeRow>[] = [
    { key: 'sku_code', header: 'SKU' },
    { key: 'service_category', header: 'Category' },
    { key: 'floor_price_rupees', header: 'Floor', render: (r) => inr(r.floor_price_rupees) },
    { key: 'list_price_rupees', header: 'List', render: (r) => inr(r.list_price_rupees) },
    { key: 'ceiling_price_rupees', header: 'Ceiling', render: (r) => inr(r.ceiling_price_rupees) },
    { key: 'ceiling_premium_pct', header: 'Ceiling Premium', render: (r) => pct(r.ceiling_premium_pct) },
    { key: 'floor_discount_pct', header: 'Floor Discount', render: (r) => pct(r.floor_discount_pct) },
    { key: 'floor_margin_pct', header: 'Floor Margin', render: (r) => pct(r.floor_margin_pct) },
  ];

  const breachLogCols: Column<BreachLogRow>[] = [
    { key: 'quote_reference', header: 'Quote' },
    { key: 'sku_code', header: 'SKU' },
    { key: 'requested_discount_pct', header: 'Requested', render: (r) => pct(r.requested_discount_pct) },
    { key: 'approved_discount_pct', header: 'Approved', render: (r) => pct(r.approved_discount_pct) },
    { key: 'authority_level_required', header: 'Required' },
    { key: 'authority_level_used', header: 'Used' },
    { key: 'breach_severity', header: 'Severity' },
    { key: 'margin_impact_rupees', header: 'Margin Impact', render: (r) => inr(r.margin_impact_rupees) },
    { key: 'resolution_status', header: 'Status' },
  ];

  const severityCols: Column<SeverityRollupRow>[] = [
    { key: 'breach_severity', header: 'Severity' },
    { key: 'breach_count', header: 'Count' },
    { key: 'total_margin_impact_rupees', header: 'Margin Impact', render: (r) => inr(r.total_margin_impact_rupees) },
    { key: 'avg_requested_discount_pct', header: 'Avg Requested', render: (r) => pct(r.avg_requested_discount_pct) },
    { key: 'pending_count', header: 'Pending' },
    { key: 'writeoff_count', header: 'Writeoff' },
  ];

  const authorityCols: Column<AuthorityRow>[] = [
    { key: 'authority_level_required', header: 'Required Level' },
    { key: 'total_breaches', header: 'Total' },
    { key: 'within_authority_count', header: 'Within' },
    { key: 'out_of_authority_count', header: 'Out of Authority' },
    { key: 'compliance_pct', header: 'Compliance', render: (r) => pct(r.compliance_pct) },
    { key: 'total_margin_loss_rupees', header: 'Margin Loss', render: (r) => inr(r.total_margin_loss_rupees) },
  ];

  const topLeakageCols: Column<TopLeakageRow>[] = [
    { key: 'sku_code', header: 'SKU' },
    { key: 'service_category', header: 'Category' },
    { key: 'customer_tier', header: 'Tier' },
    { key: 'leakage_vs_list_pct', header: 'Leakage', render: (r) => pct(r.leakage_vs_list_pct) },
    { key: 'margin_lost_rupees', header: 'Margin Lost', render: (r) => inr(r.margin_lost_rupees) },
    { key: 'quotes_won_qty', header: 'Won' },
    { key: 'pricing_power_score', header: 'Power', render: (r) => r.pricing_power_score?.toFixed(1) ?? '-' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-10 space-y-10">
      <header className="space-y-2">
        <h1 className="text-3xl font-semibold tracking-tight">
          Pricing Power & Discount-Approval Authority Matrix
        </h1>
        <p className="text-sm text-neutral-600">
          Quarterly founder review: list / ceiling / floor envelopes, win-rate, leakage,
          and authority-ladder breaches across the SKU portfolio.
        </p>
      </header>

      <section>
        <h2 className="text-xl font-medium mb-3">1. SKU pricing power overview</h2>
        <DataTable
          rows={overview}
          columns={overviewCols}
          emptyMessage="No SKUs in pricing matrix yet."
          rowKey={(r, i) => String(r.sku_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-medium mb-3">2. Leakage by service category</h2>
        <DataTable
          rows={leakageCat}
          columns={leakageCatCols}
          emptyMessage="No category rollup."
          rowKey={(r, i) => String(r.service_category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-medium mb-3">3. Pricing power by customer tier</h2>
        <DataTable
          rows={powerTier}
          columns={powerTierCols}
          emptyMessage="No tier rollup."
          rowKey={(r, i) => String(r.customer_tier ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-medium mb-3">4. Floor / list / ceiling envelope</h2>
        <DataTable
          rows={envelope}
          columns={envelopeCols}
          emptyMessage="No envelope rows."
          rowKey={(r, i) => String(r.sku_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-medium mb-3">5. Discount-approval breach log</h2>
        <DataTable
          rows={breachLog}
          columns={breachLogCols}
          emptyMessage="No breaches logged."
          rowKey={(r, i) => String(r.quote_reference ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-medium mb-3">6. Breach severity rollup</h2>
        <DataTable
          rows={severity}
          columns={severityCols}
          emptyMessage="No severity rollup."
          rowKey={(r, i) => String(r.breach_severity ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-medium mb-3">7. Authority-ladder compliance</h2>
        <DataTable
          rows={authority}
          columns={authorityCols}
          emptyMessage="No authority rollup."
          rowKey={(r, i) => String(r.authority_level_required ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-medium mb-3">8. Top leakage SKUs (margin lost)</h2>
        <DataTable
          rows={topLeakage}
          columns={topLeakageCols}
          emptyMessage="No leakage hotspots."
          rowKey={(r, i) => String(r.sku_code ?? i)}
        />
      </section>
    </main>
  );
}
