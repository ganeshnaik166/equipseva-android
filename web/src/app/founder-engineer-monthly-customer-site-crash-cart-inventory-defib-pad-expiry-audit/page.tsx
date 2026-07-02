import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/data-table';

export const dynamic = 'force-dynamic';

type Overview = { total_audits: number; sites_audited: number; grade_a_count: number; grade_f_count: number; expired_pad_sites: number; remediation_open: number };
type Defib = { hospital_name: string; site_code: string; defib_pad_lot: string; defib_pad_expiry: string; defib_pad_status: string; days_remaining: number };
type Eng = { engineer_name: string; audits_done: number; avg_items_present: number; expired_pads_found: number; grade_a_count: number; grade_f_count: number };
type Grade = { overall_grade: string; site_count: number; pct_of_total: number };
type Remed = { hospital_name: string; item_name: string; issue_type: string; severity: string; replacement_cost_rupees: number; resolution_notes: string };
type P0 = { hospital_name: string; site_code: string; city: string; engineer_name: string; overall_grade: string; expired_items: number; missing_items: number };
type Cost = { issue_type: string; open_count: number; resolved_count: number; total_cost_rupees: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [ov, dw, es, gd, rb, p0, rc] = await Promise.all([
    supabase.rpc('r2962_audit_overview'),
    supabase.rpc('r2962_defib_expiry_watch'),
    supabase.rpc('r2962_engineer_scorecard'),
    supabase.rpc('r2962_site_grade_distribution'),
    supabase.rpc('r2962_remediation_backlog'),
    supabase.rpc('r2962_p0_critical_sites'),
    supabase.rpc('r2962_remediation_cost_summary'),
  ]);

  const overview = (ov.data ?? []) as Overview[];
  const defib = (dw.data ?? []) as Defib[];
  const engineers = (es.data ?? []) as Eng[];
  const grades = (gd.data ?? []) as Grade[];
  const remed = (rb.data ?? []) as Remed[];
  const p0Sites = (p0.data ?? []) as P0[];
  const costs = (rc.data ?? []) as Cost[];

  const overviewCols: Column<Overview>[] = [
    { header: 'Total Audits', accessor: (r) => r.total_audits },
    { header: 'Sites Audited', accessor: (r) => r.sites_audited },
    { header: 'Grade A', accessor: (r) => r.grade_a_count },
    { header: 'Grade F', accessor: (r) => r.grade_f_count },
    { header: 'Expired Pad Sites', accessor: (r) => r.expired_pad_sites },
    { header: 'Open Remediation', accessor: (r) => r.remediation_open },
  ];

  const defibCols: Column<Defib>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Site', accessor: (r) => r.site_code },
    { header: 'Lot', accessor: (r) => r.defib_pad_lot },
    { header: 'Expiry', accessor: (r) => r.defib_pad_expiry },
    { header: 'Status', accessor: (r) => r.defib_pad_status },
    { header: 'Days Remaining', accessor: (r) => r.days_remaining },
  ];

  const engCols: Column<Eng>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audits_done },
    { header: 'Avg Items Present', accessor: (r) => r.avg_items_present },
    { header: 'Expired Pads Found', accessor: (r) => r.expired_pads_found },
    { header: 'Grade A', accessor: (r) => r.grade_a_count },
    { header: 'Grade F', accessor: (r) => r.grade_f_count },
  ];

  const gradeCols: Column<Grade>[] = [
    { header: 'Grade', accessor: (r) => r.overall_grade },
    { header: 'Sites', accessor: (r) => r.site_count },
    { header: '% of Total', accessor: (r) => r.pct_of_total + '%' },
  ];

  const remedCols: Column<Remed>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Item', accessor: (r) => r.item_name },
    { header: 'Issue', accessor: (r) => r.issue_type },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Cost (Rs)', accessor: (r) => r.replacement_cost_rupees },
    { header: 'Notes', accessor: (r) => r.resolution_notes },
  ];

  const p0Cols: Column<P0>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Site', accessor: (r) => r.site_code },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Grade', accessor: (r) => r.overall_grade },
    { header: 'Expired', accessor: (r) => r.expired_items },
    { header: 'Missing', accessor: (r) => r.missing_items },
  ];

  const costCols: Column<Cost>[] = [
    { header: 'Issue Type', accessor: (r) => r.issue_type },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Resolved', accessor: (r) => r.resolved_count },
    { header: 'Total Cost (Rs)', accessor: (r) => r.total_cost_rupees },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Crash-Cart Inventory & Defib Pad Expiry Audit</h1>
        <p className="text-sm text-gray-600">Round 2962 · monthly per-site crash-cart compliance & defib pad lot tracking</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audit Overview</h2>
        <DataTable rows={overview} columns={overviewCols} emptyMessage="No overview data" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Defib Pad Expiry Watch (expired & expiring soon)</h2>
        <DataTable rows={defib} columns={defibCols} emptyMessage="All defib pads valid" rowKey={(r, i) => r.site_code + i} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Scorecard</h2>
        <DataTable rows={engineers} columns={engCols} emptyMessage="No engineer activity" rowKey={(r, i) => r.engineer_name + i} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Grade Distribution</h2>
        <DataTable rows={grades} columns={gradeCols} emptyMessage="No grades" rowKey={(r, i) => r.overall_grade + i} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Remediation Backlog (open items)</h2>
        <DataTable rows={remed} columns={remedCols} emptyMessage="No open remediation" rowKey={(r, i) => r.hospital_name + r.item_name + i} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">P0 / Critical Sites</h2>
        <DataTable rows={p0Sites} columns={p0Cols} emptyMessage="No critical sites" rowKey={(r, i) => r.site_code + i} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Remediation Cost Summary</h2>
        <DataTable rows={costs} columns={costCols} emptyMessage="No cost data" rowKey={(r, i) => r.issue_type + i} />
      </section>
    </div>
  );
}
