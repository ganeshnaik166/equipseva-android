import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Idea = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  idea_label: string | null;
  idea_category: string | null;
  status: string | null;
  captured_at: string | null;
};

type AdoptedIdea = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  idea_label: string | null;
  idea_category: string | null;
  captured_at: string | null;
};

type RecentAction = {
  id: string;
  idea_id: string | null;
  idea_label: string | null;
  action_type: string | null;
  taken_at: string | null;
  by_email: string | null;
};

export default async function FounderEngineerInnovationIdeationPage() {
  const sb = await getSupabaseServerClient();

  const ideasRes = await sb.rpc('list_innovation_ideas_r2056');
  const adoptedRes = await sb.rpc('adopted_innovation_ideas_r2056');
  const recentRes = await sb.rpc('recent_innovation_actions_r2056');

  const ideas: Idea[] = (ideasRes.data as Idea[] | null) ?? [];
  const adopted: AdoptedIdea[] = (adoptedRes.data as AdoptedIdea[] | null) ?? [];
  const recent: RecentAction[] = (recentRes.data as RecentAction[] | null) ?? [];

  const totalIdeas = ideas.length;
  const submittedCount = ideas.filter((i) => i.status === 'submitted').length;
  const underReviewCount = ideas.filter((i) => i.status === 'under_review').length;
  const adoptedCount = ideas.filter((i) => i.status === 'adopted').length;
  const declinedCount = ideas.filter((i) => i.status === 'declined').length;

  const ideaColumns: Column<Idea>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id ?? '—' },
    { key: 'idea_label', header: 'Idea', render: (r: any) => r.idea_label ?? '—' },
    { key: 'idea_category', header: 'Category', render: (r: any) => (r.idea_category ?? '—').replaceAll('_', ' ') },
    { key: 'status', header: 'Status', render: (r: any) => (r.status ?? '—').replaceAll('_', ' ') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '—') },
  ];

  const adoptedColumns: Column<AdoptedIdea>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id ?? '—' },
    { key: 'idea_label', header: 'Adopted Idea', render: (r: any) => r.idea_label ?? '—' },
    { key: 'idea_category', header: 'Category', render: (r: any) => (r.idea_category ?? '—').replaceAll('_', ' ') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '—') },
  ];

  const recentColumns: Column<RecentAction>[] = [
    { key: 'idea_label', header: 'Idea', render: (r: any) => r.idea_label ?? r.idea_id ?? '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => (r.action_type ?? '—').replaceAll('_', ' ') },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => (r.taken_at ? new Date(r.taken_at).toLocaleString() : '—') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Engineer Innovation Ideation</h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Capture engineer ideas across process, tools, safety, customer experience and cost.
          Track review, adoption and rewards from a single founder console.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Ideation Pulse</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Ideas</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalIdeas}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Submitted</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{submittedCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Under Review</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{underReviewCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Adopted</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{adoptedCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Declined</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{declinedCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Ideas (latest 200)</h2>
        <DataTable<Idea>
          rows={ideas}
          columns={ideaColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Adopted Ideas</h2>
        <DataTable<AdoptedIdea>
          rows={adopted}
          columns={adoptedColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable<RecentAction>
          rows={recent}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
