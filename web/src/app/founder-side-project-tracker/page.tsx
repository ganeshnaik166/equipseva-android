import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Project = {
  id: string;
  name: string;
  description_md: string | null;
  started_on: string;
  status: string;
  weekly_hours_estimate: number;
  lesson_md: string | null;
  killed_on: string | null;
  milestone_count: number;
  hit_count: number;
  created_at: string;
};

type Milestone = {
  id: string;
  project_id: string;
  milestone_text: string;
  hit_on: string | null;
  status: string;
  created_at: string;
};

type Summary = {
  total_projects: number;
  active_projects: number;
  paused_projects: number;
  shipped_projects: number;
  killed_projects: number;
  total_weekly_hours: number;
  total_milestones: number;
  hit_milestones: number;
  missed_milestones: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [projectsRes, milestonesRes, summaryRes] = await Promise.all([
    sb.rpc('list_side_projects_r1702'),
    sb.rpc('list_side_project_milestones_r1702', { p_project_id: null }),
    sb.rpc('side_project_summary_r1702'),
  ]);

  const projects: Project[] = (projectsRes.data ?? []) as Project[];
  const milestones: Milestone[] = (milestonesRes.data ?? []) as Milestone[];
  const summaryRow: Summary | null = Array.isArray(summaryRes.data)
    ? ((summaryRes.data[0] ?? null) as Summary | null)
    : ((summaryRes.data ?? null) as Summary | null);

  const projectColumns: Column<Project>[] = [
    { key: 'name', header: 'Project', render: (r: any) => <span className="font-medium">{r.name}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="uppercase text-xs">{r.status}</span> },
    { key: 'started_on', header: 'Started', render: (r: any) => <span>{r.started_on}</span> },
    { key: 'weekly_hours_estimate', header: 'Hrs/wk', render: (r: any) => <span>{r.weekly_hours_estimate}</span> },
    {
      key: 'milestones',
      header: 'Milestones',
      render: (r: any) => (
        <span>
          {r.hit_count}/{r.milestone_count} hit
        </span>
      ),
    },
    {
      key: 'killed_on',
      header: 'Killed',
      render: (r: any) => <span>{r.killed_on ?? '-'}</span>,
    },
    {
      key: 'lesson_md',
      header: 'Lesson',
      render: (r: any) => (
        <span className="text-xs text-gray-600">
          {r.lesson_md ? (r.lesson_md.length > 80 ? r.lesson_md.slice(0, 80) + '...' : r.lesson_md) : '-'}
        </span>
      ),
    },
  ];

  const milestoneColumns: Column<Milestone>[] = [
    { key: 'milestone_text', header: 'Milestone', render: (r: any) => <span>{r.milestone_text}</span> },
    {
      key: 'project_id',
      header: 'Project',
      render: (r: any) => {
        const p = projects.find((pp) => pp.id === r.project_id);
        return <span className="text-xs">{p ? p.name : r.project_id.slice(0, 8)}</span>;
      },
    },
    { key: 'status', header: 'Status', render: (r: any) => <span className="uppercase text-xs">{r.status}</span> },
    { key: 'hit_on', header: 'Hit on', render: (r: any) => <span>{r.hit_on ?? '-'}</span> },
    {
      key: 'created_at',
      header: 'Added',
      render: (r: any) => <span className="text-xs">{new Date(r.created_at).toLocaleDateString()}</span>,
    },
  ];

  return (
    <main className="p-6 max-w-7xl mx-auto space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Side-Project Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Skunkworks experiments running alongside the main company. Track active bets, paused ideas, shipped wins and
          killed projects (with lessons captured).
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Summary</h2>
        {summaryRow ? (
          <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Total</div>
              <div className="text-2xl font-bold">{summaryRow.total_projects}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Active</div>
              <div className="text-2xl font-bold text-green-700">{summaryRow.active_projects}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Paused</div>
              <div className="text-2xl font-bold text-yellow-700">{summaryRow.paused_projects}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Shipped</div>
              <div className="text-2xl font-bold text-blue-700">{summaryRow.shipped_projects}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Killed</div>
              <div className="text-2xl font-bold text-red-700">{summaryRow.killed_projects}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Hrs/week committed</div>
              <div className="text-2xl font-bold">{summaryRow.total_weekly_hours}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Milestones</div>
              <div className="text-2xl font-bold">{summaryRow.total_milestones}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Hit</div>
              <div className="text-2xl font-bold text-green-700">{summaryRow.hit_milestones}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Missed</div>
              <div className="text-2xl font-bold text-red-700">{summaryRow.missed_milestones}</div>
            </div>
          </div>
        ) : (
          <p className="text-sm text-gray-500">No summary data.</p>
        )}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Projects ({projects.length})</h2>
        <DataTable
          rows={projects}
          columns={projectColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Milestones ({milestones.length})</h2>
        <DataTable
          rows={milestones}
          columns={milestoneColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="text-xs text-gray-500 border-t pt-4">
        <p>
          Rule of thumb: cap weekly hours committed to side projects at &lt;= 8 hrs/week total. If hit rate drops below
          50%, kill or pause something. Capture lessons on every kill so the next bet is sharper.
        </p>
      </section>
    </main>
  );
}
