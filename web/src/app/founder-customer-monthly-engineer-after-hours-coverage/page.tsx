import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_customers: number;
  total_incidents: number;
  total_after_hours: number;
  total_breaches: number;
  total_credit_rupees: number;
  avg_response_min: number;
  total_engineers: number;
  total_shifts: number;
  total_no_shows: number;
  total_bonus_rupees: number;
};

type TierRow = {
  customer_tier: string;
  customer_count: number;
  incident_total: number;
  after_hours_total: number;
  breach_total: number;
  avg_response: number;
  credit_total: number;
};

type OutcomeRow = {
  outcome_status: string;
  customer_count: number;
  incident_total: number;
  credit_total: number;
};

type PolicyRow = {
  policy_band: string;
  customer_count: number;
  after_hours_total: number;
  breach_total: number;
  avg_response: number;
};

type BreachRow = {
  customer_org_name: string;
  customer_tier: string;
  policy_band: string;
  after_hours_count: number;
  sla_breach_count: number;
  avg_response_minutes: number;
  override_credit_rupees: number;
  outcome_status: string;
};

type EngineerRow = {
  engineer_name: string;
  engineer_tier: string;
  shifts_assigned: number;
  shifts_accepted: number;
  shifts_no_show: number;
  incidents_handled: number;
  avg_first_response_min: number;
  customer_csat: number;
  outcome_grade: string;
  policy_compliance_pct: number;
  on_call_bonus_rupees: number;
};

type GradeRow = {
  outcome_grade: string;
  engineer_count: number;
  shifts_total: number;
  no_show_total: number;
  incidents_total: number;
  avg_csat: number;
  bonus_total: number;
};

type ReviewRow = {
  customer_org_name: string;
  customer_tier: string;
  policy_band: string;
  outcome_status: string;
  after_hours_count: number;
  sla_breach_count: number;
  override_credit_rupees: number;
  reviewed_at: string | null;
};

function rupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

function num(n: number | null | undefined, digits = 2) {
  return Number(n ?? 0).toFixed(digits);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summary, tiers, outcomes, policies, breaches, engineers, grades, reviewQueue] =
    await Promise.all([
      supabase.rpc('founder_r2788_summary'),
      supabase.rpc('founder_r2788_customers_by_tier'),
      supabase.rpc('founder_r2788_outcome_distribution'),
      supabase.rpc('founder_r2788_policy_bands'),
      supabase.rpc('founder_r2788_top_breach_customers'),
      supabase.rpc('founder_r2788_engineer_roster'),
      supabase.rpc('founder_r2788_engineer_grade_rollup'),
      supabase.rpc('founder_r2788_policy_review_queue'),
    ]);

  const s: SummaryRow = (summary.data?.[0] ?? {
    total_customers: 0,
    total_incidents: 0,
    total_after_hours: 0,
    total_breaches: 0,
    total_credit_rupees: 0,
    avg_response_min: 0,
    total_engineers: 0,
    total_shifts: 0,
    total_no_shows: 0,
    total_bonus_rupees: 0,
  }) as SummaryRow;

  const tierRows = (tiers.data ?? []) as TierRow[];
  const outcomeRows = (outcomes.data ?? []) as OutcomeRow[];
  const policyRows = (policies.data ?? []) as PolicyRow[];
  const breachRows = (breaches.data ?? []) as BreachRow[];
  const engineerRows = (engineers.data ?? []) as EngineerRow[];
  const gradeRows = (grades.data ?? []) as GradeRow[];
  const reviewRows = (reviewQueue.data ?? []) as ReviewRow[];

  const kpis = [
    { label: 'Customers Tracked', value: String(s.total_customers) },
    { label: 'Total Incidents', value: String(s.total_incidents) },
    { label: 'After-Hours Incidents', value: String(s.total_after_hours) },
    { label: 'SLA Breaches', value: String(s.total_breaches) },
    { label: 'Override Credits', value: rupees(s.total_credit_rupees) },
    { label: 'Avg Response (min)', value: num(s.avg_response_min) },
    { label: 'Engineers On Roster', value: String(s.total_engineers) },
    { label: 'Total Shifts', value: String(s.total_shifts) },
    { label: 'No-Shows', value: String(s.total_no_shows) },
    { label: 'On-Call Bonus Paid', value: rupees(s.total_bonus_rupees) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
          Customer Monthly Engineer After-Hours Coverage
        </h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Round r2788 — customer × incident × after-hours × engineer
          × response × outcome × policy review. Founder-only console; all data
          gated by is_founder().
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 12,
          marginBottom: 28,
        }}
      >
        {kpis.map((k) => (
          <div
            key={k.label}
            style={{
              background: '#fff',
              border: '1px solid #e5e7eb',
              borderRadius: 10,
              padding: 14,
              boxShadow: '0 1px 2px rgba(0,0,0,0.04)',
            }}
          >
            <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{k.label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: '#111827' }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>
          Customers by Tier (response & breach rollup)
        </h2>
        <DataTable
          rows={tierRows}
          columns={[
            { key: 'customer_tier', header: 'Tier', render: (r: TierRow) => r.customer_tier },
            { key: 'customer_count', header: 'Customers', render: (r: TierRow) => String(r.customer_count) },
            { key: 'incident_total', header: 'Incidents', render: (r: TierRow) => String(r.incident_total) },
            { key: 'after_hours_total', header: 'After-Hours', render: (r: TierRow) => String(r.after_hours_total) },
            { key: 'breach_total', header: 'Breaches', render: (r: TierRow) => String(r.breach_total) },
            { key: 'avg_response', header: 'Avg Response (min)', render: (r: TierRow) => num(r.avg_response) },
            { key: 'credit_total', header: 'Credits Paid', render: (r: TierRow) => rupees(r.credit_total) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TierRow, i: number) => String(r.customer_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>
          Outcome Distribution (policy review signal)
        </h2>
        <DataTable
          rows={outcomeRows}
          columns={[
            { key: 'outcome_status', header: 'Outcome', render: (r: OutcomeRow) => r.outcome_status },
            { key: 'customer_count', header: 'Customers', render: (r: OutcomeRow) => String(r.customer_count) },
            { key: 'incident_total', header: 'Incidents', render: (r: OutcomeRow) => String(r.incident_total) },
            { key: 'credit_total', header: 'Credits', render: (r: OutcomeRow) => rupees(r.credit_total) },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.outcome_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>
          Policy Band Coverage
        </h2>
        <DataTable
          rows={policyRows}
          columns={[
            { key: 'policy_band', header: 'Policy Band', render: (r: PolicyRow) => r.policy_band },
            { key: 'customer_count', header: 'Customers', render: (r: PolicyRow) => String(r.customer_count) },
            { key: 'after_hours_total', header: 'After-Hours', render: (r: PolicyRow) => String(r.after_hours_total) },
            { key: 'breach_total', header: 'Breaches', render: (r: PolicyRow) => String(r.breach_total) },
            { key: 'avg_response', header: 'Avg Response (min)', render: (r: PolicyRow) => num(r.avg_response) },
          ]}
          emptyMessage="No data"
          rowKey={(r: PolicyRow, i: number) => String(r.policy_band ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>
          Top Breach Customers (sorted by breach count & credits)
        </h2>
        <DataTable
          rows={breachRows}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: BreachRow) => r.customer_org_name },
            { key: 'customer_tier', header: 'Tier', render: (r: BreachRow) => r.customer_tier },
            { key: 'policy_band', header: 'Policy', render: (r: BreachRow) => r.policy_band },
            { key: 'after_hours_count', header: 'After-Hours', render: (r: BreachRow) => String(r.after_hours_count) },
            { key: 'sla_breach_count', header: 'Breaches', render: (r: BreachRow) => String(r.sla_breach_count) },
            { key: 'avg_response_minutes', header: 'Avg Resp (min)', render: (r: BreachRow) => num(r.avg_response_minutes) },
            { key: 'override_credit_rupees', header: 'Credit', render: (r: BreachRow) => rupees(r.override_credit_rupees) },
            { key: 'outcome_status', header: 'Outcome', render: (r: BreachRow) => r.outcome_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: BreachRow, i: number) => String(r.customer_org_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>
          Engineer After-Hours Roster (ranked by compliance & CSAT)
        </h2>
        <DataTable
          rows={engineerRows}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: EngineerRow) => r.engineer_tier },
            { key: 'shifts_assigned', header: 'Assigned', render: (r: EngineerRow) => String(r.shifts_assigned) },
            { key: 'shifts_accepted', header: 'Accepted', render: (r: EngineerRow) => String(r.shifts_accepted) },
            { key: 'shifts_no_show', header: 'No-Show', render: (r: EngineerRow) => String(r.shifts_no_show) },
            { key: 'incidents_handled', header: 'Incidents', render: (r: EngineerRow) => String(r.incidents_handled) },
            { key: 'avg_first_response_min', header: '1st Resp (min)', render: (r: EngineerRow) => num(r.avg_first_response_min) },
            { key: 'customer_csat', header: 'CSAT', render: (r: EngineerRow) => num(r.customer_csat) },
            { key: 'outcome_grade', header: 'Grade', render: (r: EngineerRow) => r.outcome_grade },
            { key: 'policy_compliance_pct', header: 'Policy %', render: (r: EngineerRow) => num(r.policy_compliance_pct, 1) },
            { key: 'on_call_bonus_rupees', header: 'Bonus', render: (r: EngineerRow) => rupees(r.on_call_bonus_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>
          Engineer Grade Rollup (A is best, D needs review)
        </h2>
        <DataTable
          rows={gradeRows}
          columns={[
            { key: 'outcome_grade', header: 'Grade', render: (r: GradeRow) => r.outcome_grade },
            { key: 'engineer_count', header: 'Engineers', render: (r: GradeRow) => String(r.engineer_count) },
            { key: 'shifts_total', header: 'Shifts', render: (r: GradeRow) => String(r.shifts_total) },
            { key: 'no_show_total', header: 'No-Shows', render: (r: GradeRow) => String(r.no_show_total) },
            { key: 'incidents_total', header: 'Incidents', render: (r: GradeRow) => String(r.incidents_total) },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: GradeRow) => num(r.avg_csat) },
            { key: 'bonus_total', header: 'Bonus Paid', render: (r: GradeRow) => rupees(r.bonus_total) },
          ]}
          emptyMessage="No data"
          rowKey={(r: GradeRow, i: number) => String(r.outcome_grade ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>
          Policy Review Queue (escalated & pending-review customers)
        </h2>
        <DataTable
          rows={reviewRows}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: ReviewRow) => r.customer_org_name },
            { key: 'customer_tier', header: 'Tier', render: (r: ReviewRow) => r.customer_tier },
            { key: 'policy_band', header: 'Policy', render: (r: ReviewRow) => r.policy_band },
            { key: 'outcome_status', header: 'Outcome', render: (r: ReviewRow) => r.outcome_status },
            { key: 'after_hours_count', header: 'After-Hours', render: (r: ReviewRow) => String(r.after_hours_count) },
            { key: 'sla_breach_count', header: 'Breaches', render: (r: ReviewRow) => String(r.sla_breach_count) },
            { key: 'override_credit_rupees', header: 'Credit', render: (r: ReviewRow) => rupees(r.override_credit_rupees) },
            {
              key: 'reviewed_at',
              header: 'Reviewed',
              render: (r: ReviewRow) => (r.reviewed_at ? new Date(r.reviewed_at).toLocaleString('en-IN') : 'pending'),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: ReviewRow, i: number) => String(r.customer_org_name ?? i)}
        />
      </section>

      <footer style={{ marginTop: 32, paddingTop: 16, borderTop: '1px solid #e5e7eb', fontSize: 12, color: '#6b7280' }}>
        r2788 — HEAVY ★★★★ founder console — 2 tables, 8 RPCs,
        all SECDEF + is_founder() gated.
      </footer>
    </div>
  );
}
