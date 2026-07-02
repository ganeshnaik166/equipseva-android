import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type LifecycleRow = {
  id: string;
  hospital_user_id: string | null;
  hospital_email: string | null;
  equipment_name: string | null;
  manufacturer: string | null;
  install_date: string | null;
  current_stage: string | null;
  expected_end_of_life_date: string | null;
  age_months: number | null;
  total_repairs: number | null;
  total_repair_cost_rupees: number | null;
  created_at: string | null;
};

type PlanningRow = {
  id: string;
  lifecycle_id: string | null;
  equipment_name: string | null;
  hospital_email: string | null;
  replacement_quote_sent_at: string | null;
  replacement_decision: string | null;
  decided_at: string | null;
  decided_by_email: string | null;
  quote_amount_rupees: number | null;
  created_at: string | null;
};

type AgingRow = {
  stage: string | null;
  unit_count: number | null;
  total_repairs_sum: number | null;
  total_cost_rupees_sum: number | null;
  avg_age_months: number | null;
};

type OpportunityRow = {
  lifecycle_id: string;
  equipment_name: string | null;
  hospital_email: string | null;
  current_stage: string | null;
  age_months: number | null;
  total_repairs: number | null;
  total_repair_cost_rupees: number | null;
  expected_end_of_life_date: string | null;
  has_open_planning: boolean | null;
};

function fmtRupees(v: number | null | undefined): string {
  if (v === null || v === undefined) return '-';
  return '₹' + Number(v).toLocaleString('en-IN');
}

function fmtDate(v: string | null | undefined): string {
  if (!v) return '-';
  try {
    return new Date(v).toLocaleDateString('en-IN');
  } catch {
    return v;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [lifecycleRes, planningRes, agingRes, opportunityRes] = await Promise.all([
    sb.rpc('r1791_list_lifecycle'),
    sb.rpc('r1791_list_planning'),
    sb.rpc('r1791_aging_equipment_summary'),
    sb.rpc('r1791_replacement_opportunities'),
  ]);

  const lifecycle: LifecycleRow[] = (lifecycleRes.data as LifecycleRow[]) ?? [];
  const planning: PlanningRow[] = (planningRes.data as PlanningRow[]) ?? [];
  const aging: AgingRow[] = (agingRes.data as AgingRow[]) ?? [];
  const opportunities: OpportunityRow[] = (opportunityRes.data as OpportunityRow[]) ?? [];

  const lifecycleCols: Column<LifecycleRow>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => r.equipment_name ?? '-' },
    { key: 'manufacturer', header: 'Manufacturer', render: (r: any) => r.manufacturer ?? '-' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'install_date', header: 'Installed', render: (r: any) => fmtDate(r.install_date) },
    { key: 'current_stage', header: 'Stage', render: (r: any) => r.current_stage ?? '-' },
    { key: 'expected_end_of_life_date', header: 'Expected EOL', render: (r: any) => fmtDate(r.expected_end_of_life_date) },
    { key: 'age_months', header: 'Age (mo)', render: (r: any) => r.age_months ?? 0 },
    { key: 'total_repairs', header: 'Repairs', render: (r: any) => r.total_repairs ?? 0 },
    { key: 'total_repair_cost_rupees', header: 'Repair Cost', render: (r: any) => fmtRupees(r.total_repair_cost_rupees) },
  ];

  const planningCols: Column<PlanningRow>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => r.equipment_name ?? '-' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'replacement_quote_sent_at', header: 'Quote Sent', render: (r: any) => fmtDate(r.replacement_quote_sent_at) },
    { key: 'quote_amount_rupees', header: 'Quote', render: (r: any) => fmtRupees(r.quote_amount_rupees) },
    { key: 'replacement_decision', header: 'Decision', render: (r: any) => r.replacement_decision ?? 'pending' },
    { key: 'decided_at', header: 'Decided', render: (r: any) => fmtDate(r.decided_at) },
    { key: 'decided_by_email', header: 'Decided By', render: (r: any) => r.decided_by_email ?? '-' },
  ];

  const agingCols: Column<AgingRow>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '-' },
    { key: 'unit_count', header: 'Units', render: (r: any) => r.unit_count ?? 0 },
    { key: 'total_repairs_sum', header: 'Total Repairs', render: (r: any) => r.total_repairs_sum ?? 0 },
    { key: 'total_cost_rupees_sum', header: 'Total Cost', render: (r: any) => fmtRupees(r.total_cost_rupees_sum) },
    { key: 'avg_age_months', header: 'Avg Age (mo)', render: (r: any) => Number(r.avg_age_months ?? 0).toFixed(1) },
  ];

  const opportunityCols: Column<OpportunityRow>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => r.equipment_name ?? '-' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'current_stage', header: 'Stage', render: (r: any) => r.current_stage ?? '-' },
    { key: 'age_months', header: 'Age (mo)', render: (r: any) => r.age_months ?? 0 },
    { key: 'total_repairs', header: 'Repairs', render: (r: any) => r.total_repairs ?? 0 },
    { key: 'total_repair_cost_rupees', header: 'Repair Cost', render: (r: any) => fmtRupees(r.total_repair_cost_rupees) },
    { key: 'expected_end_of_life_date', header: 'Expected EOL', render: (r: any) => fmtDate(r.expected_end_of_life_date) },
    { key: 'has_open_planning', header: 'Open Plan?', render: (r: any) => (r.has_open_planning ? 'yes' : 'no') },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Hospital Equipment Lifecycle Tracker</h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Per-equipment lifecycle stages, replacement planning & opportunity surfacing.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Aging Summary</h2>
        <DataTable
          rows={aging}
          columns={agingCols}
          rowKey={(r: any, i: number) => String(r.stage ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          Replacement Opportunities (aging / EOL &lt;= 180d)
        </h2>
        <DataTable
          rows={opportunities}
          columns={opportunityCols}
          rowKey={(r: any, i: number) => String(r.lifecycle_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Lifecycle Records</h2>
        <DataTable
          rows={lifecycle}
          columns={lifecycleCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Replacement Planning Log</h2>
        <DataTable
          rows={planning}
          columns={planningCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <footer style={{ fontSize: 12, color: '#888', marginTop: 24 }}>
        Round r1791 · founder console · lifecycle &gt; planning &gt; decision
      </footer>
    </main>
  );
}
