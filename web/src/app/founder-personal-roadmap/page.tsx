import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderPersonalRoadmapPage() {
  const sb = await getSupabaseServerClient();
  const currentYear = new Date().getFullYear();

  const [roadmapRes, summaryRes, topRes] = await Promise.all([
    sb.rpc('list_roadmap_r1798', { p_year: currentYear }),
    sb.rpc('year_summary_r1798', { p_year: currentYear }),
    sb.rpc('top_priority_items_r1798'),
  ]);

  const roadmap: any[] = Array.isArray(roadmapRes.data) ? roadmapRes.data : [];
  const summary: any[] = Array.isArray(summaryRes.data) ? summaryRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];

  const roadmapCols: Column<any>[] = [
    { key: 'focus_area', header: 'Focus', render: (r: any) => String(r.focus_area ?? '') },
    { key: 'goal_title', header: 'Goal', render: (r: any) => String(r.goal_title ?? '') },
    { key: 'priority', header: 'Priority', render: (r: any) => String(r.priority ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'deadline', header: 'Deadline', render: (r: any) => r.deadline ? String(r.deadline) : '—' },
    { key: 'target_state_md', header: 'Target', render: (r: any) => String(r.target_state_md ?? '—').slice(0, 120) },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'focus_area', header: 'Focus', render: (r: any) => String(r.focus_area ?? '') },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total ?? 0) },
    { key: 'achieved', header: 'Achieved', render: (r: any) => String(r.achieved ?? 0) },
    { key: 'active', header: 'Active', render: (r: any) => String(r.active ?? 0) },
    { key: 'missed', header: 'Missed', render: (r: any) => String(r.missed ?? 0) },
    { key: 'dropped', header: 'Dropped', render: (r: any) => String(r.dropped ?? 0) },
  ];

  const topCols: Column<any>[] = [
    { key: 'focus_area', header: 'Focus', render: (r: any) => String(r.focus_area ?? '') },
    { key: 'goal_title', header: 'Goal', render: (r: any) => String(r.goal_title ?? '') },
    { key: 'priority', header: 'Priority', render: (r: any) => String(r.priority ?? '') },
    { key: 'deadline', header: 'Deadline', render: (r: any) => r.deadline ? String(r.deadline) : '—' },
    { key: 'days_to_deadline', header: 'Days Left', render: (r: any) => r.days_to_deadline == null ? '—' : String(r.days_to_deadline) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Founder Personal Roadmap</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Personal-development goals across leadership, health, learning, family, finance & spiritual focus areas.
        Founder-only view (r1798) — build self while building company.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          {currentYear} goals ({roadmap.length})
        </h2>
        <DataTable rows={roadmap} columns={roadmapCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          {currentYear} summary by focus area
        </h2>
        <DataTable rows={summary} columns={summaryCols} rowKey={(r: any, i: number) => String(r.focus_area ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Top priority items (active & critical/important)
        </h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
