import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    deploymentsRes,
    followupsRes,
    topArrRes,
    kindBreakdownRes,
    responseSummaryRes,
    monthlyTrendRes,
    repeatRiskRes,
  ] = await Promise.all([
    supabase.rpc('list_deployments_r2591'),
    supabase.rpc('list_followup_actions_r2591'),
    supabase.rpc('top_arr_saved_focus_r2591'),
    supabase.rpc('emergency_kind_breakdown_r2591'),
    supabase.rpc('response_time_summary_r2591'),
    supabase.rpc('monthly_emergency_trend_r2591'),
    supabase.rpc('repeat_risk_distribution_r2591'),
  ]);

  const deployments = (deploymentsRes.data ?? []) as any[];
  const followups = (followupsRes.data ?? []) as any[];
  const topArr = (topArrRes.data ?? []) as any[];
  const kindBreakdown = (kindBreakdownRes.data ?? []) as any[];
  const responseSummary = (responseSummaryRes.data ?? []) as any[];
  const monthlyTrend = (monthlyTrendRes.data ?? []) as any[];
  const repeatRisk = (repeatRiskRes.data ?? []) as any[];

  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');

  const fmtDate = (s: string | null | undefined) =>
    s ? new Date(s).toLocaleString('en-IN') : '-';

  const deploymentCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'emergency_at', header: 'Emergency at', render: (r: any) => fmtDate(r.emergency_at) },
    { key: 'emergency_kind', header: 'Kind', render: (r: any) => r.emergency_kind ?? '-' },
    { key: 'response_minutes', header: 'Response (min)', render: (r: any) => r.response_minutes ?? '-' },
    { key: 'csat_score', header: 'CSAT', render: (r: any) => r.csat_score ?? '-' },
    { key: 'arr_saved_rupees', header: 'ARR saved', render: (r: any) => fmtRupees(r.arr_saved_rupees) },
    { key: 'repeat_risk_kind', header: 'Repeat risk', render: (r: any) => r.repeat_risk_kind ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const followupCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'action_at', header: 'Action at', render: (r: any) => fmtDate(r.action_at) },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind ?? '-' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topArrCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'total_arr_saved_rupees', header: 'ARR saved', render: (r: any) => fmtRupees(r.total_arr_saved_rupees) },
    { key: 'emergencies', header: 'Emergencies', render: (r: any) => r.emergencies ?? '-' },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => r.avg_csat ?? '-' },
  ];

  const kindBreakdownCols: Column<any>[] = [
    { key: 'emergency_kind', header: 'Kind', render: (r: any) => r.emergency_kind ?? '-' },
    { key: 'emergencies', header: 'Emergencies', render: (r: any) => r.emergencies ?? '-' },
    { key: 'avg_response_minutes', header: 'Avg response (min)', render: (r: any) => r.avg_response_minutes ?? '-' },
    { key: 'total_arr_saved_rupees', header: 'ARR saved', render: (r: any) => fmtRupees(r.total_arr_saved_rupees) },
  ];

  const responseSummaryCols: Column<any>[] = [
    { key: 'bucket', header: 'Response bucket', render: (r: any) => r.bucket ?? '-' },
    { key: 'emergencies', header: 'Emergencies', render: (r: any) => r.emergencies ?? '-' },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => r.avg_csat ?? '-' },
  ];

  const monthlyTrendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '-' },
    { key: 'emergencies', header: 'Emergencies', render: (r: any) => r.emergencies ?? '-' },
    { key: 'avg_response_minutes', header: 'Avg response (min)', render: (r: any) => r.avg_response_minutes ?? '-' },
    { key: 'total_arr_saved_rupees', header: 'ARR saved', render: (r: any) => fmtRupees(r.total_arr_saved_rupees) },
  ];

  const repeatRiskCols: Column<any>[] = [
    { key: 'repeat_risk_kind', header: 'Repeat risk', render: (r: any) => r.repeat_risk_kind ?? '-' },
    { key: 'emergencies', header: 'Emergencies', render: (r: any) => r.emergencies ?? '-' },
    { key: 'total_arr_saved_rupees', header: 'ARR saved', render: (r: any) => fmtRupees(r.total_arr_saved_rupees) },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => r.avg_csat ?? '-' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Hospital Chain Emergency Engineer Deployment
      </h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Chain > emergency > response time > engineer > CSAT > ARR saved > repeat-risk.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Deployments</h2>
        <DataTable
          rows={deployments}
          columns={deploymentCols}
          emptyMessage="No deployments logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Follow-up actions</h2>
        <DataTable
          rows={followups}
          columns={followupCols}
          emptyMessage="No follow-up actions"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top ARR saved focus</h2>
        <DataTable
          rows={topArr}
          columns={topArrCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Emergency kind breakdown</h2>
        <DataTable
          rows={kindBreakdown}
          columns={kindBreakdownCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.emergency_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Response time summary</h2>
        <DataTable
          rows={responseSummary}
          columns={responseSummaryCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Monthly emergency trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={monthlyTrendCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Repeat risk distribution</h2>
        <DataTable
          rows={repeatRisk}
          columns={repeatRiskCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.repeat_risk_kind ?? i)}
        />
      </section>
    </main>
  );
}
