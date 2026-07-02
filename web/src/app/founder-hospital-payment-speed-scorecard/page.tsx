import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalPaymentSpeedScorecardPage() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, scorecardRes, topLateRes, trendsRes, gradeDistRes, degradingRes, outstandingRes] =
    await Promise.all([
      sb.rpc('hps_r2247_summary'),
      sb.rpc('hps_r2247_scorecards'),
      sb.rpc('hps_r2247_top_late'),
      sb.rpc('hps_r2247_trends'),
      sb.rpc('hps_r2247_grade_dist'),
      sb.rpc('hps_r2247_degrading'),
      sb.rpc('hps_r2247_outstanding_top'),
    ]);

  const summary = (summaryRes.data?.[0] ?? {}) as {
    total_hospitals?: number;
    laggard_count?: number;
    fast_count?: number;
    total_outstanding?: number;
    avg_days_to_pay_all?: number;
    worst_offender?: string;
  };

  const scorecards = (scorecardRes.data ?? []) as Array<Record<string, unknown>>;
  const topLate = (topLateRes.data ?? []) as Array<Record<string, unknown>>;
  const trends = (trendsRes.data ?? []) as Array<Record<string, unknown>>;
  const gradeDist = (gradeDistRes.data ?? []) as Array<Record<string, unknown>>;
  const degrading = (degradingRes.data ?? []) as Array<Record<string, unknown>>;
  const outstanding = (outstandingRes.data ?? []) as Array<Record<string, unknown>>;

  const scorecardCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => String(r.hospital_name ?? '') },
    { key: 'hospital_city', header: 'City', render: (r) => String(r.hospital_city ?? '') },
    { key: 'invoices_count', header: 'Invoices', render: (r) => String(r.invoices_count ?? 0) },
    { key: 'avg_days_to_pay', header: 'Avg Days', render: (r) => Number(r.avg_days_to_pay ?? 0).toFixed(1) },
    { key: 'worst_days', header: 'Worst', render: (r) => String(r.worst_days ?? 0) },
    { key: 'outstanding_rupees', header: 'Outstanding', render: (r) => `₹${Number(r.outstanding_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'speed_grade', header: 'Grade', render: (r) => String(r.speed_grade ?? '') },
  ];

  const topLateCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => String(r.hospital_name ?? '') },
    { key: 'hospital_city', header: 'City', render: (r) => String(r.hospital_city ?? '') },
    { key: 'avg_days_to_pay', header: 'Avg Days', render: (r) => Number(r.avg_days_to_pay ?? 0).toFixed(1) },
    { key: 'worst_days', header: 'Worst Days', render: (r) => String(r.worst_days ?? 0) },
    { key: 'outstanding_rupees', header: 'Outstanding', render: (r) => `₹${Number(r.outstanding_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'overdue_count', header: 'Overdue', render: (r) => String(r.overdue_count ?? 0) },
    { key: 'speed_grade', header: 'Grade', render: (r) => String(r.speed_grade ?? '') },
  ];

  const trendCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => String(r.hospital_name ?? '') },
    { key: 'week_start', header: 'Week', render: (r) => String(r.week_start ?? '').slice(0, 10) },
    { key: 'invoices_issued', header: 'Issued', render: (r) => String(r.invoices_issued ?? 0) },
    { key: 'invoices_paid', header: 'Paid', render: (r) => String(r.invoices_paid ?? 0) },
    { key: 'avg_days_to_pay', header: 'Avg Days', render: (r) => Number(r.avg_days_to_pay ?? 0).toFixed(1) },
    { key: 'on_time_rate_pct', header: 'On-time %', render: (r) => `${Number(r.on_time_rate_pct ?? 0).toFixed(1)}%` },
    { key: 'trend_direction', header: 'Trend', render: (r) => String(r.trend_direction ?? '') },
    { key: 'founder_note', header: 'Note', render: (r) => String(r.founder_note ?? '') },
  ];

  const gradeCols: Column<any>[] = [
    { key: 'speed_grade', header: 'Grade', render: (r) => String(r.speed_grade ?? '') },
    { key: 'hospital_count', header: 'Hospitals', render: (r) => String(r.hospital_count ?? 0) },
    { key: 'total_outstanding', header: 'Outstanding', render: (r) => `₹${Number(r.total_outstanding ?? 0).toLocaleString('en-IN')}` },
  ];

  const degradingCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => String(r.hospital_name ?? '') },
    { key: 'week_start', header: 'Week', render: (r) => String(r.week_start ?? '').slice(0, 10) },
    { key: 'avg_days_to_pay', header: 'Avg Days', render: (r) => Number(r.avg_days_to_pay ?? 0).toFixed(1) },
    { key: 'on_time_rate_pct', header: 'On-time %', render: (r) => `${Number(r.on_time_rate_pct ?? 0).toFixed(1)}%` },
    { key: 'founder_note', header: 'Founder note', render: (r) => String(r.founder_note ?? '') },
  ];

  const outstandingCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => String(r.hospital_name ?? '') },
    { key: 'hospital_city', header: 'City', render: (r) => String(r.hospital_city ?? '') },
    { key: 'outstanding_rupees', header: 'Outstanding', render: (r) => `₹${Number(r.outstanding_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'overdue_count', header: 'Overdue', render: (r) => String(r.overdue_count ?? 0) },
    { key: 'speed_grade', header: 'Grade', render: (r) => String(r.speed_grade ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 4 }}>
        Hospital Payment Speed Scorecard
      </h1>
      <p style={{ color: '#666', marginBottom: 24, fontSize: 14 }}>
        Invoice-to-payment days per hospital. Surfaces laggards (avg &gt; 30d), tracks
        weekly trend, and flags hospitals where on-time rate is degrading.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <div style={{ padding: 14, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total hospitals</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.total_hospitals ?? 0}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Laggards (avg &gt; 30d)</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#dc2626' }}>{summary.laggard_count ?? 0}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Fast payers (&lt; 15d)</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#16a34a' }}>{summary.fast_count ?? 0}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total outstanding</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>
            {`₹${Number(summary.total_outstanding ?? 0).toLocaleString('en-IN')}`}
          </div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Avg days-to-pay (all)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{Number(summary.avg_days_to_pay_all ?? 0).toFixed(1)}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Worst offender</div>
          <div style={{ fontSize: 16, fontWeight: 600 }}>{summary.worst_offender ?? '—'}</div>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Hospital scorecards</h2>
        <p style={{ fontSize: 12, color: '#6b7280', marginBottom: 8 }}>
          Grades: fast (&lt; 15d), ontime (15–30d), slow (30–45d), laggard (&gt;= 45d).
        </p>
        <DataTable columns={scorecardCols} rows={scorecards} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top late-payers</h2>
        <DataTable columns={topLateCols} rows={topLate} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Outstanding leaderboard</h2>
        <DataTable columns={outstandingCols} rows={outstanding} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Weekly payment trend</h2>
        <DataTable columns={trendCols} rows={trends} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Degrading trend (founder action)</h2>
        <DataTable columns={degradingCols} rows={degrading} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 12 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Grade distribution</h2>
        <DataTable columns={gradeCols} rows={gradeDist} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
