import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [drillsRes, passRateRes, criticalRes] = await Promise.all([
    sb.rpc('list_field_safety_drills_r1876'),
    sb.rpc('field_safety_drill_pass_rate_r1876'),
    sb.rpc('recent_critical_field_safety_observations_r1876'),
  ]);

  const drills: any[] = Array.isArray(drillsRes.data) ? drillsRes.data : [];
  const passRates: any[] = Array.isArray(passRateRes.data) ? passRateRes.data : [];
  const criticals: any[] = Array.isArray(criticalRes.data) ? criticalRes.data : [];

  const drillCols: Column<any>[] = [
    { key: 'drill_date', header: 'Date', render: (r: any) => String(r.drill_date ?? '') },
    { key: 'drill_type', header: 'Type', render: (r: any) => String(r.drill_type ?? '') },
    { key: 'drill_location', header: 'Location', render: (r: any) => String(r.drill_location ?? '') },
    { key: 'attendee_count', header: 'Attendees', render: (r: any) => String(r.attendee_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'passed', header: 'Passed', render: (r: any) => (r.passed ? 'Yes' : 'No') },
    { key: 'conducted_by_email', header: 'Conducted by', render: (r: any) => String(r.conducted_by_email ?? '') },
  ];

  const passCols: Column<any>[] = [
    { key: 'drill_type', header: 'Drill type', render: (r: any) => String(r.drill_type ?? '') },
    { key: 'total_conducted', header: 'Conducted', render: (r: any) => String(r.total_conducted ?? 0) },
    { key: 'total_passed', header: 'Passed', render: (r: any) => String(r.total_passed ?? 0) },
    { key: 'pass_rate_pct', header: 'Pass rate %', render: (r: any) => (r.pass_rate_pct == null ? '—' : String(r.pass_rate_pct)) },
  ];

  const critCols: Column<any>[] = [
    { key: 'created_at', header: 'Logged', render: (r: any) => (r.created_at ? new Date(r.created_at).toLocaleString() : '') },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '') },
    { key: 'drill_type', header: 'Drill', render: (r: any) => String(r.drill_type ?? '') },
    { key: 'drill_location', header: 'Location', render: (r: any) => String(r.drill_location ?? '') },
    { key: 'observation_text', header: 'Observation', render: (r: any) => String(r.observation_text ?? '') },
    { key: 'action_required', header: 'Action required', render: (r: any) => String(r.action_required ?? '') },
    { key: 'action_owner_email', header: 'Owner', render: (r: any) => String(r.action_owner_email ?? '') },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer Field Safety Drill Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track field safety drills (electrical, biohazard, fire, equipment-fall, lifting),
        attendance, pass status, and critical observations from the last 90 days.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Pass rate by drill type
        </h2>
        <DataTable
          rows={passRates}
          columns={passCols}
          rowKey={(r: any, i: number) => String(r.drill_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent critical & serious observations (last 90 days)
        </h2>
        <DataTable
          rows={criticals}
          columns={critCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          All drills (latest 200)
        </h2>
        <DataTable
          rows={drills}
          columns={drillCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
