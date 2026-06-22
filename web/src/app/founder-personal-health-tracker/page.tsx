import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderPersonalHealthTrackerPage() {
  const sb = await getSupabaseServerClient();
  const [healthRes, intervRes, currentRes, recentRes] = await Promise.all([
    sb.rpc('list_health_r2038'),
    sb.rpc('list_interventions_r2038'),
    sb.rpc('current_health_r2038'),
    sb.rpc('recent_interventions_r2038'),
  ]);

  const health = (healthRes.data as any[]) ?? [];
  const interventions = (intervRes.data as any[]) ?? [];
  const current = (currentRes.data as any[]) ?? [];
  const recent = (recentRes.data as any[]) ?? [];

  const healthCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'sleep_hours_avg', header: 'Sleep hrs', render: (r: any) => String(r.sleep_hours_avg ?? 0) },
    { key: 'exercise_sessions_count', header: 'Exercise', render: (r: any) => String(r.exercise_sessions_count ?? 0) },
    { key: 'stress_score', header: 'Stress', render: (r: any) => String(r.stress_score ?? 0) },
    { key: 'energy_score', header: 'Energy', render: (r: any) => String(r.energy_score ?? 0) },
    { key: 'mood_score', header: 'Mood', render: (r: any) => String(r.mood_score ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const intervCols: Column<any>[] = [
    { key: 'intervention_type', header: 'Intervention', render: (r: any) => String(r.intervention_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Personal Health Tracker</h1>
        <p className="text-sm text-gray-600">Sleep, exercise, stress, energy and mood tracking with intervention log.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Current snapshot</h2>
        <DataTable rows={current} columns={healthCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent interventions (30 days)</h2>
        <DataTable rows={recent} columns={intervCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All health periods</h2>
        <DataTable rows={health} columns={healthCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All interventions</h2>
        <DataTable rows={interventions} columns={intervCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
