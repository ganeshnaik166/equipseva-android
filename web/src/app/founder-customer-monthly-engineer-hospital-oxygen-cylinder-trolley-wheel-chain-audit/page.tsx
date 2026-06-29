import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/DataTable';
import type { Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { metric: string; value: string };
type Wheel = { wheel_condition: string; audits: number; replace_needed: number; avg_cost: number };
type City = { city: string; audits: number; defects: number; replace_cost: number };
type Eng = { engineer_name: string; trolleys_audited: number; replace_flagged: number; avg_rust: number };
type Comp = { hospital_name: string; status: string; total: number; failed: number; cost: number; signoff: boolean };
type Breach = { hospital_name: string; engineer_lead: string; failed: number; avg_rust: number; cost: number };
type Pos = { wheel_position: string; audits: number; defects: number; avg_resistance: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [kpis, wheels, cities, engs, comps, breaches, positions] = await Promise.all([
    supabase.rpc('r3048_kpis'),
    supabase.rpc('r3048_wheel_condition_breakdown'),
    supabase.rpc('r3048_city_risk'),
    supabase.rpc('r3048_engineer_load'),
    supabase.rpc('r3048_hospital_compliance'),
    supabase.rpc('r3048_breach_hospitals'),
    supabase.rpc('r3048_wheel_position_defects'),
  ]);

  const kpiRows: Kpi[] = (kpis.data ?? []) as Kpi[];
  const wheelRows: Wheel[] = (wheels.data ?? []) as Wheel[];
  const cityRows: City[] = (cities.data ?? []) as City[];
  const engRows: Eng[] = (engs.data ?? []) as Eng[];
  const compRows: Comp[] = (comps.data ?? []) as Comp[];
  const breachRows: Breach[] = (breaches.data ?? []) as Breach[];
  const posRows: Pos[] = (positions.data ?? []) as Pos[];

  const kpiCols: Column<Kpi>[] = [
    { header: 'Metric', accessor: (r) => r.metric },
    { header: 'Value', accessor: (r) => r.value },
  ];
  const wheelCols: Column<Wheel>[] = [
    { header: 'Wheel Condition', accessor: (r) => r.wheel_condition },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Replace Flagged', accessor: (r) => r.replace_needed },
    { header: 'Avg Cost (Rs)', accessor: (r) => r.avg_cost },
  ];
  const cityCols: Column<City>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Total Defects', accessor: (r) => r.defects },
    { header: 'Replace Cost (Rs)', accessor: (r) => r.replace_cost },
  ];
  const engCols: Column<Eng>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Trolleys Audited', accessor: (r) => r.trolleys_audited },
    { header: 'Replace Flagged', accessor: (r) => r.replace_flagged },
    { header: 'Avg Chain Rust', accessor: (r) => r.avg_rust },
  ];
  const compCols: Column<Comp>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Total Trolleys', accessor: (r) => r.total },
    { header: 'Failed', accessor: (r) => r.failed },
    { header: 'Cost (Rs)', accessor: (r) => r.cost },
    { header: 'Customer Signoff', accessor: (r) => (r.signoff ? 'Yes' : 'No') },
  ];
  const breachCols: Column<Breach>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Engineer Lead', accessor: (r) => r.engineer_lead },
    { header: 'Failed Trolleys', accessor: (r) => r.failed },
    { header: 'Avg Rust', accessor: (r) => r.avg_rust },
    { header: 'Cost (Rs)', accessor: (r) => r.cost },
  ];
  const posCols: Column<Pos>[] = [
    { header: 'Wheel Position', accessor: (r) => r.wheel_position },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Defects', accessor: (r) => r.defects },
    { header: 'Avg Rolling Resistance (N)', accessor: (r) => r.avg_resistance },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>r3048 Customer Monthly Engineer Hospital Oxygen-Cylinder Trolley Wheel & Chain Audit</h1>
        <p style={{ color: '#555' }}>Wheel condition, chain tension & rust, rolling resistance — hospital-level monthly compliance.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>KPIs</h2>
        <DataTable rows={kpiRows} columns={kpiCols} emptyMessage="No KPIs." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Wheel Condition Breakdown</h2>
        <DataTable rows={wheelRows} columns={wheelCols} emptyMessage="No wheel data." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>City Risk</h2>
        <DataTable rows={cityRows} columns={cityCols} emptyMessage="No city data." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer Load</h2>
        <DataTable rows={engRows} columns={engCols} emptyMessage="No engineer data." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Hospital Compliance</h2>
        <DataTable rows={compRows} columns={compCols} emptyMessage="No compliance data." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Breach Hospitals</h2>
        <DataTable rows={breachRows} columns={breachCols} emptyMessage="No breaches." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Wheel Position Defects</h2>
        <DataTable rows={posRows} columns={posCols} emptyMessage="No position data." rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}
