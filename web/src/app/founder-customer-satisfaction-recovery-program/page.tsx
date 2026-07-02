import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_cases: number | null;
  open_cases: number | null;
  in_recovery: number | null;
  recovered: number | null;
  unresolved: number | null;
  churned: number | null;
  recovery_rate_pct: number | null;
  avg_initial_csat: number | null;
  avg_final_csat: number | null;
  total_goodwill_rupees: number | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, statusRes, categoryRes, severityRes, actionsRes, queueRes, trendRes] =
    await Promise.all([
      sb.rpc('satrec_program_summary_r2244'),
      sb.rpc('satrec_cases_by_status_r2244'),
      sb.rpc('satrec_category_breakdown_r2244'),
      sb.rpc('satrec_severity_breakdown_r2244'),
      sb.rpc('satrec_action_effectiveness_r2244'),
      sb.rpc('satrec_open_queue_r2244'),
      sb.rpc('satrec_weekly_trend_r2244'),
    ]);

  const summary: SummaryRow = (summaryRes.data?.[0] ?? {
    total_cases: 0,
    open_cases: 0,
    in_recovery: 0,
    recovered: 0,
    unresolved: 0,
    churned: 0,
    recovery_rate_pct: 0,
    avg_initial_csat: 0,
    avg_final_csat: 0,
    total_goodwill_rupees: 0,
  }) as SummaryRow;

  const statusRows: any[] = statusRes.data ?? [];
  const categoryRows: any[] = categoryRes.data ?? [];
  const severityRows: any[] = severityRes.data ?? [];
  const actionRows: any[] = actionsRes.data ?? [];
  const queueRows: any[] = queueRes.data ?? [];
  const trendRows: any[] = trendRes.data ?? [];

  const fmtInt = (n: number | null | undefined) =>
    n == null ? '0' : Number(n).toLocaleString('en-IN');
  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '₹0' : '₹' + Number(n).toLocaleString('en-IN');
  const fmtPct = (n: number | null | undefined) =>
    n == null ? '—' : Number(n).toFixed(1) + '%';
  const fmtCsat = (n: number | null | undefined) =>
    n == null ? '—' : Number(n).toFixed(2);

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'case_count', header: 'Cases', render: (r: any) => fmtInt(r.case_count) },
    { key: 'avg_days_open', header: 'Avg Days Open', render: (r: any) => String(r.avg_days_open ?? '—') },
    { key: 'avg_final_csat', header: 'Avg Final CSAT', render: (r: any) => fmtCsat(r.avg_final_csat) },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'complaint_category', header: 'Category', render: (r: any) => String(r.complaint_category ?? '') },
    { key: 'case_count', header: 'Cases', render: (r: any) => fmtInt(r.case_count) },
    { key: 'recovered_count', header: 'Recovered', render: (r: any) => fmtInt(r.recovered_count) },
    { key: 'recovery_rate_pct', header: 'Recovery %', render: (r: any) => fmtPct(r.recovery_rate_pct) },
    { key: 'avg_csat_lift', header: 'CSAT Lift', render: (r: any) => String(r.avg_csat_lift ?? '—') },
  ];

  const severityCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '') },
    { key: 'case_count', header: 'Cases', render: (r: any) => fmtInt(r.case_count) },
    { key: 'recovered_count', header: 'Recovered', render: (r: any) => fmtInt(r.recovered_count) },
    { key: 'churned_count', header: 'Churned', render: (r: any) => fmtInt(r.churned_count) },
    { key: 'recovery_rate_pct', header: 'Recovery %', render: (r: any) => fmtPct(r.recovery_rate_pct) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'uses', header: 'Uses', render: (r: any) => fmtInt(r.uses) },
    { key: 'accepted', header: 'Accepted', render: (r: any) => fmtInt(r.accepted) },
    { key: 'rejected', header: 'Rejected', render: (r: any) => fmtInt(r.rejected) },
    { key: 'total_spend_rupees', header: 'Total Spend', render: (r: any) => fmtRupees(r.total_spend_rupees) },
    { key: 'acceptance_rate_pct', header: 'Acceptance %', render: (r: any) => fmtPct(r.acceptance_rate_pct) },
  ];

  const queueCols: Column<any>[] = [
    { key: 'customer_name', header: 'Customer', render: (r: any) => String(r.customer_name ?? '') },
    { key: 'customer_org', header: 'Org', render: (r: any) => String(r.customer_org ?? '—') },
    { key: 'complaint_category', header: 'Category', render: (r: any) => String(r.complaint_category ?? '') },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'initial_csat_score', header: 'Init CSAT', render: (r: any) => fmtCsat(r.initial_csat_score) },
    { key: 'days_open', header: 'Days Open', render: (r: any) => String(r.days_open ?? '—') },
    { key: 'recovery_owner_email', header: 'Owner', render: (r: any) => String(r.recovery_owner_email ?? '—') },
    { key: 'action_count', header: 'Actions', render: (r: any) => fmtInt(r.action_count) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'cases_raised', header: 'Raised', render: (r: any) => fmtInt(r.cases_raised) },
    { key: 'cases_recovered', header: 'Recovered', render: (r: any) => fmtInt(r.cases_recovered) },
    { key: 'cases_churned', header: 'Churned', render: (r: any) => fmtInt(r.cases_churned) },
    { key: 'recovery_rate_pct', header: 'Recovery %', render: (r: any) => fmtPct(r.recovery_rate_pct) },
  ];

  const cardStyle: React.CSSProperties = {
    background: 'white',
    border: '1px solid #e5e7eb',
    borderRadius: 12,
    padding: 16,
    minWidth: 180,
  };

  return (
    <div style={{ padding: 24, background: '#f8fafc', minHeight: '100vh' }}>
      <div style={{ marginBottom: 16 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
          Customer Satisfaction Recovery Program
        </h1>
        <p style={{ color: '#475569', fontSize: 14 }}>
          Track escalations, recovery actions taken, and whether satisfaction was restored. Higher recovery rate &gt;= 70% is healthy.
        </p>
      </div>

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12, marginBottom: 24 }}>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Total Cases</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtInt(summary.total_cases)}</div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Open + In Recovery</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>
            {fmtInt((summary.open_cases ?? 0) + (summary.in_recovery ?? 0))}
          </div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Recovered</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#16a34a' }}>
            {fmtInt(summary.recovered)}
          </div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Churned</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#dc2626' }}>
            {fmtInt(summary.churned)}
          </div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Recovery Rate</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>
            {fmtPct(summary.recovery_rate_pct)}
          </div>
          <div style={{ fontSize: 11, color: '#64748b' }}>target &gt;= 70%</div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Initial CSAT</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>
            {fmtCsat(summary.avg_initial_csat)}
          </div>
          <div style={{ fontSize: 11, color: '#64748b' }}>(scale 0 to 5)</div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Final CSAT</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>
            {fmtCsat(summary.avg_final_csat)}
          </div>
          <div style={{ fontSize: 11, color: '#64748b' }}>post recovery</div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Goodwill Spend</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>
            {fmtRupees(summary.total_goodwill_rupees)}
          </div>
          <div style={{ fontSize: 11, color: '#64748b' }}>total compensation</div>
        </div>
      </div>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Open Queue (Severity First)</h2>
        <DataTable columns={queueCols} rows={queueRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status Breakdown</h2>
        <DataTable columns={statusCols} rows={statusRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By Complaint Category</h2>
        <DataTable columns={categoryCols} rows={categoryRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By Severity</h2>
        <DataTable columns={severityCols} rows={severityRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Action Effectiveness</h2>
        <DataTable columns={actionCols} rows={actionRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Weekly Trend (last 12 weeks)</h2>
        <DataTable columns={trendCols} rows={trendRows} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
