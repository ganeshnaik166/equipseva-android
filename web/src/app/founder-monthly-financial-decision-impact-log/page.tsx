import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyFinancialDecisionImpactLogPage() {
  const supabase = await getSupabaseServerClient();

  const [
    decisionsRes,
    reviewsRes,
    topPaybackRes,
    kindDistRes,
    gradeSummaryRes,
    monthlyTrendRes,
    pulseRes,
  ] = await Promise.all([
    supabase.rpc('list_decisions_r2597'),
    supabase.rpc('list_reviews_r2597'),
    supabase.rpc('top_payback_decisions_r2597'),
    supabase.rpc('decision_kind_distribution_r2597'),
    supabase.rpc('grade_summary_r2597'),
    supabase.rpc('monthly_decision_trend_r2597'),
    supabase.rpc('founder_pulse_summary_r2597'),
  ]);

  const decisions = (decisionsRes.data ?? []) as any[];
  const reviews = (reviewsRes.data ?? []) as any[];
  const topPayback = (topPaybackRes.data ?? []) as any[];
  const kindDist = (kindDistRes.data ?? []) as any[];
  const gradeSummary = (gradeSummaryRes.data ?? []) as any[];
  const monthlyTrend = (monthlyTrendRes.data ?? []) as any[];
  const pulse = (pulseRes.data ?? []) as any[];

  const fmtRupees = (n: any) => {
    const v = Number(n ?? 0);
    return v.toLocaleString('en-IN');
  };

  const decisionColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'decision_kind', header: 'Kind', render: (r: any) => r.decision_kind },
    { key: 'decision_summary_md', header: 'Summary', render: (r: any) => r.decision_summary_md },
    { key: 'spend_rupees', header: 'Spend (Rs)', render: (r: any) => fmtRupees(r.spend_rupees) },
    { key: 'roi_estimate_rupees', header: 'ROI (Rs)', render: (r: any) => fmtRupees(r.roi_estimate_rupees) },
    { key: 'payback_months', header: 'Payback (mo)', render: (r: any) => r.payback_months ?? '-' },
    { key: 'kill_rate_decision', header: 'Kill?', render: (r: any) => (r.kill_rate_decision ? 'Yes' : 'No') },
    { key: 'decision_quality_grade', header: 'Grade', render: (r: any) => r.decision_quality_grade },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const reviewColumns: Column<any>[] = [
    { key: 'reviewed_at', header: 'Reviewed', render: (r: any) => new Date(r.reviewed_at).toLocaleString('en-IN') },
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind },
    { key: 'review_kind', header: 'Review Kind', render: (r: any) => r.review_kind },
    { key: 'summary_md', header: 'Summary', render: (r: any) => r.summary_md },
    { key: 'lesson_md', header: 'Lesson', render: (r: any) => r.lesson_md ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
  ];

  const topPaybackColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'decision_kind', header: 'Kind', render: (r: any) => r.decision_kind },
    { key: 'decision_summary_md', header: 'Summary', render: (r: any) => r.decision_summary_md },
    { key: 'spend_rupees', header: 'Spend (Rs)', render: (r: any) => fmtRupees(r.spend_rupees) },
    { key: 'roi_estimate_rupees', header: 'ROI (Rs)', render: (r: any) => fmtRupees(r.roi_estimate_rupees) },
    { key: 'payback_months', header: 'Payback (mo)', render: (r: any) => r.payback_months },
    { key: 'decision_quality_grade', header: 'Grade', render: (r: any) => r.decision_quality_grade },
  ];

  const kindDistColumns: Column<any>[] = [
    { key: 'decision_kind', header: 'Kind', render: (r: any) => r.decision_kind },
    { key: 'decision_count', header: 'Count', render: (r: any) => r.decision_count },
    { key: 'total_spend_rupees', header: 'Total Spend (Rs)', render: (r: any) => fmtRupees(r.total_spend_rupees) },
    { key: 'total_roi_rupees', header: 'Total ROI (Rs)', render: (r: any) => fmtRupees(r.total_roi_rupees) },
  ];

  const gradeColumns: Column<any>[] = [
    { key: 'decision_quality_grade', header: 'Grade', render: (r: any) => r.decision_quality_grade },
    { key: 'decision_count', header: 'Count', render: (r: any) => r.decision_count },
    { key: 'avg_payback_months', header: 'Avg Payback (mo)', render: (r: any) => r.avg_payback_months ?? '-' },
    { key: 'total_spend_rupees', header: 'Total Spend (Rs)', render: (r: any) => fmtRupees(r.total_spend_rupees) },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'decision_count', header: 'Decisions', render: (r: any) => r.decision_count },
    { key: 'total_spend_rupees', header: 'Spend (Rs)', render: (r: any) => fmtRupees(r.total_spend_rupees) },
    { key: 'total_roi_rupees', header: 'ROI (Rs)', render: (r: any) => fmtRupees(r.total_roi_rupees) },
    { key: 'kill_decisions', header: 'Kill Decisions', render: (r: any) => r.kill_decisions },
  ];

  const pulseColumns: Column<any>[] = [
    { key: 'metric_label', header: 'Metric', render: (r: any) => r.metric_label },
    { key: 'metric_value', header: 'Value', render: (r: any) => r.metric_value },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Founder Monthly Financial Decision Impact Log
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Round r2597 — track every meaningful financial decision by month: hires, spend, cuts,
        investments, refunds & restructures. Grade A-F, payback & ROI, kill rate.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Founder Pulse</h2>
        <DataTable
          rows={pulse}
          columns={pulseColumns}
          emptyMessage="No pulse data."
          rowKey={(r: any, i: number) => String(r.metric_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Monthly Trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={trendColumns}
          emptyMessage="No monthly trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Decision Kind Distribution</h2>
        <DataTable
          rows={kindDist}
          columns={kindDistColumns}
          emptyMessage="No distribution data."
          rowKey={(r: any, i: number) => String(r.decision_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Grade Summary</h2>
        <DataTable
          rows={gradeSummary}
          columns={gradeColumns}
          emptyMessage="No grade summary."
          rowKey={(r: any, i: number) => String(r.decision_quality_grade ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Top Payback Decisions</h2>
        <DataTable
          rows={topPayback}
          columns={topPaybackColumns}
          emptyMessage="No payback data."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>All Decisions</h2>
        <DataTable
          rows={decisions}
          columns={decisionColumns}
          emptyMessage="No decisions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Reviews</h2>
        <DataTable
          rows={reviews}
          columns={reviewColumns}
          emptyMessage="No reviews logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
