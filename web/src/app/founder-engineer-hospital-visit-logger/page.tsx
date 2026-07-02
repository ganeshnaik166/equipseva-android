import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerHospitalVisitLoggerPage() {
  const sb = await getSupabaseServerClient();

  const [visitsRes, topRes, actionsRes] = await Promise.all([
    sb.rpc('list_visits_r2016', { p_limit: 200 }),
    sb.rpc('top_visited_hospitals_r2016', { p_limit: 20 }),
    sb.rpc('recent_actions_r2016', { p_limit: 50 }),
  ]);

  const visits = (visitsRes.data ?? []) as any[];
  const top = (topRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];

  const totalVisits = visits.length;
  const completed = visits.filter((v) => v.status === 'completed').length;
  const cancelled = visits.filter((v) => v.status === 'cancelled').length;
  const noShow = visits.filter((v) => v.status === 'no_show').length;
  const totalMinutes = visits.reduce((s, v) => s + (Number(v.visit_duration_minutes) || 0), 0);

  const visitCols: Column<any>[] = [
    { key: 'visit_date', header: 'Date', render: (r: any) => String(r.visit_date ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'visit_purpose', header: 'Purpose', render: (r: any) => String(r.visit_purpose ?? '') },
    { key: 'visit_duration_minutes', header: 'Minutes', render: (r: any) => String(r.visit_duration_minutes ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'outcome_md', header: 'Outcome', render: (r: any) => String(r.outcome_md ?? '').slice(0, 80) },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'visit_count', header: 'Visits', render: (r: any) => String(r.visit_count ?? 0) },
    { key: 'total_minutes', header: 'Total minutes', render: (r: any) => String(r.total_minutes ?? 0) },
    { key: 'last_visit_date', header: 'Last visit', render: (r: any) => String(r.last_visit_date ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken at', render: (r: any) => String(r.taken_at ?? '') },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer Hospital Visit Logger
      </h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Round 2016 — log every engineer visit to hospital with purpose, duration and outcome.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12, marginBottom: 24 }}>
        <Stat label="Total visits" value={String(totalVisits)} />
        <Stat label="Completed" value={String(completed)} />
        <Stat label="Cancelled" value={String(cancelled)} />
        <Stat label="No show" value={String(noShow)} />
        <Stat label="Total minutes" value={String(totalMinutes)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent visits</h2>
        <DataTable
          rows={visits}
          columns={visitCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top visited hospitals</h2>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.hospital_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
