import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { handling_status: string; records: number; complaints: number; pct: number };
type ChannelRow = {
  intake_channel: string;
  records: number;
  complaints: number;
  investigations: number;
  capa_linked: number;
  reportable_events: number;
  avg_linkage_pct: number;
  avg_days_to_close: number;
};
type MatrixRow = {
  intake_channel: string;
  handling_status: string;
  records: number;
  complaints: number;
  avg_linkage_pct: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  complaints: number;
  investigations: number;
  capa_linked: number;
  reportable_events: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type DigestRow = {
  complaint_category: string;
  records: number;
  complaints: number;
  reportable_events: number;
  backlog_records: number;
  max_oldest_open_days: number;
  avg_linkage_pct: number;
};
type RiskRow = {
  record_code: string;
  complaint_category: string;
  device_name: string;
  period_month: string;
  intake_channel: string;
  handling_status: string;
  trend_dir: string;
  capa_linkage_pct: number | null;
  oldest_open_days: number;
  reportable_events: number;
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
    supabase.rpc('founder_r3653_handling_status_rollup'),
    supabase.rpc('founder_r3653_intake_channel_scorecard'),
    supabase.rpc('founder_r3653_channel_status_matrix'),
    supabase.rpc('founder_r3653_monthly_complaint_trend'),
    supabase.rpc('founder_r3653_capa_status_board'),
    supabase.rpc('founder_r3653_root_cause_pareto'),
    supabase.rpc('founder_r3653_backlog_impact_digest'),
    supabase.rpc('founder_r3653_high_risk_queue'),
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
    { key: 'handling_status', header: 'Handling Status' },
    { key: 'records', header: 'Records' },
    { key: 'complaints', header: 'Complaints' },
    { key: 'pct', header: 'Share %' },
  ];

  const channelCols: Column<ChannelRow>[] = [
    { key: 'intake_channel', header: 'Intake Channel' },
    { key: 'records', header: 'Records' },
    { key: 'complaints', header: 'Complaints' },
    { key: 'investigations', header: 'Investigations' },
    { key: 'capa_linked', header: 'CAPA Linked' },
    { key: 'reportable_events', header: 'Reportable' },
    { key: 'avg_linkage_pct', header: 'Avg Linkage %' },
    { key: 'avg_days_to_close', header: 'Avg Days to Close' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'intake_channel', header: 'Intake Channel' },
    { key: 'handling_status', header: 'Handling Status' },
    { key: 'records', header: 'Records' },
    { key: 'complaints', header: 'Complaints' },
    { key: 'avg_linkage_pct', header: 'Avg Linkage %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'complaints', header: 'Complaints' },
    { key: 'investigations', header: 'Investigations' },
    { key: 'capa_linked', header: 'CAPA Linked' },
    { key: 'reportable_events', header: 'Reportable' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'complaint_category', header: 'Complaint Category' },
    { key: 'records', header: 'Records' },
    { key: 'complaints', header: 'Complaints' },
    { key: 'reportable_events', header: 'Reportable' },
    { key: 'backlog_records', header: 'Backlog Records' },
    { key: 'max_oldest_open_days', header: 'Max Open Days' },
    { key: 'avg_linkage_pct', header: 'Avg Linkage %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'record_code', header: 'Record' },
    { key: 'complaint_category', header: 'Category' },
    { key: 'device_name', header: 'Device' },
    { key: 'period_month', header: 'Month' },
    { key: 'intake_channel', header: 'Channel' },
    { key: 'handling_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'capa_linkage_pct', header: 'Linkage %' },
    { key: 'oldest_open_days', header: 'Oldest Open Days' },
    { key: 'reportable_events', header: 'Reportable' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Medical-Device Complaint-Handling / CAPA-Linkage Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Complaint-handling discipline board — intake channel (field engineer, hospital direct,
        distributor, helpline, regulator) &times; complaint category &times; device (ICU ventilator,
        infusion pump, patient monitor, dialysis machine, defibrillator, C-arm) &times; monthly
        volume &times; investigation % &times; CAPA-linkage % &times; days-to-close &times;
        reportable events &times; backlog aging &amp; CAPA closure. Founder-gated view: handling
        statuses, channel scorecards, root-cause pareto, and backlog-impact digest across the
        intake &rarr; investigation &rarr; CAPA-linkage pipeline.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Handling-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No complaint records logged yet."
          rowKey={(r, i) => String(r.handling_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Intake-channel scorecard</h2>
        <DataTable
          rows={channelRows}
          columns={channelCols}
          emptyMessage="No intake-channel rollups."
          rowKey={(r, i) => String(r.intake_channel ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Intake channel &times; handling status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.intake_channel}-${r.handling_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly complaint trend</h2>
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
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Backlog-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No backlog-impact rollups."
          rowKey={(r, i) => String(r.complaint_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk complaint records."
          rowKey={(r, i) => `${r.record_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
