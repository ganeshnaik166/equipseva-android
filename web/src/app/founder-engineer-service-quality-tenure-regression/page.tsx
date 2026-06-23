import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Cohort = {
  id: string;
  cohort_label: string;
  tenure_months_min: number;
  tenure_months_max: number;
  engineer_count: number;
  job_count: number;
  avg_rating: number | null;
  avg_first_visit_fix_rate: number | null;
  avg_rework_rate: number | null;
  avg_sla_breach_rate: number | null;
  avg_complaint_rate: number | null;
  quality_index: number | null;
  computed_at: string;
};

type Point = {
  id: string;
  engineer_name: string;
  tenure_months: number;
  jobs_completed: number;
  avg_rating: number | null;
  first_visit_fix_rate: number | null;
  rework_rate: number | null;
  sla_breach_rate: number | null;
  complaint_rate: number | null;
  quality_index: number | null;
  outlier_flag: boolean;
  outlier_reason: string | null;
  plateau_segment: string | null;
};

type Summary = {
  total_cohorts: number;
  total_engineers_charted: number;
  outlier_count: number;
  peak_quality_cohort: string | null;
  plateau_start_months: number | null;
  rookie_quality_index: number | null;
  peak_quality_index: number | null;
  late_quality_index: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [{ data: cohorts }, { data: points }, { data: summary }] = await Promise.all([
    supabase.rpc('r2326_list_cohorts'),
    supabase.rpc('r2326_list_points'),
    supabase.rpc('r2326_summary'),
  ]);

  const cohortRows: Cohort[] = (cohorts as Cohort[]) ?? [];
  const pointRows: Point[] = (points as Point[]) ?? [];
  const s: Summary | null = Array.isArray(summary) ? (summary[0] as Summary) ?? null : (summary as Summary) ?? null;

  const peakIdx = s?.peak_quality_index ?? 0;
  const rookieIdx = s?.rookie_quality_index ?? 0;
  const lateIdx = s?.late_quality_index ?? 0;
  const plateauNote =
    peakIdx && lateIdx && Math.abs(peakIdx - lateIdx) <= 2
      ? 'Plateau detected: quality flattens after peak'
      : peakIdx > lateIdx
        ? 'Decline after peak: senior engineers regressing'
        : 'Still climbing: no plateau yet';

  const cohortCols = [
    { key: 'cohort_label', header: 'Cohort', render: (r: Cohort) => r.cohort_label },
    {
      key: 'tenure_range',
      header: 'Tenure (months)',
      render: (r: Cohort) => `${r.tenure_months_min} – ${r.tenure_months_max}`,
    },
    { key: 'engineer_count', header: 'Engineers', render: (r: Cohort) => r.engineer_count },
    { key: 'job_count', header: 'Jobs', render: (r: Cohort) => r.job_count },
    {
      key: 'avg_rating',
      header: 'Avg Rating',
      render: (r: Cohort) => (r.avg_rating == null ? '—' : Number(r.avg_rating).toFixed(2)),
    },
    {
      key: 'fvf',
      header: 'First-visit fix %',
      render: (r: Cohort) =>
        r.avg_first_visit_fix_rate == null ? '—' : `${Number(r.avg_first_visit_fix_rate).toFixed(1)}%`,
    },
    {
      key: 'rework',
      header: 'Rework %',
      render: (r: Cohort) => (r.avg_rework_rate == null ? '—' : `${Number(r.avg_rework_rate).toFixed(1)}%`),
    },
    {
      key: 'sla',
      header: 'SLA breach %',
      render: (r: Cohort) =>
        r.avg_sla_breach_rate == null ? '—' : `${Number(r.avg_sla_breach_rate).toFixed(1)}%`,
    },
    {
      key: 'complaint',
      header: 'Complaint %',
      render: (r: Cohort) =>
        r.avg_complaint_rate == null ? '—' : `${Number(r.avg_complaint_rate).toFixed(1)}%`,
    },
    {
      key: 'quality_index',
      header: 'Quality Index',
      render: (r: Cohort) => (r.quality_index == null ? '—' : Number(r.quality_index).toFixed(1)),
    },
  ];

  const pointCols = [
    { key: 'engineer_name', header: 'Engineer', render: (r: Point) => r.engineer_name },
    { key: 'tenure_months', header: 'Tenure (mo)', render: (r: Point) => r.tenure_months },
    { key: 'jobs_completed', header: 'Jobs', render: (r: Point) => r.jobs_completed },
    {
      key: 'avg_rating',
      header: 'Rating',
      render: (r: Point) => (r.avg_rating == null ? '—' : Number(r.avg_rating).toFixed(2)),
    },
    {
      key: 'fvf',
      header: 'FVF %',
      render: (r: Point) =>
        r.first_visit_fix_rate == null ? '—' : `${Number(r.first_visit_fix_rate).toFixed(1)}%`,
    },
    {
      key: 'rework',
      header: 'Rework %',
      render: (r: Point) => (r.rework_rate == null ? '—' : `${Number(r.rework_rate).toFixed(1)}%`),
    },
    {
      key: 'sla',
      header: 'SLA breach %',
      render: (r: Point) =>
        r.sla_breach_rate == null ? '—' : `${Number(r.sla_breach_rate).toFixed(1)}%`,
    },
    {
      key: 'quality_index',
      header: 'Q-Index',
      render: (r: Point) => (r.quality_index == null ? '—' : Number(r.quality_index).toFixed(1)),
    },
    {
      key: 'plateau_segment',
      header: 'Segment',
      render: (r: Point) => r.plateau_segment ?? '—',
    },
    {
      key: 'outlier_flag',
      header: 'Outlier',
      render: (r: Point) => (r.outlier_flag ? `Yes — ${r.outlier_reason ?? ''}` : 'No'),
    },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Engineer service-quality vs tenure
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Does service quality improve with engineer tenure? Curve, plateau detection, outlier review.
      </p>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 12,
          marginBottom: 24,
        }}
      >
        <Stat label="Cohorts charted" value={s?.total_cohorts ?? 0} />
        <Stat label="Engineers in sample" value={s?.total_engineers_charted ?? 0} />
        <Stat label="Outliers flagged" value={s?.outlier_count ?? 0} />
        <Stat
          label="Peak cohort"
          value={s?.peak_quality_cohort ?? '—'}
          sub={s?.plateau_start_months != null ? `from ${s.plateau_start_months} mo` : ''}
        />
        <Stat
          label="Rookie Q-Index"
          value={rookieIdx ? Number(rookieIdx).toFixed(1) : '—'}
        />
        <Stat
          label="Peak Q-Index"
          value={peakIdx ? Number(peakIdx).toFixed(1) : '—'}
        />
        <Stat
          label="Late-tenure Q-Index"
          value={lateIdx ? Number(lateIdx).toFixed(1) : '—'}
          sub={plateauNote}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Tenure curve (cohorts)</h2>
        <TenureCurve rows={cohortRows} />
        <div style={{ marginTop: 16 }}>
          <DataTable<Cohort>
            rows={cohortRows}
            columns={cohortCols}
            rowKey={(r) => r.id}
            emptyMessage="No cohort buckets yet. Add buckets via r2326_add_cohort."
          />
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Engineer datapoints (n = {pointRows.length})
        </h2>
        <DataTable<Point>
          rows={pointRows}
          columns={pointCols}
          rowKey={(r) => r.id}
          emptyMessage="No engineer datapoints. Add via r2326_add_point."
        />
      </section>
    </main>
  );
}

function Stat({ label, value, sub }: { label: string; value: string | number; sub?: string }) {
  return (
    <div
      style={{
        border: '1px solid #e5e7eb',
        borderRadius: 8,
        padding: 12,
        background: '#fff',
      }}
    >
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 600 }}>{value}</div>
      {sub ? <div style={{ fontSize: 11, color: '#888', marginTop: 4 }}>{sub}</div> : null}
    </div>
  );
}

function TenureCurve({ rows }: { rows: Cohort[] }) {
  if (rows.length === 0) {
    return (
      <div style={{ padding: 16, border: '1px dashed #ddd', borderRadius: 8, color: '#888' }}>
        No cohort data — curve will render once buckets are loaded.
      </div>
    );
  }
  const max = Math.max(...rows.map((r) => Number(r.quality_index ?? 0)), 1);
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'flex-end',
        gap: 8,
        padding: 16,
        border: '1px solid #e5e7eb',
        borderRadius: 8,
        background: '#fafafa',
        minHeight: 200,
      }}
    >
      {rows.map((r) => {
        const q = Number(r.quality_index ?? 0);
        const pct = max > 0 ? (q / max) * 100 : 0;
        return (
          <div
            key={r.id}
            style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center' }}
          >
            <div style={{ fontSize: 11, color: '#444', marginBottom: 4 }}>{q.toFixed(1)}</div>
            <div
              style={{
                width: '100%',
                height: `${Math.max(pct * 1.6, 4)}px`,
                background: 'linear-gradient(180deg, #4f46e5, #818cf8)',
                borderRadius: 4,
              }}
              title={`${r.cohort_label}: Q-Index ${q.toFixed(1)}`}
            />
            <div style={{ fontSize: 10, color: '#666', marginTop: 6, textAlign: 'center' }}>
              {r.cohort_label}
            </div>
            <div style={{ fontSize: 10, color: '#999' }}>
              {r.tenure_months_min}–{r.tenure_months_max}mo
            </div>
          </div>
        );
      })}
    </div>
  );
}
