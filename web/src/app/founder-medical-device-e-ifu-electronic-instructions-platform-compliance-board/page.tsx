import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { eifu_status: string; records: number; pct: number };
type ChannelRow = {
  delivery_channel: string;
  total_records: number;
  compliant: number;
  language_gap: number;
  platform_issue: number;
  non_compliant: number;
  avg_uptime_pct: number;
  avg_download_success_pct: number;
  compliant_pct: number;
};
type MatrixRow = {
  delivery_channel: string;
  eifu_status: string;
  records: number;
  avg_uptime_pct: number;
  avg_download_success_pct: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  compliant: number;
  language_gap: number;
  platform_issue: number;
  non_compliant: number;
  avg_download_success_pct: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type GapRow = {
  device_name: string;
  eifu_ref: string;
  ifu_version: string;
  delivery_channel: string;
  languages_required: number;
  languages_published: number;
  missing_languages: number;
  eifu_status: string;
  notes: string | null;
};
type RiskRow = {
  device_name: string;
  eifu_ref: string;
  ifu_version: string;
  period_month: string;
  delivery_channel: string;
  eifu_status: string;
  trend_dir: string;
  platform_uptime_pct: number | null;
  download_success_pct: number | null;
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
    gapRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3655_eifu_status_rollup'),
    supabase.rpc('founder_r3655_delivery_channel_scorecard'),
    supabase.rpc('founder_r3655_channel_status_matrix'),
    supabase.rpc('founder_r3655_monthly_compliance_trend'),
    supabase.rpc('founder_r3655_capa_status_board'),
    supabase.rpc('founder_r3655_root_cause_pareto'),
    supabase.rpc('founder_r3655_language_gap_digest'),
    supabase.rpc('founder_r3655_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const channelRows: ChannelRow[] = (channelRes.data as ChannelRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const gapRows: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'eifu_status', header: 'e-IFU Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const channelCols: Column<ChannelRow>[] = [
    { key: 'delivery_channel', header: 'Delivery Channel' },
    { key: 'total_records', header: 'Records' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'language_gap', header: 'Language Gap' },
    { key: 'platform_issue', header: 'Platform Issue' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'avg_uptime_pct', header: 'Avg Uptime %' },
    { key: 'avg_download_success_pct', header: 'Avg Download %' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'delivery_channel', header: 'Delivery Channel' },
    { key: 'eifu_status', header: 'e-IFU Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_uptime_pct', header: 'Avg Uptime %' },
    { key: 'avg_download_success_pct', header: 'Avg Download %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'language_gap', header: 'Language Gap' },
    { key: 'platform_issue', header: 'Platform Issue' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'avg_download_success_pct', header: 'Avg Download %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const gapCols: Column<GapRow>[] = [
    { key: 'device_name', header: 'Device' },
    { key: 'eifu_ref', header: 'e-IFU Ref' },
    { key: 'ifu_version', header: 'IFU Version' },
    { key: 'delivery_channel', header: 'Channel' },
    { key: 'languages_required', header: 'Langs Required' },
    { key: 'languages_published', header: 'Langs Published' },
    { key: 'missing_languages', header: 'Missing' },
    { key: 'eifu_status', header: 'Status' },
    { key: 'notes', header: 'Notes' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'device_name', header: 'Device' },
    { key: 'eifu_ref', header: 'e-IFU Ref' },
    { key: 'ifu_version', header: 'IFU Version' },
    { key: 'period_month', header: 'Month' },
    { key: 'delivery_channel', header: 'Channel' },
    { key: 'eifu_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'platform_uptime_pct', header: 'Uptime %' },
    { key: 'download_success_pct', header: 'Download %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Medical-Device e-IFU (Electronic Instructions) Platform Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Electronic instructions-for-use platform compliance log — device &times; IFU version &times;
        language coverage (required vs published) &times; platform uptime &times; download success
        &times; paper-copy fulfilment days &times; delivery channel (web portal, QR-on-label,
        app-embedded, USB media, paper fallback) &amp; CAPA closure. Founder-gated view: e-IFU status
        distribution, delivery-channel scorecards, monthly compliance trend, root-cause pareto,
        language-gap digest, and the high-risk queue of non-compliant &amp; platform-issue devices.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. e-IFU status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No e-IFU records logged yet."
          rowKey={(r, i) => String(r.eifu_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Delivery-channel scorecard</h2>
        <DataTable
          rows={channelRows}
          columns={channelCols}
          emptyMessage="No delivery-channel rollups."
          rowKey={(r, i) => String(r.delivery_channel ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Delivery channel &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by channel."
          rowKey={(r, i) => `${r.delivery_channel}-${r.eifu_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly compliance trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Language-gap digest</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          emptyMessage="No language gaps — all devices fully published."
          rowKey={(r, i) => `${r.eifu_ref}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk e-IFU queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk e-IFU records."
          rowKey={(r, i) => `${r.eifu_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
