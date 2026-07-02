import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_customers: number;
  exact_match_pct: number;
  mismatch_count: number;
  avg_csat: number;
  total_complaints: number;
  pending_switches: number;
};

type GradeRow = {
  grade: string;
  customer_count: number;
  avg_csat: number;
  avg_rebook_pct: number;
  total_complaints: number;
};

type LangRow = {
  preferred_language: string;
  customer_count: number;
  avg_match_score: number;
  avg_csat: number;
};

type MismatchRow = {
  customer_name: string;
  customer_org: string;
  preferred_language: string;
  engineer_primary_language: string;
  match_grade: string;
  satisfaction_csat: number;
  language_complaint_count: number;
};

type SwitchRow = {
  acted_at: string;
  customer_name: string;
  trigger_reason: string;
  old_engineer: string;
  new_engineer: string;
  switch_status: string;
  expected_csat_lift: number;
  actual_csat_lift: number | null;
};

type CityRow = {
  customer_city: string;
  customer_count: number;
  exact_match_count: number;
  avg_csat: number;
  total_complaints: number;
};

type LiftRow = {
  switch_status: string;
  action_count: number;
  avg_expected_lift: number;
  avg_actual_lift: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, gradeRes, langRes, mismatchRes, switchRes, cityRes, liftRes] = await Promise.all([
    supabase.rpc('kpi_overview_r2724'),
    supabase.rpc('match_grade_breakdown_r2724'),
    supabase.rpc('language_distribution_r2724'),
    supabase.rpc('top_mismatched_customers_r2724'),
    supabase.rpc('switch_action_history_r2724'),
    supabase.rpc('city_language_health_r2724'),
    supabase.rpc('csat_lift_summary_r2724'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? {
    total_customers: 0,
    exact_match_pct: 0,
    mismatch_count: 0,
    avg_csat: 0,
    total_complaints: 0,
    pending_switches: 0,
  }) as Kpi;

  const grades: GradeRow[] = (gradeRes.data ?? []) as GradeRow[];
  const langs: LangRow[] = (langRes.data ?? []) as LangRow[];
  const mismatches: MismatchRow[] = (mismatchRes.data ?? []) as MismatchRow[];
  const switches: SwitchRow[] = (switchRes.data ?? []) as SwitchRow[];
  const cities: CityRow[] = (cityRes.data ?? []) as CityRow[];
  const lifts: LiftRow[] = (liftRes.data ?? []) as LiftRow[];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-3xl font-bold">Customer Monthly Engineer Language Preference Match</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track customer preferred language vs assigned engineer language for the month. Score match grade, watch
          csat &amp; rebook signals, and execute switch actions when match score &lt; threshold.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <KpiCard label="Customers" value={String(kpi.total_customers)} />
        <KpiCard label="Exact Match %" value={`${kpi.exact_match_pct}%`} />
        <KpiCard label="Mismatch" value={String(kpi.mismatch_count)} tone="warn" />
        <KpiCard label="Avg CSAT" value={String(kpi.avg_csat)} />
        <KpiCard label="Lang Complaints" value={String(kpi.total_complaints)} tone="warn" />
        <KpiCard label="Pending Switches" value={String(kpi.pending_switches)} />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Match Grade Breakdown</h2>
        <DataTable
          rows={grades}
          columns={[
            { key: 'grade', header: 'Grade', render: (r: GradeRow) => r.grade },
            { key: 'customer_count', header: 'Customers', render: (r: GradeRow) => String(r.customer_count) },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: GradeRow) => String(r.avg_csat) },
            { key: 'avg_rebook_pct', header: 'Avg Rebook %', render: (r: GradeRow) => `${r.avg_rebook_pct}%` },
            { key: 'total_complaints', header: 'Complaints', render: (r: GradeRow) => String(r.total_complaints) },
          ]}
          emptyMessage="No data"
          rowKey={(r: GradeRow, i: number) => String(r.grade ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Preferred-Language Distribution</h2>
        <DataTable
          rows={langs}
          columns={[
            { key: 'preferred_language', header: 'Language', render: (r: LangRow) => r.preferred_language },
            { key: 'customer_count', header: 'Customers', render: (r: LangRow) => String(r.customer_count) },
            { key: 'avg_match_score', header: 'Avg Match Score', render: (r: LangRow) => `${r.avg_match_score}%` },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: LangRow) => String(r.avg_csat) },
          ]}
          emptyMessage="No data"
          rowKey={(r: LangRow, i: number) => String(r.preferred_language ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Top Mismatched Customers (CSAT &lt; 4 or complaints &gt; 0)</h2>
        <DataTable
          rows={mismatches}
          columns={[
            { key: 'customer_name', header: 'Customer', render: (r: MismatchRow) => r.customer_name },
            { key: 'customer_org', header: 'Org', render: (r: MismatchRow) => r.customer_org },
            { key: 'preferred_language', header: 'Prefers', render: (r: MismatchRow) => r.preferred_language },
            { key: 'engineer_primary_language', header: 'Eng Lang', render: (r: MismatchRow) => r.engineer_primary_language },
            { key: 'match_grade', header: 'Grade', render: (r: MismatchRow) => r.match_grade },
            { key: 'satisfaction_csat', header: 'CSAT', render: (r: MismatchRow) => String(r.satisfaction_csat) },
            { key: 'language_complaint_count', header: 'Complaints', render: (r: MismatchRow) => String(r.language_complaint_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: MismatchRow, i: number) => String(r.customer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Switch Action History</h2>
        <DataTable
          rows={switches}
          columns={[
            { key: 'acted_at', header: 'When', render: (r: SwitchRow) => new Date(r.acted_at).toLocaleDateString() },
            { key: 'customer_name', header: 'Customer', render: (r: SwitchRow) => r.customer_name },
            { key: 'trigger_reason', header: 'Trigger', render: (r: SwitchRow) => r.trigger_reason },
            { key: 'old_engineer', header: 'From', render: (r: SwitchRow) => r.old_engineer },
            { key: 'new_engineer', header: 'To', render: (r: SwitchRow) => r.new_engineer },
            { key: 'switch_status', header: 'Status', render: (r: SwitchRow) => r.switch_status },
            { key: 'expected_csat_lift', header: 'Expected Lift', render: (r: SwitchRow) => String(r.expected_csat_lift) },
            { key: 'actual_csat_lift', header: 'Actual Lift', render: (r: SwitchRow) => r.actual_csat_lift == null ? '—' : String(r.actual_csat_lift) },
          ]}
          emptyMessage="No data"
          rowKey={(r: SwitchRow, i: number) => `${r.customer_name}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">City Language Health</h2>
        <DataTable
          rows={cities}
          columns={[
            { key: 'customer_city', header: 'City', render: (r: CityRow) => r.customer_city },
            { key: 'customer_count', header: 'Customers', render: (r: CityRow) => String(r.customer_count) },
            { key: 'exact_match_count', header: 'Exact Match', render: (r: CityRow) => String(r.exact_match_count) },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: CityRow) => String(r.avg_csat) },
            { key: 'total_complaints', header: 'Complaints', render: (r: CityRow) => String(r.total_complaints) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CityRow, i: number) => String(r.customer_city ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">CSAT Lift By Switch Status</h2>
        <DataTable
          rows={lifts}
          columns={[
            { key: 'switch_status', header: 'Status', render: (r: LiftRow) => r.switch_status },
            { key: 'action_count', header: 'Actions', render: (r: LiftRow) => String(r.action_count) },
            { key: 'avg_expected_lift', header: 'Avg Expected', render: (r: LiftRow) => String(r.avg_expected_lift) },
            { key: 'avg_actual_lift', header: 'Avg Actual', render: (r: LiftRow) => r.avg_actual_lift == null ? '—' : String(r.avg_actual_lift) },
          ]}
          emptyMessage="No data"
          rowKey={(r: LiftRow, i: number) => String(r.switch_status ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: string; tone?: 'warn' }) {
  const bg = tone === 'warn' ? 'bg-amber-50 border-amber-200' : 'bg-white border-gray-200';
  return (
    <div className={`rounded-lg border ${bg} p-4`}>
      <div className="text-xs uppercase text-gray-500">{label}</div>
      <div className="text-2xl font-semibold mt-1">{value}</div>
    </div>
  );
}
