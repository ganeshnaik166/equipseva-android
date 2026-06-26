import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_jobs: number;
  within_window_count: number;
  within_window_pct: number;
  median_deviation_minutes: number;
  grossly_late_count: number;
  promises_refined: number;
};

type WindowRow = {
  id: string;
  job_ref: string;
  customer_org: string;
  engineer_name: string;
  city: string;
  promised_window_start: string;
  promised_window_end: string;
  actual_arrival_at: string;
  deviation_minutes: number;
  within_window: boolean;
  accuracy_band: string;
};

type BandRow = {
  accuracy_band: string;
  job_count: number;
  share_pct: number;
  avg_abs_deviation: number;
};

type CityRow = {
  city: string;
  total_jobs: number;
  within_window_pct: number;
  median_deviation_minutes: number;
};

type RefinementRow = {
  id: string;
  engineer_name: string;
  city: string;
  total_jobs: number;
  on_time_count: number;
  median_deviation_minutes: number;
  p90_deviation_minutes: number;
  previous_window_minutes: number;
  recommended_window_minutes: number;
  recommendation_status: string;
  applied_at: string | null;
};

type SummaryRow = {
  recommendation_status: string;
  engineer_count: number;
  avg_recommended_window: number;
  applied_count: number;
};

type WorstRow = {
  engineer_name: string;
  city: string;
  late_jobs: number;
  avg_late_minutes: number;
  recommended_window_minutes: number | null;
};

function fmtDateTime(iso: string) {
  try {
    return new Date(iso).toLocaleString('en-IN', { dateStyle: 'short', timeStyle: 'short' });
  } catch {
    return iso;
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, listRes, bandRes, cityRes, refineRes, summaryRes, worstRes] = await Promise.all([
    supabase.rpc('founder_arrival_window_kpis_r2800'),
    supabase.rpc('founder_arrival_window_list_r2800'),
    supabase.rpc('founder_arrival_band_breakdown_r2800'),
    supabase.rpc('founder_arrival_city_precision_r2800'),
    supabase.rpc('founder_arrival_refinement_list_r2800'),
    supabase.rpc('founder_arrival_refinement_summary_r2800'),
    supabase.rpc('founder_arrival_worst_engineers_r2800'),
  ]);

  const kpi: Kpi | null = (kpiRes.data && kpiRes.data[0]) || null;
  const windows: WindowRow[] = listRes.data || [];
  const bands: BandRow[] = bandRes.data || [];
  const cities: CityRow[] = cityRes.data || [];
  const refines: RefinementRow[] = refineRes.data || [];
  const summary: SummaryRow[] = summaryRes.data || [];
  const worst: WorstRow[] = worstRes.data || [];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
          Engineer Arrival Time-Window Precision
        </h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Job-level promised window vs actual arrival. Tracks deviation, ETA accuracy, and feeds the
          promise-refinement loop that tightens or widens future windows per engineer.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total jobs" value={kpi?.total_jobs ?? 0} />
        <KpiCard label="Within window" value={`${kpi?.within_window_count ?? 0} (${kpi?.within_window_pct ?? 0}%)`} />
        <KpiCard label="Median deviation (min)" value={kpi?.median_deviation_minutes ?? 0} />
        <KpiCard label="Grossly late" value={kpi?.grossly_late_count ?? 0} tone="bad" />
        <KpiCard label="Promises refined" value={kpi?.promises_refined ?? 0} tone="good" />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Accuracy band breakdown</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 10 }}>
          Bands: on_time (|dev| &lt;= 10m), early_minor / late_minor (10&lt; |dev| &lt;= 30), early_major / late_major (30 &lt; |dev| &lt;= 60), grossly_late (&gt; 60m late).
        </p>
        <DataTable
          rows={bands}
          rowKey={(r, i) => String((r as BandRow).accuracy_band ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'accuracy_band', header: 'Band', render: (r: BandRow) => r.accuracy_band },
            { key: 'job_count', header: 'Jobs', render: (r: BandRow) => r.job_count },
            { key: 'share_pct', header: 'Share %', render: (r: BandRow) => `${r.share_pct}%` },
            { key: 'avg_abs_deviation', header: 'Avg |deviation| min', render: (r: BandRow) => r.avg_abs_deviation },
          ]}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>City precision</h2>
        <DataTable
          rows={cities}
          rowKey={(r, i) => String((r as CityRow).city ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'city', header: 'City', render: (r: CityRow) => r.city },
            { key: 'total_jobs', header: 'Jobs', render: (r: CityRow) => r.total_jobs },
            { key: 'within_window_pct', header: 'Within window %', render: (r: CityRow) => `${r.within_window_pct}%` },
            { key: 'median_deviation_minutes', header: 'Median dev (min)', render: (r: CityRow) => r.median_deviation_minutes },
          ]}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent arrivals</h2>
        <DataTable
          rows={windows}
          rowKey={(r, i) => String((r as WindowRow).id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'job_ref', header: 'Job', render: (r: WindowRow) => r.job_ref },
            { key: 'customer_org', header: 'Customer', render: (r: WindowRow) => r.customer_org },
            { key: 'engineer_name', header: 'Engineer', render: (r: WindowRow) => r.engineer_name },
            { key: 'city', header: 'City', render: (r: WindowRow) => r.city },
            { key: 'promised', header: 'Promised window', render: (r: WindowRow) => `${fmtDateTime(r.promised_window_start)} → ${fmtDateTime(r.promised_window_end)}` },
            { key: 'actual_arrival_at', header: 'Actual', render: (r: WindowRow) => fmtDateTime(r.actual_arrival_at) },
            { key: 'deviation_minutes', header: 'Deviation (min)', render: (r: WindowRow) => r.deviation_minutes },
            { key: 'within_window', header: 'In window', render: (r: WindowRow) => (r.within_window ? 'yes' : 'no') },
            { key: 'accuracy_band', header: 'Band', render: (r: WindowRow) => r.accuracy_band },
          ]}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Promise refinement summary</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 10 }}>
          Status meaning: tighten (engineer reliably on time, narrow future windows), widen
          (chronic deviation, widen windows so we stop missing them), hold (no change), re_evaluate
          (early-arrival heavy — investigate overestimated travel times).
        </p>
        <DataTable
          rows={summary}
          rowKey={(r, i) => String((r as SummaryRow).recommendation_status ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'recommendation_status', header: 'Status', render: (r: SummaryRow) => r.recommendation_status },
            { key: 'engineer_count', header: 'Engineers', render: (r: SummaryRow) => r.engineer_count },
            { key: 'avg_recommended_window', header: 'Avg recommended (min)', render: (r: SummaryRow) => r.avg_recommended_window },
            { key: 'applied_count', header: 'Applied', render: (r: SummaryRow) => r.applied_count },
          ]}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Engineer-level refinement</h2>
        <DataTable
          rows={refines}
          rowKey={(r, i) => String((r as RefinementRow).id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: RefinementRow) => r.engineer_name },
            { key: 'city', header: 'City', render: (r: RefinementRow) => r.city },
            { key: 'total_jobs', header: 'Jobs', render: (r: RefinementRow) => r.total_jobs },
            { key: 'on_time_count', header: 'On time', render: (r: RefinementRow) => r.on_time_count },
            { key: 'median_deviation_minutes', header: 'Median dev', render: (r: RefinementRow) => r.median_deviation_minutes },
            { key: 'p90_deviation_minutes', header: 'P90 dev', render: (r: RefinementRow) => r.p90_deviation_minutes },
            { key: 'window_change', header: 'Window prev → new', render: (r: RefinementRow) => `${r.previous_window_minutes} → ${r.recommended_window_minutes}` },
            { key: 'recommendation_status', header: 'Status', render: (r: RefinementRow) => r.recommendation_status },
            { key: 'applied_at', header: 'Applied', render: (r: RefinementRow) => (r.applied_at ? fmtDateTime(r.applied_at) : '—') },
          ]}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Worst-offender engineers</h2>
        <DataTable
          rows={worst}
          rowKey={(r, i) => String(`${(r as WorstRow).engineer_name}-${(r as WorstRow).city}` ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: WorstRow) => r.engineer_name },
            { key: 'city', header: 'City', render: (r: WorstRow) => r.city },
            { key: 'late_jobs', header: 'Late jobs', render: (r: WorstRow) => r.late_jobs },
            { key: 'avg_late_minutes', header: 'Avg late (min)', render: (r: WorstRow) => r.avg_late_minutes },
            { key: 'recommended_window_minutes', header: 'Recommended window (min)', render: (r: WorstRow) => r.recommended_window_minutes ?? '—' },
          ]}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: number | string; tone?: 'good' | 'bad' }) {
  const color = tone === 'bad' ? '#b00020' : tone === 'good' ? '#0a7d2c' : '#111';
  return (
    <div style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: 12, padding: 16 }}>
      <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, color, marginTop: 6 }}>{value}</div>
    </div>
  );
}
