import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Revision = {
  id: string;
  quarter: string;
  tier_name: string;
  old_price_rupees: number;
  new_price_rupees: number;
  pct_change: number;
  rationale: string;
  effective_date: string;
  approved_by: string;
  status: string;
};

type Outcome = {
  id: string;
  revision_quarter: string;
  tier_name: string;
  customers_impacted: number;
  churn_pct: number;
  upsell_pct: number;
  revenue_delta_rupees: number;
  nps_delta: number;
  outcome_label: string;
  notes: string;
  measured_at: string;
};

type Kpi = {
  total_revisions: number;
  live_revisions: number;
  proposed_revisions: number;
  rolled_back: number;
  total_revenue_delta: number;
  avg_pct_change: number;
};

type ByTier = {
  tier_name: string;
  revision_count: number;
  latest_price: number;
  total_delta: number;
  avg_churn: number;
  avg_upsell: number;
};

type ByQuarter = {
  quarter: string;
  revision_count: number;
  avg_pct_change: number;
  total_delta: number;
  wins: number;
  losses: number;
};

type Win = {
  tier_name: string;
  revision_quarter: string;
  revenue_delta_rupees: number;
  upsell_pct: number;
  nps_delta: number;
  notes: string;
};

type Rollback = {
  tier_name: string;
  quarter: string;
  old_price_rupees: number;
  new_price_rupees: number;
  pct_change: number;
  rationale: string;
};

function rupees(n: number | null | undefined) {
  if (n === null || n === undefined) return '₹0';
  const sign = n < 0 ? '-' : '';
  return sign + '₹' + Math.abs(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined) {
  if (n === null || n === undefined) return '0%';
  return `${n.toFixed(2)}%`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [revRes, outRes, kpiRes, tierRes, qtrRes, winRes, rbRes] = await Promise.all([
    supabase.rpc('founder_pricing_revisions_list_r2833'),
    supabase.rpc('founder_pricing_outcomes_list_r2833'),
    supabase.rpc('founder_pricing_kpi_summary_r2833'),
    supabase.rpc('founder_pricing_by_tier_r2833'),
    supabase.rpc('founder_pricing_by_quarter_r2833'),
    supabase.rpc('founder_pricing_top_wins_r2833'),
    supabase.rpc('founder_pricing_rollbacks_r2833'),
  ]);

  const revisions: Revision[] = (revRes.data as Revision[]) ?? [];
  const outcomes: Outcome[] = (outRes.data as Outcome[]) ?? [];
  const kpi: Kpi = ((kpiRes.data as Kpi[])?.[0]) ?? {
    total_revisions: 0, live_revisions: 0, proposed_revisions: 0,
    rolled_back: 0, total_revenue_delta: 0, avg_pct_change: 0,
  };
  const byTier: ByTier[] = (tierRes.data as ByTier[]) ?? [];
  const byQuarter: ByQuarter[] = (qtrRes.data as ByQuarter[]) ?? [];
  const wins: Win[] = (winRes.data as Win[]) ?? [];
  const rollbacks: Rollback[] = (rbRes.data as Rollback[]) ?? [];

  return (
    <main style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>
          Quarterly Pricing Tier Revision History
        </h1>
        <p style={{ color: '#64748b', marginTop: 6 }}>
          Tier × old price × new price × rationale × customer impact × outcome — r2833
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total revisions" value={String(kpi.total_revisions ?? 0)} />
        <KpiCard label="Live" value={String(kpi.live_revisions ?? 0)} />
        <KpiCard label="Proposed" value={String(kpi.proposed_revisions ?? 0)} />
        <KpiCard label="Rolled back" value={String(kpi.rolled_back ?? 0)} />
        <KpiCard label="Revenue delta" value={rupees(kpi.total_revenue_delta)} />
        <KpiCard label="Avg pct change" value={pct(kpi.avg_pct_change)} />
      </section>

      <Section title="Revision log (price moves quarter over quarter)">
        <DataTable
          rows={revisions}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: Revision) => r.quarter },
            { key: 'tier_name', header: 'Tier', render: (r: Revision) => r.tier_name },
            { key: 'old', header: 'Old price', render: (r: Revision) => rupees(r.old_price_rupees) },
            { key: 'new', header: 'New price', render: (r: Revision) => rupees(r.new_price_rupees) },
            { key: 'pct', header: '% change', render: (r: Revision) => pct(r.pct_change) },
            { key: 'rationale', header: 'Rationale', render: (r: Revision) => r.rationale },
            { key: 'eff', header: 'Effective', render: (r: Revision) => r.effective_date },
            { key: 'status', header: 'Status', render: (r: Revision) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: Revision, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="By tier (latest price & cumulative impact)">
        <DataTable
          rows={byTier}
          columns={[
            { key: 'tier', header: 'Tier', render: (r: ByTier) => r.tier_name },
            { key: 'cnt', header: 'Revisions', render: (r: ByTier) => String(r.revision_count) },
            { key: 'latest', header: 'Latest price', render: (r: ByTier) => rupees(r.latest_price) },
            { key: 'delta', header: 'Revenue delta', render: (r: ByTier) => rupees(r.total_delta) },
            { key: 'churn', header: 'Avg churn', render: (r: ByTier) => pct(r.avg_churn) },
            { key: 'ups', header: 'Avg upsell', render: (r: ByTier) => pct(r.avg_upsell) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByTier, i: number) => String(r.tier_name ?? i)}
        />
      </Section>

      <Section title="By quarter (wins vs losses)">
        <DataTable
          rows={byQuarter}
          columns={[
            { key: 'q', header: 'Quarter', render: (r: ByQuarter) => r.quarter },
            { key: 'cnt', header: 'Revisions', render: (r: ByQuarter) => String(r.revision_count) },
            { key: 'apct', header: 'Avg % change', render: (r: ByQuarter) => pct(r.avg_pct_change) },
            { key: 'delta', header: 'Revenue delta', render: (r: ByQuarter) => rupees(r.total_delta) },
            { key: 'win', header: 'Wins', render: (r: ByQuarter) => String(r.wins) },
            { key: 'loss', header: 'Losses', render: (r: ByQuarter) => String(r.losses) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByQuarter, i: number) => String(r.quarter ?? i)}
        />
      </Section>

      <Section title="Outcomes (customer impact per revision)">
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'q', header: 'Quarter', render: (r: Outcome) => r.revision_quarter },
            { key: 'tier', header: 'Tier', render: (r: Outcome) => r.tier_name },
            { key: 'cust', header: 'Customers', render: (r: Outcome) => String(r.customers_impacted) },
            { key: 'churn', header: 'Churn', render: (r: Outcome) => pct(r.churn_pct) },
            { key: 'ups', header: 'Upsell', render: (r: Outcome) => pct(r.upsell_pct) },
            { key: 'rev', header: 'Revenue delta', render: (r: Outcome) => rupees(r.revenue_delta_rupees) },
            { key: 'nps', header: 'NPS delta', render: (r: Outcome) => r.nps_delta.toFixed(2) },
            { key: 'label', header: 'Outcome', render: (r: Outcome) => r.outcome_label },
            { key: 'measured', header: 'Measured', render: (r: Outcome) => r.measured_at },
          ]}
          emptyMessage="No data"
          rowKey={(r: Outcome, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Top wins (highest revenue delta)">
        <DataTable
          rows={wins}
          columns={[
            { key: 'tier', header: 'Tier', render: (r: Win) => r.tier_name },
            { key: 'q', header: 'Quarter', render: (r: Win) => r.revision_quarter },
            { key: 'rev', header: 'Revenue delta', render: (r: Win) => rupees(r.revenue_delta_rupees) },
            { key: 'ups', header: 'Upsell', render: (r: Win) => pct(r.upsell_pct) },
            { key: 'nps', header: 'NPS delta', render: (r: Win) => r.nps_delta.toFixed(2) },
            { key: 'notes', header: 'Notes', render: (r: Win) => r.notes },
          ]}
          emptyMessage="No data"
          rowKey={(r: Win, i: number) => String(`${r.tier_name}-${r.revision_quarter}-${i}`)}
        />
      </Section>

      <Section title="Rolled-back revisions (what didn’t work)">
        <DataTable
          rows={rollbacks}
          columns={[
            { key: 'tier', header: 'Tier', render: (r: Rollback) => r.tier_name },
            { key: 'q', header: 'Quarter', render: (r: Rollback) => r.quarter },
            { key: 'old', header: 'Old price', render: (r: Rollback) => rupees(r.old_price_rupees) },
            { key: 'new', header: 'New price', render: (r: Rollback) => rupees(r.new_price_rupees) },
            { key: 'pct', header: '% change', render: (r: Rollback) => pct(r.pct_change) },
            { key: 'rationale', header: 'Rationale', render: (r: Rollback) => r.rationale },
          ]}
          emptyMessage="No data"
          rowKey={(r: Rollback, i: number) => String(`${r.tier_name}-${r.quarter}-${i}`)}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: 12, padding: 16 }}>
      <div style={{ fontSize: 12, color: '#64748b', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 6 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
