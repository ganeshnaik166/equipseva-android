import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Portfolio = { chain_name: string; quarter: string; branches: number; total_kg: number; avg_audit: number; red_count: number; critical_findings: number };
type Variance = { chain_name: string; hospital_branch: string; quarter: string; total_kg: number; variance_kg: number; variance_pct: number; status: string };
type RiskBand = { audit_risk_band: string; manifests: number; avg_score: number; total_kg: number; branches: number };
type Filing = { chain_name: string; hospital_branch: string; quarter: string; deadline: string; filed_at: string | null; days_to_deadline: number; status: string };
type Matrix = { finding_category: string; observations: number; minors: number; majors: number; criticals: number; open_count: number; penalty_at_risk_rupees: number };
type Critical = { chain_code: string; finding_code: string; finding_category: string; severity: string; description: string; remediation_owner: string; due_date: string; penalty_risk_rupees: number; remediation_status: string };
type Cbwtf = { cbwtf_operator: string; manifests: number; total_kg: number; avg_audit: number; disputed_count: number; missing_count: number };
type Stream = { state_code: string; manifests: number; yellow_kg: number; red_kg: number; white_kg: number; blue_kg: number; total_kg: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [portfolio, variance, bands, filing, matrix, critical, cbwtf, stream] = await Promise.all([
    sb.rpc('rpc_r2991_chain_quarter_portfolio'),
    sb.rpc('rpc_r2991_variance_leaderboard'),
    sb.rpc('rpc_r2991_audit_risk_bands'),
    sb.rpc('rpc_r2991_spcb_filing_board'),
    sb.rpc('rpc_r2991_findings_matrix'),
    sb.rpc('rpc_r2991_critical_findings'),
    sb.rpc('rpc_r2991_cbwtf_operator_perf'),
    sb.rpc('rpc_r2991_state_color_stream'),
  ]);

  const portfolioRows: Portfolio[] = (portfolio.data ?? []) as Portfolio[];
  const varianceRows: Variance[] = (variance.data ?? []) as Variance[];
  const bandRows: RiskBand[] = (bands.data ?? []) as RiskBand[];
  const filingRows: Filing[] = (filing.data ?? []) as Filing[];
  const matrixRows: Matrix[] = (matrix.data ?? []) as Matrix[];
  const criticalRows: Critical[] = (critical.data ?? []) as Critical[];
  const cbwtfRows: Cbwtf[] = (cbwtf.data ?? []) as Cbwtf[];
  const streamRows: Stream[] = (stream.data ?? []) as Stream[];

  const portfolioCols: Column<Portfolio>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Branches', accessor: (r) => r.branches },
    { header: 'Total kg', accessor: (r) => r.total_kg },
    { header: 'Avg Audit', accessor: (r) => r.avg_audit },
    { header: 'Red/Critical', accessor: (r) => r.red_count },
    { header: 'Critical Findings', accessor: (r) => r.critical_findings },
  ];
  const varianceCols: Column<Variance>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Branch', accessor: (r) => r.hospital_branch },
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Total kg', accessor: (r) => r.total_kg },
    { header: 'Variance kg', accessor: (r) => r.variance_kg },
    { header: 'Variance %', accessor: (r) => r.variance_pct },
    { header: 'Status', accessor: (r) => r.status },
  ];
  const bandCols: Column<RiskBand>[] = [
    { header: 'Risk Band', accessor: (r) => r.audit_risk_band },
    { header: 'Manifests', accessor: (r) => r.manifests },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Total kg', accessor: (r) => r.total_kg },
    { header: 'Branches', accessor: (r) => r.branches },
  ];
  const filingCols: Column<Filing>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Branch', accessor: (r) => r.hospital_branch },
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Deadline', accessor: (r) => r.deadline },
    { header: 'Filed At', accessor: (r) => r.filed_at ?? '—' },
    { header: 'Days to Deadline', accessor: (r) => r.days_to_deadline },
    { header: 'Status', accessor: (r) => r.status },
  ];
  const matrixCols: Column<Matrix>[] = [
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Observations', accessor: (r) => r.observations },
    { header: 'Minor', accessor: (r) => r.minors },
    { header: 'Major', accessor: (r) => r.majors },
    { header: 'Critical', accessor: (r) => r.criticals },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Penalty Risk (rupees)', accessor: (r) => r.penalty_at_risk_rupees },
  ];
  const criticalCols: Column<Critical>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Code', accessor: (r) => r.finding_code },
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Description', accessor: (r) => r.description },
    { header: 'Owner', accessor: (r) => r.remediation_owner },
    { header: 'Due', accessor: (r) => r.due_date },
    { header: 'Penalty Risk', accessor: (r) => r.penalty_risk_rupees },
    { header: 'Status', accessor: (r) => r.remediation_status },
  ];
  const cbwtfCols: Column<Cbwtf>[] = [
    { header: 'CBWTF Operator', accessor: (r) => r.cbwtf_operator },
    { header: 'Manifests', accessor: (r) => r.manifests },
    { header: 'Total kg', accessor: (r) => r.total_kg },
    { header: 'Avg Audit', accessor: (r) => r.avg_audit },
    { header: 'Disputed', accessor: (r) => r.disputed_count },
    { header: 'Missing', accessor: (r) => r.missing_count },
  ];
  const streamCols: Column<Stream>[] = [
    { header: 'State', accessor: (r) => r.state_code },
    { header: 'Manifests', accessor: (r) => r.manifests },
    { header: 'Yellow kg', accessor: (r) => r.yellow_kg },
    { header: 'Red kg', accessor: (r) => r.red_kg },
    { header: 'White kg', accessor: (r) => r.white_kg },
    { header: 'Blue kg', accessor: (r) => r.blue_kg },
    { header: 'Total kg', accessor: (r) => r.total_kg },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Chain Quarterly BMW Manifest Reconciliation & CPCB Audit</h1>
        <p className="text-sm text-slate-600">Round r2991 — color-stream tonnage, CBWTF reconciliation variance, SPCB filing board & CPCB rule-ref findings.</p>
      </header>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Chain × Quarter Portfolio</h2>
        <DataTable rows={portfolioRows} columns={portfolioCols} emptyMessage="No chain portfolio rows." rowKey={(r, i) => String((r as Portfolio).chain_name + (r as Portfolio).quarter + i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Reconciliation Variance Leaderboard</h2>
        <DataTable rows={varianceRows} columns={varianceCols} emptyMessage="No variance manifests." rowKey={(r, i) => String((r as Variance).chain_name + (r as Variance).hospital_branch + i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">CPCB Audit Risk Bands</h2>
        <DataTable rows={bandRows} columns={bandCols} emptyMessage="No risk bands." rowKey={(r, i) => String((r as RiskBand).audit_risk_band + i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">SPCB Filing Board (deadline vs today)</h2>
        <DataTable rows={filingRows} columns={filingCols} emptyMessage="No filings tracked." rowKey={(r, i) => String((r as Filing).chain_name + (r as Filing).hospital_branch + (r as Filing).quarter + i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Findings Matrix — Category × Severity</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No findings." rowKey={(r, i) => String((r as Matrix).finding_category + i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Critical & Major Open Findings</h2>
        <DataTable rows={criticalRows} columns={criticalCols} emptyMessage="No critical findings." rowKey={(r, i) => String((r as Critical).finding_code + i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">CBWTF Operator Performance</h2>
        <DataTable rows={cbwtfRows} columns={cbwtfCols} emptyMessage="No CBWTF operators." rowKey={(r, i) => String((r as Cbwtf).cbwtf_operator + i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Color-Stream Tonnage by State</h2>
        <DataTable rows={streamRows} columns={streamCols} emptyMessage="No state breakdown." rowKey={(r, i) => String((r as Stream).state_code + i)} />
      </section>
    </div>
  );
}