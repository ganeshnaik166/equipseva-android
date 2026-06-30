import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/data-table';

export const dynamic = 'force-dynamic';

type ChainSummaryRow = {
  chain_name: string;
  total_tubs: number;
  passed: number;
  failed_or_quarantined: number;
  major_drift: number;
  total_remediation_cost_rupees: number;
};

type FailingTubRow = {
  tub_asset_tag: string;
  chain_name: string;
  hospital_branch: string;
  calibration_status: string;
  disinfection_grade: string;
  temperature_drift_celsius: number;
  jet_pressure_drift_psi: number;
  next_due_at: string;
};

type PathogenRow = {
  pathogen_detected: string;
  finding_count: number;
  critical_count: number;
  open_count: number;
  max_cfu: number;
};

type OpenFindingRow = {
  finding_code: string;
  severity: string;
  category: string;
  description: string;
  remediation_owner: string;
  remediation_due_at: string;
  days_until_due: number;
};

type QuarterRow = {
  quarter_label: string;
  tubs_audited: number;
  passed: number;
  pass_rate_pct: number;
  avg_temp_drift: number;
  avg_chlorine_ppm: number;
};

type BranchRow = {
  hospital_branch: string;
  chain_name: string;
  tub_count: number;
  worst_grade: string;
  open_critical_findings: number;
  next_due_at: string;
};

type SeverityRow = {
  severity: string;
  total: number;
  open_count: number;
  closed_count: number;
  oldest_open_due: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    chainSummary,
    failingTubs,
    pathogenBreakdown,
    openFindings,
    quarterThroughput,
    branchHotlist,
    severityRollup,
  ] = await Promise.all([
    supabase.rpc('r3087_chain_summary'),
    supabase.rpc('r3087_failing_tubs'),
    supabase.rpc('r3087_pathogen_breakdown'),
    supabase.rpc('r3087_open_findings'),
    supabase.rpc('r3087_quarter_throughput'),
    supabase.rpc('r3087_branch_hotlist'),
    supabase.rpc('r3087_severity_rollup'),
  ]);

  const chainCols: Column<ChainSummaryRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Total Tubs', accessor: (r) => r.total_tubs },
    { header: 'Passed', accessor: (r) => r.passed },
    { header: 'Failed/Quarantined', accessor: (r) => r.failed_or_quarantined },
    { header: 'Major Drift', accessor: (r) => r.major_drift },
    { header: 'Remediation Cost (Rs)', accessor: (r) => r.total_remediation_cost_rupees },
  ];

  const failingCols: Column<FailingTubRow>[] = [
    { header: 'Asset', accessor: (r) => r.tub_asset_tag },
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Branch', accessor: (r) => r.hospital_branch },
    { header: 'Status', accessor: (r) => r.calibration_status },
    { header: 'Grade', accessor: (r) => r.disinfection_grade },
    { header: 'Temp Drift (C)', accessor: (r) => r.temperature_drift_celsius },
    { header: 'Jet Drift (PSI)', accessor: (r) => r.jet_pressure_drift_psi },
    { header: 'Next Due', accessor: (r) => r.next_due_at },
  ];

  const pathogenCols: Column<PathogenRow>[] = [
    { header: 'Pathogen', accessor: (r) => r.pathogen_detected },
    { header: 'Findings', accessor: (r) => r.finding_count },
    { header: 'Critical', accessor: (r) => r.critical_count },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Max CFU/ml', accessor: (r) => r.max_cfu },
  ];

  const openFindingCols: Column<OpenFindingRow>[] = [
    { header: 'Code', accessor: (r) => r.finding_code },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Description', accessor: (r) => r.description },
    { header: 'Owner', accessor: (r) => r.remediation_owner },
    { header: 'Due', accessor: (r) => r.remediation_due_at },
    { header: 'Days Until Due', accessor: (r) => r.days_until_due },
  ];

  const quarterCols: Column<QuarterRow>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter_label },
    { header: 'Tubs Audited', accessor: (r) => r.tubs_audited },
    { header: 'Passed', accessor: (r) => r.passed },
    { header: 'Pass Rate %', accessor: (r) => r.pass_rate_pct },
    { header: 'Avg Temp Drift', accessor: (r) => r.avg_temp_drift },
    { header: 'Avg Chlorine ppm', accessor: (r) => r.avg_chlorine_ppm },
  ];

  const branchCols: Column<BranchRow>[] = [
    { header: 'Branch', accessor: (r) => r.hospital_branch },
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Tubs', accessor: (r) => r.tub_count },
    { header: 'Worst Grade', accessor: (r) => r.worst_grade },
    { header: 'Open Critical', accessor: (r) => r.open_critical_findings },
    { header: 'Next Due', accessor: (r) => r.next_due_at },
  ];

  const severityCols: Column<SeverityRow>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Closed', accessor: (r) => r.closed_count },
    { header: 'Oldest Open Due', accessor: (r) => r.oldest_open_due ?? '-' },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>
          Hospital Chain Quarterly Burn-Unit Hydrotherapy Tub Calibration & Disinfection Audit
        </h1>
        <p style={{ color: '#555', marginTop: 8 }}>
          Round r3087 — chain-by-chain rollup of burn-unit hydrotherapy tubs across calibration drift, disinfection
          grades, pathogen detections, and remediation SLA. Findings where days_until_due &lt;= 0 are overdue and
          severity &gt;= high need founder eyes today.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Chain Summary</h2>
        <DataTable
          rows={(chainSummary.data ?? []) as ChainSummaryRow[]}
          columns={chainCols}
          emptyMessage="No chains reporting."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Failing & Drifting Tubs</h2>
        <DataTable
          rows={(failingTubs.data ?? []) as FailingTubRow[]}
          columns={failingCols}
          emptyMessage="All tubs within spec."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pathogen Breakdown</h2>
        <DataTable
          rows={(pathogenBreakdown.data ?? []) as PathogenRow[]}
          columns={pathogenCols}
          emptyMessage="No pathogens detected."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Open Findings</h2>
        <DataTable
          rows={(openFindings.data ?? []) as OpenFindingRow[]}
          columns={openFindingCols}
          emptyMessage="All findings closed."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Quarter Throughput</h2>
        <DataTable
          rows={(quarterThroughput.data ?? []) as QuarterRow[]}
          columns={quarterCols}
          emptyMessage="No quarter data."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Branch Hotlist</h2>
        <DataTable
          rows={(branchHotlist.data ?? []) as BranchRow[]}
          columns={branchCols}
          emptyMessage="No branches."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Severity Rollup</h2>
        <DataTable
          rows={(severityRollup.data ?? []) as SeverityRow[]}
          columns={severityCols}
          emptyMessage="No findings."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </main>
  );
}
