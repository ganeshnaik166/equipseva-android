import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Summary = { total_events: number; restocked: number; breached: number; escalated: number; open_count: number; avg_latency_min: number };
type Hosp = { hospital_name: string; events: number; avg_latency: number; breaches: number };
type Ward = { ward: string; events: number; avg_latency: number; breach_rate: number };
type Eng = { engineer_name: string; events: number; avg_latency: number; on_time: number };
type LockSum = { total_audits: number; passed: number; warned: number; failed: number; critical_count: number; avg_score: number };
type LockType = { lock_type: string; audits: number; avg_score: number; total_violations: number };
type Crit = { hospital_name: string; cart_code: string; lock_type: string; compliance_score: number; violations: number; audit_date: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [summary, byHospital, byWard, byEngineer, lockSummary, lockByType, criticals] = await Promise.all([
    supabase.rpc('r3064_restock_summary'),
    supabase.rpc('r3064_latency_by_hospital'),
    supabase.rpc('r3064_latency_by_ward'),
    supabase.rpc('r3064_engineer_performance'),
    supabase.rpc('r3064_lock_compliance_summary'),
    supabase.rpc('r3064_lock_by_type'),
    supabase.rpc('r3064_critical_alerts'),
  ]);

  const s: Summary | null = (summary.data as Summary[] | null)?.[0] ?? null;
  const ls: LockSum | null = (lockSummary.data as LockSum[] | null)?.[0] ?? null;
  const hosp: Hosp[] = (byHospital.data as Hosp[] | null) ?? [];
  const ward: Ward[] = (byWard.data as Ward[] | null) ?? [];
  const eng: Eng[] = (byEngineer.data as Eng[] | null) ?? [];
  const lt: LockType[] = (lockByType.data as LockType[] | null) ?? [];
  const cr: Crit[] = (criticals.data as Crit[] | null) ?? [];

  const hospCols: Column<Hosp>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Events', accessor: (r) => r.events },
    { header: 'Avg Latency (min)', accessor: (r) => r.avg_latency },
    { header: 'Breaches', accessor: (r) => r.breaches },
  ];
  const wardCols: Column<Ward>[] = [
    { header: 'Ward', accessor: (r) => r.ward },
    { header: 'Events', accessor: (r) => r.events },
    { header: 'Avg Latency', accessor: (r) => r.avg_latency },
    { header: 'Breach Rate %', accessor: (r) => r.breach_rate },
  ];
  const engCols: Column<Eng>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Events', accessor: (r) => r.events },
    { header: 'Avg Latency', accessor: (r) => r.avg_latency },
    { header: 'On-Time (<= SLA)', accessor: (r) => r.on_time },
  ];
  const ltCols: Column<LockType>[] = [
    { header: 'Lock Type', accessor: (r) => r.lock_type },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Total Violations', accessor: (r) => r.total_violations },
  ];
  const crCols: Column<Crit>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Cart', accessor: (r) => r.cart_code },
    { header: 'Lock', accessor: (r) => r.lock_type },
    { header: 'Score', accessor: (r) => r.compliance_score },
    { header: 'Violations', accessor: (r) => r.violations },
    { header: 'Date', accessor: (r) => r.audit_date },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Crash-Cart Restock Latency & Lock Compliance</h1>
        <p className="text-sm text-gray-600">Round r3064 · Batch 440 milestone · monthly engineer-hospital ops</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="border rounded p-3"><div className="text-xs">Total Events</div><div className="text-xl font-semibold">{s?.total_events ?? 0}</div></div>
        <div className="border rounded p-3"><div className="text-xs">Restocked</div><div className="text-xl font-semibold">{s?.restocked ?? 0}</div></div>
        <div className="border rounded p-3"><div className="text-xs">Breached</div><div className="text-xl font-semibold">{s?.breached ?? 0}</div></div>
        <div className="border rounded p-3"><div className="text-xs">Escalated</div><div className="text-xl font-semibold">{s?.escalated ?? 0}</div></div>
        <div className="border rounded p-3"><div className="text-xs">Open</div><div className="text-xl font-semibold">{s?.open_count ?? 0}</div></div>
        <div className="border rounded p-3"><div className="text-xs">Avg Latency (min)</div><div className="text-xl font-semibold">{s?.avg_latency_min ?? 0}</div></div>
      </section>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="border rounded p-3"><div className="text-xs">Lock Audits</div><div className="text-xl font-semibold">{ls?.total_audits ?? 0}</div></div>
        <div className="border rounded p-3"><div className="text-xs">Passed</div><div className="text-xl font-semibold">{ls?.passed ?? 0}</div></div>
        <div className="border rounded p-3"><div className="text-xs">Warned</div><div className="text-xl font-semibold">{ls?.warned ?? 0}</div></div>
        <div className="border rounded p-3"><div className="text-xs">Failed</div><div className="text-xl font-semibold">{ls?.failed ?? 0}</div></div>
        <div className="border rounded p-3"><div className="text-xs">Critical</div><div className="text-xl font-semibold">{ls?.critical_count ?? 0}</div></div>
        <div className="border rounded p-3"><div className="text-xs">Avg Score</div><div className="text-xl font-semibold">{ls?.avg_score ?? 0}</div></div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Latency by Hospital</h2>
        <DataTable rows={hosp} columns={hospCols} emptyMessage="No hospital data" rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Latency by Ward</h2>
        <DataTable rows={ward} columns={wardCols} emptyMessage="No ward data" rowKey={(r, i) => String(r.ward ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Performance</h2>
        <DataTable rows={eng} columns={engCols} emptyMessage="No engineer data" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Lock Compliance by Type</h2>
        <DataTable rows={lt} columns={ltCols} emptyMessage="No lock-type data" rowKey={(r, i) => String(r.lock_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical Alerts (Unremediated)</h2>
        <DataTable rows={cr} columns={crCols} emptyMessage="No critical alerts" rowKey={(r, i) => String(r.cart_code ?? i)} />
      </section>
    </div>
  );
}
