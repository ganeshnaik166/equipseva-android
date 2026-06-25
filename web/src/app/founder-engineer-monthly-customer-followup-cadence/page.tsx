import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_cadences: number;
  on_track: number;
  due_soon: number;
  overdue: number;
  completed: number;
  unique_engineers: number;
  unique_customers: number;
};

type CadenceRow = {
  engineer_name: string;
  engineer_code: string;
  customer_name: string;
  customer_org: string;
  customer_city: string;
  last_touch_at: string;
  last_touch_channel: string;
  cadence_target_days: number;
  next_followup_at: string;
  status: string;
  notes: string | null;
};

type OverdueRow = {
  engineer_code: string;
  engineer_name: string;
  customer_name: string;
  days_overdue: number;
  notes: string | null;
};

type ChannelMixRow = { channel: string; touches: number; pct: number };
type OutcomeRow = { outcome: string; count_n: number; amc_lift_rupees: number; job_lift_rupees: number };
type LeaderboardRow = { engineer_code: string; touches: number; amc_lift_rupees: number; job_lift_rupees: number; positive_pct: number };
type SentimentRow = { sentiment: string; count_n: number; pct: number };
type CityRow = { city: string; customers: number; overdue_n: number };

function fmtDate(s: string | null) {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: 'numeric' });
  } catch {
    return s;
  }
}

function fmtRupees(paise: number) {
  const rupees = Math.round((paise || 0) / 100);
  return '₹' + rupees.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    summaryRes,
    cadenceRes,
    overdueRes,
    channelRes,
    outcomeRes,
    leaderboardRes,
    sentimentRes,
    cityRes,
  ] = await Promise.all([
    supabase.rpc('founder_followup_cadence_summary_r2770'),
    supabase.rpc('founder_followup_cadence_rows_r2770'),
    supabase.rpc('founder_followup_overdue_r2770'),
    supabase.rpc('founder_followup_channel_mix_r2770'),
    supabase.rpc('founder_followup_outcome_summary_r2770'),
    supabase.rpc('founder_followup_engineer_leaderboard_r2770'),
    supabase.rpc('founder_followup_sentiment_mix_r2770'),
    supabase.rpc('founder_followup_city_distribution_r2770'),
  ]);

  const summary = ((summaryRes.data ?? [])[0] ?? {
    total_cadences: 0,
    on_track: 0,
    due_soon: 0,
    overdue: 0,
    completed: 0,
    unique_engineers: 0,
    unique_customers: 0,
  }) as SummaryRow;

  const cadences = (cadenceRes.data ?? []) as CadenceRow[];
  const overdue = (overdueRes.data ?? []) as OverdueRow[];
  const channels = (channelRes.data ?? []) as ChannelMixRow[];
  const outcomes = (outcomeRes.data ?? []) as OutcomeRow[];
  const leaderboard = (leaderboardRes.data ?? []) as LeaderboardRow[];
  const sentiments = (sentimentRes.data ?? []) as SentimentRow[];
  const cities = (cityRes.data ?? []) as CityRow[];

  return (
    <main className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Monthly Customer Followup Cadence</h1>
        <p className="text-sm text-neutral-500">
          Round r2770 — engineer × customer × last touch × cadence × next followup × outcome
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <Kpi label="Total cadences" value={String(summary.total_cadences)} />
        <Kpi label="On track" value={String(summary.on_track)} />
        <Kpi label="Due soon" value={String(summary.due_soon)} />
        <Kpi label="Overdue" value={String(summary.overdue)} />
        <Kpi label="Completed" value={String(summary.completed)} />
        <Kpi label="Engineers" value={String(summary.unique_engineers)} />
        <Kpi label="Customers" value={String(summary.unique_customers)} />
        <Kpi label="Overdue cities" value={String(cities.filter((c) => c.overdue_n > 0).length)} />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Cadence schedule</h2>
        <DataTable
          rows={cadences}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: CadenceRow) => <span>{r.engineer_name} ({r.engineer_code})</span> },
            { key: 'customer_name', header: 'Customer', render: (r: CadenceRow) => <span>{r.customer_name}</span> },
            { key: 'customer_org', header: 'Org', render: (r: CadenceRow) => <span>{r.customer_org}</span> },
            { key: 'customer_city', header: 'City', render: (r: CadenceRow) => <span>{r.customer_city}</span> },
            { key: 'last_touch_at', header: 'Last touch', render: (r: CadenceRow) => <span>{fmtDate(r.last_touch_at)} · {r.last_touch_channel}</span> },
            { key: 'cadence_target_days', header: 'Cadence', render: (r: CadenceRow) => <span>{r.cadence_target_days}d</span> },
            { key: 'next_followup_at', header: 'Next followup', render: (r: CadenceRow) => <span>{fmtDate(r.next_followup_at)}</span> },
            { key: 'status', header: 'Status', render: (r: CadenceRow) => <span>{r.status}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: CadenceRow, i: number) => String(r.engineer_code + '-' + r.customer_name + '-' + i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Overdue followups</h2>
        <DataTable
          rows={overdue}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: OverdueRow) => <span>{r.engineer_name} ({r.engineer_code})</span> },
            { key: 'customer_name', header: 'Customer', render: (r: OverdueRow) => <span>{r.customer_name}</span> },
            { key: 'days_overdue', header: 'Days overdue', render: (r: OverdueRow) => <span>{r.days_overdue}</span> },
            { key: 'notes', header: 'Notes', render: (r: OverdueRow) => <span>{r.notes ?? '-'}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: OverdueRow, i: number) => String(r.engineer_code + '-' + r.customer_name + '-' + i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Channel mix</h2>
        <DataTable
          rows={channels}
          columns={[
            { key: 'channel', header: 'Channel', render: (r: ChannelMixRow) => <span>{r.channel}</span> },
            { key: 'touches', header: 'Touches', render: (r: ChannelMixRow) => <span>{r.touches}</span> },
            { key: 'pct', header: 'Share %', render: (r: ChannelMixRow) => <span>{r.pct}%</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChannelMixRow, i: number) => String(r.channel + '-' + i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => <span>{r.outcome}</span> },
            { key: 'count_n', header: 'Count', render: (r: OutcomeRow) => <span>{r.count_n}</span> },
            { key: 'amc_lift_rupees', header: 'AMC lift', render: (r: OutcomeRow) => <span>{fmtRupees(r.amc_lift_rupees)}</span> },
            { key: 'job_lift_rupees', header: 'Job lift', render: (r: OutcomeRow) => <span>{fmtRupees(r.job_lift_rupees)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.outcome + '-' + i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Engineer leaderboard</h2>
        <DataTable
          rows={leaderboard}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: LeaderboardRow) => <span>{r.engineer_code}</span> },
            { key: 'touches', header: 'Touches', render: (r: LeaderboardRow) => <span>{r.touches}</span> },
            { key: 'amc_lift_rupees', header: 'AMC lift', render: (r: LeaderboardRow) => <span>{fmtRupees(r.amc_lift_rupees)}</span> },
            { key: 'job_lift_rupees', header: 'Job lift', render: (r: LeaderboardRow) => <span>{fmtRupees(r.job_lift_rupees)}</span> },
            { key: 'positive_pct', header: 'Positive %', render: (r: LeaderboardRow) => <span>{r.positive_pct ?? 0}%</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: LeaderboardRow, i: number) => String(r.engineer_code + '-' + i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Sentiment mix</h2>
        <DataTable
          rows={sentiments}
          columns={[
            { key: 'sentiment', header: 'Sentiment', render: (r: SentimentRow) => <span>{r.sentiment}</span> },
            { key: 'count_n', header: 'Count', render: (r: SentimentRow) => <span>{r.count_n}</span> },
            { key: 'pct', header: 'Share %', render: (r: SentimentRow) => <span>{r.pct}%</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: SentimentRow, i: number) => String(r.sentiment + '-' + i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">City distribution</h2>
        <DataTable
          rows={cities}
          columns={[
            { key: 'city', header: 'City', render: (r: CityRow) => <span>{r.city}</span> },
            { key: 'customers', header: 'Customers', render: (r: CityRow) => <span>{r.customers}</span> },
            { key: 'overdue_n', header: 'Overdue', render: (r: CityRow) => <span>{r.overdue_n}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: CityRow, i: number) => String(r.city + '-' + i)}
        />
      </section>
    </main>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-4">
      <div className="text-xs text-neutral-500">{label}</div>
      <div className="mt-1 text-xl font-semibold">{value}</div>
    </div>
  );
}
