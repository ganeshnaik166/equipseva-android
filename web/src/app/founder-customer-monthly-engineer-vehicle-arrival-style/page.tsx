import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_visits: number;
  avg_clean: number;
  avg_impression: number;
  exemplary: number;
  coach_req: number;
};

type VisitRow = {
  id: string;
  job_code: string;
  engineer_name: string;
  customer_org: string;
  visit_month: string;
  visit_date: string;
  vehicle_kind: string;
  vehicle_clean_score: number;
  parked_correctly: boolean;
  customer_impression_score: number;
  verdict: string;
  notes: string | null;
};

type SummaryRow = {
  id: string;
  engineer_name: string;
  visit_month: string;
  total_visits: number;
  avg_clean_score: number;
  avg_impression_score: number;
  parked_correct_pct: number;
  exemplary_count: number;
  warn_count: number;
  coach_required: boolean;
};

type KindRow = {
  vehicle_kind: string;
  visits: number;
  avg_clean: number;
  avg_impression: number;
  parked_ok_pct: number;
};

type VerdictRow = { verdict: string; n: number; pct: number };
type CoachRow = { engineer_name: string; total_visits: number; avg_impression: number; warn_count: number };
type TopRow = { engineer_name: string; avg_impression: number; exemplary_count: number; parked_correct_pct: number };
type ParkRow = { job_code: string; engineer_name: string; customer_org: string; vehicle_kind: string; visit_date: string; notes: string | null };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpis, visits, summary, byKind, mix, coach, top, parking] = await Promise.all([
    supabase.rpc('founder_vas_r2860_kpis'),
    supabase.rpc('founder_vas_r2860_recent_visits'),
    supabase.rpc('founder_vas_r2860_monthly_summary'),
    supabase.rpc('founder_vas_r2860_by_vehicle_kind'),
    supabase.rpc('founder_vas_r2860_verdict_mix'),
    supabase.rpc('founder_vas_r2860_coach_list'),
    supabase.rpc('founder_vas_r2860_top_arrivals'),
    supabase.rpc('founder_vas_r2860_parking_audit'),
  ]);

  const k: KpiRow = (kpis.data?.[0] as KpiRow) ?? {
    total_visits: 0,
    avg_clean: 0,
    avg_impression: 0,
    exemplary: 0,
    coach_req: 0,
  };

  const visitRows = (visits.data ?? []) as VisitRow[];
  const summaryRows = (summary.data ?? []) as SummaryRow[];
  const kindRows = (byKind.data ?? []) as KindRow[];
  const mixRows = (mix.data ?? []) as VerdictRow[];
  const coachRows = (coach.data ?? []) as CoachRow[];
  const topRows = (top.data ?? []) as TopRow[];
  const parkRows = (parking.data ?? []) as ParkRow[];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Engineer vehicle arrival style</h1>
        <p className="text-sm text-neutral-500">
          Customer-monthly cut: job × vehicle kind × clean × parked × customer impression × verdict.
          Coach engineers when avg impression score &lt;= 5 or warn_count &gt;= 3.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-5">
        <KpiCard label="Total visits" value={String(k.total_visits ?? 0)} />
        <KpiCard label="Avg clean / 10" value={fmt(k.avg_clean)} />
        <KpiCard label="Avg impression / 10" value={fmt(k.avg_impression)} />
        <KpiCard label="Exemplary" value={String(k.exemplary ?? 0)} />
        <KpiCard label="Coach required" value={String(k.coach_req ?? 0)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent arrival observations</h2>
        <DataTable<VisitRow>
          rows={visitRows}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
          columns={[
            { key: 'visit_date', header: 'Date', render: (r) => r.visit_date },
            { key: 'job_code', header: 'Job', render: (r) => r.job_code },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'customer_org', header: 'Customer', render: (r) => r.customer_org },
            { key: 'vehicle_kind', header: 'Vehicle', render: (r) => r.vehicle_kind },
            { key: 'vehicle_clean_score', header: 'Clean', render: (r) => `${r.vehicle_clean_score}/10` },
            { key: 'parked_correctly', header: 'Parked OK', render: (r) => (r.parked_correctly ? 'yes' : 'no') },
            { key: 'customer_impression_score', header: 'Impression', render: (r) => `${r.customer_impression_score}/10` },
            { key: 'verdict', header: 'Verdict', render: (r) => r.verdict },
            { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '' },
          ]}
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-lg font-medium">Monthly engineer summary</h2>
          <DataTable<SummaryRow>
            rows={summaryRows}
            emptyMessage="No data"
            rowKey={(r, i) => String(r.id ?? i)}
            columns={[
              { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
              { key: 'visit_month', header: 'Month', render: (r) => r.visit_month },
              { key: 'total_visits', header: 'Visits', render: (r) => String(r.total_visits) },
              { key: 'avg_clean_score', header: 'Avg clean', render: (r) => fmt(r.avg_clean_score) },
              { key: 'avg_impression_score', header: 'Avg impression', render: (r) => fmt(r.avg_impression_score) },
              { key: 'parked_correct_pct', header: 'Parked OK %', render: (r) => fmt(r.parked_correct_pct) },
              { key: 'coach_required', header: 'Coach?', render: (r) => (r.coach_required ? 'yes' : 'no') },
            ]}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-lg font-medium">By vehicle kind</h2>
          <DataTable<KindRow>
            rows={kindRows}
            emptyMessage="No data"
            rowKey={(r, i) => String(r.vehicle_kind ?? i)}
            columns={[
              { key: 'vehicle_kind', header: 'Vehicle', render: (r) => r.vehicle_kind },
              { key: 'visits', header: 'Visits', render: (r) => String(r.visits) },
              { key: 'avg_clean', header: 'Avg clean', render: (r) => fmt(r.avg_clean) },
              { key: 'avg_impression', header: 'Avg impression', render: (r) => fmt(r.avg_impression) },
              { key: 'parked_ok_pct', header: 'Parked OK %', render: (r) => fmt(r.parked_ok_pct) },
            ]}
          />
        </div>
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-lg font-medium">Verdict mix</h2>
          <DataTable<VerdictRow>
            rows={mixRows}
            emptyMessage="No data"
            rowKey={(r, i) => String(r.verdict ?? i)}
            columns={[
              { key: 'verdict', header: 'Verdict', render: (r) => r.verdict },
              { key: 'n', header: 'Count', render: (r) => String(r.n) },
              { key: 'pct', header: 'Share %', render: (r) => fmt(r.pct) },
            ]}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-lg font-medium">Top arrivals</h2>
          <DataTable<TopRow>
            rows={topRows}
            emptyMessage="No data"
            rowKey={(r, i) => String(r.engineer_name ?? i)}
            columns={[
              { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
              { key: 'avg_impression', header: 'Avg impression', render: (r) => fmt(r.avg_impression) },
              { key: 'exemplary_count', header: 'Exemplary', render: (r) => String(r.exemplary_count) },
              { key: 'parked_correct_pct', header: 'Parked OK %', render: (r) => fmt(r.parked_correct_pct) },
            ]}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Coach list (impression &lt;= 5 or warns &gt;= 3)</h2>
        <DataTable<CoachRow>
          rows={coachRows}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.engineer_name ?? i)}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'total_visits', header: 'Visits', render: (r) => String(r.total_visits) },
            { key: 'avg_impression', header: 'Avg impression', render: (r) => fmt(r.avg_impression) },
            { key: 'warn_count', header: 'Warns', render: (r) => String(r.warn_count) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Parking audit (parked_correctly = false)</h2>
        <DataTable<ParkRow>
          rows={parkRows}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.job_code ?? i)}
          columns={[
            { key: 'visit_date', header: 'Date', render: (r) => r.visit_date },
            { key: 'job_code', header: 'Job', render: (r) => r.job_code },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'customer_org', header: 'Customer', render: (r) => r.customer_org },
            { key: 'vehicle_kind', header: 'Vehicle', render: (r) => r.vehicle_kind },
            { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '' },
          ]}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold tabular-nums">{value}</div>
    </div>
  );
}

function fmt(n: number | null | undefined) {
  if (n === null || n === undefined) return '0';
  const x = typeof n === 'string' ? Number(n) : n;
  if (Number.isNaN(x)) return '0';
  return x.toFixed(2);
}
