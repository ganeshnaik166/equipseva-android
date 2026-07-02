import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/founder/DataTable';
import type { Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type Summary = { total_sweeps: number; compliant: number; minor: number; major: number; critical: number; total_fine_risk_rupees: number; expired_cpcb_sites: number };
type Violation = { violation: string; occurrences: number; total_fine_rupees: number };
type Engineer = { engineer_name: string; sweeps_done: number; breaches_found: number; fine_risk_rupees: number };
type City = { city: string; sites_swept: number; criticals: number; fine_risk_rupees: number };
type Container = { container_type: string; count_sites: number; avg_fill_pct: number; total_capacity_litres: number };
type Action = { action_status: string; action_count: number; total_cost_rupees: number; followups: number };
type Offender = { customer_site: string; city: string; breaches: number; fine_risk_rupees: number; last_swept: string };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [summary, violations, engineers, cities, containers, actions, offenders] = await Promise.all([
    sb.rpc('founder_r2970_overall_compliance_summary'),
    sb.rpc('founder_r2970_violation_breakdown'),
    sb.rpc('founder_r2970_engineer_leaderboard'),
    sb.rpc('founder_r2970_city_hotspots'),
    sb.rpc('founder_r2970_container_type_mix'),
    sb.rpc('founder_r2970_corrective_action_status'),
    sb.rpc('founder_r2970_top_offender_sites'),
  ]);

  const sumRows: Summary[] = (summary.data as Summary[]) ?? [];
  const violationRows: Violation[] = (violations.data as Violation[]) ?? [];
  const engineerRows: Engineer[] = (engineers.data as Engineer[]) ?? [];
  const cityRows: City[] = (cities.data as City[]) ?? [];
  const containerRows: Container[] = (containers.data as Container[]) ?? [];
  const actionRows: Action[] = (actions.data as Action[]) ?? [];
  const offenderRows: Offender[] = (offenders.data as Offender[]) ?? [];

  const sumCols: Column<Summary>[] = [
    { key: 'total_sweeps', header: 'Total Sweeps' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'minor', header: 'Minor' },
    { key: 'major', header: 'Major' },
    { key: 'critical', header: 'Critical' },
    { key: 'total_fine_risk_rupees', header: 'Fine Risk (Rs)' },
    { key: 'expired_cpcb_sites', header: 'Expired CPCB' },
  ];

  const violationCols: Column<Violation>[] = [
    { key: 'violation', header: 'BMW Rule 2016 Violation' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_fine_rupees', header: 'Total Fine (Rs)' },
  ];

  const engineerCols: Column<Engineer>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'sweeps_done', header: 'Sweeps' },
    { key: 'breaches_found', header: 'Breaches' },
    { key: 'fine_risk_rupees', header: 'Fine Risk (Rs)' },
  ];

  const cityCols: Column<City>[] = [
    { key: 'city', header: 'City' },
    { key: 'sites_swept', header: 'Sites' },
    { key: 'criticals', header: 'Critical Breaches' },
    { key: 'fine_risk_rupees', header: 'Fine Risk (Rs)' },
  ];

  const containerCols: Column<Container>[] = [
    { key: 'container_type', header: 'Container Type' },
    { key: 'count_sites', header: 'Sites' },
    { key: 'avg_fill_pct', header: 'Avg Fill %' },
    { key: 'total_capacity_litres', header: 'Total Capacity (L)' },
  ];

  const actionCols: Column<Action>[] = [
    { key: 'action_status', header: 'Action Status' },
    { key: 'action_count', header: 'Count' },
    { key: 'total_cost_rupees', header: 'Cost (Rs)' },
    { key: 'followups', header: 'Followups' },
  ];

  const offenderCols: Column<Offender>[] = [
    { key: 'customer_site', header: 'Customer Site' },
    { key: 'city', header: 'City' },
    { key: 'breaches', header: 'Breaches' },
    { key: 'fine_risk_rupees', header: 'Fine Risk (Rs)' },
    { key: 'last_swept', header: 'Last Swept' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Sharps &amp; Biohazard Bin Compliance Sweep</h1>
        <p className="text-sm text-gray-600">BMW Rules 2016 + CPCB compliance — round r2970. Threshold: fill &gt;= 75% triggers minor breach; &gt;= 90% triggers major.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overall Compliance Summary</h2>
        <DataTable rows={sumRows} columns={sumCols} emptyMessage="No summary." rowKey={(r,i)=>String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Violation Breakdown</h2>
        <DataTable rows={violationRows} columns={violationCols} emptyMessage="No violations." rowKey={(r,i)=>String(r.violation??i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Leaderboard</h2>
        <DataTable rows={engineerRows} columns={engineerCols} emptyMessage="No engineers." rowKey={(r,i)=>String(r.engineer_name??i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Hotspots</h2>
        <DataTable rows={cityRows} columns={cityCols} emptyMessage="No cities." rowKey={(r,i)=>String(r.city??i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Container Type Mix</h2>
        <DataTable rows={containerRows} columns={containerCols} emptyMessage="No containers." rowKey={(r,i)=>String(r.container_type??i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Corrective Action Status</h2>
        <DataTable rows={actionRows} columns={actionCols} emptyMessage="No actions." rowKey={(r,i)=>String(r.action_status??i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Offender Sites</h2>
        <DataTable rows={offenderRows} columns={offenderCols} emptyMessage="No offenders." rowKey={(r,i)=>String(r.customer_site??i)} />
      </section>
    </div>
  );
}
