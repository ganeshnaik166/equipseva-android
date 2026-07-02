import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainVelocity = { chain_name: string; claims_count: number; recovered_count: number; avg_velocity: number | null; recovery_rate: number | null };
type OemScore = { oem_name: string; total_claims: number; recovered: number; rejected: number; escalated: number; avg_velocity: number | null; total_recovered_rupees: number };
type CategoryVel = { equipment_category: string; claims_count: number; avg_velocity_days: number | null; recovery_pct: number | null };
type OpenAging = { claim_reference: string; chain_name: string; oem_name: string; status: string; days_open: number; claim_amount_rupees: number };
type Shortfall = { chain_name: string; oem_name: string; claim_total_rupees: number; recovered_total_rupees: number; shortfall_rupees: number; shortfall_pct: number | null };
type GradeRollup = { audit_grade: string; partnership_count: number; avg_recovery_rate: number | null; avg_velocity_days: number | null };
type TopRecovery = { claim_reference: string; chain_name: string; oem_name: string; equipment_category: string; recovered_amount_rupees: number; velocity_days: number | null };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [chains, oems, cats, openA, shorts, grades, tops] = await Promise.all([
    supabase.rpc('founder_r2987_chain_velocity_summary'),
    supabase.rpc('founder_r2987_oem_scorecard'),
    supabase.rpc('founder_r2987_category_velocity'),
    supabase.rpc('founder_r2987_open_claims_aging'),
    supabase.rpc('founder_r2987_recovery_shortfall'),
    supabase.rpc('founder_r2987_audit_grade_rollup'),
    supabase.rpc('founder_r2987_top_recoveries'),
  ]);

  const chainRows = (chains.data ?? []) as ChainVelocity[];
  const oemRows = (oems.data ?? []) as OemScore[];
  const catRows = (cats.data ?? []) as CategoryVel[];
  const openRows = (openA.data ?? []) as OpenAging[];
  const shortRows = (shorts.data ?? []) as Shortfall[];
  const gradeRows = (grades.data ?? []) as GradeRollup[];
  const topRows = (tops.data ?? []) as TopRecovery[];

  const chainCols: Column<ChainVelocity>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Claims', accessor: (r) => r.claims_count },
    { header: 'Recovered', accessor: (r) => r.recovered_count },
    { header: 'Avg Velocity (days)', accessor: (r) => r.avg_velocity ?? '—' },
    { header: 'Recovery Rate %', accessor: (r) => r.recovery_rate ?? '—' },
  ];

  const oemCols: Column<OemScore>[] = [
    { header: 'OEM', accessor: (r) => r.oem_name },
    { header: 'Total', accessor: (r) => r.total_claims },
    { header: 'Recovered', accessor: (r) => r.recovered },
    { header: 'Rejected', accessor: (r) => r.rejected },
    { header: 'Escalated', accessor: (r) => r.escalated },
    { header: 'Avg Vel.', accessor: (r) => r.avg_velocity ?? '—' },
    { header: 'Total Recovered (₹)', accessor: (r) => r.total_recovered_rupees.toLocaleString() },
  ];

  const catCols: Column<CategoryVel>[] = [
    { header: 'Category', accessor: (r) => r.equipment_category },
    { header: 'Claims', accessor: (r) => r.claims_count },
    { header: 'Avg Velocity (days)', accessor: (r) => r.avg_velocity_days ?? '—' },
    { header: 'Recovery %', accessor: (r) => r.recovery_pct ?? '—' },
  ];

  const openCols: Column<OpenAging>[] = [
    { header: 'Claim Ref', accessor: (r) => r.claim_reference },
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'OEM', accessor: (r) => r.oem_name },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Days Open', accessor: (r) => r.days_open },
    { header: 'Amount (₹)', accessor: (r) => r.claim_amount_rupees.toLocaleString() },
  ];

  const shortCols: Column<Shortfall>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'OEM', accessor: (r) => r.oem_name },
    { header: 'Claimed (₹)', accessor: (r) => r.claim_total_rupees.toLocaleString() },
    { header: 'Recovered (₹)', accessor: (r) => r.recovered_total_rupees.toLocaleString() },
    { header: 'Shortfall (₹)', accessor: (r) => r.shortfall_rupees.toLocaleString() },
    { header: 'Shortfall %', accessor: (r) => r.shortfall_pct ?? '—' },
  ];

  const gradeCols: Column<GradeRollup>[] = [
    { header: 'Grade', accessor: (r) => r.audit_grade },
    { header: 'Partnerships', accessor: (r) => r.partnership_count },
    { header: 'Avg Recovery %', accessor: (r) => r.avg_recovery_rate ?? '—' },
    { header: 'Avg Velocity (days)', accessor: (r) => r.avg_velocity_days ?? '—' },
  ];

  const topCols: Column<TopRecovery>[] = [
    { header: 'Claim Ref', accessor: (r) => r.claim_reference },
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'OEM', accessor: (r) => r.oem_name },
    { header: 'Category', accessor: (r) => r.equipment_category },
    { header: 'Recovered (₹)', accessor: (r) => r.recovered_amount_rupees.toLocaleString() },
    { header: 'Velocity (days)', accessor: (r) => r.velocity_days ?? '—' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Equipment OEM Warranty-Claim Recovery Velocity Audit</h1>
        <p className="text-sm text-gray-600">Round r2987 — chains & OEMs scored on claim velocity & recovery</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain Velocity Summary</h2>
        <DataTable rows={chainRows} columns={chainCols} emptyMessage="No chain data" rowKey={(r, i) => String((r as ChainVelocity).chain_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">OEM Scorecard</h2>
        <DataTable rows={oemRows} columns={oemCols} emptyMessage="No OEM data" rowKey={(r, i) => String((r as OemScore).oem_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Category Velocity</h2>
        <DataTable rows={catRows} columns={catCols} emptyMessage="No category data" rowKey={(r, i) => String((r as CategoryVel).equipment_category ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Claims Aging</h2>
        <DataTable rows={openRows} columns={openCols} emptyMessage="No open claims" rowKey={(r, i) => String((r as OpenAging).claim_reference ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recovery Shortfall</h2>
        <DataTable rows={shortRows} columns={shortCols} emptyMessage="No shortfalls" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audit Grade Roll-up</h2>
        <DataTable rows={gradeRows} columns={gradeCols} emptyMessage="No audits" rowKey={(r, i) => String((r as GradeRollup).audit_grade ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Recoveries</h2>
        <DataTable rows={topRows} columns={topCols} emptyMessage="No recoveries" rowKey={(r, i) => String((r as TopRecovery).claim_reference ?? i)} />
      </section>
    </main>
  );
}
