import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_pairings: number;
  total_hours: number;
  avg_skill_jump: number;
  avg_csat_mentee: number;
  extend_count: number;
  reassign_count: number;
  terminate_count: number;
};

type Pairing = {
  id: string;
  pairing_month: string;
  mentor_name: string;
  mentor_tier: string;
  mentee_name: string;
  mentee_tier_before: string;
  mentee_tier_after: string;
  hours_spent: number;
  skill_jump: number;
  csat_mentee: number;
  pairing_verdict: string;
};

type Mentor = {
  mentor_name: string;
  mentor_tier: string;
  mentee_count: number;
  total_hours: number;
  avg_skill_jump: number;
  avg_csat_mentee: number;
};

type ActionRow = {
  mentor_name: string;
  mentee_name: string;
  hours_spent: number;
  skill_jump: number;
  csat_mentee: number;
  pairing_verdict: string;
  founder_notes: string | null;
};

type SkillRow = {
  skill_area: string;
  pair_count: number;
  avg_before: number;
  avg_after: number;
  avg_jump: number;
  signoff_rate: number;
};

type TierRow = {
  movement: string;
  pair_count: number;
  avg_hours: number;
  avg_csat: number;
};

type EffectivenessRow = {
  mentor_name: string;
  mentee_name: string;
  skill_jump: number;
  csat_avg: number;
  jobs_total: number;
  effectiveness_score: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, pairingsRes, mentorsRes, actionRes, skillRes, tierRes, effRes] = await Promise.all([
    supabase.rpc('founder_r2730_pairing_overview'),
    supabase.rpc('founder_r2730_list_pairings'),
    supabase.rpc('founder_r2730_top_mentors'),
    supabase.rpc('founder_r2730_action_required'),
    supabase.rpc('founder_r2730_skill_breakdown'),
    supabase.rpc('founder_r2730_tier_progression'),
    supabase.rpc('founder_r2730_effectiveness_score'),
  ]);

  const overview: Overview = (overviewRes.data?.[0] as Overview) ?? {
    total_pairings: 0,
    total_hours: 0,
    avg_skill_jump: 0,
    avg_csat_mentee: 0,
    extend_count: 0,
    reassign_count: 0,
    terminate_count: 0,
  };
  const pairings: Pairing[] = (pairingsRes.data as Pairing[]) ?? [];
  const mentors: Mentor[] = (mentorsRes.data as Mentor[]) ?? [];
  const actions: ActionRow[] = (actionRes.data as ActionRow[]) ?? [];
  const skills: SkillRow[] = (skillRes.data as SkillRow[]) ?? [];
  const tiers: TierRow[] = (tierRes.data as TierRow[]) ?? [];
  const effectiveness: EffectivenessRow[] = (effRes.data as EffectivenessRow[]) ?? [];

  const kpis = [
    { label: 'Total Pairings', value: String(overview.total_pairings) },
    { label: 'Total Hours', value: Number(overview.total_hours).toFixed(1) },
    { label: 'Avg Skill Jump', value: Number(overview.avg_skill_jump).toFixed(2) },
    { label: 'Avg Mentee CSAT', value: Number(overview.avg_csat_mentee).toFixed(2) },
    { label: 'Extend', value: String(overview.extend_count) },
    { label: 'Reassign', value: String(overview.reassign_count) },
    { label: 'Terminate', value: String(overview.terminate_count) },
  ];

  return (
    <main style={{ padding: '24px', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '24px', fontWeight: 700, margin: 0 }}>
          Engineer Monthly Mentee Pairing Effectiveness
        </h1>
        <p style={{ color: '#555', marginTop: '6px' }}>
          Mentor x mentee x hours x skill jump x CSAT x pairing verdict. Founder picks which pairs
          to extend, reassign, or terminate every month.
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))',
          gap: '12px',
          marginBottom: '28px',
        }}
      >
        {kpis.map((k) => (
          <div
            key={k.label}
            style={{
              border: '1px solid #e5e7eb',
              borderRadius: '8px',
              padding: '12px 14px',
              background: '#fff',
            }}
          >
            <div style={{ fontSize: '12px', color: '#6b7280' }}>{k.label}</div>
            <div style={{ fontSize: '20px', fontWeight: 700, marginTop: '4px' }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>All Pairings</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '10px' }}>
          Sorted by skill jump (highest first). Skill jump &gt;= 1.5 is a strong pair.
        </p>
        <DataTable
          rows={pairings}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'pairing_month', header: 'Month', render: (r: Pairing) => r.pairing_month },
            { key: 'mentor_name', header: 'Mentor', render: (r: Pairing) => r.mentor_name },
            { key: 'mentor_tier', header: 'Mentor Tier', render: (r: Pairing) => r.mentor_tier },
            { key: 'mentee_name', header: 'Mentee', render: (r: Pairing) => r.mentee_name },
            {
              key: 'tier_move',
              header: 'Tier Move',
              render: (r: Pairing) => `${r.mentee_tier_before} -> ${r.mentee_tier_after}`,
            },
            { key: 'hours_spent', header: 'Hours', render: (r: Pairing) => Number(r.hours_spent).toFixed(1) },
            { key: 'skill_jump', header: 'Skill Jump', render: (r: Pairing) => Number(r.skill_jump).toFixed(2) },
            { key: 'csat_mentee', header: 'Mentee CSAT', render: (r: Pairing) => Number(r.csat_mentee).toFixed(2) },
            { key: 'pairing_verdict', header: 'Verdict', render: (r: Pairing) => r.pairing_verdict },
          ]}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Top Mentors</h2>
        <DataTable
          rows={mentors}
          rowKey={(r, i) => `${r.mentor_name}-${i}`}
          emptyMessage="No data"
          columns={[
            { key: 'mentor_name', header: 'Mentor', render: (r: Mentor) => r.mentor_name },
            { key: 'mentor_tier', header: 'Tier', render: (r: Mentor) => r.mentor_tier },
            { key: 'mentee_count', header: 'Mentees', render: (r: Mentor) => String(r.mentee_count) },
            { key: 'total_hours', header: 'Hours', render: (r: Mentor) => Number(r.total_hours).toFixed(1) },
            { key: 'avg_skill_jump', header: 'Avg Skill Jump', render: (r: Mentor) => Number(r.avg_skill_jump).toFixed(2) },
            { key: 'avg_csat_mentee', header: 'Avg Mentee CSAT', render: (r: Mentor) => Number(r.avg_csat_mentee).toFixed(2) },
          ]}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Action Required</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '10px' }}>
          Pairs marked reassign or terminate. Founder review before the next cohort.
        </p>
        <DataTable
          rows={actions}
          rowKey={(r, i) => `${r.mentor_name}-${r.mentee_name}-${i}`}
          emptyMessage="No data"
          columns={[
            { key: 'mentor_name', header: 'Mentor', render: (r: ActionRow) => r.mentor_name },
            { key: 'mentee_name', header: 'Mentee', render: (r: ActionRow) => r.mentee_name },
            { key: 'hours_spent', header: 'Hours', render: (r: ActionRow) => Number(r.hours_spent).toFixed(1) },
            { key: 'skill_jump', header: 'Skill Jump', render: (r: ActionRow) => Number(r.skill_jump).toFixed(2) },
            { key: 'csat_mentee', header: 'Mentee CSAT', render: (r: ActionRow) => Number(r.csat_mentee).toFixed(2) },
            { key: 'pairing_verdict', header: 'Verdict', render: (r: ActionRow) => r.pairing_verdict },
            { key: 'founder_notes', header: 'Notes', render: (r: ActionRow) => r.founder_notes ?? '' },
          ]}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Skill Area Breakdown</h2>
        <DataTable
          rows={skills}
          rowKey={(r, i) => `${r.skill_area}-${i}`}
          emptyMessage="No data"
          columns={[
            { key: 'skill_area', header: 'Skill', render: (r: SkillRow) => r.skill_area },
            { key: 'pair_count', header: 'Pairs', render: (r: SkillRow) => String(r.pair_count) },
            { key: 'avg_before', header: 'Avg Before', render: (r: SkillRow) => Number(r.avg_before).toFixed(2) },
            { key: 'avg_after', header: 'Avg After', render: (r: SkillRow) => Number(r.avg_after).toFixed(2) },
            { key: 'avg_jump', header: 'Avg Jump', render: (r: SkillRow) => Number(r.avg_jump).toFixed(2) },
            { key: 'signoff_rate', header: 'Signoff %', render: (r: SkillRow) => Number(r.signoff_rate).toFixed(1) },
          ]}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Tier Progression</h2>
        <DataTable
          rows={tiers}
          rowKey={(r, i) => `${r.movement}-${i}`}
          emptyMessage="No data"
          columns={[
            { key: 'movement', header: 'Movement', render: (r: TierRow) => r.movement },
            { key: 'pair_count', header: 'Pairs', render: (r: TierRow) => String(r.pair_count) },
            { key: 'avg_hours', header: 'Avg Hours', render: (r: TierRow) => Number(r.avg_hours).toFixed(1) },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: TierRow) => Number(r.avg_csat).toFixed(2) },
          ]}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Effectiveness Score</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '10px' }}>
          Composite = skill jump x 4 & CSAT avg x 3 & jobs total x 0.2. Higher is better.
        </p>
        <DataTable
          rows={effectiveness}
          rowKey={(r, i) => `${r.mentor_name}-${r.mentee_name}-${i}`}
          emptyMessage="No data"
          columns={[
            { key: 'mentor_name', header: 'Mentor', render: (r: EffectivenessRow) => r.mentor_name },
            { key: 'mentee_name', header: 'Mentee', render: (r: EffectivenessRow) => r.mentee_name },
            { key: 'skill_jump', header: 'Skill Jump', render: (r: EffectivenessRow) => Number(r.skill_jump).toFixed(2) },
            { key: 'csat_avg', header: 'CSAT Avg', render: (r: EffectivenessRow) => Number(r.csat_avg).toFixed(2) },
            { key: 'jobs_total', header: 'Jobs', render: (r: EffectivenessRow) => String(r.jobs_total) },
            { key: 'effectiveness_score', header: 'Score', render: (r: EffectivenessRow) => Number(r.effectiveness_score).toFixed(2) },
          ]}
        />
      </section>
    </main>
  );
}
