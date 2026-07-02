import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_engineer_months: number;
  total_feedback_received: number;
  total_responded: number;
  total_loops_closed: number;
  network_response_rate: number | null;
  network_closure_rate: number | null;
  avg_csat: number | null;
};

type EngineerRow = {
  id: string;
  month_label: string;
  engineer_code: string;
  engineer_name: string;
  engineer_tier: string;
  region: string;
  feedback_received_count: number;
  feedback_responded_count: number;
  loops_closed_count: number;
  response_rate_pct: number | null;
  closure_rate_pct: number | null;
  avg_response_hours: number;
  avg_closure_hours: number;
  csat_score: number;
  tier_verdict: string;
};

type TierRow = {
  engineer_tier: string;
  engineer_count: number;
  feedback_received: number;
  loops_closed: number;
  closure_rate_pct: number | null;
  avg_csat: number | null;
};

type VerdictRow = {
  tier_verdict: string;
  engineer_count: number;
  avg_closure_rate: number | null;
  avg_csat: number | null;
};

type TrendRow = {
  month_label: string;
  month_start: string;
  feedback_received: number;
  loops_closed: number;
  closure_rate_pct: number | null;
  avg_csat: number | null;
};

type EventRow = {
  id: string;
  event_at: string;
  event_kind: string;
  customer_label: string;
  hours_elapsed: number;
  engineer_name: string;
  engineer_tier: string;
  notes: string | null;
};

type RegionRow = {
  region: string;
  engineer_months: number;
  feedback_received: number;
  closure_rate_pct: number | null;
  avg_csat: number | null;
};

type TopRow = {
  engineer_code: string;
  engineer_name: string;
  engineer_tier: string;
  total_feedback: number;
  total_closed: number;
  best_csat: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, engRes, tierRes, verdictRes, trendRes, eventRes, regionRes, topRes] = await Promise.all([
    supabase.rpc('r2810_kpis'),
    supabase.rpc('r2810_engineer_rows'),
    supabase.rpc('r2810_tier_breakdown'),
    supabase.rpc('r2810_verdict_distribution'),
    supabase.rpc('r2810_monthly_trend'),
    supabase.rpc('r2810_open_loop_events'),
    supabase.rpc('r2810_region_summary'),
    supabase.rpc('r2810_top_responders'),
  ]);

  const kpi: Kpi | null = (kpiRes.data?.[0] as Kpi) ?? null;
  const engineers: EngineerRow[] = (engRes.data as EngineerRow[]) ?? [];
  const tiers: TierRow[] = (tierRes.data as TierRow[]) ?? [];
  const verdicts: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const events: EventRow[] = (eventRes.data as EventRow[]) ?? [];
  const regions: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[]) ?? [];

  const fmtPct = (v: number | null | undefined) => (v == null ? '—' : `${v}%`);
  const fmtNum = (v: number | null | undefined) => (v == null ? '—' : String(v));

  return (
    <div className="mx-auto max-w-7xl px-6 py-10 space-y-10">
      <header className="space-y-2">
        <p className="text-xs uppercase tracking-widest text-slate-500">Round 2810 · Founder Console</p>
        <h1 className="text-3xl font-semibold tracking-tight">Engineer Monthly Customer Feedback Loop Closure Rate</h1>
        <p className="text-slate-600 max-w-3xl">
          Per-engineer view of feedback received, responded to, and fully closed each month, paired with response &amp; closure
          time, CSAT, and a tier verdict (promote / hold / watch / demote). Closure rate &gt;= 90% holds platinum; &lt; 60% trips a demote.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Engineer-months" value={fmtNum(kpi?.total_engineer_months)} />
        <KpiCard label="Feedback received" value={fmtNum(kpi?.total_feedback_received)} />
        <KpiCard label="Loops closed" value={fmtNum(kpi?.total_loops_closed)} />
        <KpiCard label="Network closure rate" value={fmtPct(kpi?.network_closure_rate)} accent />
        <KpiCard label="Network response rate" value={fmtPct(kpi?.network_response_rate)} />
        <KpiCard label="Responded total" value={fmtNum(kpi?.total_responded)} />
        <KpiCard label="Average CSAT" value={fmtNum(kpi?.avg_csat)} />
        <KpiCard label="Tiers tracked" value={String(tiers.length)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Engineer × month leaderboard</h2>
        <DataTable
          rows={engineers}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'month_label', header: 'Month', render: (r: EngineerRow) => r.month_label },
            { key: 'engineer_code', header: 'Code', render: (r: EngineerRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: EngineerRow) => r.engineer_tier },
            { key: 'region', header: 'Region', render: (r: EngineerRow) => r.region },
            { key: 'feedback_received_count', header: 'Received', render: (r: EngineerRow) => r.feedback_received_count },
            { key: 'feedback_responded_count', header: 'Responded', render: (r: EngineerRow) => r.feedback_responded_count },
            { key: 'loops_closed_count', header: 'Closed', render: (r: EngineerRow) => r.loops_closed_count },
            { key: 'response_rate_pct', header: 'Resp %', render: (r: EngineerRow) => fmtPct(r.response_rate_pct) },
            { key: 'closure_rate_pct', header: 'Closure %', render: (r: EngineerRow) => fmtPct(r.closure_rate_pct) },
            { key: 'avg_response_hours', header: 'Resp h', render: (r: EngineerRow) => r.avg_response_hours },
            { key: 'avg_closure_hours', header: 'Close h', render: (r: EngineerRow) => r.avg_closure_hours },
            { key: 'csat_score', header: 'CSAT', render: (r: EngineerRow) => r.csat_score },
            { key: 'tier_verdict', header: 'Verdict', render: (r: EngineerRow) => <VerdictPill verdict={r.tier_verdict} /> },
          ]}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-8">
        <div className="space-y-3">
          <h2 className="text-xl font-semibold">Tier breakdown</h2>
          <DataTable
            rows={tiers}
            rowKey={(r, i) => String(r.engineer_tier ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'engineer_tier', header: 'Tier', render: (r: TierRow) => r.engineer_tier },
              { key: 'engineer_count', header: 'Engineer-months', render: (r: TierRow) => r.engineer_count },
              { key: 'feedback_received', header: 'Received', render: (r: TierRow) => r.feedback_received },
              { key: 'loops_closed', header: 'Closed', render: (r: TierRow) => r.loops_closed },
              { key: 'closure_rate_pct', header: 'Closure %', render: (r: TierRow) => fmtPct(r.closure_rate_pct) },
              { key: 'avg_csat', header: 'CSAT', render: (r: TierRow) => fmtNum(r.avg_csat) },
            ]}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-xl font-semibold">Verdict distribution</h2>
          <DataTable
            rows={verdicts}
            rowKey={(r, i) => String(r.tier_verdict ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'tier_verdict', header: 'Verdict', render: (r: VerdictRow) => <VerdictPill verdict={r.tier_verdict} /> },
              { key: 'engineer_count', header: 'Engineers', render: (r: VerdictRow) => r.engineer_count },
              { key: 'avg_closure_rate', header: 'Avg closure %', render: (r: VerdictRow) => fmtPct(r.avg_closure_rate) },
              { key: 'avg_csat', header: 'Avg CSAT', render: (r: VerdictRow) => fmtNum(r.avg_csat) },
            ]}
          />
        </div>
      </section>

      <section className="grid md:grid-cols-2 gap-8">
        <div className="space-y-3">
          <h2 className="text-xl font-semibold">Monthly trend</h2>
          <DataTable
            rows={trend}
            rowKey={(r, i) => String(r.month_start ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'month_label', header: 'Month', render: (r: TrendRow) => r.month_label },
              { key: 'feedback_received', header: 'Received', render: (r: TrendRow) => r.feedback_received },
              { key: 'loops_closed', header: 'Closed', render: (r: TrendRow) => r.loops_closed },
              { key: 'closure_rate_pct', header: 'Closure %', render: (r: TrendRow) => fmtPct(r.closure_rate_pct) },
              { key: 'avg_csat', header: 'CSAT', render: (r: TrendRow) => fmtNum(r.avg_csat) },
            ]}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-xl font-semibold">Region summary</h2>
          <DataTable
            rows={regions}
            rowKey={(r, i) => String(r.region ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'region', header: 'Region', render: (r: RegionRow) => r.region },
              { key: 'engineer_months', header: 'Engineer-months', render: (r: RegionRow) => r.engineer_months },
              { key: 'feedback_received', header: 'Received', render: (r: RegionRow) => r.feedback_received },
              { key: 'closure_rate_pct', header: 'Closure %', render: (r: RegionRow) => fmtPct(r.closure_rate_pct) },
              { key: 'avg_csat', header: 'CSAT', render: (r: RegionRow) => fmtNum(r.avg_csat) },
            ]}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Top responders</h2>
        <DataTable
          rows={top}
          rowKey={(r, i) => String(r.engineer_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: TopRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: TopRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: TopRow) => r.engineer_tier },
            { key: 'total_feedback', header: 'Feedback', render: (r: TopRow) => r.total_feedback },
            { key: 'total_closed', header: 'Closed', render: (r: TopRow) => r.total_closed },
            { key: 'best_csat', header: 'Best CSAT', render: (r: TopRow) => r.best_csat },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Recent loop events</h2>
        <p className="text-sm text-slate-600">
          Granular feedback-loop activity stream (received → responded → closed / escalated / reopened). Hours-elapsed
          measured from feedback receipt; values &gt;= 24h flag SLA risk.
        </p>
        <DataTable
          rows={events}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'event_at', header: 'When', render: (r: EventRow) => new Date(r.event_at).toLocaleString('en-IN') },
            { key: 'event_kind', header: 'Kind', render: (r: EventRow) => r.event_kind },
            { key: 'customer_label', header: 'Customer', render: (r: EventRow) => r.customer_label },
            { key: 'engineer_name', header: 'Engineer', render: (r: EventRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: EventRow) => r.engineer_tier },
            { key: 'hours_elapsed', header: 'Hours', render: (r: EventRow) => r.hours_elapsed },
            { key: 'notes', header: 'Notes', render: (r: EventRow) => r.notes ?? '—' },
          ]}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value, accent }: { label: string; value: string; accent?: boolean }) {
  return (
    <div
      className={
        'rounded-2xl border p-4 shadow-sm ' +
        (accent ? 'border-emerald-300 bg-emerald-50' : 'border-slate-200 bg-white')
      }
    >
      <p className="text-xs uppercase tracking-wider text-slate-500">{label}</p>
      <p className="mt-1 text-2xl font-semibold tabular-nums">{value}</p>
    </div>
  );
}

function VerdictPill({ verdict }: { verdict: string }) {
  const map: Record<string, string> = {
    promote: 'bg-emerald-100 text-emerald-800 border-emerald-300',
    hold: 'bg-sky-100 text-sky-800 border-sky-300',
    watch: 'bg-amber-100 text-amber-800 border-amber-300',
    demote: 'bg-rose-100 text-rose-800 border-rose-300',
  };
  const cls = map[verdict] ?? 'bg-slate-100 text-slate-800 border-slate-300';
  return <span className={`inline-block rounded-full border px-2 py-0.5 text-xs font-medium ${cls}`}>{verdict}</span>;
}
