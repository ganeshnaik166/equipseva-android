import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { delivery_status: string; cells: number; pct: number };
type ChannelRow = {
  channel: string;
  cells: number;
  total_sent: number;
  total_delivered: number;
  avg_delivery_pct: number;
  avg_open_pct: number;
  total_failures: number;
  total_opt_outs: number;
  total_cost_rupees: number;
};
type MatrixRow = {
  channel_class: string;
  delivery_status: string;
  cells: number;
  total_sent: number;
  total_failures: number;
  avg_latency_seconds: number;
};
type TrendRow = {
  period_month: string;
  cells: number;
  total_sent: number;
  total_delivered: number;
  avg_delivery_pct: number;
  total_failures: number;
  total_dnd_blocked: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type DigestRow = {
  channel_class: string;
  cells: number;
  total_failures: number;
  avg_latency_seconds: number;
  total_dnd_blocked: number;
  total_opt_outs: number;
  total_cost_rupees: number;
};
type RiskRow = {
  notif_code: string;
  notif_type: string;
  channel: string;
  period_month: string;
  channel_class: string;
  delivery_status: string;
  trend_dir: string;
  delivery_pct: number | null;
  failures: number;
  dnd_blocked: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    channelRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3700_delivery_status_rollup'),
    supabase.rpc('founder_r3700_channel_scorecard'),
    supabase.rpc('founder_r3700_class_status_matrix'),
    supabase.rpc('founder_r3700_monthly_delivery_trend'),
    supabase.rpc('founder_r3700_capa_status_board'),
    supabase.rpc('founder_r3700_root_cause_pareto'),
    supabase.rpc('founder_r3700_failure_latency_digest'),
    supabase.rpc('founder_r3700_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const channelRows: ChannelRow[] = (channelRes.data as ChannelRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'delivery_status', header: 'Delivery Status' },
    { key: 'cells', header: 'Channel-Months' },
    { key: 'pct', header: 'Share %' },
  ];

  const channelCols: Column<ChannelRow>[] = [
    { key: 'channel', header: 'Channel / Provider' },
    { key: 'cells', header: 'Channel-Months' },
    { key: 'total_sent', header: 'Sent' },
    { key: 'total_delivered', header: 'Delivered' },
    { key: 'avg_delivery_pct', header: 'Avg Delivery %' },
    { key: 'avg_open_pct', header: 'Avg Open %' },
    { key: 'total_failures', header: 'Failures' },
    { key: 'total_opt_outs', header: 'Opt-Outs' },
    { key: 'total_cost_rupees', header: 'Cost (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'channel_class', header: 'Channel Class' },
    { key: 'delivery_status', header: 'Delivery Status' },
    { key: 'cells', header: 'Channel-Months' },
    { key: 'total_sent', header: 'Sent' },
    { key: 'total_failures', header: 'Failures' },
    { key: 'avg_latency_seconds', header: 'Avg Latency (s)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'cells', header: 'Channel-Months' },
    { key: 'total_sent', header: 'Sent' },
    { key: 'total_delivered', header: 'Delivered' },
    { key: 'avg_delivery_pct', header: 'Avg Delivery %' },
    { key: 'total_failures', header: 'Failures' },
    { key: 'total_dnd_blocked', header: 'DND Blocked' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'channel_class', header: 'Channel Class' },
    { key: 'cells', header: 'Channel-Months' },
    { key: 'total_failures', header: 'Failures' },
    { key: 'avg_latency_seconds', header: 'Avg Latency (s)' },
    { key: 'total_dnd_blocked', header: 'DND Blocked' },
    { key: 'total_opt_outs', header: 'Opt-Outs' },
    { key: 'total_cost_rupees', header: 'Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'notif_code', header: 'Notif Code' },
    { key: 'notif_type', header: 'Type' },
    { key: 'channel', header: 'Channel' },
    { key: 'period_month', header: 'Month' },
    { key: 'channel_class', header: 'Class' },
    { key: 'delivery_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'delivery_pct', header: 'Delivery %' },
    { key: 'failures', header: 'Failures' },
    { key: 'dnd_blocked', header: 'DND Blocked' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Notification-Delivery / Channel-Health Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Platform notification delivery health — notif type &times; channel (FCM push, MSG91 &amp;
        Gupshup SMS, Meta Cloud API WhatsApp, AWS SES email, transactional OTP) &times; monthly
        sent/delivered/opened &times; latency &times; failures &times; opt-outs &times; DND blocks
        &times; provider cost &amp; CAPA closure. Founder-gated view: delivery-status rollups,
        channel scorecards, class &times; status matrix, root-cause pareto, and the blocked /
        high-failure (&lt;90% delivery) queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Delivery status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No delivery health rows logged yet."
          rowKey={(r, i) => String(r.delivery_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Channel scorecard</h2>
        <DataTable
          rows={channelRows}
          columns={channelCols}
          emptyMessage="No channel rollups."
          rowKey={(r, i) => String(r.channel ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Channel class &times; delivery status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix cells."
          rowKey={(r, i) => `${r.channel_class}-${r.delivery_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly delivery trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Failure &amp; latency digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No failure/latency rollups."
          rowKey={(r, i) => String(r.channel_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk channel queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk channels."
          rowKey={(r, i) => `${r.notif_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
