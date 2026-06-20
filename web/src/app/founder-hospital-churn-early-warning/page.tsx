import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

async function safeRpc(sb: any, fn: string, args?: any) {
  try {
    const { data, error } = await sb.rpc(fn, args ?? {});
    if (error) return [];
    return Array.isArray(data) ? data : (data ? [data] : []);
  } catch {
    return [];
  }
}

function fmtNum(n: any, d: number = 0): string {
  const v = Number(n);
  if (!Number.isFinite(v)) return '—';
  return v.toFixed(d);
}

export default async function FounderHospitalChurnEarlyWarningPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const summaryRows = await safeRpc(sb, 'rpc_founder_churn_summary_v2');
  const latest      = await safeRpc(sb, 'rpc_founder_churn_latest_scores_v2', { p_limit: 100 });
  const redBand     = await safeRpc(sb, 'rpc_founder_churn_red_band_v2');
  const ladder      = await safeRpc(sb, 'rpc_founder_churn_action_ladder_v2');
  const signals     = await safeRpc(sb, 'rpc_founder_churn_signal_breakdown_v2');
  const trend       = await safeRpc(sb, 'rpc_founder_churn_band_trend_v2', { p_days: 30 });
  const saveRate    = await safeRpc(sb, 'rpc_founder_churn_save_rate_v2');

  const s = (summaryRows[0] ?? {}) as any;

  const kpis: Kpi[] = [
    { label: 'Total hospitals',     value: fmtNum(s.total_hospitals) },
    { label: 'Green band',          value: fmtNum(s.green_count) },
    { label: 'Yellow band',         value: fmtNum(s.yellow_count) },
    { label: 'Orange band',         value: fmtNum(s.orange_count) },
    { label: 'Red band',            value: fmtNum(s.red_count) },
    { label: 'Avg risk score',      value: fmtNum(s.avg_risk_score, 1) },
    { label: 'Avg payment delay (d)', value: fmtNum(s.avg_payment_delay, 1) },
    { label: 'Avg ticket volume',   value: fmtNum(s.avg_ticket_volume, 1) },
    { label: 'Avg NPS drop (pts)',  value: fmtNum(s.avg_nps_drop, 1) },
    { label: 'Total escalations 60d', value: fmtNum(s.total_escalations) },
    { label: 'Hospitals at risk',   value: fmtNum(s.hospitals_at_risk) },
    { label: 'Predicted churns 90d', value: fmtNum(s.predicted_churns_90d) },
    { label: 'Actions pending',     value: fmtNum(s.actions_pending) },
    { label: 'Actions saved',       value: fmtNum(s.actions_saved) },
    { label: 'Actions churned',     value: fmtNum(s.actions_churned) },
    { label: 'Ladder rung 4 (CEO call)', value: fmtNum(s.ladder_4_count) },
  ];

  const latestCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'risk_band',     header: 'Band',     render: (r: any) => r.risk_band ?? '—' },
    { key: 'risk_score',    header: 'Score',    render: (r: any) => fmtNum(r.risk_score, 1) },
    { key: 'amc_payment_delay_days', header: 'Pay delay (d)', render: (r: any) => fmtNum(r.amc_payment_delay_days, 1) },
    { key: 'ticket_volume_30d', header: 'Tix 30d', render: (r: any) => fmtNum(r.ticket_volume_30d) },
    { key: 'nps_drop_points', header: 'NPS drop', render: (r: any) => fmtNum(r.nps_drop_points, 1) },
    { key: 'escalation_count_60d', header: 'Esc 60d', render: (r: any) => fmtNum(r.escalation_count_60d) },
    { key: 'predicted_churn_at', header: 'Predicted churn', render: (r: any) => r.predicted_churn_at ?? '—' },
  ];

  const redCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'risk_score', header: 'Score', render: (r: any) => fmtNum(r.risk_score, 1) },
    { key: 'amc_payment_delay_days', header: 'Pay delay (d)', render: (r: any) => fmtNum(r.amc_payment_delay_days, 1) },
    { key: 'ticket_volume_30d', header: 'Tix 30d', render: (r: any) => fmtNum(r.ticket_volume_30d) },
    { key: 'escalation_count_60d', header: 'Esc 60d', render: (r: any) => fmtNum(r.escalation_count_60d) },
    { key: 'predicted_churn_at', header: 'Predicted churn', render: (r: any) => r.predicted_churn_at ?? '—' },
    { key: 'days_to_predicted_churn', header: 'Days left', render: (r: any) => fmtNum(r.days_to_predicted_churn, 0) },
  ];

  const ladderCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'risk_band', header: 'Band', render: (r: any) => r.risk_band ?? '—' },
    { key: 'ladder_rung', header: 'Rung', render: (r: any) => fmtNum(r.ladder_rung) },
    { key: 'action_step', header: 'Action', render: (r: any) => r.action_step ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? 'pending' },
    { key: 'taken_by_email', header: 'Owner', render: (r: any) => r.taken_by_email ?? '—' },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ?? '—' },
  ];

  const signalCols: Column<any>[] = [
    { key: 'signal_name', header: 'Signal', render: (r: any) => r.signal_name ?? '—' },
    { key: 'avg_value', header: 'Overall avg', render: (r: any) => fmtNum(r.avg_value, 2) },
    { key: 'red_band_avg', header: 'Red avg', render: (r: any) => fmtNum(r.red_band_avg, 2) },
    { key: 'green_band_avg', header: 'Green avg', render: (r: any) => fmtNum(r.green_band_avg, 2) },
    { key: 'contribution_pct', header: 'Weight %', render: (r: any) => fmtNum(r.contribution_pct, 1) },
  ];

  const saveRateCols: Column<any>[] = [
    { key: 'ladder_rung', header: 'Rung', render: (r: any) => fmtNum(r.ladder_rung) },
    { key: 'total_actions', header: 'Total', render: (r: any) => fmtNum(r.total_actions) },
    { key: 'saved_count', header: 'Saved', render: (r: any) => fmtNum(r.saved_count) },
    { key: 'churned_count', header: 'Churned', render: (r: any) => fmtNum(r.churned_count) },
    { key: 'pending_count', header: 'Pending', render: (r: any) => fmtNum(r.pending_count) },
    { key: 'save_rate_pct', header: 'Save rate %', render: (r: any) => fmtNum(r.save_rate_pct, 1) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
        Hospital Churn Early-Warning
      </h1>
      <p style={{ color: '#64748b', marginBottom: 24 }}>
        90d churn prediction from AMC payment delay + tickets + NPS + escalations.
        Red band {">"}=75 score triggers ladder rung 4 (founder save call).
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e2e8f0', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#64748b' }}>{k.label}</div>
            <div style={{ fontSize: 22, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Latest churn scores (per hospital)</h2>
        <DataTable rows={latest} columns={latestCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Red band — immediate action required</h2>
        <DataTable rows={redBand} columns={redCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Founder action ladder</h2>
        <DataTable rows={ladder} columns={ladderCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Signal breakdown</h2>
        <DataTable rows={signals} columns={signalCols} rowKey={(r: any) => r.signal_name} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Save rate by ladder rung</h2>
        <DataTable rows={saveRate} columns={saveRateCols} rowKey={(r: any) => String(r.ladder_rung)} />
      </section>

      <section style={{ marginBottom: 24, fontSize: 12, color: '#64748b' }}>
        Trend buckets loaded: {trend.length}. Bands: green {"<"}25, yellow 25-49, orange 50-74, red {">"}=75.
      </section>
    </main>
  );
}
