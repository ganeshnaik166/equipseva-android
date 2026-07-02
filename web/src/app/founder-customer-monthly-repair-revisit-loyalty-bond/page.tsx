import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Column<T> = {
  key: string;
  header: string;
  render?: (row: T) => React.ReactNode;
};

type PatternRow = {
  id: string;
  hospital_name: string;
  city: string;
  snapshot_month: string;
  repair_jobs_count: number;
  unique_devices_serviced: number;
  repeat_device_visits: number;
  avg_days_between_visits: number;
  total_billed_rupees: number;
  satisfaction_avg: number;
  on_time_completion_pct: number;
  escalation_count: number;
  loyalty_score: number;
  revisit_pattern: string;
  churn_risk: string;
  notes: string | null;
};

type ChurnRow = {
  id: string;
  hospital_name: string;
  city: string;
  snapshot_month: string;
  repair_jobs_count: number;
  loyalty_score: number;
  revisit_pattern: string;
  churn_risk: string;
  notes: string | null;
};

type BondRow = {
  id: string;
  hospital_name: string;
  city: string;
  bond_tier: string;
  bond_term_months: number;
  discount_pct: number;
  min_monthly_jobs: number;
  monthly_commit_rupees: number;
  total_bond_value_rupees: number;
  offer_status: string;
  signed_at: string | null;
  declined_reason: string | null;
  projected_ltv_uplift_rupees: number;
  expires_at: string;
};

type CadenceRow = {
  bucket: string;
  hospital_count: number;
  avg_loyalty: number;
  total_billed_rupees: number;
};

type TrendRow = {
  hospital_name: string;
  snapshot_month: string;
  repair_jobs_count: number;
  total_billed_rupees: number;
  loyalty_score: number;
  revisit_pattern: string;
};

type TierRow = {
  bond_tier: string;
  offers_count: number;
  signed_count: number;
  pending_count: number;
  total_value_rupees: number;
  projected_uplift_rupees: number;
  avg_discount_pct: number;
};

type ActionRow = {
  priority: number;
  hospital_name: string;
  action: string;
  rationale: string;
  est_value_rupees: number;
};

type KpiRow = {
  hospitals_tracked: number;
  total_jobs_this_month: number;
  total_billed_this_month: number;
  avg_loyalty_score: number;
  high_risk_hospitals: number;
  compounding_hospitals: number;
  signed_bonds: number;
  pending_bonds: number;
  total_bond_value_rupees: number;
  projected_ltv_uplift_rupees: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  return new Date(s).toISOString().slice(0, 10);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, patternRes, churnRes, bondRes, cadenceRes, trendRes, tierRes, actionRes] = await Promise.all([
    supabase.rpc('rpc_r2888_kpi_summary'),
    supabase.rpc('rpc_r2888_revisit_pattern_list', { p_month: null }),
    supabase.rpc('rpc_r2888_churn_watch'),
    supabase.rpc('rpc_r2888_bond_offers_list'),
    supabase.rpc('rpc_r2888_revisit_cadence_buckets'),
    supabase.rpc('rpc_r2888_top_account_trend'),
    supabase.rpc('rpc_r2888_bond_tier_rollup'),
    supabase.rpc('rpc_r2888_founder_action_list'),
  ]);

  const kpi: KpiRow | null = (kpiRes.data as KpiRow[] | null)?.[0] ?? null;
  const patternRows: PatternRow[] = (patternRes.data as PatternRow[] | null) ?? [];
  const churnRows: ChurnRow[] = (churnRes.data as ChurnRow[] | null) ?? [];
  const bondRows: BondRow[] = (bondRes.data as BondRow[] | null) ?? [];
  const cadenceRows: CadenceRow[] = (cadenceRes.data as CadenceRow[] | null) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[] | null) ?? [];
  const tierRows: TierRow[] = (tierRes.data as TierRow[] | null) ?? [];
  const actionRows: ActionRow[] = (actionRes.data as ActionRow[] | null) ?? [];

  const patternColumns: Column<PatternRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'snapshot_month', header: 'Month', render: (r) => fmtDate(r.snapshot_month) },
    { key: 'repair_jobs_count', header: 'Jobs', render: (r) => r.repair_jobs_count },
    { key: 'repeat_device_visits', header: 'Re-visits', render: (r) => r.repeat_device_visits },
    { key: 'avg_days_between_visits', header: 'Avg days/visit', render: (r) => Number(r.avg_days_between_visits).toFixed(1) },
    { key: 'total_billed_rupees', header: 'Billed', render: (r) => fmtRupees(r.total_billed_rupees) },
    { key: 'loyalty_score', header: 'Loyalty', render: (r) => Number(r.loyalty_score).toFixed(1) },
    { key: 'revisit_pattern', header: 'Pattern', render: (r) => r.revisit_pattern },
    { key: 'churn_risk', header: 'Churn risk', render: (r) => r.churn_risk },
  ];

  const churnColumns: Column<ChurnRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'repair_jobs_count', header: 'Jobs this month', render: (r) => r.repair_jobs_count },
    { key: 'loyalty_score', header: 'Loyalty', render: (r) => Number(r.loyalty_score).toFixed(1) },
    { key: 'revisit_pattern', header: 'Pattern', render: (r) => r.revisit_pattern },
    { key: 'churn_risk', header: 'Risk', render: (r) => r.churn_risk },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '-' },
  ];

  const bondColumns: Column<BondRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'bond_tier', header: 'Tier', render: (r) => r.bond_tier },
    { key: 'bond_term_months', header: 'Term (mo)', render: (r) => r.bond_term_months },
    { key: 'discount_pct', header: 'Discount %', render: (r) => Number(r.discount_pct).toFixed(1) },
    { key: 'min_monthly_jobs', header: 'Min jobs/mo', render: (r) => r.min_monthly_jobs },
    { key: 'monthly_commit_rupees', header: 'Monthly commit', render: (r) => fmtRupees(r.monthly_commit_rupees) },
    { key: 'total_bond_value_rupees', header: 'Bond value', render: (r) => fmtRupees(r.total_bond_value_rupees) },
    { key: 'projected_ltv_uplift_rupees', header: 'LTV uplift', render: (r) => fmtRupees(r.projected_ltv_uplift_rupees) },
    { key: 'offer_status', header: 'Status', render: (r) => r.offer_status },
    { key: 'expires_at', header: 'Expires', render: (r) => fmtDate(r.expires_at) },
  ];

  const cadenceColumns: Column<CadenceRow>[] = [
    { key: 'bucket', header: 'Cadence bucket', render: (r) => r.bucket },
    { key: 'hospital_count', header: 'Hospitals', render: (r) => r.hospital_count },
    { key: 'avg_loyalty', header: 'Avg loyalty', render: (r) => Number(r.avg_loyalty).toFixed(1) },
    { key: 'total_billed_rupees', header: 'Billed', render: (r) => fmtRupees(r.total_billed_rupees) },
  ];

  const trendColumns: Column<TrendRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'snapshot_month', header: 'Month', render: (r) => fmtDate(r.snapshot_month) },
    { key: 'repair_jobs_count', header: 'Jobs', render: (r) => r.repair_jobs_count },
    { key: 'total_billed_rupees', header: 'Billed', render: (r) => fmtRupees(r.total_billed_rupees) },
    { key: 'loyalty_score', header: 'Loyalty', render: (r) => Number(r.loyalty_score).toFixed(1) },
    { key: 'revisit_pattern', header: 'Pattern', render: (r) => r.revisit_pattern },
  ];

  const tierColumns: Column<TierRow>[] = [
    { key: 'bond_tier', header: 'Tier', render: (r) => r.bond_tier },
    { key: 'offers_count', header: 'Offers', render: (r) => r.offers_count },
    { key: 'signed_count', header: 'Signed', render: (r) => r.signed_count },
    { key: 'pending_count', header: 'Pending', render: (r) => r.pending_count },
    { key: 'total_value_rupees', header: 'Total value', render: (r) => fmtRupees(r.total_value_rupees) },
    { key: 'projected_uplift_rupees', header: 'Projected uplift', render: (r) => fmtRupees(r.projected_uplift_rupees) },
    { key: 'avg_discount_pct', header: 'Avg discount %', render: (r) => Number(r.avg_discount_pct).toFixed(2) },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: 'priority', header: 'Priority', render: (r) => r.priority },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'action', header: 'Action', render: (r) => r.action },
    { key: 'rationale', header: 'Why', render: (r) => r.rationale },
    { key: 'est_value_rupees', header: 'Est value', render: (r) => fmtRupees(r.est_value_rupees) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>
          Customer Monthly Repair-Job Re-Visit Pattern & Loyalty Bond
        </h1>
        <p style={{ color: '#555', marginTop: 8, fontSize: 15, lineHeight: 1.5 }}>
          Founder console r2888 — which hospitals keep coming back, how fast, and where loyalty bonds
          should be offered. A hospital that re-visits the same device under 30 days is a compounding
          account; cadence &gt;= 40 days is fading. Bonds convert repeat behavior into committed revenue.
        </p>
      </header>

      {kpi && (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
          <KpiCard label="Hospitals tracked" value={String(kpi.hospitals_tracked)} />
          <KpiCard label="Jobs (this month)" value={String(kpi.total_jobs_this_month)} />
          <KpiCard label="Billed (this month)" value={fmtRupees(kpi.total_billed_this_month)} />
          <KpiCard label="Avg loyalty score" value={Number(kpi.avg_loyalty_score).toFixed(1)} />
          <KpiCard label="Compounding accounts" value={String(kpi.compounding_hospitals)} />
          <KpiCard label="High-risk churn" value={String(kpi.high_risk_hospitals)} tone="warn" />
          <KpiCard label="Signed bonds" value={String(kpi.signed_bonds)} />
          <KpiCard label="Pending bonds" value={String(kpi.pending_bonds)} />
          <KpiCard label="Signed bond value" value={fmtRupees(kpi.total_bond_value_rupees)} />
          <KpiCard label="Projected LTV uplift" value={fmtRupees(kpi.projected_ltv_uplift_rupees)} />
        </section>
      )}

      <Section title="Founder action list" subtitle="Highest-leverage moves this week, ranked.">
        <DataTable
          rows={actionRows}
          columns={actionColumns}
          emptyMessage="No actions queued."
          rowKey={(r, i) => String((r as ActionRow).hospital_name + '-' + i)}
        />
      </Section>

      <Section title="Churn watch" subtitle="Hospitals trending below loyalty threshold or fading cadence.">
        <DataTable
          rows={churnRows}
          columns={churnColumns}
          emptyMessage="No churn-risk hospitals — clean month."
          rowKey={(r, i) => String((r as ChurnRow).id ?? i)}
        />
      </Section>

      <Section title="Monthly revisit pattern (all snapshots)" subtitle="Per-hospital monthly behavior — jobs, re-visits, cadence, loyalty.">
        <DataTable
          rows={patternRows}
          columns={patternColumns}
          emptyMessage="No revisit data yet."
          rowKey={(r, i) => String((r as PatternRow).id ?? i)}
        />
      </Section>

      <Section title="Revisit cadence buckets" subtitle="How tight the average days-between-visit is across the base.">
        <DataTable
          rows={cadenceRows}
          columns={cadenceColumns}
          emptyMessage="No cadence buckets."
          rowKey={(r, i) => String((r as CadenceRow).bucket + '-' + i)}
        />
      </Section>

      <Section title="Top account 3-month trend" subtitle="Top 6 accounts by billed — month-over-month direction.">
        <DataTable
          rows={trendRows}
          columns={trendColumns}
          emptyMessage="No trend data."
          rowKey={(r, i) => String((r as TrendRow).hospital_name + '-' + (r as TrendRow).snapshot_month + '-' + i)}
        />
      </Section>

      <Section title="Loyalty bond offers" subtitle="Bond tier, term, discount, and pipeline status per hospital.">
        <DataTable
          rows={bondRows}
          columns={bondColumns}
          emptyMessage="No bond offers issued."
          rowKey={(r, i) => String((r as BondRow).id ?? i)}
        />
      </Section>

      <Section title="Bond tier rollup" subtitle="How signed-vs-pending stacks up across tiers.">
        <DataTable
          rows={tierRows}
          columns={tierColumns}
          emptyMessage="No bond tiers."
          rowKey={(r, i) => String((r as TierRow).bond_tier + '-' + i)}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: string; tone?: 'warn' | 'ok' }) {
  const border = tone === 'warn' ? '#f59e0b' : '#e5e7eb';
  const bg = tone === 'warn' ? '#fffbeb' : '#ffffff';
  return (
    <div style={{ border: `1px solid ${border}`, background: bg, borderRadius: 10, padding: 14 }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 6 }}>{value}</div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 700, margin: 0 }}>{title}</h2>
      <p style={{ color: '#6b7280', fontSize: 13, marginTop: 4, marginBottom: 12 }}>{subtitle}</p>
      {children}
    </section>
  );
}
