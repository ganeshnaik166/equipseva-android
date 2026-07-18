import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { assist_verdict: string; sessions: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_sessions: number;
  resolved_remote: number;
  visits_avoided: number;
  kb_articles: number;
  avg_minutes: number;
  remote_fix_pct: number;
};
type MatrixRow = {
  assist_channel: string;
  equipment_category: string;
  sessions: number;
  resolved_remote: number;
  avg_minutes: number;
};
type TrendRow = {
  request_date: string;
  sessions: number;
  resolved_remote: number;
  visits_avoided: number;
  total_minutes: number;
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
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  assist_ref_code: string;
  requesting_engineer_name: string;
  equipment_category: string;
  assist_channel: string;
  request_date: string;
  minutes_spent: number | null;
  assist_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3228_verdict_rollup'),
    supabase.rpc('founder_r3228_hospital_scorecard'),
    supabase.rpc('founder_r3228_channel_category_matrix'),
    supabase.rpc('founder_r3228_daily_trend'),
    supabase.rpc('founder_r3228_capa_status_board'),
    supabase.rpc('founder_r3228_root_cause_pareto'),
    supabase.rpc('founder_r3228_regulatory_impact_digest'),
    supabase.rpc('founder_r3228_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'assist_verdict', header: 'Verdict' },
    { key: 'sessions', header: 'Sessions' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_sessions', header: 'Sessions' },
    { key: 'resolved_remote', header: 'Resolved Remotely' },
    { key: 'visits_avoided', header: 'Visits Avoided' },
    { key: 'kb_articles', header: 'KB Articles' },
    { key: 'avg_minutes', header: 'Avg Minutes' },
    { key: 'remote_fix_pct', header: 'Remote Fix %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'assist_channel', header: 'Channel' },
    { key: 'equipment_category', header: 'Equipment Category' },
    { key: 'sessions', header: 'Sessions' },
    { key: 'resolved_remote', header: 'Resolved Remotely' },
    { key: 'avg_minutes', header: 'Avg Minutes' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'request_date', header: 'Date' },
    { key: 'sessions', header: 'Sessions' },
    { key: 'resolved_remote', header: 'Resolved Remotely' },
    { key: 'visits_avoided', header: 'Visits Avoided' },
    { key: 'total_minutes', header: 'Total Minutes' },
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

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'assist_ref_code', header: 'Ref' },
    { key: 'requesting_engineer_name', header: 'Requesting Engineer' },
    { key: 'equipment_category', header: 'Equipment' },
    { key: 'assist_channel', header: 'Channel' },
    { key: 'request_date', header: 'Date' },
    { key: 'minutes_spent', header: 'Minutes' },
    { key: 'assist_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Second-Opinion Consult &amp; Remote-Diagnosis Assist Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Remote assist log &mdash; requesting engineer &times; assisting expert &times; channel &times;
        equipment category &times; resolved-remotely &times; visit-avoided &times; minutes &times;
        KB article &amp; CAPA closure. Founder-gated view: verdict rollups, hospital scorecards,
        channel-category matrix, root-cause pareto, and regulatory-impact digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Assist verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No assist sessions logged yet."
          rowKey={(r, i) => String(r.assist_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital remote-assist scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Channel &times; equipment category matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No sessions by channel."
          rowKey={(r, i) => `${r.assist_channel}-${r.equipment_category}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily remote-assist trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.request_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk / unresolved assist queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk sessions."
          rowKey={(r, i) => `${r.assist_ref_code}-${r.request_date}-${i}`}
        />
      </section>
    </main>
  );
}
