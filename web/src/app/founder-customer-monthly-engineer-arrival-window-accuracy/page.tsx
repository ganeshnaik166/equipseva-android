import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type HitRate = { total_jobs: number; hits: number; misses: number; hit_rate: number; avg_variance_min: number };
type Cause = { cause: string; miss_count: number; avg_variance_min: number; avg_csat: number };
type Promise = { job_code: string; customer_name: string; engineer_name: string; promised_window_label: string; variance_minutes: number; hit_window: boolean; cause: string; csat_score: number; reported_on: string };
type WindowPerf = { promised_window_label: string; jobs: number; hit_rate: number; avg_variance: number; avg_csat: number };
type Engineer = { engineer_name: string; jobs: number; hits: number; hit_rate: number; avg_variance: number };
type Refinement = { rule_code: string; rule_label: string; applies_to_window: string; buffer_minutes_added: number; hit_rate_before: number; hit_rate_after: number; csat_lift: number; status: string; effective_from: string };
type RefSummary = { total_rules: number; adopted: number; piloting: number; proposed: number; avg_lift_pct: number; avg_csat_lift: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [hitRateRes, causeRes, promisesRes, windowPerfRes, engineerRes, refinementsRes, refSummaryRes] = await Promise.all([
    supabase.rpc('founder_r2712_window_hit_rate'),
    supabase.rpc('founder_r2712_cause_breakdown'),
    supabase.rpc('founder_r2712_promises_recent'),
    supabase.rpc('founder_r2712_window_label_perf'),
    supabase.rpc('founder_r2712_engineer_punctuality'),
    supabase.rpc('founder_r2712_refinements_active'),
    supabase.rpc('founder_r2712_refinement_summary'),
  ]);

  const hit: HitRate | null = (hitRateRes.data as HitRate[] | null)?.[0] ?? null;
  const causes: Cause[] = (causeRes.data as Cause[] | null) ?? [];
  const promises: Promise[] = (promisesRes.data as Promise[] | null) ?? [];
  const windowPerf: WindowPerf[] = (windowPerfRes.data as WindowPerf[] | null) ?? [];
  const engineers: Engineer[] = (engineerRes.data as Engineer[] | null) ?? [];
  const refinements: Refinement[] = (refinementsRes.data as Refinement[] | null) ?? [];
  const refSummary: RefSummary | null = (refSummaryRes.data as RefSummary[] | null)?.[0] ?? null;

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Customer Monthly — Engineer Arrival Window Accuracy</h1>
        <p className="text-sm text-gray-500">Job × promised window × actual arrival × variance × cause × promise refinement (r2712)</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="rounded-xl border p-4">
          <div className="text-xs text-gray-500">Total jobs</div>
          <div className="text-2xl font-semibold">{hit?.total_jobs ?? 0}</div>
        </div>
        <div className="rounded-xl border p-4">
          <div className="text-xs text-gray-500">Hit rate</div>
          <div className="text-2xl font-semibold">{hit?.hit_rate ?? 0}%</div>
        </div>
        <div className="rounded-xl border p-4">
          <div className="text-xs text-gray-500">Avg variance</div>
          <div className="text-2xl font-semibold">{hit?.avg_variance_min ?? 0} min</div>
        </div>
        <div className="rounded-xl border p-4">
          <div className="text-xs text-gray-500">Adopted rules</div>
          <div className="text-2xl font-semibold">{refSummary?.adopted ?? 0}</div>
        </div>
        <div className="rounded-xl border p-4">
          <div className="text-xs text-gray-500">Avg lift</div>
          <div className="text-2xl font-semibold">+{refSummary?.avg_lift_pct ?? 0}%</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Miss cause breakdown</h2>
        <DataTable
          rows={causes}
          columns={[
            { key: 'cause', header: 'Cause', render: (r: Cause) => r.cause },
            { key: 'miss_count', header: 'Misses', render: (r: Cause) => r.miss_count },
            { key: 'avg_variance_min', header: 'Avg variance (min)', render: (r: Cause) => r.avg_variance_min },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: Cause) => r.avg_csat },
          ]}
          emptyMessage="No data"
          rowKey={(r: Cause, i: number) => String(r.cause ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Window label performance</h2>
        <DataTable
          rows={windowPerf}
          columns={[
            { key: 'promised_window_label', header: 'Window', render: (r: WindowPerf) => r.promised_window_label },
            { key: 'jobs', header: 'Jobs', render: (r: WindowPerf) => r.jobs },
            { key: 'hit_rate', header: 'Hit rate %', render: (r: WindowPerf) => r.hit_rate },
            { key: 'avg_variance', header: 'Avg variance', render: (r: WindowPerf) => r.avg_variance },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: WindowPerf) => r.avg_csat },
          ]}
          emptyMessage="No data"
          rowKey={(r: WindowPerf, i: number) => String(r.promised_window_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer punctuality</h2>
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Engineer) => r.engineer_name },
            { key: 'jobs', header: 'Jobs', render: (r: Engineer) => r.jobs },
            { key: 'hits', header: 'Hits', render: (r: Engineer) => r.hits },
            { key: 'hit_rate', header: 'Hit rate %', render: (r: Engineer) => r.hit_rate },
            { key: 'avg_variance', header: 'Avg variance', render: (r: Engineer) => r.avg_variance },
          ]}
          emptyMessage="No data"
          rowKey={(r: Engineer, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent arrival promises</h2>
        <DataTable
          rows={promises}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: Promise) => r.job_code },
            { key: 'customer_name', header: 'Customer', render: (r: Promise) => r.customer_name },
            { key: 'engineer_name', header: 'Engineer', render: (r: Promise) => r.engineer_name },
            { key: 'promised_window_label', header: 'Window', render: (r: Promise) => r.promised_window_label },
            { key: 'variance_minutes', header: 'Variance (min)', render: (r: Promise) => r.variance_minutes },
            { key: 'hit_window', header: 'Hit?', render: (r: Promise) => (r.hit_window ? 'Yes' : 'No') },
            { key: 'cause', header: 'Cause', render: (r: Promise) => r.cause },
            { key: 'csat_score', header: 'CSAT', render: (r: Promise) => r.csat_score },
            { key: 'reported_on', header: 'Date', render: (r: Promise) => r.reported_on },
          ]}
          emptyMessage="No data"
          rowKey={(r: Promise, i: number) => String(r.job_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Promise refinement rules</h2>
        <p className="text-xs text-gray-500 mb-2">Lift = hit rate after − hit rate before. Adopted rules graduated; piloting in trial.</p>
        <DataTable
          rows={refinements}
          columns={[
            { key: 'rule_code', header: 'Code', render: (r: Refinement) => r.rule_code },
            { key: 'rule_label', header: 'Rule', render: (r: Refinement) => r.rule_label },
            { key: 'applies_to_window', header: 'Window', render: (r: Refinement) => r.applies_to_window },
            { key: 'buffer_minutes_added', header: 'Buffer (min)', render: (r: Refinement) => r.buffer_minutes_added },
            { key: 'hit_rate_before', header: 'Before %', render: (r: Refinement) => r.hit_rate_before },
            { key: 'hit_rate_after', header: 'After %', render: (r: Refinement) => r.hit_rate_after },
            { key: 'csat_lift', header: 'CSAT lift', render: (r: Refinement) => r.csat_lift },
            { key: 'status', header: 'Status', render: (r: Refinement) => r.status },
            { key: 'effective_from', header: 'From', render: (r: Refinement) => r.effective_from },
          ]}
          emptyMessage="No data"
          rowKey={(r: Refinement, i: number) => String(r.rule_code ?? i)}
        />
      </section>
    </div>
  );
}
