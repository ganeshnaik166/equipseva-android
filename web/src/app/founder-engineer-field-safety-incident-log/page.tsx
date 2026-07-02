import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerFieldSafetyIncidentLogPage() {
  const supabase = await getSupabaseServerClient();

  const [incidentsRes, breakdownRes, rcaQueueRes] = await Promise.all([
    supabase.rpc('list_incidents_r2338'),
    supabase.rpc('incident_type_breakdown_r2338'),
    supabase.rpc('open_rca_queue_r2338'),
  ]);

  const incidents = (incidentsRes.data ?? []) as any[];
  const breakdown = (breakdownRes.data ?? []) as any[];
  const rcaQueue = (rcaQueueRes.data ?? []) as any[];

  const incidentCols: Column<any>[] = [
    { key: 'occurred_at', header: 'When', render: (r) => r.occurred_at ? new Date(r.occurred_at).toLocaleString() : '-' },
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email ?? r.engineer_id?.slice(0, 8) },
    { key: 'incident_type', header: 'Type', render: (r) => String(r.incident_type ?? '').replace(/_/g, ' ') },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'site_location', header: 'Site', render: (r) => r.site_location || '-' },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'mitigation_count', header: 'Mitigations', render: (r) => `${r.applied_mitigation_count ?? 0} / ${r.mitigation_count ?? 0}` },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'incident_type', header: 'Type', render: (r) => String(r.incident_type ?? '').replace(/_/g, ' ') },
    { key: 'total_count', header: 'Total', render: (r) => r.total_count },
    { key: 'open_count', header: 'Open', render: (r) => r.open_count },
    { key: 'closed_count', header: 'Closed', render: (r) => r.closed_count },
    { key: 'serious_or_critical_count', header: 'Serious/Critical', render: (r) => r.serious_or_critical_count },
    { key: 'last_occurred', header: 'Last seen', render: (r) => r.last_occurred ? new Date(r.last_occurred).toLocaleDateString() : '-' },
  ];

  const rcaCols: Column<any>[] = [
    { key: 'occurred_at', header: 'When', render: (r) => r.occurred_at ? new Date(r.occurred_at).toLocaleString() : '-' },
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email ?? r.engineer_id?.slice(0, 8) },
    { key: 'incident_type', header: 'Type', render: (r) => String(r.incident_type ?? '').replace(/_/g, ' ') },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'days_open', header: 'Days open', render: (r) => r.days_open },
    { key: 'pending_mitigations', header: 'Pending mitig.', render: (r) => r.pending_mitigations },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 600 }}>Engineer field-safety incident log</h1>
        <p style={{ opacity: 0.7, marginTop: 4 }}>
          Slip/trip/fall, electric shock, biohazard & other field incidents — RCA progress and mitigations applied.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Open RCA queue (priority &gt;= serious first)</h2>
        <DataTable
          rows={rcaQueue}
          emptyMessage="No open incidents — all RCAs closed."
          rowKey={(r) => r.id}
          columns={rcaCols}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Incident-type breakdown</h2>
        <DataTable
          rows={breakdown}
          emptyMessage="No incidents logged yet."
          rowKey={(r) => r.incident_type}
          columns={breakdownCols}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All incidents</h2>
        <DataTable
          rows={incidents}
          emptyMessage="No incidents have been logged."
          rowKey={(r) => r.id}
          columns={incidentCols}
        />
      </section>
    </main>
  );
}
