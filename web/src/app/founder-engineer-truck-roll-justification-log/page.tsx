import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerTruckRollJustificationLogPage() {
  const supabase = await getSupabaseServerClient();

  const [
    rollsRes,
    analysisRes,
    topEngineersRes,
    reasonBreakdownRes,
    weeklyTrendRes,
    topHospitalsRes,
    phoneFixRes,
  ] = await Promise.all([
    supabase.rpc('list_truck_rolls_r2502'),
    supabase.rpc('list_avoidability_analysis_r2502'),
    supabase.rpc('top_avoidable_engineers_r2502'),
    supabase.rpc('reason_kind_breakdown_r2502'),
    supabase.rpc('weekly_avoidable_trend_r2502'),
    supabase.rpc('top_avoidable_hospitals_r2502'),
    supabase.rpc('phone_fix_success_rate_r2502'),
  ]);

  const rolls = (rollsRes.data ?? []) as any[];
  const analysis = (analysisRes.data ?? []) as any[];
  const topEngineers = (topEngineersRes.data ?? []) as any[];
  const reasonBreakdown = (reasonBreakdownRes.data ?? []) as any[];
  const weeklyTrend = (weeklyTrendRes.data ?? []) as any[];
  const topHospitals = (topHospitalsRes.data ?? []) as any[];
  const phoneFix = (phoneFixRes.data ?? []) as any[];

  const rollCols: Column<any>[] = [
    { key: 'rolled_at', header: 'Rolled at', render: (r: any) => new Date(r.rolled_at).toLocaleString() },
    { key: 'reason_kind', header: 'Reason', render: (r: any) => r.reason_kind },
    { key: 'avoidability', header: 'Avoidability', render: (r: any) => r.avoidability },
    { key: 'billable', header: 'Billable', render: (r: any) => (r.billable ? 'yes' : 'no') },
    { key: 'billed_rupees', header: 'Billed', render: (r: any) => `Rs ${r.billed_rupees}` },
    { key: 'phone_fix_attempted', header: 'Phone fix?', render: (r: any) => (r.phone_fix_attempted ? `yes (${r.phone_fix_minutes}m)` : 'no') },
    { key: 'cost_rupees', header: 'Cost', render: (r: any) => `Rs ${r.cost_rupees}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const analysisCols: Column<any>[] = [
    { key: 'period_start', header: 'Period start', render: (r: any) => r.period_start },
    { key: 'period_end', header: 'Period end', render: (r: any) => r.period_end },
    { key: 'total_rolls', header: 'Total', render: (r: any) => r.total_rolls },
    { key: 'avoidable_rolls', header: 'Avoidable', render: (r: any) => r.avoidable_rolls },
    { key: 'marginal_rolls', header: 'Marginal', render: (r: any) => r.marginal_rolls },
    { key: 'unavoidable_rolls', header: 'Unavoidable', render: (r: any) => r.unavoidable_rolls },
    { key: 'total_cost_rupees', header: 'Total cost', render: (r: any) => `Rs ${r.total_cost_rupees}` },
    { key: 'avoidable_cost_rupees', header: 'Avoidable cost', render: (r: any) => `Rs ${r.avoidable_cost_rupees}` },
    { key: 'top_avoidable_reason', header: 'Top reason', render: (r: any) => r.top_avoidable_reason ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const topEngCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => r.engineer_user_id ?? '(unknown)' },
    { key: 'avoidable_count', header: 'Avoidable rolls', render: (r: any) => r.avoidable_count },
    { key: 'avoidable_cost', header: 'Avoidable cost', render: (r: any) => `Rs ${r.avoidable_cost}` },
  ];

  const reasonCols: Column<any>[] = [
    { key: 'reason_kind', header: 'Reason', render: (r: any) => r.reason_kind },
    { key: 'roll_count', header: 'Rolls', render: (r: any) => r.roll_count },
    { key: 'total_cost', header: 'Total cost', render: (r: any) => `Rs ${r.total_cost}` },
    { key: 'avoidable_count', header: 'Avoidable', render: (r: any) => r.avoidable_count },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start },
    { key: 'total_rolls', header: 'Total', render: (r: any) => r.total_rolls },
    { key: 'avoidable_rolls', header: 'Avoidable', render: (r: any) => r.avoidable_rolls },
    { key: 'avoidable_cost', header: 'Avoidable cost', render: (r: any) => `Rs ${r.avoidable_cost ?? 0}` },
  ];

  const topHospCols: Column<any>[] = [
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => r.hospital_user_id ?? '(unknown)' },
    { key: 'avoidable_count', header: 'Avoidable rolls', render: (r: any) => r.avoidable_count },
    { key: 'avoidable_cost', header: 'Avoidable cost', render: (r: any) => `Rs ${r.avoidable_cost}` },
  ];

  const phoneFixCols: Column<any>[] = [
    { key: 'total_rolls', header: 'Total rolls', render: (r: any) => r.total_rolls },
    { key: 'phone_attempted', header: 'Phone attempted', render: (r: any) => r.phone_attempted },
    { key: 'phone_attempted_pct', header: 'Attempted %', render: (r: any) => `${r.phone_attempted_pct ?? 0}%` },
    { key: 'avg_phone_minutes', header: 'Avg phone min', render: (r: any) => r.avg_phone_minutes ?? 0 },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer Truck Roll Justification Log
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Every site visit logged with reason, avoidability & phone-fix attempt => kill avoidable rolls, save cost.
      </p>

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Truck rolls</h2>
      <DataTable
        rows={rolls}
        columns={rollCols}
        emptyMessage="No truck rolls logged"
        rowKey={(r: any, i: number) => String(r.id ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Weekly avoidability analysis</h2>
      <DataTable
        rows={analysis}
        columns={analysisCols}
        emptyMessage="No analysis periods"
        rowKey={(r: any, i: number) => String(r.id ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Top avoidable engineers</h2>
      <DataTable
        rows={topEngineers}
        columns={topEngCols}
        emptyMessage="No avoidable engineers"
        rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Reason-kind breakdown</h2>
      <DataTable
        rows={reasonBreakdown}
        columns={reasonCols}
        emptyMessage="No reasons"
        rowKey={(r: any, i: number) => String(r.reason_kind ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Weekly avoidable trend</h2>
      <DataTable
        rows={weeklyTrend}
        columns={weeklyCols}
        emptyMessage="No trend data"
        rowKey={(r: any, i: number) => String(r.week_start ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Top avoidable hospitals</h2>
      <DataTable
        rows={topHospitals}
        columns={topHospCols}
        emptyMessage="No avoidable hospitals"
        rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Phone-fix success rate</h2>
      <DataTable
        rows={phoneFix}
        columns={phoneFixCols}
        emptyMessage="No phone-fix data"
        rowKey={(r: any, i: number) => String(i)}
      />
    </div>
  );
}
