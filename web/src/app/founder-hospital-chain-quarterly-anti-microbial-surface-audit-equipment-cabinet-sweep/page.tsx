import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = { chain_name: string; total_sweeps: number; failed_sweeps: number; remediated_sweeps: number; pass_rate_pct: number; total_remediation_rupees: number };
type PathogenRow = { pathogen_flag: string; sweep_count: number; mean_cfu: number; max_cfu: number; branches_affected: number };
type HotRow = { chain_name: string; hospital_branch: string; cabinet_code: string; swab_zone: string; cfu_per_cm2: number; pathogen_flag: string; sweep_status: string };
type ZoneRow = { swab_zone: string; sweeps: number; failures: number; mean_cfu: number; risk_score: number };
type PipelineRow = { action_kind: string; open_count: number; in_progress_count: number; resolved_count: number; escalated_count: number; total_spent: number };
type BranchRow = { chain_name: string; hospital_branch: string; sweeps: number; fails: number; remediated: number; worst_pathogen: string; total_cost: number };
type EscRow = { chain_name: string; hospital_branch: string; cabinet_code: string; pathogen_flag: string; cfu_per_cm2: number; action_kind: string; action_owner: string; outcome: string };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [chain, pathogen, hot, zone, pipe, branch, esc] = await Promise.all([
    sb.rpc('rpc_r2951_chain_summary'),
    sb.rpc('rpc_r2951_pathogen_breakdown'),
    sb.rpc('rpc_r2951_hottest_cabinets'),
    sb.rpc('rpc_r2951_zone_risk'),
    sb.rpc('rpc_r2951_remediation_pipeline'),
    sb.rpc('rpc_r2951_branch_heatmap'),
    sb.rpc('rpc_r2951_open_escalations'),
  ]);

  const chainRows = (chain.data ?? []) as ChainRow[];
  const pathogenRows = (pathogen.data ?? []) as PathogenRow[];
  const hotRows = (hot.data ?? []) as HotRow[];
  const zoneRows = (zone.data ?? []) as ZoneRow[];
  const pipeRows = (pipe.data ?? []) as PipelineRow[];
  const branchRows = (branch.data ?? []) as BranchRow[];
  const escRows = (esc.data ?? []) as EscRow[];

  const chainCols: Column<ChainRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Sweeps', accessor: (r) => r.total_sweeps },
    { header: 'Failed', accessor: (r) => r.failed_sweeps },
    { header: 'Remediated', accessor: (r) => r.remediated_sweeps },
    { header: 'Pass %', accessor: (r) => r.pass_rate_pct },
    { header: 'Remediation Rs.', accessor: (r) => r.total_remediation_rupees },
  ];

  const pathogenCols: Column<PathogenRow>[] = [
    { header: 'Pathogen', accessor: (r) => r.pathogen_flag },
    { header: 'Sweeps', accessor: (r) => r.sweep_count },
    { header: 'Mean CFU', accessor: (r) => r.mean_cfu },
    { header: 'Max CFU', accessor: (r) => r.max_cfu },
    { header: 'Branches', accessor: (r) => r.branches_affected },
  ];

  const hotCols: Column<HotRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Branch', accessor: (r) => r.hospital_branch },
    { header: 'Cabinet', accessor: (r) => r.cabinet_code },
    { header: 'Zone', accessor: (r) => r.swab_zone },
    { header: 'CFU/cm²', accessor: (r) => r.cfu_per_cm2 },
    { header: 'Pathogen', accessor: (r) => r.pathogen_flag },
    { header: 'Status', accessor: (r) => r.sweep_status },
  ];

  const zoneCols: Column<ZoneRow>[] = [
    { header: 'Zone', accessor: (r) => r.swab_zone },
    { header: 'Sweeps', accessor: (r) => r.sweeps },
    { header: 'Failures', accessor: (r) => r.failures },
    { header: 'Mean CFU', accessor: (r) => r.mean_cfu },
    { header: 'Risk Score', accessor: (r) => r.risk_score },
  ];

  const pipeCols: Column<PipelineRow>[] = [
    { header: 'Action', accessor: (r) => r.action_kind },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'In Progress', accessor: (r) => r.in_progress_count },
    { header: 'Resolved', accessor: (r) => r.resolved_count },
    { header: 'Escalated', accessor: (r) => r.escalated_count },
    { header: 'Spent Rs.', accessor: (r) => r.total_spent },
  ];

  const branchCols: Column<BranchRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Branch', accessor: (r) => r.hospital_branch },
    { header: 'Sweeps', accessor: (r) => r.sweeps },
    { header: 'Fails', accessor: (r) => r.fails },
    { header: 'Remediated', accessor: (r) => r.remediated },
    { header: 'Worst Pathogen', accessor: (r) => r.worst_pathogen },
    { header: 'Cost Rs.', accessor: (r) => r.total_cost },
  ];

  const escCols: Column<EscRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Branch', accessor: (r) => r.hospital_branch },
    { header: 'Cabinet', accessor: (r) => r.cabinet_code },
    { header: 'Pathogen', accessor: (r) => r.pathogen_flag },
    { header: 'CFU/cm²', accessor: (r) => r.cfu_per_cm2 },
    { header: 'Action', accessor: (r) => r.action_kind },
    { header: 'Owner', accessor: (r) => r.action_owner },
    { header: 'Outcome', accessor: (r) => r.outcome },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Hospital Chain Quarterly Anti-Microbial Surface-Audit Equipment Cabinet Sweep</h1>
        <p style={{ color: '#666', marginTop: 4 }}>Round 2951 · Founder console · cabinet swab + remediation pipeline across chains</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Chain summary</h2>
        <DataTable rows={chainRows} columns={chainCols} emptyMessage="No chains" rowKey={(r, i) => String((r as ChainRow).chain_name ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pathogen breakdown</h2>
        <DataTable rows={pathogenRows} columns={pathogenCols} emptyMessage="No pathogens" rowKey={(r, i) => String((r as PathogenRow).pathogen_flag ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Hottest cabinets (top 10 by CFU)</h2>
        <DataTable rows={hotRows} columns={hotCols} emptyMessage="No cabinets" rowKey={(r, i) => String((r as HotRow).cabinet_code ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Zone risk ranking</h2>
        <DataTable rows={zoneRows} columns={zoneCols} emptyMessage="No zones" rowKey={(r, i) => String((r as ZoneRow).swab_zone ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Remediation pipeline</h2>
        <DataTable rows={pipeRows} columns={pipeCols} emptyMessage="No remediation" rowKey={(r, i) => String((r as PipelineRow).action_kind ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Branch heatmap</h2>
        <DataTable rows={branchRows} columns={branchCols} emptyMessage="No branches" rowKey={(r, i) => String(((r as BranchRow).chain_name + (r as BranchRow).hospital_branch) ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Open escalations</h2>
        <DataTable rows={escRows} columns={escCols} emptyMessage="No open escalations" rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}
