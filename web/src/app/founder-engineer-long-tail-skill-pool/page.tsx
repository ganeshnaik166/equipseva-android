import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerLongTailSkillPoolPage() {
  const sb = await getSupabaseServerClient();

  const [skillsRes, demandRes, highValueRes, fadingRes, summaryRes] = await Promise.all([
    sb.rpc('list_long_tail_skills_r1844'),
    sb.rpc('list_skill_demand_r1844', { p_skill_id: null }),
    sb.rpc('high_value_skills_r1844'),
    sb.rpc('fading_skills_r1844'),
    sb.rpc('skill_demand_summary_r1844'),
  ]);

  const skills: any[] = skillsRes.data ?? [];
  const demand: any[] = demandRes.data ?? [];
  const highValue: any[] = highValueRes.data ?? [];
  const fading: any[] = fadingRes.data ?? [];
  const summary: any = (summaryRes.data ?? [])[0] ?? {};

  const skillCols: Column<any>[] = [
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name ?? '' },
    { key: 'skill_category', header: 'Category', render: (r: any) => r.skill_category ?? '' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '' },
    { key: 'mastery_level', header: 'Mastery (1-5)', render: (r: any) => String(r.mastery_level ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'acquired_at', header: 'Acquired', render: (r: any) => r.acquired_at ? new Date(r.acquired_at).toLocaleDateString() : '' },
  ];

  const demandCols: Column<any>[] = [
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name ?? '' },
    { key: 'demand_source', header: 'Source', render: (r: any) => r.demand_source ?? '' },
    { key: 'value_realized_md', header: 'Value (md)', render: (r: any) => Number(r.value_realized_md ?? 0).toFixed(2) },
    { key: 'demand_event_at', header: 'Event At', render: (r: any) => r.demand_event_at ? new Date(r.demand_event_at).toLocaleString() : '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const highValueCols: Column<any>[] = [
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name ?? '' },
    { key: 'skill_category', header: 'Category', render: (r: any) => r.skill_category ?? '' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '' },
    { key: 'mastery_level', header: 'Mastery', render: (r: any) => String(r.mastery_level ?? '') },
    { key: 'total_value_md', header: 'Total Value (md)', render: (r: any) => Number(r.total_value_md ?? 0).toFixed(2) },
    { key: 'demand_events', header: 'Events', render: (r: any) => String(r.demand_events ?? 0) },
  ];

  const fadingCols: Column<any>[] = [
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name ?? '' },
    { key: 'skill_category', header: 'Category', render: (r: any) => r.skill_category ?? '' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'last_demand_at', header: 'Last Demand', render: (r: any) => r.last_demand_at ? new Date(r.last_demand_at).toLocaleDateString() : 'never' },
    { key: 'days_since_demand', header: 'Days Since', render: (r: any) => r.days_since_demand == null ? '—' : String(r.days_since_demand) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Long-Tail Skill Pool</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Rare engineer skills: legacy gear, vendor-specific calibration, regulatory, language & region.
      </p>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
          <Stat label="Total Skills" value={String(summary.total_skills ?? 0)} />
          <Stat label="Active" value={String(summary.active_skills ?? 0)} />
          <Stat label="Aging" value={String(summary.aging_skills ?? 0)} />
          <Stat label="Lost" value={String(summary.lost_skills ?? 0)} />
          <Stat label="Demand Events" value={String(summary.total_demand_events ?? 0)} />
          <Stat label="Total Value (md)" value={Number(summary.total_value_md ?? 0).toFixed(2)} />
          <Stat label="Unique Engineers" value={String(summary.unique_engineers ?? 0)} />
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Long-Tail Skills</h2>
        <DataTable rows={skills} columns={skillCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>High-Value Skills</h2>
        <DataTable rows={highValue} columns={highValueCols} rowKey={(r: any, i: number) => String(r.skill_id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Fading Skills (aging / lost / no demand &gt; 180 days)</h2>
        <DataTable rows={fading} columns={fadingCols} rowKey={(r: any, i: number) => String(r.skill_id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Demand Signals</h2>
        <DataTable rows={demand} columns={demandCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#6b7280' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
