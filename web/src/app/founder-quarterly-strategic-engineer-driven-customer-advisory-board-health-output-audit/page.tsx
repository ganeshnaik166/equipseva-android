import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/data-table';
import type { Column } from '@/components/data-table';

export const dynamic = 'force-dynamic';

type Member = { member_name: string; hospital_org: string; member_role: string; city: string; attendance_rate_pct: number; contributions_count: number; status: string };
type RoleRow = { member_role: string; members: number; avg_attendance: number; avg_contributions: number };
type SponsorRow = { engineer_sponsor: string; members_sponsored: number; active_members: number; avg_attendance: number };
type QuarterRow = { quarter_label: string; total_outputs: number; shipped: number; approved: number; total_impact_lakhs: number };
type TypeRow = { output_type: string; total: number; shipped: number; avg_health: number; total_impact_lakhs: number };
type TopOutput = { output_title: string; quarter_label: string; driving_engineer: string; est_revenue_impact_lakhs: number; adoption_status: string; health_score: number };
type Snapshot = { metric: string; value: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [roster, byRole, sponsorLoad, qSummary, typeBreak, topOutputs, snapshot] = await Promise.all([
    supabase.rpc('founder_r3041_member_roster'),
    supabase.rpc('founder_r3041_attendance_by_role'),
    supabase.rpc('founder_r3041_engineer_sponsor_load'),
    supabase.rpc('founder_r3041_quarterly_output_summary'),
    supabase.rpc('founder_r3041_output_type_breakdown'),
    supabase.rpc('founder_r3041_top_outputs_by_impact'),
    supabase.rpc('founder_r3041_board_health_snapshot'),
  ]);

  const rosterCols: Column<Member>[] = [
    { header: 'Member', accessor: (r) => r.member_name },
    { header: 'Hospital', accessor: (r) => r.hospital_org },
    { header: 'Role', accessor: (r) => r.member_role },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Attendance %', accessor: (r) => r.attendance_rate_pct },
    { header: 'Contributions', accessor: (r) => r.contributions_count },
    { header: 'Status', accessor: (r) => r.status },
  ];
  const roleCols: Column<RoleRow>[] = [
    { header: 'Role', accessor: (r) => r.member_role },
    { header: 'Members', accessor: (r) => r.members },
    { header: 'Avg Attendance', accessor: (r) => r.avg_attendance },
    { header: 'Avg Contributions', accessor: (r) => r.avg_contributions },
  ];
  const sponsorCols: Column<SponsorRow>[] = [
    { header: 'Engineer Sponsor', accessor: (r) => r.engineer_sponsor },
    { header: 'Sponsored', accessor: (r) => r.members_sponsored },
    { header: 'Active', accessor: (r) => r.active_members },
    { header: 'Avg Attendance', accessor: (r) => r.avg_attendance },
  ];
  const qCols: Column<QuarterRow>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter_label },
    { header: 'Outputs', accessor: (r) => r.total_outputs },
    { header: 'Shipped', accessor: (r) => r.shipped },
    { header: 'Approved', accessor: (r) => r.approved },
    { header: 'Impact (L)', accessor: (r) => r.total_impact_lakhs },
  ];
  const typeCols: Column<TypeRow>[] = [
    { header: 'Output Type', accessor: (r) => r.output_type },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Shipped', accessor: (r) => r.shipped },
    { header: 'Avg Health', accessor: (r) => r.avg_health },
    { header: 'Impact (L)', accessor: (r) => r.total_impact_lakhs },
  ];
  const topCols: Column<TopOutput>[] = [
    { header: 'Title', accessor: (r) => r.output_title },
    { header: 'Quarter', accessor: (r) => r.quarter_label },
    { header: 'Driving Engineer', accessor: (r) => r.driving_engineer },
    { header: 'Impact (L)', accessor: (r) => r.est_revenue_impact_lakhs },
    { header: 'Adoption', accessor: (r) => r.adoption_status },
    { header: 'Health', accessor: (r) => r.health_score },
  ];
  const snapCols: Column<Snapshot>[] = [
    { header: 'Metric', accessor: (r) => r.metric },
    { header: 'Value', accessor: (r) => r.value },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Quarterly Strategic CAB Health & Output Audit</h1>
        <p className="text-sm text-gray-600">Engineer-driven Customer Advisory Board roster, attendance, sponsor load & quarterly outputs.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Board Health Snapshot</h2>
        <DataTable rows={(snapshot.data ?? []) as Snapshot[]} columns={snapCols} emptyMessage="No snapshot." rowKey={(r,i)=>String(r.metric ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Member Roster</h2>
        <DataTable rows={(roster.data ?? []) as Member[]} columns={rosterCols} emptyMessage="No members." rowKey={(r,i)=>String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Attendance by Role</h2>
        <DataTable rows={(byRole.data ?? []) as RoleRow[]} columns={roleCols} emptyMessage="No roles." rowKey={(r,i)=>String(r.member_role ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Sponsor Load</h2>
        <DataTable rows={(sponsorLoad.data ?? []) as SponsorRow[]} columns={sponsorCols} emptyMessage="No sponsors." rowKey={(r,i)=>String(r.engineer_sponsor ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Output Summary</h2>
        <DataTable rows={(qSummary.data ?? []) as QuarterRow[]} columns={qCols} emptyMessage="No quarters." rowKey={(r,i)=>String(r.quarter_label ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Output Type Breakdown</h2>
        <DataTable rows={(typeBreak.data ?? []) as TypeRow[]} columns={typeCols} emptyMessage="No types." rowKey={(r,i)=>String(r.output_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Outputs by Impact</h2>
        <DataTable rows={(topOutputs.data ?? []) as TopOutput[]} columns={topCols} emptyMessage="No outputs." rowKey={(r,i)=>String(i)} />
      </section>
    </main>
  );
}
