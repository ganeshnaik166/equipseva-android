import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { total_contracts: number; on_track: number; behind: number; at_risk: number; breached: number; avg_uptime: number };
type ByTier = { amc_tier: string; contracts: number; total_elevators: number; monthly_revenue_rupees: number };
type Behind = { hospital_name: string; hospital_city: string; sync_status: string; monthly_visit_quota: number; monthly_visits_completed: number; next_visit_due_at: string | null };
type EngineerLoad = { assigned_engineer_name: string; contracts: number; total_elevators: number; avg_uptime: number };
type Outcome = { visit_outcome: string; visits: number; signoff_count: number; total_parts: number };
type City = { hospital_city: string; contracts: number; elevators: number; breached_count: number; avg_uptime: number };
type Recent = { hospital_name: string; engineer_name: string; scheduled_at: string; visit_outcome: string; parts_replaced_count: number; signoff: boolean };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, tierRes, behindRes, engRes, outRes, cityRes, recentRes] = await Promise.all([
    supabase.rpc('r2988_sync_overview'),
    supabase.rpc('r2988_contracts_by_tier'),
    supabase.rpc('r2988_behind_schedule'),
    supabase.rpc('r2988_engineer_load'),
    supabase.rpc('r2988_visit_outcomes'),
    supabase.rpc('r2988_city_breakdown'),
    supabase.rpc('r2988_recent_visits'),
  ]);

  const overview = (overviewRes.data ?? []) as Overview[];
  const tiers = (tierRes.data ?? []) as ByTier[];
  const behind = (behindRes.data ?? []) as Behind[];
  const engineers = (engRes.data ?? []) as EngineerLoad[];
  const outcomes = (outRes.data ?? []) as Outcome[];
  const cities = (cityRes.data ?? []) as City[];
  const recent = (recentRes.data ?? []) as Recent[];

  const overviewCols: Column<Overview>[] = [
    { header: 'Total contracts', accessor: (r) => r.total_contracts },
    { header: 'On track', accessor: (r) => r.on_track },
    { header: 'Behind', accessor: (r) => r.behind },
    { header: 'At risk', accessor: (r) => r.at_risk },
    { header: 'Breached', accessor: (r) => r.breached },
    { header: 'Avg uptime %', accessor: (r) => r.avg_uptime },
  ];

  const tierCols: Column<ByTier>[] = [
    { header: 'Tier', accessor: (r) => r.amc_tier },
    { header: 'Contracts', accessor: (r) => r.contracts },
    { header: 'Elevators', accessor: (r) => r.total_elevators },
    { header: 'Monthly revenue (Rs)', accessor: (r) => r.monthly_revenue_rupees },
  ];

  const behindCols: Column<Behind>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.hospital_city },
    { header: 'Status', accessor: (r) => r.sync_status },
    { header: 'Quota', accessor: (r) => r.monthly_visit_quota },
    { header: 'Completed', accessor: (r) => r.monthly_visits_completed },
    { header: 'Next visit due', accessor: (r) => r.next_visit_due_at ? new Date(r.next_visit_due_at).toLocaleDateString() : '—' },
  ];

  const engCols: Column<EngineerLoad>[] = [
    { header: 'Engineer', accessor: (r) => r.assigned_engineer_name },
    { header: 'Contracts', accessor: (r) => r.contracts },
    { header: 'Elevators', accessor: (r) => r.total_elevators },
    { header: 'Avg uptime %', accessor: (r) => r.avg_uptime },
  ];

  const outCols: Column<Outcome>[] = [
    { header: 'Outcome', accessor: (r) => r.visit_outcome },
    { header: 'Visits', accessor: (r) => r.visits },
    { header: 'Signoffs', accessor: (r) => r.signoff_count },
    { header: 'Parts replaced', accessor: (r) => r.total_parts },
  ];

  const cityCols: Column<City>[] = [
    { header: 'City', accessor: (r) => r.hospital_city },
    { header: 'Contracts', accessor: (r) => r.contracts },
    { header: 'Elevators', accessor: (r) => r.elevators },
    { header: 'Breached', accessor: (r) => r.breached_count },
    { header: 'Avg uptime %', accessor: (r) => r.avg_uptime },
  ];

  const recentCols: Column<Recent>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Scheduled', accessor: (r) => new Date(r.scheduled_at).toLocaleString() },
    { header: 'Outcome', accessor: (r) => r.visit_outcome },
    { header: 'Parts', accessor: (r) => r.parts_replaced_count },
    { header: 'Signoff', accessor: (r) => r.signoff ? 'yes' : 'no' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Lift / Elevator AMC Sync Tracker</h1>
        <p className="text-sm text-gray-600">Customer &amp; engineer monthly visit sync across hospital lift/elevator AMC contracts. Behind/at-risk surfaced &gt;= breach threshold.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Portfolio overview</h2>
        <DataTable rows={overview} columns={overviewCols} emptyMessage="No overview" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Contracts by AMC tier</h2>
        <DataTable rows={tiers} columns={tierCols} emptyMessage="No tier data" rowKey={(r, i) => String(r.amc_tier ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Behind schedule (visits &lt; quota)</h2>
        <DataTable rows={behind} columns={behindCols} emptyMessage="All on track" rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer load</h2>
        <DataTable rows={engineers} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String(r.assigned_engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Visit outcomes</h2>
        <DataTable rows={outcomes} columns={outCols} emptyMessage="No visits" rowKey={(r, i) => String(r.visit_outcome ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City breakdown</h2>
        <DataTable rows={cities} columns={cityCols} emptyMessage="No cities" rowKey={(r, i) => String(r.hospital_city ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent visits</h2>
        <DataTable rows={recent} columns={recentCols} emptyMessage="No recent visits" rowKey={(r, i) => String(i)} />
      </section>
    </main>
  );
}
