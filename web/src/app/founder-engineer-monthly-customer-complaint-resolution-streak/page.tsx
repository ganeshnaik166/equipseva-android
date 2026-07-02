import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type OverviewRow = {
  total_engineers: number | null;
  elite_count: number | null;
  at_risk_count: number | null;
  total_bonus_rupees: number | null;
  avg_streak: number | null;
};

type LeaderRow = {
  engineer_code: string;
  engineer_name: string;
  region: string;
  streak_months: number;
  bonus_rupees: number;
  verdict: string;
};

type AtRiskRow = {
  engineer_code: string;
  engineer_name: string;
  region: string;
  complaints_received: number;
  complaints_resolved: number;
  avg_resolve_days: number;
  verdict: string;
};

type EventRow = {
  engineer_code: string;
  complaint_ref: string;
  raised_on: string;
  resolved_on: string | null;
  resolve_days: number | null;
  severity: string;
  outcome: string;
  notes: string | null;
};

type RegionRow = {
  region: string;
  engineers: number;
  avg_streak: number;
  total_bonus: number;
  elite_share: number;
};

type SeverityRow = {
  severity: string;
  total: number;
  resolved: number;
  escalated: number;
  reopened: number;
};

type BonusRow = {
  engineer_code: string;
  engineer_name: string;
  streak_months: number;
  bonus_rupees: number;
  verdict: string;
};

type StreakRow = {
  engineer_code: string;
  engineer_name: string;
  region: string;
  month_label: string;
  complaints_received: number;
  complaints_resolved: number;
  avg_resolve_days: number;
  streak_months: number;
  bonus_rupees: number;
  verdict: string;
};

function fmtMoney(n: number | null | undefined) {
  if (n == null) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, leaderRes, atRiskRes, eventsRes, regionRes, severityRes, bonusRes, streakRes] = await Promise.all([
    supabase.rpc('founder_r2758_overview'),
    supabase.rpc('founder_r2758_leaderboard'),
    supabase.rpc('founder_r2758_at_risk'),
    supabase.rpc('founder_r2758_events'),
    supabase.rpc('founder_r2758_region_rollup'),
    supabase.rpc('founder_r2758_severity_mix'),
    supabase.rpc('founder_r2758_bonus_queue'),
    supabase.rpc('founder_r2758_streak_table'),
  ]);

  const overview: OverviewRow = (overviewRes.data?.[0] ?? {
    total_engineers: 0,
    elite_count: 0,
    at_risk_count: 0,
    total_bonus_rupees: 0,
    avg_streak: 0,
  }) as OverviewRow;

  const leaders: LeaderRow[] = (leaderRes.data ?? []) as LeaderRow[];
  const atRisk: AtRiskRow[] = (atRiskRes.data ?? []) as AtRiskRow[];
  const events: EventRow[] = (eventsRes.data ?? []) as EventRow[];
  const regions: RegionRow[] = (regionRes.data ?? []) as RegionRow[];
  const severities: SeverityRow[] = (severityRes.data ?? []) as SeverityRow[];
  const bonuses: BonusRow[] = (bonusRes.data ?? []) as BonusRow[];
  const streaks: StreakRow[] = (streakRes.data ?? []) as StreakRow[];

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Complaint Resolution Streak</h1>
        <p className="text-sm text-gray-600">
          Track which engineers keep streaks of zero-escalation months. Streak &gt;= 6 months unlocks bonus payout tier.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Engineers</div>
          <div className="text-xl font-semibold">{overview.total_engineers ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Elite</div>
          <div className="text-xl font-semibold">{overview.elite_count ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">At Risk</div>
          <div className="text-xl font-semibold">{overview.at_risk_count ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Bonus Pool</div>
          <div className="text-xl font-semibold">{fmtMoney(overview.total_bonus_rupees)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Avg Streak (months)</div>
          <div className="text-xl font-semibold">{overview.avg_streak ?? 0}</div>
        </div>
      </section>

      <section>
        <h2 className="font-semibold mb-2">Leaderboard (streak desc)</h2>
        <DataTable<LeaderRow>
          rows={leaders}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'region', header: 'Region', render: (r) => r.region },
            { key: 'streak_months', header: 'Streak (mo)', render: (r) => String(r.streak_months) },
            { key: 'bonus_rupees', header: 'Bonus', render: (r) => fmtMoney(r.bonus_rupees) },
            { key: 'verdict', header: 'Verdict', render: (r) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.engineer_code ?? i)}
        />
      </section>

      <section>
        <h2 className="font-semibold mb-2">At-Risk Engineers</h2>
        <p className="text-xs text-gray-500 mb-2">
          Avg resolve days &gt; 3 or unresolved-complaint share &gt;= 25%.
        </p>
        <DataTable<AtRiskRow>
          rows={atRisk}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'region', header: 'Region', render: (r) => r.region },
            { key: 'complaints_received', header: 'Received', render: (r) => String(r.complaints_received) },
            { key: 'complaints_resolved', header: 'Resolved', render: (r) => String(r.complaints_resolved) },
            { key: 'avg_resolve_days', header: 'Avg Days', render: (r) => String(r.avg_resolve_days) },
            { key: 'verdict', header: 'Verdict', render: (r) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.engineer_code ?? i)}
        />
      </section>

      <section>
        <h2 className="font-semibold mb-2">Region Rollup</h2>
        <DataTable<RegionRow>
          rows={regions}
          columns={[
            { key: 'region', header: 'Region', render: (r) => r.region },
            { key: 'engineers', header: 'Engineers', render: (r) => String(r.engineers) },
            { key: 'avg_streak', header: 'Avg Streak', render: (r) => String(r.avg_streak) },
            { key: 'total_bonus', header: 'Total Bonus', render: (r) => fmtMoney(r.total_bonus) },
            { key: 'elite_share', header: 'Elite %', render: (r) => String(r.elite_share) + '%' },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section>
        <h2 className="font-semibold mb-2">Severity Mix</h2>
        <DataTable<SeverityRow>
          rows={severities}
          columns={[
            { key: 'severity', header: 'Severity', render: (r) => r.severity },
            { key: 'total', header: 'Total', render: (r) => String(r.total) },
            { key: 'resolved', header: 'Resolved', render: (r) => String(r.resolved) },
            { key: 'escalated', header: 'Escalated', render: (r) => String(r.escalated) },
            { key: 'reopened', header: 'Reopened', render: (r) => String(r.reopened) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.severity ?? i)}
        />
      </section>

      <section>
        <h2 className="font-semibold mb-2">Bonus Payout Queue</h2>
        <DataTable<BonusRow>
          rows={bonuses}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'streak_months', header: 'Streak (mo)', render: (r) => String(r.streak_months) },
            { key: 'bonus_rupees', header: 'Bonus', render: (r) => fmtMoney(r.bonus_rupees) },
            { key: 'verdict', header: 'Verdict', render: (r) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.engineer_code ?? i)}
        />
      </section>

      <section>
        <h2 className="font-semibold mb-2">Complaint Events</h2>
        <DataTable<EventRow>
          rows={events}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
            { key: 'complaint_ref', header: 'Ref', render: (r) => r.complaint_ref },
            { key: 'raised_on', header: 'Raised', render: (r) => r.raised_on },
            { key: 'resolved_on', header: 'Resolved', render: (r) => r.resolved_on ?? '—' },
            { key: 'resolve_days', header: 'Days', render: (r) => (r.resolve_days == null ? '—' : String(r.resolve_days)) },
            { key: 'severity', header: 'Severity', render: (r) => r.severity },
            { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
            { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '' },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.complaint_ref ?? i)}
        />
      </section>

      <section>
        <h2 className="font-semibold mb-2">Full Streak Table</h2>
        <DataTable<StreakRow>
          rows={streaks}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'region', header: 'Region', render: (r) => r.region },
            { key: 'month_label', header: 'Month', render: (r) => r.month_label },
            { key: 'complaints_received', header: 'Rec', render: (r) => String(r.complaints_received) },
            { key: 'complaints_resolved', header: 'Res', render: (r) => String(r.complaints_resolved) },
            { key: 'avg_resolve_days', header: 'Avg Days', render: (r) => String(r.avg_resolve_days) },
            { key: 'streak_months', header: 'Streak', render: (r) => String(r.streak_months) },
            { key: 'bonus_rupees', header: 'Bonus', render: (r) => fmtMoney(r.bonus_rupees) },
            { key: 'verdict', header: 'Verdict', render: (r) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.engineer_code ?? i)}
        />
      </section>
    </main>
  );
}
