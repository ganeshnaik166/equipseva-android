import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerCsatRecoveryPlaybookPage() {
  const supabase = await getSupabaseServerClient();

  const [
    dropsRes,
    actionsRes,
    focusRes,
    actionKindRes,
    npsRes,
    topHospitalsRes,
    monthlyRes,
  ] = await Promise.all([
    supabase.rpc('list_drops_r2464'),
    supabase.rpc('list_recovery_actions_r2464'),
    supabase.rpc('top_drops_focus_r2464'),
    supabase.rpc('action_kind_summary_r2464'),
    supabase.rpc('nps_recovery_summary_r2464'),
    supabase.rpc('top_hospitals_in_recovery_r2464'),
    supabase.rpc('monthly_drop_trend_r2464'),
  ]);

  const drops = (dropsRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const actionKinds = (actionKindRes.data ?? []) as any[];
  const nps = (npsRes.data ?? []) as any[];
  const topHospitals = (topHospitalsRes.data ?? []) as any[];
  const monthly = (monthlyRes.data ?? []) as any[];

  const dropCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'drop_detected_at', header: 'Detected', render: (r: any) => new Date(r.drop_detected_at).toLocaleString() },
    { key: 'prior_csat', header: 'Prior', render: (r: any) => Number(r.prior_csat).toFixed(1) },
    { key: 'current_csat', header: 'Current', render: (r: any) => Number(r.current_csat).toFixed(1) },
    { key: 'csat_delta', header: 'Delta', render: (r: any) => Number(r.csat_delta).toFixed(1) },
    { key: 'drop_kind', header: 'Kind', render: (r: any) => r.drop_kind },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString() },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'action_summary', header: 'Summary', render: (r: any) => r.action_summary },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => r.follow_up_at ? new Date(r.follow_up_at).toLocaleDateString() : '—' },
    { key: 'nps_recovery_score', header: 'NPS Recovery', render: (r: any) => r.nps_recovery_score == null ? '—' : Number(r.nps_recovery_score).toFixed(1) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'csat_delta', header: 'Delta', render: (r: any) => Number(r.csat_delta).toFixed(1) },
    { key: 'drop_kind', header: 'Kind', render: (r: any) => r.drop_kind },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'detected_at', header: 'Detected', render: (r: any) => new Date(r.detected_at).toLocaleDateString() },
  ];

  const actionKindCols: Column<any>[] = [
    { key: 'action_kind', header: 'Action Kind', render: (r: any) => r.action_kind },
    { key: 'action_count', header: 'Count', render: (r: any) => r.action_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'negative_count', header: 'Negative', render: (r: any) => r.negative_count },
    { key: 'pending_count', header: 'Pending', render: (r: any) => r.pending_count },
  ];

  const npsCols: Column<any>[] = [
    { key: 'avg_nps_recovery', header: 'Avg NPS Recovery', render: (r: any) => r.avg_nps_recovery == null ? '—' : Number(r.avg_nps_recovery).toFixed(2) },
    { key: 'positive_actions', header: 'Positive', render: (r: any) => r.positive_actions },
    { key: 'neutral_actions', header: 'Neutral', render: (r: any) => r.neutral_actions },
    { key: 'negative_actions', header: 'Negative', render: (r: any) => r.negative_actions },
    { key: 'pending_actions', header: 'Pending', render: (r: any) => r.pending_actions },
  ];

  const topHospitalsCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'drop_count', header: 'Drops', render: (r: any) => r.drop_count },
    { key: 'avg_delta', header: 'Avg Delta', render: (r: any) => Number(r.avg_delta).toFixed(2) },
    { key: 'worst_severity', header: 'Worst Severity', render: (r: any) => r.worst_severity },
    { key: 'open_drops', header: 'Open', render: (r: any) => r.open_drops },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => new Date(r.month_start).toLocaleDateString(undefined, { year: 'numeric', month: 'short' }) },
    { key: 'drops_detected', header: 'Drops', render: (r: any) => r.drops_detected },
    { key: 'avg_delta', header: 'Avg Delta', render: (r: any) => Number(r.avg_delta).toFixed(2) },
    { key: 'critical_count', header: 'Critical', render: (r: any) => r.critical_count },
    { key: 'resolved_count', header: 'Resolved', render: (r: any) => r.resolved_count },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Customer CSAT Recovery Playbook
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Detect CSAT drops > track recovery actions => close the loop & restore NPS.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>NPS recovery summary</h2>
        <DataTable
          rows={nps}
          columns={npsCols}
          emptyMessage="No recovery actions logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top drops in focus</h2>
        <DataTable
          rows={focus}
          columns={focusCols}
          emptyMessage="No open or in-progress drops."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top hospitals in recovery</h2>
        <DataTable
          rows={topHospitals}
          columns={topHospitalsCols}
          emptyMessage="No hospital recovery data."
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Action kind summary</h2>
        <DataTable
          rows={actionKinds}
          columns={actionKindCols}
          emptyMessage="No actions logged."
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Monthly drop trend</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          emptyMessage="No monthly data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All CSAT drops</h2>
        <DataTable
          rows={drops}
          columns={dropCols}
          emptyMessage="No CSAT drops detected."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All recovery actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No recovery actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
