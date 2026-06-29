import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type Summary = { hospital_name: string; readings_total: number; breaches: number; criticals: number; warnings: number; compliant_pct: number | null };
type Critical = { hospital_name: string; fridge_label: string; temperature_celsius: number; door_lock_state: string; body_count: number; notes: string | null };
type OpenInc = { hospital_name: string; fridge_label: string; incident_kind: string; severity: string; engineer_name: string; opened_at: string };
type Eng = { engineer_name: string; readings_logged: number; breaches_seen: number; incidents_handled: number; incidents_open: number };
type Lock = { door_lock_state: string; fridge_count: number; avg_door_open_minutes: number | null };
type Mttr = { incident_kind: string; total_incidents: number; resolved_count: number; avg_resolution_minutes: number | null };
type Latest = { hospital_name: string; fridge_label: string; reading_taken_at: string; temperature_celsius: number; compliance_status: string; body_count: number };
type Sev = { severity: string; total: number; open_count: number; resolved_count: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [summary, critical, openInc, eng, lock, mttr, latest, sev] = await Promise.all([
    sb.rpc('r3044_monthly_compliance_summary'),
    sb.rpc('r3044_critical_fridges'),
    sb.rpc('r3044_open_incidents'),
    sb.rpc('r3044_engineer_scorecard'),
    sb.rpc('r3044_door_lock_breakdown'),
    sb.rpc('r3044_incident_mttr'),
    sb.rpc('r3044_latest_readings'),
    sb.rpc('r3044_severity_distribution'),
  ]);

  const summaryRows = (summary.data ?? []) as Summary[];
  const criticalRows = (critical.data ?? []) as Critical[];
  const openRows = (openInc.data ?? []) as OpenInc[];
  const engRows = (eng.data ?? []) as Eng[];
  const lockRows = (lock.data ?? []) as Lock[];
  const mttrRows = (mttr.data ?? []) as Mttr[];
  const latestRows = (latest.data ?? []) as Latest[];
  const sevRows = (sev.data ?? []) as Sev[];

  const summaryCols: Column<Summary>[] = [
    { header: 'Hospital', cell: (r) => r.hospital_name },
    { header: 'Readings', cell: (r) => r.readings_total },
    { header: 'Breaches', cell: (r) => r.breaches },
    { header: 'Criticals', cell: (r) => r.criticals },
    { header: 'Warnings', cell: (r) => r.warnings },
    { header: 'Compliant %', cell: (r) => r.compliant_pct ?? '-' },
  ];
  const criticalCols: Column<Critical>[] = [
    { header: 'Hospital', cell: (r) => r.hospital_name },
    { header: 'Fridge', cell: (r) => r.fridge_label },
    { header: 'Temp °C', cell: (r) => r.temperature_celsius },
    { header: 'Lock', cell: (r) => r.door_lock_state },
    { header: 'Bodies', cell: (r) => r.body_count },
    { header: 'Notes', cell: (r) => r.notes ?? '-' },
  ];
  const openCols: Column<OpenInc>[] = [
    { header: 'Hospital', cell: (r) => r.hospital_name },
    { header: 'Fridge', cell: (r) => r.fridge_label },
    { header: 'Kind', cell: (r) => r.incident_kind },
    { header: 'Severity', cell: (r) => r.severity },
    { header: 'Engineer', cell: (r) => r.engineer_name },
    { header: 'Opened', cell: (r) => new Date(r.opened_at).toLocaleString() },
  ];
  const engCols: Column<Eng>[] = [
    { header: 'Engineer', cell: (r) => r.engineer_name },
    { header: 'Readings', cell: (r) => r.readings_logged },
    { header: 'Breaches Seen', cell: (r) => r.breaches_seen },
    { header: 'Handled', cell: (r) => r.incidents_handled },
    { header: 'Open', cell: (r) => r.incidents_open },
  ];
  const lockCols: Column<Lock>[] = [
    { header: 'Lock State', cell: (r) => r.door_lock_state },
    { header: 'Fridges', cell: (r) => r.fridge_count },
    { header: 'Avg Door-Open Min', cell: (r) => r.avg_door_open_minutes ?? '-' },
  ];
  const mttrCols: Column<Mttr>[] = [
    { header: 'Incident Kind', cell: (r) => r.incident_kind },
    { header: 'Total', cell: (r) => r.total_incidents },
    { header: 'Resolved', cell: (r) => r.resolved_count },
    { header: 'Avg Mins', cell: (r) => r.avg_resolution_minutes ?? '-' },
  ];
  const latestCols: Column<Latest>[] = [
    { header: 'Hospital', cell: (r) => r.hospital_name },
    { header: 'Fridge', cell: (r) => r.fridge_label },
    { header: 'Taken', cell: (r) => new Date(r.reading_taken_at).toLocaleString() },
    { header: 'Temp', cell: (r) => r.temperature_celsius },
    { header: 'Status', cell: (r) => r.compliance_status },
    { header: 'Bodies', cell: (r) => r.body_count },
  ];
  const sevCols: Column<Sev>[] = [
    { header: 'Severity', cell: (r) => r.severity },
    { header: 'Total', cell: (r) => r.total },
    { header: 'Open', cell: (r) => r.open_count },
    { header: 'Resolved', cell: (r) => r.resolved_count },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Mortuary Fridge Temperature & Door-Lock Compliance</h1>
        <p style={{ color: '#666', fontSize: 13 }}>Round r3044 · Customer-monthly engineer-hospital cold-chain audit. Target band: -25°C to -15°C.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly compliance summary</h2>
        <DataTable rows={summaryRows} columns={summaryCols} emptyMessage="No readings logged" rowKey={(r, i) => String((r as Summary).hospital_name ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Critical fridges right now</h2>
        <DataTable rows={criticalRows} columns={criticalCols} emptyMessage="All fridges within band" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Open incidents</h2>
        <DataTable rows={openRows} columns={openCols} emptyMessage="No open incidents" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer scorecard</h2>
        <DataTable rows={engRows} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String((r as Eng).engineer_name ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Door-lock state breakdown</h2>
        <DataTable rows={lockRows} columns={lockCols} emptyMessage="No lock data" rowKey={(r, i) => String((r as Lock).door_lock_state ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Incident MTTR by kind</h2>
        <DataTable rows={mttrRows} columns={mttrCols} emptyMessage="No incidents" rowKey={(r, i) => String((r as Mttr).incident_kind ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Latest 15 readings</h2>
        <DataTable rows={latestRows} columns={latestCols} emptyMessage="No readings" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Severity distribution</h2>
        <DataTable rows={sevRows} columns={sevCols} emptyMessage="No incidents" rowKey={(r, i) => String((r as Sev).severity ?? i)} />
      </section>
    </div>
  );
}
