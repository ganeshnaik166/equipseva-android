import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_incidents: number;
  critical_incidents: number;
  translator_use_pct: number;
  avg_translator_minutes: number;
  avg_csat_delta_pct: number;
  total_extra_cost_rupees: number;
};

type Incident = {
  job_code: string;
  city: string;
  hospital_name: string;
  engineer_name: string;
  engineer_language: string;
  customer_language: string;
  severity: string;
  outcome: string;
  translator_minutes: number;
  csat_delta_pct: number;
  extra_cost_rupees: number;
};

type PairRow = {
  pair: string;
  incidents: number;
  critical_count: number;
  translator_pct: number;
  avg_csat_delta: number;
  total_cost_rupees: number;
};

type MonthlyRow = {
  rollup_month: string;
  total_incidents: number;
  critical_incidents: number;
  translator_invocations: number;
  translator_minutes_total: number;
  reassignments: number;
  refunds_issued: number;
  avg_csat_delta_pct: number;
  total_extra_cost_rupees: number;
  top_mismatch_pair: string | null;
};

type OutcomeRow = {
  outcome: string;
  incidents: number;
  pct_of_total: number;
  avg_csat_delta: number;
  total_cost_rupees: number;
};

type CityRow = {
  city: string;
  incidents: number;
  critical_count: number;
  translator_minutes_total: number;
  total_cost_rupees: number;
};

type RoiRow = {
  with_translator_avg_csat: number;
  without_translator_avg_csat: number;
  with_translator_avg_cost: number;
  without_translator_avg_cost: number;
  csat_swing_pct: number;
};

type SeverityRow = {
  severity: string;
  incidents: number;
  pct_of_total: number;
  avg_translator_minutes: number;
  total_cost_rupees: number;
};

function fmtMoney(n: number | null | undefined) {
  if (n === null || n === undefined) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined) {
  if (n === null || n === undefined) return '0%';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, recentRes, pairRes, trendRes, outcomeRes, cityRes, roiRes, sevRes] = await Promise.all([
    supabase.rpc('founder_lang_mismatch_kpis_r2768'),
    supabase.rpc('founder_lang_mismatch_recent_incidents_r2768'),
    supabase.rpc('founder_lang_mismatch_pair_breakdown_r2768'),
    supabase.rpc('founder_lang_mismatch_monthly_trend_r2768'),
    supabase.rpc('founder_lang_mismatch_outcomes_r2768'),
    supabase.rpc('founder_lang_mismatch_city_hotspots_r2768'),
    supabase.rpc('founder_lang_mismatch_translator_roi_r2768'),
    supabase.rpc('founder_lang_mismatch_severity_mix_r2768'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? {
    total_incidents: 0,
    critical_incidents: 0,
    translator_use_pct: 0,
    avg_translator_minutes: 0,
    avg_csat_delta_pct: 0,
    total_extra_cost_rupees: 0,
  }) as Kpi;

  const recent: Incident[] = (recentRes.data ?? []) as Incident[];
  const pairs: PairRow[] = (pairRes.data ?? []) as PairRow[];
  const monthly: MonthlyRow[] = (trendRes.data ?? []) as MonthlyRow[];
  const outcomes: OutcomeRow[] = (outcomeRes.data ?? []) as OutcomeRow[];
  const cities: CityRow[] = (cityRes.data ?? []) as CityRow[];
  const roi: RoiRow = (roiRes.data?.[0] ?? {
    with_translator_avg_csat: 0,
    without_translator_avg_csat: 0,
    with_translator_avg_cost: 0,
    without_translator_avg_cost: 0,
    csat_swing_pct: 0,
  }) as RoiRow;
  const severities: SeverityRow[] = (sevRes.data ?? []) as SeverityRow[];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Engineer & Customer Language Mismatch Incidents</h1>
        <p className="text-sm text-gray-600">
          Monthly view of jobs where engineer language differs from customer language. Tracks translator
          usage, CSAT impact, outcome mix, and cost overhead.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <div className="rounded border p-4 bg-white">
          <div className="text-xs text-gray-500">Total Incidents</div>
          <div className="text-xl font-semibold">{kpi.total_incidents}</div>
        </div>
        <div className="rounded border p-4 bg-white">
          <div className="text-xs text-gray-500">Critical</div>
          <div className="text-xl font-semibold">{kpi.critical_incidents}</div>
        </div>
        <div className="rounded border p-4 bg-white">
          <div className="text-xs text-gray-500">Translator Use</div>
          <div className="text-xl font-semibold">{fmtPct(kpi.translator_use_pct)}</div>
        </div>
        <div className="rounded border p-4 bg-white">
          <div className="text-xs text-gray-500">Avg Translator Min</div>
          <div className="text-xl font-semibold">{Number(kpi.avg_translator_minutes ?? 0).toFixed(1)}</div>
        </div>
        <div className="rounded border p-4 bg-white">
          <div className="text-xs text-gray-500">Avg CSAT Delta</div>
          <div className="text-xl font-semibold">{fmtPct(kpi.avg_csat_delta_pct)}</div>
        </div>
        <div className="rounded border p-4 bg-white">
          <div className="text-xs text-gray-500">Total Extra Cost</div>
          <div className="text-xl font-semibold">{fmtMoney(kpi.total_extra_cost_rupees)}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Incidents</h2>
        <DataTable
          rows={recent}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: Incident) => r.job_code },
            { key: 'city', header: 'City', render: (r: Incident) => r.city },
            { key: 'hospital_name', header: 'Hospital', render: (r: Incident) => r.hospital_name },
            { key: 'engineer_name', header: 'Engineer', render: (r: Incident) => r.engineer_name },
            { key: 'eng_lang', header: 'Eng Lang', render: (r: Incident) => r.engineer_language },
            { key: 'cust_lang', header: 'Cust Lang', render: (r: Incident) => r.customer_language },
            { key: 'severity', header: 'Severity', render: (r: Incident) => r.severity },
            { key: 'outcome', header: 'Outcome', render: (r: Incident) => r.outcome },
            { key: 'translator_minutes', header: 'Tr Min', render: (r: Incident) => String(r.translator_minutes) },
            { key: 'csat_delta_pct', header: 'CSAT Δ', render: (r: Incident) => fmtPct(r.csat_delta_pct) },
            { key: 'extra_cost_rupees', header: 'Extra Cost', render: (r: Incident) => fmtMoney(r.extra_cost_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Incident, i: number) => String(r.job_code ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Language Pair Breakdown</h2>
        <DataTable
          rows={pairs}
          columns={[
            { key: 'pair', header: 'Pair (eng -> cust)', render: (r: PairRow) => r.pair },
            { key: 'incidents', header: 'Incidents', render: (r: PairRow) => String(r.incidents) },
            { key: 'critical_count', header: 'Critical', render: (r: PairRow) => String(r.critical_count) },
            { key: 'translator_pct', header: 'Translator %', render: (r: PairRow) => fmtPct(r.translator_pct) },
            { key: 'avg_csat_delta', header: 'Avg CSAT Δ', render: (r: PairRow) => fmtPct(r.avg_csat_delta) },
            { key: 'total_cost_rupees', header: 'Total Cost', render: (r: PairRow) => fmtMoney(r.total_cost_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: PairRow, i: number) => String(r.pair ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Monthly Trend</h2>
        <DataTable
          rows={monthly}
          columns={[
            { key: 'rollup_month', header: 'Month', render: (r: MonthlyRow) => r.rollup_month },
            { key: 'total_incidents', header: 'Incidents', render: (r: MonthlyRow) => String(r.total_incidents) },
            { key: 'critical_incidents', header: 'Critical', render: (r: MonthlyRow) => String(r.critical_incidents) },
            { key: 'translator_invocations', header: 'Tr Calls', render: (r: MonthlyRow) => String(r.translator_invocations) },
            { key: 'translator_minutes_total', header: 'Tr Min Tot', render: (r: MonthlyRow) => String(r.translator_minutes_total) },
            { key: 'reassignments', header: 'Reassign', render: (r: MonthlyRow) => String(r.reassignments) },
            { key: 'refunds_issued', header: 'Refunds', render: (r: MonthlyRow) => String(r.refunds_issued) },
            { key: 'avg_csat_delta_pct', header: 'Avg CSAT Δ', render: (r: MonthlyRow) => fmtPct(r.avg_csat_delta_pct) },
            { key: 'total_extra_cost_rupees', header: 'Extra Cost', render: (r: MonthlyRow) => fmtMoney(r.total_extra_cost_rupees) },
            { key: 'top_mismatch_pair', header: 'Top Pair', render: (r: MonthlyRow) => r.top_mismatch_pair ?? '' },
          ]}
          emptyMessage="No data"
          rowKey={(r: MonthlyRow, i: number) => String(r.rollup_month ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Outcome Mix</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
            { key: 'incidents', header: 'Incidents', render: (r: OutcomeRow) => String(r.incidents) },
            { key: 'pct_of_total', header: '% of Total', render: (r: OutcomeRow) => fmtPct(r.pct_of_total) },
            { key: 'avg_csat_delta', header: 'Avg CSAT Δ', render: (r: OutcomeRow) => fmtPct(r.avg_csat_delta) },
            { key: 'total_cost_rupees', header: 'Total Cost', render: (r: OutcomeRow) => fmtMoney(r.total_cost_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">City Hotspots</h2>
        <DataTable
          rows={cities}
          columns={[
            { key: 'city', header: 'City', render: (r: CityRow) => r.city },
            { key: 'incidents', header: 'Incidents', render: (r: CityRow) => String(r.incidents) },
            { key: 'critical_count', header: 'Critical', render: (r: CityRow) => String(r.critical_count) },
            { key: 'translator_minutes_total', header: 'Tr Min Tot', render: (r: CityRow) => String(r.translator_minutes_total) },
            { key: 'total_cost_rupees', header: 'Total Cost', render: (r: CityRow) => fmtMoney(r.total_cost_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CityRow, i: number) => String(r.city ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Translator ROI</h2>
        <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
          <div className="rounded border p-4 bg-white">
            <div className="text-xs text-gray-500">CSAT w/ Translator</div>
            <div className="text-xl font-semibold">{fmtPct(roi.with_translator_avg_csat)}</div>
          </div>
          <div className="rounded border p-4 bg-white">
            <div className="text-xs text-gray-500">CSAT w/o Translator</div>
            <div className="text-xl font-semibold">{fmtPct(roi.without_translator_avg_csat)}</div>
          </div>
          <div className="rounded border p-4 bg-white">
            <div className="text-xs text-gray-500">Avg Cost w/ Translator</div>
            <div className="text-xl font-semibold">{fmtMoney(roi.with_translator_avg_cost)}</div>
          </div>
          <div className="rounded border p-4 bg-white">
            <div className="text-xs text-gray-500">Avg Cost w/o Translator</div>
            <div className="text-xl font-semibold">{fmtMoney(roi.without_translator_avg_cost)}</div>
          </div>
          <div className="rounded border p-4 bg-white">
            <div className="text-xs text-gray-500">CSAT Swing</div>
            <div className="text-xl font-semibold">{fmtPct(roi.csat_swing_pct)}</div>
          </div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Severity Mix</h2>
        <DataTable
          rows={severities}
          columns={[
            { key: 'severity', header: 'Severity', render: (r: SeverityRow) => r.severity },
            { key: 'incidents', header: 'Incidents', render: (r: SeverityRow) => String(r.incidents) },
            { key: 'pct_of_total', header: '% of Total', render: (r: SeverityRow) => fmtPct(r.pct_of_total) },
            { key: 'avg_translator_minutes', header: 'Avg Tr Min', render: (r: SeverityRow) => Number(r.avg_translator_minutes ?? 0).toFixed(1) },
            { key: 'total_cost_rupees', header: 'Total Cost', render: (r: SeverityRow) => fmtMoney(r.total_cost_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: SeverityRow, i: number) => String(r.severity ?? i)}
        />
      </section>
    </main>
  );
}