import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [opps, signals, topArr, funnel, strength, ownerLoad, calendar] = await Promise.all([
    supabase.rpc('list_opportunities_r2436'),
    supabase.rpc('list_signals_log_r2436'),
    supabase.rpc('top_arr_opportunities_r2436'),
    supabase.rpc('status_funnel_r2436'),
    supabase.rpc('signal_strength_breakdown_r2436'),
    supabase.rpc('owner_load_r2436'),
    supabase.rpc('this_week_action_calendar_r2436'),
  ]);

  const oppsRows = opps.data ?? [];
  const signalsRows = signals.data ?? [];
  const topArrRows = topArr.data ?? [];
  const funnelRows = funnel.data ?? [];
  const strengthRows = strength.data ?? [];
  const ownerRows = ownerLoad.data ?? [];
  const calendarRows = calendar.data ?? [];

  const fmtRupees = (v: any) => {
    const n = Number(v ?? 0);
    return '₹' + n.toLocaleString('en-IN');
  };
  const fmtDate = (v: any) => (v ? new Date(v).toLocaleString('en-IN') : '—');

  const oppsCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'current_amc_tier', header: 'Current', render: (r: any) => r.current_amc_tier },
    { key: 'upsell_target_tier', header: 'Target', render: (r: any) => r.upsell_target_tier },
    { key: 'upsell_probability_pct', header: 'Prob %', render: (r: any) => `${r.upsell_probability_pct}%` },
    { key: 'incremental_arr_rupees', header: 'Incr ARR', render: (r: any) => fmtRupees(r.incremental_arr_rupees) },
    { key: 'signal_kind', header: 'Signal', render: (r: any) => r.signal_kind },
    { key: 'signal_strength', header: 'Strength', render: (r: any) => r.signal_strength },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'action_due_at', header: 'Due', render: (r: any) => fmtDate(r.action_due_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const signalsCols: Column<any>[] = [
    { key: 'observed_at', header: 'Observed', render: (r: any) => fmtDate(r.observed_at) },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'signal_kind', header: 'Kind', render: (r: any) => r.signal_kind },
    { key: 'signal_value', header: 'Value', render: (r: any) => r.signal_value },
    { key: 'signal_score_delta', header: 'Score', render: (r: any) => `+${r.signal_score_delta}` },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topArrCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'current_amc_tier', header: 'From', render: (r: any) => r.current_amc_tier },
    { key: 'upsell_target_tier', header: 'To', render: (r: any) => r.upsell_target_tier },
    { key: 'incremental_arr_rupees', header: 'Incr ARR', render: (r: any) => fmtRupees(r.incremental_arr_rupees) },
    { key: 'weighted_arr_rupees', header: 'Weighted ARR', render: (r: any) => fmtRupees(r.weighted_arr_rupees) },
    { key: 'upsell_probability_pct', header: 'Prob %', render: (r: any) => `${r.upsell_probability_pct}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'opp_count', header: 'Opps', render: (r: any) => r.opp_count },
    { key: 'total_arr_rupees', header: 'Total ARR', render: (r: any) => fmtRupees(r.total_arr_rupees) },
    { key: 'weighted_arr_rupees', header: 'Weighted ARR', render: (r: any) => fmtRupees(r.weighted_arr_rupees) },
  ];

  const strengthCols: Column<any>[] = [
    { key: 'signal_strength', header: 'Strength', render: (r: any) => r.signal_strength },
    { key: 'opp_count', header: 'Opps', render: (r: any) => r.opp_count },
    { key: 'avg_probability_pct', header: 'Avg Prob %', render: (r: any) => `${r.avg_probability_pct}%` },
    { key: 'total_arr_rupees', header: 'Total ARR', render: (r: any) => fmtRupees(r.total_arr_rupees) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'open_opps', header: 'Open', render: (r: any) => r.open_opps },
    { key: 'total_opps', header: 'Total', render: (r: any) => r.total_opps },
    { key: 'pipeline_arr_rupees', header: 'Pipeline ARR', render: (r: any) => fmtRupees(r.pipeline_arr_rupees) },
    { key: 'weighted_arr_rupees', header: 'Weighted ARR', render: (r: any) => fmtRupees(r.weighted_arr_rupees) },
  ];

  const calendarCols: Column<any>[] = [
    { key: 'action_due_at', header: 'Due', render: (r: any) => fmtDate(r.action_due_at) },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'proposed_action', header: 'Action', render: (r: any) => r.proposed_action },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'signal_strength', header: 'Strength', render: (r: any) => r.signal_strength },
    { key: 'upsell_probability_pct', header: 'Prob %', render: (r: any) => `${r.upsell_probability_pct}%` },
    { key: 'incremental_arr_rupees', header: 'Incr ARR', render: (r: any) => fmtRupees(r.incremental_arr_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <main style={{ padding: '1.5rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Customer AMC Upsell Opportunity Scanner
      </h1>
      <p style={{ color: '#666', marginBottom: '1.5rem' }}>
        Hospital × current AMC × upsell target × probability × incremental ARR × owner.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>This Week Action Calendar</h2>
        <DataTable
          rows={calendarRows}
          columns={calendarCols}
          emptyMessage="No actions due this week."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Top ARR Opportunities</h2>
        <DataTable
          rows={topArrRows}
          columns={topArrCols}
          emptyMessage="No qualified opportunities."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Status Funnel</h2>
        <DataTable
          rows={funnelRows}
          columns={funnelCols}
          emptyMessage="No funnel data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Signal Strength Breakdown</h2>
        <DataTable
          rows={strengthRows}
          columns={strengthCols}
          emptyMessage="No signals captured."
          rowKey={(r: any, i: number) => String(r.signal_strength ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Owner Load</h2>
        <DataTable
          rows={ownerRows}
          columns={ownerCols}
          emptyMessage="No owners assigned."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>All Opportunities</h2>
        <DataTable
          rows={oppsRows}
          columns={oppsCols}
          emptyMessage="No opportunities scanned yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Signals Log</h2>
        <DataTable
          rows={signalsRows}
          columns={signalsCols}
          emptyMessage="No signals logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
