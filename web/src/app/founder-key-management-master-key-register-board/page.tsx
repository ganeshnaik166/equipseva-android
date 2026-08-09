import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { register_status: string; entries: number; pct: number };
type SiteRow = {
  site_name: string;
  entries: number;
  keys_total_sum: number;
  keys_issued_sum: number;
  keys_returned_sum: number;
  keys_lost_sum: number;
  discrepancies_sum: number;
  reconciled: number;
  reconciled_pct: number;
};
type MatrixRow = {
  key_class: string;
  register_status: string;
  entries: number;
  keys_lost_sum: number;
  discrepancies_sum: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  keys_issued_sum: number;
  keys_returned_sum: number;
  keys_lost_sum: number;
  locks_rekeyed_sum: number;
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
type LostRow = {
  key_class: string;
  entries: number;
  keys_lost_sum: number;
  locks_rekeyed_sum: number;
  lost_key_open: number;
  uncontrolled: number;
};
type RiskRow = {
  site_name: string;
  key_set_code: string;
  key_class: string;
  period_month: string;
  register_status: string;
  keys_lost: number;
  discrepancies: number;
  custodian_assigned: boolean;
  register_audit_current: boolean;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    siteRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    lostRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3692_register_status_rollup'),
    supabase.rpc('founder_r3692_site_scorecard'),
    supabase.rpc('founder_r3692_key_class_status_matrix'),
    supabase.rpc('founder_r3692_monthly_issuance_trend'),
    supabase.rpc('founder_r3692_capa_status_board'),
    supabase.rpc('founder_r3692_root_cause_pareto'),
    supabase.rpc('founder_r3692_lost_key_digest'),
    supabase.rpc('founder_r3692_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const siteRows: SiteRow[] = (siteRes.data as SiteRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const lostRows: LostRow[] = (lostRes.data as LostRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'register_status', header: 'Register Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const siteCols: Column<SiteRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'entries', header: 'Entries' },
    { key: 'keys_total_sum', header: 'Keys Total' },
    { key: 'keys_issued_sum', header: 'Issued' },
    { key: 'keys_returned_sum', header: 'Returned' },
    { key: 'keys_lost_sum', header: 'Lost' },
    { key: 'discrepancies_sum', header: 'Discrepancies' },
    { key: 'reconciled', header: 'Reconciled' },
    { key: 'reconciled_pct', header: 'Reconciled %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'key_class', header: 'Key Class' },
    { key: 'register_status', header: 'Register Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'keys_lost_sum', header: 'Keys Lost' },
    { key: 'discrepancies_sum', header: 'Discrepancies' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'keys_issued_sum', header: 'Issued' },
    { key: 'keys_returned_sum', header: 'Returned' },
    { key: 'keys_lost_sum', header: 'Lost' },
    { key: 'locks_rekeyed_sum', header: 'Locks Rekeyed' },
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

  const lostCols: Column<LostRow>[] = [
    { key: 'key_class', header: 'Key Class' },
    { key: 'entries', header: 'Entries' },
    { key: 'keys_lost_sum', header: 'Keys Lost' },
    { key: 'locks_rekeyed_sum', header: 'Locks Rekeyed' },
    { key: 'lost_key_open', header: 'Lost-Key Open' },
    { key: 'uncontrolled', header: 'Uncontrolled' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'key_set_code', header: 'Key Set' },
    { key: 'key_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'register_status', header: 'Status' },
    { key: 'keys_lost', header: 'Lost' },
    { key: 'discrepancies', header: 'Discrepancies' },
    { key: 'custodian_assigned', header: 'Custodian' },
    { key: 'register_audit_current', header: 'Audit Current' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Key-Management / Master-Key Register Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Physical key management across own premises — master-key register per site (Mumbai HQ,
        Chennai branch, Delhi warehouse, Bengaluru refurb center) &times; key class (master,
        sub-master, server-room, warehouse dock, vehicle) &times; issuance &amp; returns &times;
        lost keys &times; locks rekeyed &times; custodian &amp; audit currency &times;
        discrepancies &amp; CAPA closure. Founder-gated view: register-status rollups, site
        scorecards, monthly issuance trends, lost-key digest, and the uncontrolled /
        lost-key-open high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Register status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No key-register entries logged yet."
          rowKey={(r, i) => String(r.register_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Site key-register scorecard</h2>
        <DataTable
          rows={siteRows}
          columns={siteCols}
          emptyMessage="No site rollups."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Key class &times; register status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by key class."
          rowKey={(r, i) => `${r.key_class}-${r.register_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly issuance trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Lost-key digest by key class</h2>
        <DataTable
          rows={lostRows}
          columns={lostCols}
          emptyMessage="No lost-key rollups."
          rowKey={(r, i) => String(r.key_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk register queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk register entries."
          rowKey={(r, i) => `${r.key_set_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
