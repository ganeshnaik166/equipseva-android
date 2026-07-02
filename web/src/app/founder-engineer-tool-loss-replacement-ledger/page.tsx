import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    lossesRes,
    offendersRes,
    topEngineersRes,
    trendRes,
    kindBreakdownRes,
    insuranceRes,
    statusRes,
  ] = await Promise.all([
    sb.rpc('list_losses_r2486'),
    sb.rpc('list_repeat_offenders_r2486'),
    sb.rpc('top_loss_engineers_r2486'),
    sb.rpc('monthly_replacement_trend_r2486'),
    sb.rpc('loss_kind_breakdown_r2486'),
    sb.rpc('insurance_recovery_summary_r2486'),
    sb.rpc('status_funnel_r2486'),
  ]);

  const losses: any[] = Array.isArray(lossesRes.data) ? lossesRes.data : [];
  const offenders: any[] = Array.isArray(offendersRes.data) ? offendersRes.data : [];
  const topEngineers: any[] = Array.isArray(topEngineersRes.data) ? topEngineersRes.data : [];
  const trend: any[] = Array.isArray(trendRes.data) ? trendRes.data : [];
  const kindBreakdown: any[] = Array.isArray(kindBreakdownRes.data) ? kindBreakdownRes.data : [];
  const insurance: any[] = Array.isArray(insuranceRes.data) ? insuranceRes.data : [];
  const statusFunnel: any[] = Array.isArray(statusRes.data) ? statusRes.data : [];

  const lossCols: Column<any>[] = [
    { key: 'tool_name', header: 'Tool', render: (r: any) => String(r.tool_name ?? '') },
    { key: 'tool_kind', header: 'Kind', render: (r: any) => String(r.tool_kind ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => r.engineer_user_id ? String(r.engineer_user_id).slice(0, 8) : '' },
    { key: 'loss_at', header: 'Lost At', render: (r: any) => r.loss_at ? new Date(r.loss_at).toLocaleString() : '' },
    { key: 'loss_reason_kind', header: 'Reason', render: (r: any) => String(r.loss_reason_kind ?? '') },
    { key: 'replacement_cost_rupees', header: 'Cost (Rs)', render: (r: any) => String(r.replacement_cost_rupees ?? 0) },
    { key: 'insurance_claim_filed', header: 'Claim Filed', render: (r: any) => r.insurance_claim_filed ? 'yes' : 'no' },
    { key: 'insurance_recovery_rupees', header: 'Recovered (Rs)', render: (r: any) => String(r.insurance_recovery_rupees ?? 0) },
    { key: 'repeat_offender', header: 'Repeat', render: (r: any) => r.repeat_offender ? 'yes' : 'no' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const offenderCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => r.engineer_user_id ? String(r.engineer_user_id).slice(0, 8) : '' },
    { key: 'period_start', header: 'Period Start', render: (r: any) => String(r.period_start ?? '') },
    { key: 'period_end', header: 'Period End', render: (r: any) => String(r.period_end ?? '') },
    { key: 'loss_count', header: 'Losses', render: (r: any) => String(r.loss_count ?? 0) },
    { key: 'total_replacement_rupees', header: 'Total Cost (Rs)', render: (r: any) => String(r.total_replacement_rupees ?? 0) },
    { key: 'top_loss_kind', header: 'Top Kind', render: (r: any) => String(r.top_loss_kind ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'action_plan_md', header: 'Action Plan', render: (r: any) => String(r.action_plan_md ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const topEngineerCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => r.engineer_user_id ? String(r.engineer_user_id).slice(0, 8) : '' },
    { key: 'loss_count', header: 'Losses', render: (r: any) => String(r.loss_count ?? 0) },
    { key: 'total_replacement_rupees', header: 'Total Cost (Rs)', render: (r: any) => String(r.total_replacement_rupees ?? 0) },
    { key: 'total_recovered_rupees', header: 'Recovered (Rs)', render: (r: any) => String(r.total_recovered_rupees ?? 0) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start ?? '') },
    { key: 'loss_count', header: 'Losses', render: (r: any) => String(r.loss_count ?? 0) },
    { key: 'total_replacement_rupees', header: 'Total Cost (Rs)', render: (r: any) => String(r.total_replacement_rupees ?? 0) },
    { key: 'total_recovered_rupees', header: 'Recovered (Rs)', render: (r: any) => String(r.total_recovered_rupees ?? 0) },
  ];

  const kindCols: Column<any>[] = [
    { key: 'loss_reason_kind', header: 'Reason', render: (r: any) => String(r.loss_reason_kind ?? '') },
    { key: 'loss_count', header: 'Losses', render: (r: any) => String(r.loss_count ?? 0) },
    { key: 'total_replacement_rupees', header: 'Total Cost (Rs)', render: (r: any) => String(r.total_replacement_rupees ?? 0) },
    { key: 'total_recovered_rupees', header: 'Recovered (Rs)', render: (r: any) => String(r.total_recovered_rupees ?? 0) },
  ];

  const insuranceCols: Column<any>[] = [
    { key: 'claims_filed', header: 'Claims Filed', render: (r: any) => String(r.claims_filed ?? 0) },
    { key: 'claims_not_filed', header: 'Claims Not Filed', render: (r: any) => String(r.claims_not_filed ?? 0) },
    { key: 'total_loss_rupees', header: 'Total Loss (Rs)', render: (r: any) => String(r.total_loss_rupees ?? 0) },
    { key: 'total_recovered_rupees', header: 'Total Recovered (Rs)', render: (r: any) => String(r.total_recovered_rupees ?? 0) },
    { key: 'recovery_rate_pct', header: 'Recovery Rate %', render: (r: any) => String(r.recovery_rate_pct ?? 0) },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'loss_count', header: 'Losses', render: (r: any) => String(r.loss_count ?? 0) },
    { key: 'total_replacement_rupees', header: 'Total Cost (Rs)', render: (r: any) => String(r.total_replacement_rupees ?? 0) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Engineer Tool Loss & Replacement Ledger</h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Track tools lost in the field, replacement costs, insurance recovery rates & repeat-offender engineers. Use to drive accountability and cap fleet-tool burn-rate.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Insurance Recovery Summary</h2>
        <DataTable rows={insurance} columns={insuranceCols} emptyMessage="No insurance data yet." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status Funnel</h2>
        <DataTable rows={statusFunnel} columns={statusCols} emptyMessage="No status data yet." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Loss Reason Breakdown</h2>
        <DataTable rows={kindBreakdown} columns={kindCols} emptyMessage="No loss reason data yet." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Replacement Trend</h2>
        <DataTable rows={trend} columns={trendCols} emptyMessage="No trend data yet." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Loss Engineers</h2>
        <DataTable rows={topEngineers} columns={topEngineerCols} emptyMessage="No engineers ranked yet." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Repeat Offenders & Action Plans</h2>
        <DataTable rows={offenders} columns={offenderCols} emptyMessage="No repeat offenders tracked yet." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Tool Losses</h2>
        <DataTable rows={losses} columns={lossCols} emptyMessage="No losses logged yet." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
