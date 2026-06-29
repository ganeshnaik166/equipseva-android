import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = { chain_name: string; facilities: number; avg_compliance: number; fails: number; watches: number; passes: number };
type EquipRow = { equipment_type: string; units: number; avg_turnaround: number; avg_sla: number; over_sla: number };
type CriticalRow = { facility_code: string; chain_name: string; finding_code: string; category: string; description: string; remediation_days: number; estimated_cost_rupees: number };
type StatusRow = { audit_status: string; count: number; avg_score: number };
type CategoryRow = { category: string; total: number; open: number; closed: number; total_cost_rupees: number };
type WorstRow = { facility_code: string; chain_name: string; equipment_type: string; compliance_score: number; avg_turnaround_minutes: number; sla_minutes: number; audit_status: string };
type KpiRow = { total_audits: number; total_facilities: number; total_units: number; avg_compliance: number; open_findings: number; critical_open: number; total_remediation_cost_rupees: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [chains, equip, critical, status, categories, worst, kpis] = await Promise.all([
    supabase.rpc('r2955_chain_summary'),
    supabase.rpc('r2955_equipment_turnaround'),
    supabase.rpc('r2955_critical_findings'),
    supabase.rpc('r2955_status_distribution'),
    supabase.rpc('r2955_finding_categories'),
    supabase.rpc('r2955_worst_facilities'),
    supabase.rpc('r2955_kpis'),
  ]);

  const chainRows: ChainRow[] = (chains.data as ChainRow[]) ?? [];
  const equipRows: EquipRow[] = (equip.data as EquipRow[]) ?? [];
  const criticalRows: CriticalRow[] = (critical.data as CriticalRow[]) ?? [];
  const statusRows: StatusRow[] = (status.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categories.data as CategoryRow[]) ?? [];
  const worstRows: WorstRow[] = (worst.data as WorstRow[]) ?? [];
  const kpi: KpiRow | null = ((kpis.data as KpiRow[]) ?? [])[0] ?? null;

  const chainCols: Column<ChainRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Facilities', accessor: (r) => r.facilities },
    { header: 'Avg Compliance', accessor: (r) => r.avg_compliance },
    { header: 'Pass', accessor: (r) => r.passes },
    { header: 'Watch', accessor: (r) => r.watches },
    { header: 'Fail', accessor: (r) => r.fails },
  ];

  const equipCols: Column<EquipRow>[] = [
    { header: 'Equipment', accessor: (r) => r.equipment_type },
    { header: 'Units', accessor: (r) => r.units },
    { header: 'Avg TAT (min)', accessor: (r) => r.avg_turnaround },
    { header: 'Avg SLA (min)', accessor: (r) => r.avg_sla },
    { header: 'Over SLA', accessor: (r) => r.over_sla },
  ];

  const criticalCols: Column<CriticalRow>[] = [
    { header: 'Facility', accessor: (r) => r.facility_code },
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Code', accessor: (r) => r.finding_code },
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Description', accessor: (r) => r.description },
    { header: 'Days', accessor: (r) => r.remediation_days },
    { header: 'Cost (Rs)', accessor: (r) => r.estimated_cost_rupees.toLocaleString() },
  ];

  const statusCols: Column<StatusRow>[] = [
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'Count', accessor: (r) => r.count },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
  ];

  const catCols: Column<CategoryRow>[] = [
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Open', accessor: (r) => r.open },
    { header: 'Closed', accessor: (r) => r.closed },
    { header: 'Cost (Rs)', accessor: (r) => r.total_cost_rupees.toLocaleString() },
  ];

  const worstCols: Column<WorstRow>[] = [
    { header: 'Facility', accessor: (r) => r.facility_code },
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Equipment', accessor: (r) => r.equipment_type },
    { header: 'Score', accessor: (r) => r.compliance_score },
    { header: 'TAT', accessor: (r) => r.avg_turnaround_minutes },
    { header: 'SLA', accessor: (r) => r.sla_minutes },
    { header: 'Status', accessor: (r) => r.audit_status },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Linen-Laundry Equipment Compliance & Turn-Around Audit</h1>
        <p className="text-sm text-gray-600">Round 2955 · Founder console</p>
      </div>

      {kpi && (
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-3">
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Audits</div><div className="text-xl font-semibold">{kpi.total_audits}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Facilities</div><div className="text-xl font-semibold">{kpi.total_facilities}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Units</div><div className="text-xl font-semibold">{kpi.total_units}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Avg Compliance</div><div className="text-xl font-semibold">{kpi.avg_compliance}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Open Findings</div><div className="text-xl font-semibold">{kpi.open_findings}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Critical Open</div><div className="text-xl font-semibold">{kpi.critical_open}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Remediation Rs</div><div className="text-xl font-semibold">{kpi.total_remediation_cost_rupees?.toLocaleString()}</div></div>
        </div>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain summary</h2>
        <DataTable rows={chainRows} columns={chainCols} emptyMessage="No chains" rowKey={(r, i) => String((r as ChainRow).chain_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Equipment turnaround vs SLA</h2>
        <DataTable rows={equipRows} columns={equipCols} emptyMessage="No equipment" rowKey={(r, i) => String((r as EquipRow).equipment_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical open findings</h2>
        <DataTable rows={criticalRows} columns={criticalCols} emptyMessage="No critical findings" rowKey={(r, i) => String((r as CriticalRow).finding_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status distribution</h2>
        <DataTable rows={statusRows} columns={statusCols} emptyMessage="No statuses" rowKey={(r, i) => String((r as StatusRow).audit_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Finding categories</h2>
        <DataTable rows={categoryRows} columns={catCols} emptyMessage="No categories" rowKey={(r, i) => String((r as CategoryRow).category ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Worst facilities (bottom 10)</h2>
        <DataTable rows={worstRows} columns={worstCols} emptyMessage="No facilities" rowKey={(r, i) => String((r as WorstRow).facility_code ?? i)} />
      </section>
    </div>
  );
}
