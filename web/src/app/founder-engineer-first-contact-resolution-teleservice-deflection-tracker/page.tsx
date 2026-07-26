import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ResolutionRow = { resolution: string; tickets: number; pct: number };
type ChannelRow = {
  channel: string;
  total_tickets: number;
  fcr_count: number;
  resolved_remote: number;
  deflected: number;
  escalated: number;
  onsite_avoided: number;
  avg_handle_time_min: number;
  fcr_pct: number;
};
type MatrixRow = {
  issue_type: string;
  resolution: string;
  tickets: number;
  fcr_count: number;
  avg_handle_time_min: number;
};
type TrendRow = {
  month: string;
  tickets: number;
  fcr_count: number;
  onsite_avoided: number;
  deflected: number;
  fcr_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_saved_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_saved_rupees: number;
  pct: number;
};
type ImpactRow = {
  issue_type: string;
  tickets: number;
  onsite_avoided: number;
  dispatched: number;
  avg_handle_time_min: number;
  avoidance_pct: number;
};
type RiskRow = {
  hospital_name: string;
  ticket_code: string;
  engineer_name: string;
  device_model: string;
  channel: string;
  issue_type: string;
  resolution: string;
  handle_time_min: number;
  contact_date: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    resolutionRes,
    channelRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3452_resolution_rollup'),
    supabase.rpc('founder_r3452_channel_scorecard'),
    supabase.rpc('founder_r3452_issue_resolution_matrix'),
    supabase.rpc('founder_r3452_monthly_fcr_trend'),
    supabase.rpc('founder_r3452_capa_status_board'),
    supabase.rpc('founder_r3452_root_cause_pareto'),
    supabase.rpc('founder_r3452_onsite_avoidance_impact_digest'),
    supabase.rpc('founder_r3452_high_risk_queue'),
  ]);

  const resolutionRows: ResolutionRow[] = (resolutionRes.data as ResolutionRow[]) ?? [];
  const channelRows: ChannelRow[] = (channelRes.data as ChannelRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const resolutionCols: Column<ResolutionRow>[] = [
    { key: 'resolution', header: 'Resolution' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'pct', header: 'Share %' },
  ];

  const channelCols: Column<ChannelRow>[] = [
    { key: 'channel', header: 'Channel' },
    { key: 'total_tickets', header: 'Tickets' },
    { key: 'fcr_count', header: 'FCR' },
    { key: 'resolved_remote', header: 'Resolved Remote' },
    { key: 'deflected', header: 'Deflected' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'onsite_avoided', header: 'Onsite Avoided' },
    { key: 'avg_handle_time_min', header: 'Avg Handle (min)' },
    { key: 'fcr_pct', header: 'FCR %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'issue_type', header: 'Issue Type' },
    { key: 'resolution', header: 'Resolution' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'fcr_count', header: 'FCR' },
    { key: 'avg_handle_time_min', header: 'Avg Handle (min)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'month', header: 'Month' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'fcr_count', header: 'FCR' },
    { key: 'onsite_avoided', header: 'Onsite Avoided' },
    { key: 'deflected', header: 'Deflected' },
    { key: 'fcr_pct', header: 'FCR %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_saved_rupees', header: 'Avg Saved (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_saved_rupees', header: 'Total Saved (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'issue_type', header: 'Issue Type' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'onsite_avoided', header: 'Onsite Avoided' },
    { key: 'dispatched', header: 'Dispatched' },
    { key: 'avg_handle_time_min', header: 'Avg Handle (min)' },
    { key: 'avoidance_pct', header: 'Avoidance %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ticket_code', header: 'Ticket' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'device_model', header: 'Device' },
    { key: 'channel', header: 'Channel' },
    { key: 'issue_type', header: 'Issue' },
    { key: 'resolution', header: 'Resolution' },
    { key: 'handle_time_min', header: 'Handle (min)' },
    { key: 'contact_date', header: 'Date' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer First-Contact-Resolution / Teleservice Deflection Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Remote and tele-service first-contact-resolution (FCR) log with onsite-visit deflection
        tracking — engineer &times; channel (phone, remote session, email, chat, self-service)
        &times; issue type &times; resolution &times; first-contact-resolved &times; handle time
        &times; onsite-avoidance &amp; CAPA closure. Founder-gated view: resolution mix, channel
        scorecards, issue &times; resolution matrix, monthly FCR trend, root-cause pareto, and
        onsite-avoidance impact across deflected &amp; escalated tickets.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Resolution distribution</h2>
        <DataTable
          rows={resolutionRows}
          columns={resolutionCols}
          emptyMessage="No teleservice tickets logged yet."
          rowKey={(r, i) => String(r.resolution ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Issue type &times; resolution matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No tickets by issue type."
          rowKey={(r, i) => `${r.issue_type}-${r.resolution}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly FCR trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Onsite-avoidance impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.issue_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk tickets."
          rowKey={(r, i) => `${r.ticket_code}-${r.contact_date}-${i}`}
        />
      </section>
    </main>
  );
}
