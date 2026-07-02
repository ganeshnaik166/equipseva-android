import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_engineers: number;
  total_skill_rows: number;
  bench_gaps: number;
  avg_competency: number;
  avg_utilization: number;
  expiring_certs_30d: number;
  open_actions: number;
  p0_actions: number;
};

type SkillRow = {
  id: string;
  snapshot_month: string;
  engineer_name: string;
  vertical: string;
  competency: string;
  competency_score: number;
  cert_status: string;
  cert_expires_on: string | null;
  utilization_pct: number;
  jobs_completed: number;
  csat_avg: number;
  bench_gap_flag: boolean;
  notes: string | null;
};

type VerticalCov = {
  vertical: string;
  engineers_count: number;
  experts_count: number;
  avg_score: number;
  avg_utilization: number;
  gap_count: number;
};

type EngineerRollup = {
  engineer_id: string;
  engineer_name: string;
  verticals_covered: number;
  avg_score: number;
  total_jobs: number;
  avg_csat: number;
  open_actions: number;
};

type CertRow = {
  engineer_name: string;
  vertical: string;
  cert_status: string;
  cert_expires_on: string | null;
  days_to_expiry: number;
};

type ActionRow = {
  id: string;
  engineer_name: string;
  vertical: string;
  action_kind: string;
  priority: string;
  status: string;
  due_on: string;
  estimated_hours: number;
  expected_score_lift: number;
  notes: string | null;
};

type ActionMix = {
  action_kind: string;
  total_actions: number;
  open_actions: number;
  total_hours: number;
  expected_lift_sum: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, matrixRes, verticalRes, engineerRes, gapsRes, certsRes, actionsRes, mixRes] = await Promise.all([
    supabase.rpc('founder_skill_matrix_kpis_r2766'),
    supabase.rpc('founder_skill_matrix_rows_r2766'),
    supabase.rpc('founder_vertical_coverage_r2766'),
    supabase.rpc('founder_engineer_rollup_r2766'),
    supabase.rpc('founder_bench_gaps_r2766'),
    supabase.rpc('founder_expiring_certs_r2766'),
    supabase.rpc('founder_upskill_actions_r2766'),
    supabase.rpc('founder_action_mix_r2766'),
  ]);

  const kpis: Kpis | null = Array.isArray(kpisRes.data) ? kpisRes.data[0] ?? null : kpisRes.data ?? null;
  const matrix: SkillRow[] = (matrixRes.data as SkillRow[]) ?? [];
  const verticals: VerticalCov[] = (verticalRes.data as VerticalCov[]) ?? [];
  const engineers: EngineerRollup[] = (engineerRes.data as EngineerRollup[]) ?? [];
  const gaps: SkillRow[] = (gapsRes.data as SkillRow[]) ?? [];
  const certs: CertRow[] = (certsRes.data as CertRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];
  const mix: ActionMix[] = (mixRes.data as ActionMix[]) ?? [];

  return (
    <main style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>
          Engineer Monthly Cross-Vertical Skill Matrix
        </h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Per-engineer competency, cert, utilization & gap rollup across verticals. Drives monthly upskill action queue.
        </p>
      </header>

      {/* KPI cards */}
      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <KpiCard label="Engineers" value={kpis?.total_engineers ?? 0} />
        <KpiCard label="Skill rows" value={kpis?.total_skill_rows ?? 0} />
        <KpiCard label="Bench gaps" value={kpis?.bench_gaps ?? 0} accent="#b91c1c" />
        <KpiCard label="Avg competency" value={(kpis?.avg_competency ?? 0).toFixed(2)} suffix=" / 5" />
        <KpiCard label="Avg utilization" value={(kpis?.avg_utilization ?? 0).toFixed(1)} suffix="%" />
        <KpiCard label="Certs expiring <=30d" value={kpis?.expiring_certs_30d ?? 0} accent="#b45309" />
        <KpiCard label="Open actions" value={kpis?.open_actions ?? 0} />
        <KpiCard label="P0 actions" value={kpis?.p0_actions ?? 0} accent="#b91c1c" />
      </section>

      <Section title="Vertical Coverage Rollup" subtitle="Bench depth per medical vertical">
        <DataTable
          rows={verticals}
          rowKey={(r, i) => String((r as VerticalCov).vertical ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'vertical', header: 'Vertical', render: (r: VerticalCov) => <strong>{r.vertical}</strong> },
            { key: 'engineers_count', header: 'Engineers', render: (r: VerticalCov) => r.engineers_count },
            { key: 'experts_count', header: 'Experts/Masters', render: (r: VerticalCov) => r.experts_count },
            { key: 'avg_score', header: 'Avg score', render: (r: VerticalCov) => r.avg_score },
            { key: 'avg_utilization', header: 'Avg util %', render: (r: VerticalCov) => r.avg_utilization },
            { key: 'gap_count', header: 'Gaps', render: (r: VerticalCov) => r.gap_count },
          ]}
        />
      </Section>

      <Section title="Engineer Rollup" subtitle="Per-engineer averages across all verticals">
        <DataTable
          rows={engineers}
          rowKey={(r, i) => String((r as EngineerRollup).engineer_id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRollup) => <strong>{r.engineer_name}</strong> },
            { key: 'verticals_covered', header: 'Verticals', render: (r: EngineerRollup) => r.verticals_covered },
            { key: 'avg_score', header: 'Avg score', render: (r: EngineerRollup) => r.avg_score },
            { key: 'total_jobs', header: 'Jobs', render: (r: EngineerRollup) => r.total_jobs },
            { key: 'avg_csat', header: 'CSAT', render: (r: EngineerRollup) => r.avg_csat },
            { key: 'open_actions', header: 'Open actions', render: (r: EngineerRollup) => r.open_actions },
          ]}
        />
      </Section>

      <Section title="Skill Matrix (full grid)" subtitle="Every engineer x vertical row">
        <DataTable
          rows={matrix}
          rowKey={(r, i) => String((r as SkillRow).id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: SkillRow) => r.engineer_name },
            { key: 'vertical', header: 'Vertical', render: (r: SkillRow) => r.vertical },
            { key: 'competency', header: 'Competency', render: (r: SkillRow) => r.competency },
            { key: 'competency_score', header: 'Score', render: (r: SkillRow) => r.competency_score },
            { key: 'cert_status', header: 'Cert', render: (r: SkillRow) => r.cert_status },
            { key: 'cert_expires_on', header: 'Expires', render: (r: SkillRow) => r.cert_expires_on ?? '—' },
            { key: 'utilization_pct', header: 'Util %', render: (r: SkillRow) => r.utilization_pct },
            { key: 'jobs_completed', header: 'Jobs', render: (r: SkillRow) => r.jobs_completed },
            { key: 'csat_avg', header: 'CSAT', render: (r: SkillRow) => r.csat_avg },
            { key: 'bench_gap_flag', header: 'Gap?', render: (r: SkillRow) => (r.bench_gap_flag ? 'YES' : '—') },
          ]}
        />
      </Section>

      <Section title="Bench Gaps" subtitle="Rows flagged as coverage risk">
        <DataTable
          rows={gaps}
          rowKey={(r, i) => String((r as SkillRow).id ?? i)}
          emptyMessage="No gaps"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: SkillRow) => r.engineer_name },
            { key: 'vertical', header: 'Vertical', render: (r: SkillRow) => r.vertical },
            { key: 'competency', header: 'Competency', render: (r: SkillRow) => r.competency },
            { key: 'competency_score', header: 'Score', render: (r: SkillRow) => r.competency_score },
            { key: 'notes', header: 'Notes', render: (r: SkillRow) => r.notes ?? '—' },
          ]}
        />
      </Section>

      <Section title="Expiring Certs (next 90 days)" subtitle="Renewal blockers">
        <DataTable
          rows={certs}
          rowKey={(r, i) => String(`${(r as CertRow).engineer_name}-${(r as CertRow).vertical}-${i}`)}
          emptyMessage="No expiring certs"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: CertRow) => r.engineer_name },
            { key: 'vertical', header: 'Vertical', render: (r: CertRow) => r.vertical },
            { key: 'cert_status', header: 'Status', render: (r: CertRow) => r.cert_status },
            { key: 'cert_expires_on', header: 'Expires on', render: (r: CertRow) => r.cert_expires_on ?? '—' },
            { key: 'days_to_expiry', header: 'Days to expiry', render: (r: CertRow) => r.days_to_expiry },
          ]}
        />
      </Section>

      <Section title="Upskill Action Queue" subtitle="P0 first, then by due date">
        <DataTable
          rows={actions}
          rowKey={(r, i) => String((r as ActionRow).id ?? i)}
          emptyMessage="No actions queued"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: ActionRow) => r.engineer_name },
            { key: 'vertical', header: 'Vertical', render: (r: ActionRow) => r.vertical },
            { key: 'action_kind', header: 'Kind', render: (r: ActionRow) => r.action_kind },
            { key: 'priority', header: 'Priority', render: (r: ActionRow) => <strong style={{ color: r.priority === 'p0' ? '#b91c1c' : '#444' }}>{r.priority}</strong> },
            { key: 'status', header: 'Status', render: (r: ActionRow) => r.status },
            { key: 'due_on', header: 'Due', render: (r: ActionRow) => r.due_on },
            { key: 'estimated_hours', header: 'Est hrs', render: (r: ActionRow) => r.estimated_hours },
            { key: 'expected_score_lift', header: 'Lift', render: (r: ActionRow) => r.expected_score_lift },
          ]}
        />
      </Section>

      <Section title="Action Mix by Kind" subtitle="Where training hours flow">
        <DataTable
          rows={mix}
          rowKey={(r, i) => String((r as ActionMix).action_kind ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'action_kind', header: 'Kind', render: (r: ActionMix) => r.action_kind },
            { key: 'total_actions', header: 'Total', render: (r: ActionMix) => r.total_actions },
            { key: 'open_actions', header: 'Open', render: (r: ActionMix) => r.open_actions },
            { key: 'total_hours', header: 'Hours', render: (r: ActionMix) => r.total_hours },
            { key: 'expected_lift_sum', header: 'Lift sum', render: (r: ActionMix) => r.expected_lift_sum },
          ]}
        />
      </Section>

      <footer style={{ marginTop: 32, paddingTop: 16, borderTop: '1px solid #eee', color: '#666', fontSize: 12 }}>
        Round r2766 — founder-only console. Rows where score &lt;= 2.5 or status = none flagged as bench gap.
      </footer>
    </main>
  );
}

function KpiCard({ label, value, suffix, accent }: { label: string; value: number | string; suffix?: string; accent?: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 14, background: '#fff' }}>
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, color: accent ?? '#111' }}>
        {value}
        {suffix ? <span style={{ fontSize: 13, fontWeight: 500, color: '#666' }}>{suffix}</span> : null}
      </div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 17, fontWeight: 600, marginBottom: 2 }}>{title}</h2>
      {subtitle ? <p style={{ color: '#666', fontSize: 13, marginBottom: 10 }}>{subtitle}</p> : null}
      {children}
    </section>
  );
}
