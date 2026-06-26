import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_offers: number;
  total_accepted: number;
  acceptance_rate: number | null;
  avg_dwell: number | null;
  avg_bond: number | null;
};

type EngineerRow = {
  engineer_name: string;
  offers: number;
  accepted: number;
  acceptance_rate: number | null;
  avg_dwell: number | null;
  avg_bond: number | null;
};

type VerdictRow = {
  verdict: string;
  visits: number;
  avg_bond: number | null;
  avg_dwell: number | null;
};

type OutcomeRow = {
  outcome: string;
  visits: number;
  acceptance_rate: number | null;
};

type BandRow = {
  band: string;
  engineers: number;
  avg_acceptance: number | null;
  avg_bond: number | null;
};

type RedWatchRow = {
  engineer_name: string;
  band: string;
  acceptance_rate: number | null;
  avg_bond_score: number | null;
  founder_note: string | null;
};

type RecentRow = {
  offer_month: string;
  engineer_name: string;
  customer_name: string;
  job_code: string;
  tea_offered: boolean;
  tea_accepted: boolean;
  dwell_minutes: number;
  bond_score: number;
  outcome: string;
  verdict: string;
};

type ExemplarRow = {
  engineer_name: string;
  exemplar_visits: number;
  warm_bond_visits: number;
  total_visits: number;
};

function fmt(n: number | null | undefined, suffix = ''): string {
  if (n === null || n === undefined) return '-';
  return String(n) + suffix;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpiRes,
    engineerRes,
    verdictRes,
    outcomeRes,
    bandRes,
    redWatchRes,
    recentRes,
    exemplarRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2884_kpi_summary'),
    supabase.rpc('founder_r2884_by_engineer'),
    supabase.rpc('founder_r2884_by_verdict'),
    supabase.rpc('founder_r2884_by_outcome'),
    supabase.rpc('founder_r2884_audit_bands'),
    supabase.rpc('founder_r2884_red_watch'),
    supabase.rpc('founder_r2884_recent_offers'),
    supabase.rpc('founder_r2884_exemplar_leaderboard'),
  ]);

  const kpi: KpiRow = (kpiRes.data?.[0] as KpiRow) ?? {
    total_offers: 0,
    total_accepted: 0,
    acceptance_rate: 0,
    avg_dwell: 0,
    avg_bond: 0,
  };
  const engineerRows: EngineerRow[] = (engineerRes.data as EngineerRow[]) ?? [];
  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const outcomeRows: OutcomeRow[] = (outcomeRes.data as OutcomeRow[]) ?? [];
  const bandRows: BandRow[] = (bandRes.data as BandRow[]) ?? [];
  const redWatchRows: RedWatchRow[] = (redWatchRes.data as RedWatchRow[]) ?? [];
  const recentRows: RecentRow[] = (recentRes.data as RecentRow[]) ?? [];
  const exemplarRows: ExemplarRow[] = (exemplarRes.data as ExemplarRow[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">
          Customer Monthly — Engineer-Job Customer Tea Acceptance
        </h1>
        <p className="text-sm text-gray-600">
          Round r2884 — engineer × tea offered × accepted × dwell × bond × outcome × verdict.
          Tea acceptance &gt;= 70% signals warm rapport; &lt; 30% flags escalation.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total Visits</div>
          <div className="text-xl font-semibold">{kpi.total_offers}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Tea Accepted</div>
          <div className="text-xl font-semibold">{kpi.total_accepted}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Acceptance Rate</div>
          <div className="text-xl font-semibold">{fmt(kpi.acceptance_rate, '%')}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Avg Dwell (min)</div>
          <div className="text-xl font-semibold">{fmt(kpi.avg_dwell)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Avg Bond Score</div>
          <div className="text-xl font-semibold">{fmt(kpi.avg_bond)}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">By Engineer</h2>
        <DataTable
          rows={engineerRows}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => r.engineer_name },
            { key: 'offers', header: 'Offers', render: (r: EngineerRow) => String(r.offers) },
            { key: 'accepted', header: 'Accepted', render: (r: EngineerRow) => String(r.accepted) },
            { key: 'acceptance_rate', header: 'Accept %', render: (r: EngineerRow) => fmt(r.acceptance_rate, '%') },
            { key: 'avg_dwell', header: 'Avg Dwell', render: (r: EngineerRow) => fmt(r.avg_dwell) },
            { key: 'avg_bond', header: 'Avg Bond', render: (r: EngineerRow) => fmt(r.avg_bond) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">By Verdict</h2>
        <DataTable
          rows={verdictRows}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
            { key: 'visits', header: 'Visits', render: (r: VerdictRow) => String(r.visits) },
            { key: 'avg_bond', header: 'Avg Bond', render: (r: VerdictRow) => fmt(r.avg_bond) },
            { key: 'avg_dwell', header: 'Avg Dwell', render: (r: VerdictRow) => fmt(r.avg_dwell) },
          ]}
          emptyMessage="No data"
          rowKey={(r: VerdictRow, i: number) => String(r.verdict ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">By Outcome</h2>
        <DataTable
          rows={outcomeRows}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
            { key: 'visits', header: 'Visits', render: (r: OutcomeRow) => String(r.visits) },
            { key: 'acceptance_rate', header: 'Accept %', render: (r: OutcomeRow) => fmt(r.acceptance_rate, '%') },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Audit Bands</h2>
        <DataTable
          rows={bandRows}
          columns={[
            { key: 'band', header: 'Band', render: (r: BandRow) => r.band },
            { key: 'engineers', header: 'Engineers', render: (r: BandRow) => String(r.engineers) },
            { key: 'avg_acceptance', header: 'Avg Accept %', render: (r: BandRow) => fmt(r.avg_acceptance, '%') },
            { key: 'avg_bond', header: 'Avg Bond', render: (r: BandRow) => fmt(r.avg_bond) },
          ]}
          emptyMessage="No data"
          rowKey={(r: BandRow, i: number) => String(r.band ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Red &amp; Watch List</h2>
        <p className="text-xs text-gray-500">
          Acceptance &lt; 30% or bond &lt; 40 — founder action required.
        </p>
        <DataTable
          rows={redWatchRows}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: RedWatchRow) => r.engineer_name },
            { key: 'band', header: 'Band', render: (r: RedWatchRow) => r.band },
            { key: 'acceptance_rate', header: 'Accept %', render: (r: RedWatchRow) => fmt(r.acceptance_rate, '%') },
            { key: 'avg_bond_score', header: 'Avg Bond', render: (r: RedWatchRow) => fmt(r.avg_bond_score) },
            { key: 'founder_note', header: 'Founder Note', render: (r: RedWatchRow) => r.founder_note ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: RedWatchRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Exemplar Leaderboard</h2>
        <DataTable
          rows={exemplarRows}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: ExemplarRow) => r.engineer_name },
            { key: 'exemplar_visits', header: 'Exemplar', render: (r: ExemplarRow) => String(r.exemplar_visits) },
            { key: 'warm_bond_visits', header: 'Warm Bond', render: (r: ExemplarRow) => String(r.warm_bond_visits) },
            { key: 'total_visits', header: 'Total Visits', render: (r: ExemplarRow) => String(r.total_visits) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ExemplarRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Recent Offers Feed</h2>
        <DataTable
          rows={recentRows}
          columns={[
            { key: 'offer_month', header: 'Month', render: (r: RecentRow) => r.offer_month },
            { key: 'engineer_name', header: 'Engineer', render: (r: RecentRow) => r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: RecentRow) => r.customer_name },
            { key: 'job_code', header: 'Job', render: (r: RecentRow) => r.job_code },
            { key: 'tea_offered', header: 'Offered', render: (r: RecentRow) => (r.tea_offered ? 'yes' : 'no') },
            { key: 'tea_accepted', header: 'Accepted', render: (r: RecentRow) => (r.tea_accepted ? 'yes' : 'no') },
            { key: 'dwell_minutes', header: 'Dwell (min)', render: (r: RecentRow) => String(r.dwell_minutes) },
            { key: 'bond_score', header: 'Bond', render: (r: RecentRow) => String(r.bond_score) },
            { key: 'outcome', header: 'Outcome', render: (r: RecentRow) => r.outcome },
            { key: 'verdict', header: 'Verdict', render: (r: RecentRow) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: RecentRow, i: number) => String(r.job_code ?? i)}
        />
      </section>
    </div>
  );
}
