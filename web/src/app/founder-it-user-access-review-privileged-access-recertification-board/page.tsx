import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { review_status: string; systems: number; pct: number };
type OwnerRow = {
  system_owner: string;
  systems: number;
  certified: number;
  overdue_or_missed: number;
  accounts_total: number;
  accounts_reviewed: number;
  avg_review_pct: number;
  privileged_accounts: number;
  orphan_accounts: number;
  revocations_done: number;
};
type MatrixRow = {
  system_criticality: string;
  review_status: string;
  systems: number;
  accounts_total: number;
  privileged_accounts: number;
  avg_review_pct: number;
};
type TrendRow = {
  period_month: string;
  systems: number;
  certified: number;
  overdue_or_not_started: number;
  avg_review_pct: number;
  orphan_accounts: number;
  excessive_rights: number;
  revocations: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_accounts_impacted: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_accounts_impacted: number;
  pct: number;
};
type DigestRow = {
  system_criticality: string;
  systems: number;
  orphan_accounts: number;
  excessive_rights_found: number;
  revocations_done: number;
  unremediated_gap: number;
};
type RiskRow = {
  system_name: string;
  system_owner: string;
  period_month: string;
  system_criticality: string;
  review_status: string;
  review_pct: number | null;
  privileged_accounts: number;
  orphan_accounts: number;
  excessive_rights_found: number;
  next_review_due: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    ownerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3658_review_status_rollup'),
    supabase.rpc('founder_r3658_system_owner_scorecard'),
    supabase.rpc('founder_r3658_criticality_status_matrix'),
    supabase.rpc('founder_r3658_monthly_review_trend'),
    supabase.rpc('founder_r3658_capa_status_board'),
    supabase.rpc('founder_r3658_root_cause_pareto'),
    supabase.rpc('founder_r3658_orphan_excess_digest'),
    supabase.rpc('founder_r3658_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const ownerRows: OwnerRow[] = (ownerRes.data as OwnerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'review_status', header: 'Review Status' },
    { key: 'systems', header: 'Systems' },
    { key: 'pct', header: 'Share %' },
  ];

  const ownerCols: Column<OwnerRow>[] = [
    { key: 'system_owner', header: 'System Owner' },
    { key: 'systems', header: 'Systems' },
    { key: 'certified', header: 'Certified' },
    { key: 'overdue_or_missed', header: 'Overdue / Not Started' },
    { key: 'accounts_total', header: 'Accounts' },
    { key: 'accounts_reviewed', header: 'Reviewed' },
    { key: 'avg_review_pct', header: 'Avg Review %' },
    { key: 'privileged_accounts', header: 'Privileged' },
    { key: 'orphan_accounts', header: 'Orphans' },
    { key: 'revocations_done', header: 'Revocations' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'system_criticality', header: 'Criticality' },
    { key: 'review_status', header: 'Review Status' },
    { key: 'systems', header: 'Systems' },
    { key: 'accounts_total', header: 'Accounts' },
    { key: 'privileged_accounts', header: 'Privileged' },
    { key: 'avg_review_pct', header: 'Avg Review %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period Month' },
    { key: 'systems', header: 'Systems' },
    { key: 'certified', header: 'Certified' },
    { key: 'overdue_or_not_started', header: 'Overdue / Not Started' },
    { key: 'avg_review_pct', header: 'Avg Review %' },
    { key: 'orphan_accounts', header: 'Orphans' },
    { key: 'excessive_rights', header: 'Excessive Rights' },
    { key: 'revocations', header: 'Revocations' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_accounts_impacted', header: 'Avg Accounts Impacted' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_accounts_impacted', header: 'Total Accounts Impacted' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'system_criticality', header: 'Criticality' },
    { key: 'systems', header: 'Systems' },
    { key: 'orphan_accounts', header: 'Orphans' },
    { key: 'excessive_rights_found', header: 'Excessive Rights' },
    { key: 'revocations_done', header: 'Revocations' },
    { key: 'unremediated_gap', header: 'Unremediated Gap' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'system_name', header: 'System' },
    { key: 'system_owner', header: 'Owner' },
    { key: 'period_month', header: 'Period' },
    { key: 'system_criticality', header: 'Criticality' },
    { key: 'review_status', header: 'Status' },
    { key: 'review_pct', header: 'Review %' },
    { key: 'privileged_accounts', header: 'Privileged' },
    { key: 'orphan_accounts', header: 'Orphans' },
    { key: 'excessive_rights_found', header: 'Excessive Rights' },
    { key: 'next_review_due', header: 'Next Due' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        IT User-Access Review / Privileged-Access Recertification Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Quarterly user-access review &amp; privileged-access recertification per system &mdash; system
        &times; owner &times; period &times; accounts reviewed &times; privileged accounts &times;
        orphan accounts &times; excessive rights &times; revocations &times; criticality &amp; CAPA
        closure across ERP, CRM, field-service app, Supabase prod, O365, VPN, HRMS, payroll &amp;
        infra admin surfaces. Founder-gated view: review-status rollups, owner scorecards,
        root-cause pareto, and the high-risk (overdue / not-started) recertification queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Review status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No access reviews logged yet."
          rowKey={(r, i) => String(r.review_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. System-owner scorecard</h2>
        <DataTable
          rows={ownerRows}
          columns={ownerCols}
          emptyMessage="No owner rollups."
          rowKey={(r, i) => String(r.system_owner ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Criticality &times; review-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.system_criticality}-${r.review_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly review trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Orphan / excessive-rights digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No digest rollups."
          rowKey={(r, i) => String(r.system_criticality ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk recertification queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk systems."
          rowKey={(r, i) => `${r.system_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
