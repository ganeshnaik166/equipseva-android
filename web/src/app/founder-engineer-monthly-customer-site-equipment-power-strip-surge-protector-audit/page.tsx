import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/founder/DataTable';
import type { Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { total_audits: number; total_devices: number; total_failed: number; fail_rate_pct: number };
type Outcome = { outcome: string; audit_count: number; total_devices: number };
type City = { city: string; audit_count: number; devices: number; failed: number };
type Sev = { severity: string; finding_count: number; open_count: number; remediation_cost: number };
type FType = { finding_type: string; finding_count: number; critical_count: number };
type Eng = { engineer_name: string; audits: number; devices: number; failed: number };
type Crit = { audit_code: string; customer_site: string; finding_type: string; remediation_cost: number; reported_at: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [ov, oc, ci, sv, ft, en, cr] = await Promise.all([
    supabase.rpc('r2966_audit_overview'),
    supabase.rpc('r2966_outcome_breakdown'),
    supabase.rpc('r2966_city_summary'),
    supabase.rpc('r2966_finding_severity_mix'),
    supabase.rpc('r2966_finding_type_mix'),
    supabase.rpc('r2966_engineer_leaderboard'),
    supabase.rpc('r2966_critical_open_findings'),
  ]);

  const overview = (ov.data ?? []) as Overview[];
  const outcomes = (oc.data ?? []) as Outcome[];
  const cities = (ci.data ?? []) as City[];
  const sevs = (sv.data ?? []) as Sev[];
  const ftypes = (ft.data ?? []) as FType[];
  const engs = (en.data ?? []) as Eng[];
  const crits = (cr.data ?? []) as Crit[];

  const overviewCols: Column<Overview>[] = [
    { header: 'Audits', accessor: (r) => r.total_audits },
    { header: 'Devices', accessor: (r) => r.total_devices },
    { header: 'Failed', accessor: (r) => r.total_failed },
    { header: 'Fail %', accessor: (r) => r.fail_rate_pct },
  ];
  const outcomeCols: Column<Outcome>[] = [
    { header: 'Outcome', accessor: (r) => r.outcome },
    { header: 'Audits', accessor: (r) => r.audit_count },
    { header: 'Devices', accessor: (r) => r.total_devices },
  ];
  const cityCols: Column<City>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Audits', accessor: (r) => r.audit_count },
    { header: 'Devices', accessor: (r) => r.devices },
    { header: 'Failed', accessor: (r) => r.failed },
  ];
  const sevCols: Column<Sev>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Findings', accessor: (r) => r.finding_count },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Cost (Rs)', accessor: (r) => r.remediation_cost },
  ];
  const ftCols: Column<FType>[] = [
    { header: 'Type', accessor: (r) => r.finding_type },
    { header: 'Findings', accessor: (r) => r.finding_count },
    { header: 'Critical', accessor: (r) => r.critical_count },
  ];
  const engCols: Column<Eng>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Devices', accessor: (r) => r.devices },
    { header: 'Failed', accessor: (r) => r.failed },
  ];
  const critCols: Column<Crit>[] = [
    { header: 'Audit', accessor: (r) => r.audit_code },
    { header: 'Site', accessor: (r) => r.customer_site },
    { header: 'Finding', accessor: (r) => r.finding_type },
    { header: 'Cost (Rs)', accessor: (r) => r.remediation_cost },
    { header: 'Reported', accessor: (r) => r.reported_at },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1>Engineer Monthly Power-Strip & Surge-Protector Audit (r2966)</h1>
      <p>Monthly on-site review of power strips & surge protectors across customer hospitals.</p>

      <section style={{ marginTop: 24 }}>
        <h2>Overview</h2>
        <DataTable rows={overview} columns={overviewCols} emptyMessage="No overview" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Outcome Breakdown</h2>
        <DataTable rows={outcomes} columns={outcomeCols} emptyMessage="No outcomes" rowKey={(r, i) => String(r.outcome ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>City Summary</h2>
        <DataTable rows={cities} columns={cityCols} emptyMessage="No cities" rowKey={(r, i) => String(r.city ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Finding Severity Mix</h2>
        <DataTable rows={sevs} columns={sevCols} emptyMessage="No severities" rowKey={(r, i) => String(r.severity ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Finding Type Mix</h2>
        <DataTable rows={ftypes} columns={ftCols} emptyMessage="No types" rowKey={(r, i) => String(r.finding_type ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Engineer Leaderboard</h2>
        <DataTable rows={engs} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Critical & High Open Findings</h2>
        <DataTable rows={crits} columns={critCols} emptyMessage="No critical findings" rowKey={(r, i) => String(r.audit_code ?? i)} />
      </section>
    </main>
  );
}
