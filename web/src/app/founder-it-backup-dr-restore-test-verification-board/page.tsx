import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { dr_status: string; systems: number; pct: number };
type TypeRow = {
  backup_type: string;
  total_systems: number;
  verified: number;
  test_overdue: number;
  breached: number;
  unprotected: number;
  restore_passed: number;
  offsite_gap: number;
  avg_success_pct: number;
};
type MatrixRow = {
  tier: string;
  dr_status: string;
  systems: number;
  restore_passed: number;
  avg_success_pct: number;
};
type TrendRow = {
  test_month: string;
  restore_tests: number;
  tests_passed: number;
  tests_failed: number;
  avg_rpo_achieved_hrs: number;
  avg_rto_achieved_hrs: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_downtime_risk_hrs: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_downtime_risk_hrs: number;
  pct: number;
};
type BreachRow = {
  system_name: string;
  tier: string;
  rpo_target_hrs: number;
  rpo_achieved_hrs: number | null;
  rto_target_hrs: number;
  rto_achieved_hrs: number | null;
  dr_status: string;
  trend_dir: string;
};
type RiskRow = {
  system_name: string;
  backup_type: string;
  tier: string;
  dr_status: string;
  backup_success_pct: number;
  last_restore_test: string | null;
  restore_test_passed: boolean;
  offsite_copy: boolean;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    typeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    breachRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3659_dr_status_rollup'),
    supabase.rpc('founder_r3659_backup_type_scorecard'),
    supabase.rpc('founder_r3659_tier_dr_status_matrix'),
    supabase.rpc('founder_r3659_monthly_restore_test_trend'),
    supabase.rpc('founder_r3659_capa_status_board'),
    supabase.rpc('founder_r3659_root_cause_pareto'),
    supabase.rpc('founder_r3659_rpo_rto_breach_digest'),
    supabase.rpc('founder_r3659_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const typeRows: TypeRow[] = (typeRes.data as TypeRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const breachRows: BreachRow[] = (breachRes.data as BreachRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'dr_status', header: 'DR Status' },
    { key: 'systems', header: 'Systems' },
    { key: 'pct', header: 'Share %' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'backup_type', header: 'Backup Type' },
    { key: 'total_systems', header: 'Systems' },
    { key: 'verified', header: 'Verified' },
    { key: 'test_overdue', header: 'Test Overdue' },
    { key: 'breached', header: 'RPO/RTO Breach' },
    { key: 'unprotected', header: 'Unprotected' },
    { key: 'restore_passed', header: 'Restore Passed' },
    { key: 'offsite_gap', header: 'Offsite Gap' },
    { key: 'avg_success_pct', header: 'Avg Success %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'tier', header: 'Tier' },
    { key: 'dr_status', header: 'DR Status' },
    { key: 'systems', header: 'Systems' },
    { key: 'restore_passed', header: 'Restore Passed' },
    { key: 'avg_success_pct', header: 'Avg Success %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_month', header: 'Test Month' },
    { key: 'restore_tests', header: 'Restore Tests' },
    { key: 'tests_passed', header: 'Passed' },
    { key: 'tests_failed', header: 'Failed' },
    { key: 'avg_rpo_achieved_hrs', header: 'Avg RPO Achieved (hrs)' },
    { key: 'avg_rto_achieved_hrs', header: 'Avg RTO Achieved (hrs)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_downtime_risk_hrs', header: 'Avg Downtime Risk (hrs)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_downtime_risk_hrs', header: 'Total Downtime Risk (hrs)' },
    { key: 'pct', header: 'Share %' },
  ];

  const breachCols: Column<BreachRow>[] = [
    { key: 'system_name', header: 'System' },
    { key: 'tier', header: 'Tier' },
    { key: 'rpo_target_hrs', header: 'RPO Target (hrs)' },
    { key: 'rpo_achieved_hrs', header: 'RPO Achieved (hrs)' },
    { key: 'rto_target_hrs', header: 'RTO Target (hrs)' },
    { key: 'rto_achieved_hrs', header: 'RTO Achieved (hrs)' },
    { key: 'dr_status', header: 'DR Status' },
    { key: 'trend_dir', header: 'Trend' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'system_name', header: 'System' },
    { key: 'backup_type', header: 'Backup Type' },
    { key: 'tier', header: 'Tier' },
    { key: 'dr_status', header: 'DR Status' },
    { key: 'backup_success_pct', header: 'Success %' },
    { key: 'last_restore_test', header: 'Last Restore Test' },
    { key: 'restore_test_passed', header: 'Test Passed' },
    { key: 'offsite_copy', header: 'Offsite Copy' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        IT Backup / DR Restore-Test Verification Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Backup success &amp; DR restore-test verification per system — backup type (full daily,
        incremental hourly, differential nightly, snapshot, continuous replication, weekly full)
        &times; backup-job success % &times; last restore test &times; RPO/RTO target vs achieved
        &times; offsite copy &times; tier &amp; CAPA closure. Founder-gated view: DR status rollups,
        backup-type scorecards, tier &times; status matrix, restore-test trend, root-cause pareto,
        and the RPO/RTO-breach &amp; unprotected high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. DR status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No backup/DR systems logged yet."
          rowKey={(r, i) => String(r.dr_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Backup-type scorecard</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No backup-type rollups."
          rowKey={(r, i) => String(r.backup_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Tier &times; DR-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No systems by tier."
          rowKey={(r, i) => `${r.tier}-${r.dr_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly restore-test trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No restore tests logged."
          rowKey={(r, i) => String(r.test_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. RPO/RTO breach digest</h2>
        <DataTable
          rows={breachRows}
          columns={breachCols}
          emptyMessage="No RPO/RTO breaches."
          rowKey={(r, i) => `${r.system_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk system queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk systems."
          rowKey={(r, i) => `${r.system_name}-${i}`}
        />
      </section>
    </main>
  );
}
