import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerCareerDevelopmentPlanPage() {
  const sb = await getSupabaseServerClient();

  const [plansRes, byTrackRes, recentMsRes] = await Promise.all([
    sb.rpc('list_career_plans_r1980'),
    sb.rpc('career_plans_by_track_r1980'),
    sb.rpc('recent_career_milestones_r1980'),
  ]);

  const plans: any[] = Array.isArray(plansRes.data) ? plansRes.data : [];
  const byTrack: any[] = Array.isArray(byTrackRes.data) ? byTrackRes.data : [];
  const recentMs: any[] = Array.isArray(recentMsRes.data) ? recentMsRes.data : [];

  const plansCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? r.engineer_user_id ?? '') },
    { key: 'career_track', header: 'Track', render: (r: any) => String(r.career_track ?? '') },
    { key: 'target_role', header: 'Target Role', render: (r: any) => String(r.target_role ?? '') },
    { key: 'target_completion_date', header: 'Target Date', render: (r: any) => r.target_completion_date ? String(r.target_completion_date) : '—' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'started_at', header: 'Started', render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleDateString() : '—' },
  ];

  const trackCols: Column<any>[] = [
    { key: 'career_track', header: 'Track', render: (r: any) => String(r.career_track ?? '') },
    { key: 'total', header: 'Total Plans', render: (r: any) => String(r.total ?? 0) },
    { key: 'active_count', header: 'Active', render: (r: any) => String(r.active_count ?? 0) },
    { key: 'completed_count', header: 'Completed', render: (r: any) => String(r.completed_count ?? 0) },
  ];

  const msCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'career_track', header: 'Track', render: (r: any) => String(r.career_track ?? '') },
    { key: 'milestone_type', header: 'Milestone', render: (r: any) => String(r.milestone_type ?? '') },
    { key: 'milestone_at', header: 'When', render: (r: any) => r.milestone_at ? new Date(r.milestone_at).toLocaleString() : '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 120) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Career Development Plan</h1>
        <p className="text-sm text-gray-600">
          Per-engineer career tracks with target roles and milestone progress.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Plans by Track</h2>
        <DataTable rows={byTrack} columns={trackCols} rowKey={(r: any, i: number) => String(r.career_track ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Plans (up to 200)</h2>
        <DataTable rows={plans} columns={plansCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Milestones</h2>
        <DataTable rows={recentMs} columns={msCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
