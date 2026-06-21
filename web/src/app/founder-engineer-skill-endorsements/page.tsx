import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerSkillEndorsementsPage() {
  const sb = await getSupabaseServerClient();

  const [endorsementsRes, summariesRes, topSkillsRes, topEndorsersRes, hospitalEngRes] = await Promise.all([
    sb.rpc('list_endorsements_r1712'),
    sb.rpc('list_summaries_r1712'),
    sb.rpc('top_endorsed_skills_r1712'),
    sb.rpc('top_endorsers_r1712'),
    sb.rpc('hospital_endorsed_engineers_r1712'),
  ]);

  const endorsements: any[] = endorsementsRes.data ?? [];
  const summaries: any[] = summariesRes.data ?? [];
  const topSkills: any[] = topSkillsRes.data ?? [];
  const topEndorsers: any[] = topEndorsersRes.data ?? [];
  const hospitalEng: any[] = hospitalEngRes.data ?? [];

  const totalEndorsements = endorsements.length;
  const totalWeight = endorsements.reduce((acc, r) => acc + (Number(r.weight) || 0), 0);
  const distinctEngineers = new Set(endorsements.map((r) => r.engineer_user_id)).size;
  const distinctSkills = new Set(endorsements.map((r) => r.skill)).size;

  const endorsementCols: Column<any>[] = [
    { key: 'endorsed_at', header: 'When', render: (r: any) => (r.endorsed_at ? new Date(r.endorsed_at).toLocaleString() : '—') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'skill', header: 'Skill', render: (r: any) => r.skill ?? '—' },
    { key: 'endorser_email', header: 'Endorser', render: (r: any) => r.endorser_email ?? '—' },
    { key: 'endorser_role', header: 'Role', render: (r: any) => r.endorser_role ?? '—' },
    { key: 'weight', header: 'Weight', render: (r: any) => String(r.weight ?? 0) },
    { key: 'endorsement_text', header: 'Note', render: (r: any) => r.endorsement_text ?? '—' },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'skill', header: 'Skill', render: (r: any) => r.skill ?? '—' },
    { key: 'total_endorsements', header: 'Endorsements', render: (r: any) => String(r.total_endorsements ?? 0) },
    { key: 'weighted_score', header: 'Weighted Score', render: (r: any) => String(r.weighted_score ?? 0) },
    { key: 'last_endorsed_at', header: 'Last Endorsed', render: (r: any) => (r.last_endorsed_at ? new Date(r.last_endorsed_at).toLocaleString() : '—') },
  ];

  const topSkillsCols: Column<any>[] = [
    { key: 'skill', header: 'Skill', render: (r: any) => r.skill ?? '—' },
    { key: 'total_endorsements', header: 'Endorsements', render: (r: any) => String(r.total_endorsements ?? 0) },
    { key: 'weighted_score', header: 'Weighted Score', render: (r: any) => String(r.weighted_score ?? 0) },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => String(r.engineer_count ?? 0) },
  ];

  const topEndorsersCols: Column<any>[] = [
    { key: 'endorser_email', header: 'Endorser', render: (r: any) => r.endorser_email ?? '—' },
    { key: 'endorser_role', header: 'Role', render: (r: any) => r.endorser_role ?? '—' },
    { key: 'total_endorsements', header: 'Count', render: (r: any) => String(r.total_endorsements ?? 0) },
    { key: 'total_weight', header: 'Total Weight', render: (r: any) => String(r.total_weight ?? 0) },
    { key: 'last_endorsed_at', header: 'Last', render: (r: any) => (r.last_endorsed_at ? new Date(r.last_endorsed_at).toLocaleString() : '—') },
  ];

  const hospitalEngCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'hospital_endorsements', header: 'Hospital Endorsements', render: (r: any) => String(r.hospital_endorsements ?? 0) },
    { key: 'hospital_weight', header: 'Hospital Weight', render: (r: any) => String(r.hospital_weight ?? 0) },
    { key: 'distinct_skills', header: 'Skills', render: (r: any) => String(r.distinct_skills ?? 0) },
    { key: 'last_endorsed_at', header: 'Last', render: (r: any) => (r.last_endorsed_at ? new Date(r.last_endorsed_at).toLocaleString() : '—') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Engineer Skill Endorsements</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Hospital and peer endorsements per engineer skill. Weighted scoring (1–5) tracks credibility across the network.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 32 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total Endorsements</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalEndorsements}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total Weighted Score</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalWeight}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Engineers Endorsed</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{distinctEngineers}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Distinct Skills</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{distinctSkills}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Endorsements</h2>
        <DataTable rows={endorsements} columns={endorsementCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Skill Summaries (per engineer)</h2>
        <DataTable rows={summaries} columns={summaryCols} rowKey={(r: any, i: number) => `${r.engineer_user_id}-${r.skill}-${i}`} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Endorsed Skills</h2>
        <DataTable rows={topSkills} columns={topSkillsCols} rowKey={(r: any, i: number) => String(r.skill ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Endorsers</h2>
        <DataTable rows={topEndorsers} columns={topEndorsersCols} rowKey={(r: any, i: number) => String(r.endorser_email ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Hospital-Endorsed Engineers</h2>
        <DataTable rows={hospitalEng} columns={hospitalEngCols} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />
      </section>
    </main>
  );
}
