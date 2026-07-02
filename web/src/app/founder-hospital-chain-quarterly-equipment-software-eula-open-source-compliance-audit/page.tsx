import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { chain_code: string; chain_name: string; audit_status: string; units: number; violations: number; risk: number; next_review: string };
type Status = { audit_status: string; chain_count: number; total_units: number; total_violations: number };
type License = { license_family: string; finding_count: number; p0_count: number; p1_count: number; copyleft_count: number };
type OpenFinding = { chain_code: string; equipment_serial: string; software_component: string; license_family: string; severity: string; remediation_status: string; due: string };
type Pyramid = { severity: string; count_total: number; copyleft_share: number; oss_share: number; cost_rupees: number };
type CostChain = { chain_code: string; chain_name: string; open_findings: number; total_cost_rupees: number; max_severity: string };
type Upcoming = { chain_code: string; chain_name: string; next_review_due: string; days_until: number; audit_status: string; legal_owner: string };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [overview, status, license, open, pyramid, cost, upcoming] = await Promise.all([
    sb.rpc('rpc_r2959_audit_overview'),
    sb.rpc('rpc_r2959_status_breakdown'),
    sb.rpc('rpc_r2959_license_family_exposure'),
    sb.rpc('rpc_r2959_open_findings'),
    sb.rpc('rpc_r2959_severity_pyramid'),
    sb.rpc('rpc_r2959_remediation_cost_by_chain'),
    sb.rpc('rpc_r2959_upcoming_reviews'),
  ]);

  const overviewRows: Overview[] = (overview.data ?? []) as Overview[];
  const statusRows: Status[] = (status.data ?? []) as Status[];
  const licenseRows: License[] = (license.data ?? []) as License[];
  const openRows: OpenFinding[] = (open.data ?? []) as OpenFinding[];
  const pyramidRows: Pyramid[] = (pyramid.data ?? []) as Pyramid[];
  const costRows: CostChain[] = (cost.data ?? []) as CostChain[];
  const upcomingRows: Upcoming[] = (upcoming.data ?? []) as Upcoming[];

  const overviewCols: Column<Overview>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Name', accessor: (r) => r.chain_name },
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'Units', accessor: (r) => r.units },
    { header: 'Violations', accessor: (r) => r.violations },
    { header: 'Risk', accessor: (r) => r.risk },
    { header: 'Next Review', accessor: (r) => r.next_review },
  ];
  const statusCols: Column<Status>[] = [
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'Chains', accessor: (r) => r.chain_count },
    { header: 'Units', accessor: (r) => r.total_units },
    { header: 'Violations', accessor: (r) => r.total_violations },
  ];
  const licenseCols: Column<License>[] = [
    { header: 'License', accessor: (r) => r.license_family },
    { header: 'Findings', accessor: (r) => r.finding_count },
    { header: 'P0', accessor: (r) => r.p0_count },
    { header: 'P1', accessor: (r) => r.p1_count },
    { header: 'Copyleft', accessor: (r) => r.copyleft_count },
  ];
  const openCols: Column<OpenFinding>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Serial', accessor: (r) => r.equipment_serial },
    { header: 'Component', accessor: (r) => r.software_component },
    { header: 'License', accessor: (r) => r.license_family },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Status', accessor: (r) => r.remediation_status },
    { header: 'Due', accessor: (r) => r.due },
  ];
  const pyramidCols: Column<Pyramid>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Total', accessor: (r) => r.count_total },
    { header: 'Copyleft', accessor: (r) => r.copyleft_share },
    { header: 'OSS', accessor: (r) => r.oss_share },
    { header: 'Cost (Rs)', accessor: (r) => r.cost_rupees },
  ];
  const costCols: Column<CostChain>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Name', accessor: (r) => r.chain_name },
    { header: 'Open', accessor: (r) => r.open_findings },
    { header: 'Cost (Rs)', accessor: (r) => r.total_cost_rupees },
    { header: 'Max Sev', accessor: (r) => r.max_severity },
  ];
  const upcomingCols: Column<Upcoming>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Name', accessor: (r) => r.chain_name },
    { header: 'Due', accessor: (r) => r.next_review_due },
    { header: 'Days', accessor: (r) => r.days_until },
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'Owner', accessor: (r) => r.legal_owner },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Quarterly EULA & OSS Compliance Audit</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>Round r2959 — equipment software license & open-source compliance across hospital chains.</p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Audit Overview by Chain</h2>
        <DataTable rows={overviewRows} columns={overviewCols} emptyMessage="No audits" rowKey={(r, i) => String((r as Overview).chain_code ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Status Breakdown</h2>
        <DataTable rows={statusRows} columns={statusCols} emptyMessage="No data" rowKey={(r, i) => String((r as Status).audit_status ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>License Family Exposure</h2>
        <DataTable rows={licenseRows} columns={licenseCols} emptyMessage="No licenses" rowKey={(r, i) => String((r as License).license_family ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Open Findings (severity &lt;= p1 priority)</h2>
        <DataTable rows={openRows} columns={openCols} emptyMessage="No open findings" rowKey={(r, i) => String((r as OpenFinding).equipment_serial ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Severity Pyramid</h2>
        <DataTable rows={pyramidRows} columns={pyramidCols} emptyMessage="No findings" rowKey={(r, i) => String((r as Pyramid).severity ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Remediation Cost by Chain</h2>
        <DataTable rows={costRows} columns={costCols} emptyMessage="No costs" rowKey={(r, i) => String((r as CostChain).chain_code ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Upcoming Quarterly Reviews</h2>
        <DataTable rows={upcomingRows} columns={upcomingCols} emptyMessage="No reviews scheduled" rowKey={(r, i) => String((r as Upcoming).chain_code ?? i)} />
      </section>
    </main>
  );
}
