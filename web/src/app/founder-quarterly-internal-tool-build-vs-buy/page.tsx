import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_candidates: number;
  build_count: number;
  buy_count: number;
  hybrid_count: number;
  defer_kill_count: number;
  total_build_estimate_rupees: number;
  total_buy_yearly_rupees: number;
  avg_moat_score: number;
};

type Candidate = {
  id: string;
  tool_name: string;
  need_description: string;
  current_pain_level: string;
  current_workaround: string;
  estimated_users: number;
  build_estimate_weeks: number;
  build_estimate_rupees: number;
  ongoing_maint_rupees_yearly: number;
  buy_options: string;
  buy_cost_rupees_yearly: number;
  strategic_moat_score: number;
  verdict: string;
};

type Decision = {
  tool_name: string;
  quarter_label: string;
  decision: string;
  decision_owner: string;
  budget_approved_rupees: number;
  rupees_actually_spent: number;
  target_ship_date: string;
  actual_outcome: string;
  retro_lesson: string;
};

type VerdictBreak = {
  verdict: string;
  candidate_count: number;
  total_build_rupees: number;
  total_buy_yearly_rupees: number;
  avg_moat: number;
};

type HighMoat = {
  tool_name: string;
  need_description: string;
  strategic_moat_score: number;
  build_estimate_weeks: number;
  build_estimate_rupees: number;
  verdict: string;
};

type Variance = {
  tool_name: string;
  quarter_label: string;
  budget_approved_rupees: number;
  rupees_actually_spent: number;
  variance_rupees: number;
  variance_pct: number;
  actual_outcome: string;
};

type Outcome = {
  actual_outcome: string;
  decision_count: number;
  total_spent_rupees: number;
};

type Pain = {
  current_pain_level: string;
  candidate_count: number;
  avg_users: number;
  avg_moat: number;
};

const fmtINR = (n: number) =>
  n >= 10000000
    ? `Rs ${(n / 10000000).toFixed(2)} Cr`
    : n >= 100000
    ? `Rs ${(n / 100000).toFixed(2)} L`
    : `Rs ${n.toLocaleString('en-IN')}`;

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, candidatesRes, decisionsRes, verdictRes, moatRes, varianceRes, outcomeRes, painRes] = await Promise.all([
    supabase.rpc('founder_r2797_kpis'),
    supabase.rpc('founder_r2797_candidates'),
    supabase.rpc('founder_r2797_decisions'),
    supabase.rpc('founder_r2797_verdict_breakdown'),
    supabase.rpc('founder_r2797_high_moat_builds'),
    supabase.rpc('founder_r2797_budget_variance'),
    supabase.rpc('founder_r2797_outcome_summary'),
    supabase.rpc('founder_r2797_pain_review'),
  ]);

  const kpis: Kpi | null = (kpisRes.data?.[0] as Kpi) ?? null;
  const candidates: Candidate[] = (candidatesRes.data as Candidate[]) ?? [];
  const decisions: Decision[] = (decisionsRes.data as Decision[]) ?? [];
  const verdictBreak: VerdictBreak[] = (verdictRes.data as VerdictBreak[]) ?? [];
  const highMoat: HighMoat[] = (moatRes.data as HighMoat[]) ?? [];
  const variance: Variance[] = (varianceRes.data as Variance[]) ?? [];
  const outcomes: Outcome[] = (outcomeRes.data as Outcome[]) ?? [];
  const pain: Pain[] = (painRes.data as Pain[]) ?? [];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Quarterly Internal Tool Build-vs-Buy</h1>
        <p className="text-sm text-gray-600 mt-1">
          Review every internal tool need each quarter. Decide build, buy, hybrid, defer, or kill.
          Track outcome vs budget so future calls get sharper.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Candidates reviewed</div>
          <div className="text-2xl font-bold">{kpis?.total_candidates ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Build / Buy / Hybrid</div>
          <div className="text-2xl font-bold">
            {kpis?.build_count ?? 0} / {kpis?.buy_count ?? 0} / {kpis?.hybrid_count ?? 0}
          </div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total build estimate</div>
          <div className="text-2xl font-bold">{fmtINR(kpis?.total_build_estimate_rupees ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total buy yearly</div>
          <div className="text-2xl font-bold">{fmtINR(kpis?.total_buy_yearly_rupees ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Avg moat score</div>
          <div className="text-2xl font-bold">{kpis?.avg_moat_score ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Deferred or killed</div>
          <div className="text-2xl font-bold">{kpis?.defer_kill_count ?? 0}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Verdict breakdown</h2>
        <DataTable
          rows={verdictBreak}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: VerdictBreak) => r.verdict },
            { key: 'candidate_count', header: 'Count', render: (r: VerdictBreak) => String(r.candidate_count) },
            { key: 'total_build_rupees', header: 'Build spend', render: (r: VerdictBreak) => fmtINR(r.total_build_rupees) },
            { key: 'total_buy_yearly_rupees', header: 'Buy yearly', render: (r: VerdictBreak) => fmtINR(r.total_buy_yearly_rupees) },
            { key: 'avg_moat', header: 'Avg moat', render: (r: VerdictBreak) => String(r.avg_moat) },
          ]}
          emptyMessage="No data"
          rowKey={(r: VerdictBreak, i: number) => String(r.verdict ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">High-moat candidates (score &gt;= 7)</h2>
        <DataTable
          rows={highMoat}
          columns={[
            { key: 'tool_name', header: 'Tool', render: (r: HighMoat) => r.tool_name },
            { key: 'need_description', header: 'Need', render: (r: HighMoat) => r.need_description },
            { key: 'strategic_moat_score', header: 'Moat', render: (r: HighMoat) => String(r.strategic_moat_score) },
            { key: 'build_estimate_weeks', header: 'Weeks', render: (r: HighMoat) => String(r.build_estimate_weeks) },
            { key: 'build_estimate_rupees', header: 'Build cost', render: (r: HighMoat) => fmtINR(r.build_estimate_rupees) },
            { key: 'verdict', header: 'Verdict', render: (r: HighMoat) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: HighMoat, i: number) => String(r.tool_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All candidates</h2>
        <DataTable
          rows={candidates}
          columns={[
            { key: 'tool_name', header: 'Tool', render: (r: Candidate) => r.tool_name },
            { key: 'current_pain_level', header: 'Pain', render: (r: Candidate) => r.current_pain_level },
            { key: 'estimated_users', header: 'Users', render: (r: Candidate) => String(r.estimated_users) },
            { key: 'build_estimate_rupees', header: 'Build', render: (r: Candidate) => fmtINR(r.build_estimate_rupees) },
            { key: 'buy_cost_rupees_yearly', header: 'Buy yr', render: (r: Candidate) => fmtINR(r.buy_cost_rupees_yearly) },
            { key: 'strategic_moat_score', header: 'Moat', render: (r: Candidate) => String(r.strategic_moat_score) },
            { key: 'verdict', header: 'Verdict', render: (r: Candidate) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: Candidate, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Quarterly decisions log</h2>
        <DataTable
          rows={decisions}
          columns={[
            { key: 'quarter_label', header: 'Quarter', render: (r: Decision) => r.quarter_label },
            { key: 'tool_name', header: 'Tool', render: (r: Decision) => r.tool_name },
            { key: 'decision', header: 'Decision', render: (r: Decision) => r.decision },
            { key: 'decision_owner', header: 'Owner', render: (r: Decision) => r.decision_owner },
            { key: 'budget_approved_rupees', header: 'Budget', render: (r: Decision) => fmtINR(r.budget_approved_rupees) },
            { key: 'rupees_actually_spent', header: 'Spent', render: (r: Decision) => fmtINR(r.rupees_actually_spent) },
            { key: 'target_ship_date', header: 'Target ship', render: (r: Decision) => r.target_ship_date },
            { key: 'actual_outcome', header: 'Outcome', render: (r: Decision) => r.actual_outcome },
            { key: 'retro_lesson', header: 'Lesson', render: (r: Decision) => r.retro_lesson },
          ]}
          emptyMessage="No data"
          rowKey={(r: Decision, i: number) => String(`${r.tool_name}-${r.quarter_label}` ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Budget variance (shipped only)</h2>
        <DataTable
          rows={variance}
          columns={[
            { key: 'tool_name', header: 'Tool', render: (r: Variance) => r.tool_name },
            { key: 'quarter_label', header: 'Quarter', render: (r: Variance) => r.quarter_label },
            { key: 'budget_approved_rupees', header: 'Approved', render: (r: Variance) => fmtINR(r.budget_approved_rupees) },
            { key: 'rupees_actually_spent', header: 'Spent', render: (r: Variance) => fmtINR(r.rupees_actually_spent) },
            { key: 'variance_rupees', header: 'Delta', render: (r: Variance) => fmtINR(r.variance_rupees) },
            { key: 'variance_pct', header: 'Variance %', render: (r: Variance) => `${r.variance_pct}%` },
            { key: 'actual_outcome', header: 'Outcome', render: (r: Variance) => r.actual_outcome },
          ]}
          emptyMessage="No data"
          rowKey={(r: Variance, i: number) => String(`${r.tool_name}-${r.quarter_label}` ?? i)}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-3">Outcome summary</h2>
          <DataTable
            rows={outcomes}
            columns={[
              { key: 'actual_outcome', header: 'Outcome', render: (r: Outcome) => r.actual_outcome },
              { key: 'decision_count', header: 'Count', render: (r: Outcome) => String(r.decision_count) },
              { key: 'total_spent_rupees', header: 'Spent', render: (r: Outcome) => fmtINR(r.total_spent_rupees) },
            ]}
            emptyMessage="No data"
            rowKey={(r: Outcome, i: number) => String(r.actual_outcome ?? i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-3">Pain-level review</h2>
          <DataTable
            rows={pain}
            columns={[
              { key: 'current_pain_level', header: 'Pain', render: (r: Pain) => r.current_pain_level },
              { key: 'candidate_count', header: 'Count', render: (r: Pain) => String(r.candidate_count) },
              { key: 'avg_users', header: 'Avg users', render: (r: Pain) => String(r.avg_users) },
              { key: 'avg_moat', header: 'Avg moat', render: (r: Pain) => String(r.avg_moat) },
            ]}
            emptyMessage="No data"
            rowKey={(r: Pain, i: number) => String(r.current_pain_level ?? i)}
          />
        </div>
      </section>
    </main>
  );
}
