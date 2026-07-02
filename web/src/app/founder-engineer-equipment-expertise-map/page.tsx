import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Expertise = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  equipment_category: string;
  expertise_level: number;
  years_of_experience: number;
  certifications_count: number;
  last_repair_at: string | null;
  last_updated_at: string;
  open_gaps: number;
};

type GapAction = {
  id: string;
  expertise_id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  equipment_category: string;
  expertise_level: number;
  gap_description: string;
  action_type: string;
  target_date: string | null;
  status: string;
  created_at: string;
};

type TopExpert = {
  equipment_category: string;
  engineer_user_id: string;
  engineer_email: string | null;
  expertise_level: number;
  years_of_experience: number;
  certifications_count: number;
  last_repair_at: string | null;
};

type Gap = {
  equipment_category: string;
  engineer_count: number;
  max_level: number;
  avg_level: number;
  experts_count: number;
  open_gap_actions: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [expertiseRes, gapActionsRes, topExpertsRes, gapsRes] = await Promise.all([
    sb.rpc('list_expertise_r1740'),
    sb.rpc('list_gap_actions_r1740'),
    sb.rpc('top_experts_per_category_r1740'),
    sb.rpc('expertise_gaps_r1740'),
  ]);

  const expertise: Expertise[] = (expertiseRes.data ?? []) as Expertise[];
  const gapActions: GapAction[] = (gapActionsRes.data ?? []) as GapAction[];
  const topExperts: TopExpert[] = (topExpertsRes.data ?? []) as TopExpert[];
  const gaps: Gap[] = (gapsRes.data ?? []) as Gap[];

  const totalEntries = expertise.length;
  const expertCount = expertise.filter((e) => e.expertise_level >= 8).length;
  const openActions = gapActions.filter((g) => g.status !== 'closed').length;
  const categories = new Set(expertise.map((e) => e.equipment_category)).size;

  const expertiseCols: Column<Expertise>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? String(r.engineer_user_id).slice(0, 8) },
    { key: 'category', header: 'Equipment category', render: (r: any) => r.equipment_category },
    { key: 'level', header: 'Level (1-10)', render: (r: any) => String(r.expertise_level) },
    { key: 'years', header: 'Years exp', render: (r: any) => String(r.years_of_experience) },
    { key: 'certs', header: 'Certifications', render: (r: any) => String(r.certifications_count) },
    { key: 'last_repair', header: 'Last repair', render: (r: any) => (r.last_repair_at ? new Date(r.last_repair_at).toLocaleDateString() : '—') },
    { key: 'updated', header: 'Updated', render: (r: any) => new Date(r.last_updated_at).toLocaleDateString() },
    { key: 'gaps', header: 'Open gaps', render: (r: any) => String(r.open_gaps) },
  ];

  const gapActionCols: Column<GapAction>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? String(r.engineer_user_id).slice(0, 8) },
    { key: 'category', header: 'Category', render: (r: any) => r.equipment_category },
    { key: 'level', header: 'Level', render: (r: any) => String(r.expertise_level) },
    { key: 'gap', header: 'Gap description', render: (r: any) => r.gap_description },
    { key: 'action', header: 'Action', render: (r: any) => r.action_type },
    { key: 'target', header: 'Target', render: (r: any) => (r.target_date ? new Date(r.target_date).toLocaleDateString() : '—') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'created', header: 'Created', render: (r: any) => new Date(r.created_at).toLocaleDateString() },
  ];

  const topExpertCols: Column<TopExpert>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.equipment_category },
    { key: 'engineer', header: 'Top engineer', render: (r: any) => r.engineer_email ?? String(r.engineer_user_id).slice(0, 8) },
    { key: 'level', header: 'Level', render: (r: any) => String(r.expertise_level) },
    { key: 'years', header: 'Years exp', render: (r: any) => String(r.years_of_experience) },
    { key: 'certs', header: 'Certifications', render: (r: any) => String(r.certifications_count) },
    { key: 'last_repair', header: 'Last repair', render: (r: any) => (r.last_repair_at ? new Date(r.last_repair_at).toLocaleDateString() : '—') },
  ];

  const gapCols: Column<Gap>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.equipment_category },
    { key: 'engineers', header: 'Engineers', render: (r: any) => String(r.engineer_count) },
    { key: 'max', header: 'Max level', render: (r: any) => String(r.max_level) },
    { key: 'avg', header: 'Avg level', render: (r: any) => Number(r.avg_level).toFixed(2) },
    { key: 'experts', header: 'Experts (level >= 8)', render: (r: any) => String(r.experts_count) },
    { key: 'open_actions', header: 'Open actions', render: (r: any) => String(r.open_gap_actions) },
  ];

  return (
    <div style={{ maxWidth: 1280, margin: '0 auto', padding: 24 }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Engineer Equipment Expertise Map</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Per-engineer × equipment expertise matrix. Identify gaps where no engineer scores &gt;= 8 and log training, shadowing, or hiring actions.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total entries</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalEntries}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Categories covered</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{categories}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Experts (level &gt;= 8)</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{expertCount}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Open gap actions</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{openActions}</div>
        </div>
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Expertise matrix</h2>
        <DataTable rows={expertise} columns={expertiseCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Category coverage gaps</h2>
        <p style={{ color: '#666', fontSize: 14, marginBottom: 12 }}>
          Categories sorted by fewest experts (level &gt;= 8) first. Low expert count &amp; low avg level = highest hire/train priority.
        </p>
        <DataTable rows={gaps} columns={gapCols} rowKey={(r: any, i: number) => String(r.equipment_category ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top experts per category</h2>
        <DataTable rows={topExperts} columns={topExpertCols} rowKey={(r: any, i: number) => `${r.equipment_category}-${r.engineer_user_id}-${i}`} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Gap actions</h2>
        <DataTable rows={gapActions} columns={gapActionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
