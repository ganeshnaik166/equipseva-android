import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KPI = {
  total_sessions: number;
  validated_sessions: number;
  disputed_sessions: number;
  avg_effectiveness: number;
  avg_score_lift: number;
  total_savings_rupees: number;
  hospitals_at_risk: number;
};

type TopEngineer = {
  engineer_code: string;
  engineer_tier: string;
  sessions: number;
  avg_effectiveness: number;
  avg_lift: number;
};

type HospitalOutcome = {
  hospital_name: string;
  hospital_tier: string;
  avg_effectiveness: number;
  callbacks_avoided: number;
  savings_rupees: number;
  amc_renewed: boolean;
  retention_signal: string;
};

type TierBreakdown = {
  hospital_tier: string;
  hospitals: number;
  avg_effectiveness: number;
  total_savings: number;
  renewal_rate: number;
};

type Disputed = {
  hospital_name: string;
  engineer_code: string;
  topic: string;
  effectiveness_score: number;
  post_test_score: number;
};

type AtRisk = {
  hospital_name: string;
  hospital_tier: string;
  avg_effectiveness: number;
  nps_change: number;
  retention_signal: string;
};

type TopicEfficacy = {
  topic: string;
  sessions: number;
  avg_effectiveness: number;
  avg_lift: number;
};

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpis, top, outcomes, tiers, disputed, atRisk, topics] = await Promise.all([
    supabase.rpc('founder_r2900_program_kpis'),
    supabase.rpc('founder_r2900_top_engineers'),
    supabase.rpc('founder_r2900_hospital_outcomes'),
    supabase.rpc('founder_r2900_tier_breakdown'),
    supabase.rpc('founder_r2900_disputed_sessions'),
    supabase.rpc('founder_r2900_at_risk_accounts'),
    supabase.rpc('founder_r2900_topic_efficacy'),
  ]);

  const k: KPI | null = (kpis.data as KPI[] | null)?.[0] ?? null;
  const topRows: TopEngineer[] = (top.data as TopEngineer[]) ?? [];
  const outcomeRows: HospitalOutcome[] = (outcomes.data as HospitalOutcome[]) ?? [];
  const tierRows: TierBreakdown[] = (tiers.data as TierBreakdown[]) ?? [];
  const disputedRows: Disputed[] = (disputed.data as Disputed[]) ?? [];
  const atRiskRows: AtRisk[] = (atRisk.data as AtRisk[]) ?? [];
  const topicRows: TopicEfficacy[] = (topics.data as TopicEfficacy[]) ?? [];

  const topCols: Column<TopEngineer>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier },
    { key: 'sessions', header: 'Sessions', render: (r) => r.sessions },
    { key: 'avg_effectiveness', header: 'Avg Effectiveness', render: (r) => `${r.avg_effectiveness}%` },
    { key: 'avg_lift', header: 'Score Lift', render: (r) => `+${r.avg_lift}` },
  ];

  const outcomeCols: Column<HospitalOutcome>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'hospital_tier', header: 'Tier', render: (r) => r.hospital_tier },
    { key: 'avg_effectiveness', header: 'Effectiveness', render: (r) => `${r.avg_effectiveness}%` },
    { key: 'callbacks_avoided', header: 'Callbacks Avoided', render: (r) => r.callbacks_avoided },
    { key: 'savings_rupees', header: 'Savings', render: (r) => rupees(r.savings_rupees) },
    { key: 'amc_renewed', header: 'AMC Renewed', render: (r) => (r.amc_renewed ? 'Yes' : 'No') },
    { key: 'retention_signal', header: 'Signal', render: (r) => r.retention_signal },
  ];

  const tierCols: Column<TierBreakdown>[] = [
    { key: 'hospital_tier', header: 'Tier', render: (r) => r.hospital_tier },
    { key: 'hospitals', header: 'Hospitals', render: (r) => r.hospitals },
    { key: 'avg_effectiveness', header: 'Avg Effectiveness', render: (r) => `${r.avg_effectiveness}%` },
    { key: 'total_savings', header: 'Total Savings', render: (r) => rupees(r.total_savings) },
    { key: 'renewal_rate', header: 'Renewal Rate', render: (r) => `${r.renewal_rate}%` },
  ];

  const disputedCols: Column<Disputed>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'topic', header: 'Topic', render: (r) => r.topic },
    { key: 'effectiveness_score', header: 'Effectiveness', render: (r) => `${r.effectiveness_score}%` },
    { key: 'post_test_score', header: 'Post-Test', render: (r) => `${r.post_test_score}` },
  ];

  const atRiskCols: Column<AtRisk>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'hospital_tier', header: 'Tier', render: (r) => r.hospital_tier },
    { key: 'avg_effectiveness', header: 'Effectiveness', render: (r) => `${r.avg_effectiveness}%` },
    { key: 'nps_change', header: 'NPS Change', render: (r) => `${r.nps_change}` },
    { key: 'retention_signal', header: 'Signal', render: (r) => r.retention_signal },
  ];

  const topicCols: Column<TopicEfficacy>[] = [
    { key: 'topic', header: 'Topic', render: (r) => r.topic },
    { key: 'sessions', header: 'Sessions', render: (r) => r.sessions },
    { key: 'avg_effectiveness', header: 'Avg Effectiveness', render: (r) => `${r.avg_effectiveness}%` },
    { key: 'avg_lift', header: 'Avg Lift', render: (r) => `+${r.avg_lift}` },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
          Customer Monthly Engineer Technical Knowledge Transfer Effectiveness
        </h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Round r2900 · Measures how well engineers train hospital biomed staff each month —
          and whether the lift drives self-service repairs, callback avoidance, AMC renewal & retention.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <KpiCard label="Total Sessions" value={k?.total_sessions ?? 0} />
        <KpiCard label="Validated" value={k?.validated_sessions ?? 0} />
        <KpiCard label="Disputed" value={k?.disputed_sessions ?? 0} />
        <KpiCard label="Avg Effectiveness" value={`${k?.avg_effectiveness ?? 0}%`} />
        <KpiCard label="Avg Score Lift" value={`+${k?.avg_score_lift ?? 0}`} />
        <KpiCard label="Total Savings" value={rupees(k?.total_savings_rupees ?? 0)} />
        <KpiCard label="Hospitals At Risk" value={k?.hospitals_at_risk ?? 0} />
      </section>

      <Section title="Top Engineers by Effectiveness">
        <DataTable
          rows={topRows}
          columns={topCols}
          emptyMessage="No engineer data yet"
          rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.engineer_code}-${i}`)}
        />
      </Section>

      <Section title="Hospital Outcomes (savings & retention)">
        <DataTable
          rows={outcomeRows}
          columns={outcomeCols}
          emptyMessage="No hospital outcomes yet"
          rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.hospital_name}-${i}`)}
        />
      </Section>

      <Section title="Tier Breakdown">
        <DataTable
          rows={tierRows}
          columns={tierCols}
          emptyMessage="No tier rollup yet"
          rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.hospital_tier}-${i}`)}
        />
      </Section>

      <Section title="Disputed Sessions (effectiveness < threshold)">
        <DataTable
          rows={disputedRows}
          columns={disputedCols}
          emptyMessage="No disputes"
          rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.hospital_name}-${r.engineer_code}-${i}`)}
        />
      </Section>

      <Section title="At-Risk Accounts (signal = at_risk or churn)">
        <DataTable
          rows={atRiskRows}
          columns={atRiskCols}
          emptyMessage="No at-risk accounts"
          rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.hospital_name}-${i}`)}
        />
      </Section>

      <Section title="Topic Efficacy (which training sticks)">
        <DataTable
          rows={topicRows}
          columns={topicCols}
          emptyMessage="No topic data yet"
          rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.topic}-${i}`)}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 6 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }} dangerouslySetInnerHTML={{ __html: title }} />
      {children}
    </section>
  );
}
