import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Summary = { total_audits: number; passing: number; minor: number; major: number; failing: number; followups: number };
type Vendor = { system_vendor: string; audits: number; avg_transit: number; total_missing: number; fail_count: number };
type WorstSite = { hospital_name: string; city: string; capsules_missing: number; diverter_failures: number; status: string };
type Engineer = { engineer_name: string; audits: number; passes: number; avg_pressure: number };
type Outcome = { outcome: string; events: number; avg_transit: number; critical_count: number };
type Payload = { payload_type: string; events: number; delivered: number; lost_or_damaged: number; avg_transit: number };
type Incident = { event_at: string; hospital_name: string; capsule_id: string; payload_type: string; priority: string; outcome: string; transit_seconds: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, vendorRes, worstRes, engRes, outcomeRes, payloadRes, incidentRes] = await Promise.all([
    supabase.rpc('r2986_audit_summary'),
    supabase.rpc('r2986_vendor_breakdown'),
    supabase.rpc('r2986_worst_sites'),
    supabase.rpc('r2986_engineer_leaderboard'),
    supabase.rpc('r2986_capsule_outcomes'),
    supabase.rpc('r2986_payload_stats'),
    supabase.rpc('r2986_capsule_incidents'),
  ]);

  const summary: Summary | null = (summaryRes.data?.[0] as Summary) ?? null;
  const vendors: Vendor[] = (vendorRes.data as Vendor[]) ?? [];
  const worst: WorstSite[] = (worstRes.data as WorstSite[]) ?? [];
  const engineers: Engineer[] = (engRes.data as Engineer[]) ?? [];
  const outcomes: Outcome[] = (outcomeRes.data as Outcome[]) ?? [];
  const payloads: Payload[] = (payloadRes.data as Payload[]) ?? [];
  const incidents: Incident[] = (incidentRes.data as Incident[]) ?? [];

  const vendorCols: Column<Vendor>[] = [
    { header: 'Vendor', accessor: (r) => r.system_vendor },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg Transit (s)', accessor: (r) => r.avg_transit },
    { header: 'Capsules Missing', accessor: (r) => r.total_missing },
    { header: 'Fail Count', accessor: (r) => r.fail_count },
  ];

  const worstCols: Column<WorstSite>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Missing', accessor: (r) => r.capsules_missing },
    { header: 'Diverter Fails', accessor: (r) => r.diverter_failures },
    { header: 'Status', accessor: (r) => r.status },
  ];

  const engCols: Column<Engineer>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Passes', accessor: (r) => r.passes },
    { header: 'Avg Blower kPa', accessor: (r) => r.avg_pressure },
  ];

  const outcomeCols: Column<Outcome>[] = [
    { header: 'Outcome', accessor: (r) => r.outcome },
    { header: 'Events', accessor: (r) => r.events },
    { header: 'Avg Transit (s)', accessor: (r) => r.avg_transit },
    { header: 'Critical', accessor: (r) => r.critical_count },
  ];

  const payloadCols: Column<Payload>[] = [
    { header: 'Payload', accessor: (r) => r.payload_type },
    { header: 'Events', accessor: (r) => r.events },
    { header: 'Delivered', accessor: (r) => r.delivered },
    { header: 'Lost / Damaged', accessor: (r) => r.lost_or_damaged },
    { header: 'Avg Transit (s)', accessor: (r) => r.avg_transit },
  ];

  const incidentCols: Column<Incident>[] = [
    { header: 'When', accessor: (r) => new Date(r.event_at).toLocaleString() },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Capsule', accessor: (r) => r.capsule_id },
    { header: 'Payload', accessor: (r) => r.payload_type },
    { header: 'Priority', accessor: (r) => r.priority },
    { header: 'Outcome', accessor: (r) => r.outcome },
    { header: 'Transit (s)', accessor: (r) => r.transit_seconds },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Pneumatic-Tube Capsule Audit (r2986)</h1>
        <p className="text-sm text-gray-600">Engineer monthly customer-site audit of hospital pneumatic-tube systems & capsule-tracking telemetry.</p>
      </header>

      {summary && (
        <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Total Audits</div><div className="text-xl font-semibold">{summary.total_audits}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Pass</div><div className="text-xl font-semibold text-green-700">{summary.passing}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Minor</div><div className="text-xl font-semibold text-yellow-700">{summary.minor}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Major</div><div className="text-xl font-semibold text-orange-700">{summary.major}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Fail</div><div className="text-xl font-semibold text-red-700">{summary.failing}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Followups</div><div className="text-xl font-semibold">{summary.followups}</div></div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Vendor Breakdown</h2>
        <DataTable rows={vendors} columns={vendorCols} emptyMessage="No vendor data" rowKey={(r, i) => String(r.system_vendor ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Worst-Performing Sites (status &gt;= major)</h2>
        <DataTable rows={worst} columns={worstCols} emptyMessage="No problem sites" rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Leaderboard</h2>
        <DataTable rows={engineers} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Capsule Outcome Breakdown</h2>
        <DataTable rows={outcomes} columns={outcomeCols} emptyMessage="No outcome data" rowKey={(r, i) => String(r.outcome ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Payload-Type Stats</h2>
        <DataTable rows={payloads} columns={payloadCols} emptyMessage="No payload data" rowKey={(r, i) => String(r.payload_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Capsule Incidents (stuck / lost / damaged / rerouted)</h2>
        <DataTable rows={incidents} columns={incidentCols} emptyMessage="No incidents" rowKey={(r, i) => String(r.capsule_id ?? i)} />
      </section>
    </div>
  );
}
