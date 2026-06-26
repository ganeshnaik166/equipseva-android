import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_handovers: number;
  clean_signoffs: number;
  disputed_count: number;
  avg_witness_quality: number;
  avg_dispute_risk: number;
  avg_csat: number;
  followups_open: number;
};

type EngineerRow = {
  engineer_code: string;
  engineer_name: string;
  handovers: number;
  clean: number;
  disputed: number;
  avg_csat: number;
  avg_risk: number;
};

type HandoverRow = {
  id: string;
  engineer_code: string;
  engineer_name: string;
  hospital_name: string;
  equipment_label: string;
  handover_date: string;
  handover_type: string;
  signoff_status: string;
  outcome_label: string;
  csat: number;
  risk: number;
  witnesses: number;
  method: string;
  followup: boolean;
};

type WitnessRow = {
  witness_name: string;
  witness_role: string;
  hospital_name: string;
  engineer_code: string;
  credential_verified: boolean;
  signature_quality: string;
  evidence_kind: string;
  risk_flag: string;
};

type OutcomeRow = {
  outcome_label: string;
  events: number;
  avg_risk: number;
  avg_csat: number;
  followups: number;
};

type MethodRow = {
  signoff_method: string;
  events: number;
  clean_rate: number;
  avg_risk: number;
  avg_witness_quality: number;
};

type HighRiskRow = {
  engineer_code: string;
  hospital_name: string;
  equipment_label: string;
  handover_date: string;
  signoff_status: string;
  dispute_risk: number;
  witness_count: number;
  outcome: string;
};

type RoleRow = {
  witness_role: string;
  total: number;
  verified: number;
  clean_signatures: number;
  high_risk: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, engRes, listRes, witnessRes, outcomeRes, methodRes, riskRes, roleRes] = await Promise.all([
    supabase.rpc('founder_r2842_handover_kpis'),
    supabase.rpc('founder_r2842_engineer_rollup'),
    supabase.rpc('founder_r2842_handover_list'),
    supabase.rpc('founder_r2842_witness_ledger'),
    supabase.rpc('founder_r2842_outcome_mix'),
    supabase.rpc('founder_r2842_method_effectiveness'),
    supabase.rpc('founder_r2842_high_risk'),
    supabase.rpc('founder_r2842_witness_role_coverage'),
  ]);

  const kpi: Kpi | null = (kpiRes.data?.[0] as Kpi) ?? null;
  const engineers: EngineerRow[] = (engRes.data as EngineerRow[]) ?? [];
  const handovers: HandoverRow[] = (listRes.data as HandoverRow[]) ?? [];
  const witnesses: WitnessRow[] = (witnessRes.data as WitnessRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomeRes.data as OutcomeRow[]) ?? [];
  const methods: MethodRow[] = (methodRes.data as MethodRow[]) ?? [];
  const highRisk: HighRiskRow[] = (riskRes.data as HighRiskRow[]) ?? [];
  const roles: RoleRow[] = (roleRes.data as RoleRow[]) ?? [];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '6px' }}>
          Engineer Monthly Customer Handover Signoff & Witness Ledger
        </h1>
        <p style={{ color: '#555', fontSize: '14px' }}>
          Round r2842 — tracks engineer handover events, witness coverage, signoff method, dispute risk &amp; outcome.
          Rows where risk &gt;= 3.0 surface in the high-risk queue.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <KpiCard label="Total handovers" value={kpi?.total_handovers ?? 0} />
        <KpiCard label="Clean signoffs" value={kpi?.clean_signoffs ?? 0} />
        <KpiCard label="Disputed / escalated" value={kpi?.disputed_count ?? 0} tone="danger" />
        <KpiCard label="Avg witness quality" value={kpi?.avg_witness_quality ?? 0} />
        <KpiCard label="Avg dispute risk" value={kpi?.avg_dispute_risk ?? 0} tone="warn" />
        <KpiCard label="Avg CSAT" value={kpi?.avg_csat ?? 0} />
        <KpiCard label="Followups open" value={kpi?.followups_open ?? 0} tone="warn" />
      </section>

      <Section title="Engineer rollup" subtitle="Per-engineer signoff quality & risk">
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: EngineerRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Name', render: (r: EngineerRow) => r.engineer_name },
            { key: 'handovers', header: 'Handovers', render: (r: EngineerRow) => r.handovers },
            { key: 'clean', header: 'Clean', render: (r: EngineerRow) => r.clean },
            { key: 'disputed', header: 'Disputed', render: (r: EngineerRow) => r.disputed },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: EngineerRow) => r.avg_csat },
            { key: 'avg_risk', header: 'Avg risk', render: (r: EngineerRow) => r.avg_risk },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer_code ?? i)}
        />
      </Section>

      <Section title="Handover ledger" subtitle="Every handover event this month">
        <DataTable
          rows={handovers}
          columns={[
            { key: 'handover_date', header: 'Date', render: (r: HandoverRow) => r.handover_date },
            { key: 'engineer_code', header: 'Engineer', render: (r: HandoverRow) => r.engineer_code },
            { key: 'hospital_name', header: 'Hospital', render: (r: HandoverRow) => r.hospital_name },
            { key: 'equipment_label', header: 'Equipment', render: (r: HandoverRow) => r.equipment_label },
            { key: 'handover_type', header: 'Type', render: (r: HandoverRow) => r.handover_type },
            { key: 'signoff_status', header: 'Signoff', render: (r: HandoverRow) => r.signoff_status },
            { key: 'outcome_label', header: 'Outcome', render: (r: HandoverRow) => r.outcome_label },
            { key: 'csat', header: 'CSAT', render: (r: HandoverRow) => r.csat },
            { key: 'risk', header: 'Risk', render: (r: HandoverRow) => r.risk },
            { key: 'witnesses', header: 'Witnesses', render: (r: HandoverRow) => r.witnesses },
            { key: 'method', header: 'Method', render: (r: HandoverRow) => r.method },
            { key: 'followup', header: 'Followup', render: (r: HandoverRow) => (r.followup ? 'yes' : 'no') },
          ]}
          emptyMessage="No data"
          rowKey={(r: HandoverRow, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Witness ledger" subtitle="Per-witness credential & risk view">
        <DataTable
          rows={witnesses}
          columns={[
            { key: 'witness_name', header: 'Witness', render: (r: WitnessRow) => r.witness_name },
            { key: 'witness_role', header: 'Role', render: (r: WitnessRow) => r.witness_role },
            { key: 'hospital_name', header: 'Hospital', render: (r: WitnessRow) => r.hospital_name },
            { key: 'engineer_code', header: 'Engineer', render: (r: WitnessRow) => r.engineer_code },
            { key: 'credential_verified', header: 'Verified', render: (r: WitnessRow) => (r.credential_verified ? 'yes' : 'no') },
            { key: 'signature_quality', header: 'Sig quality', render: (r: WitnessRow) => r.signature_quality },
            { key: 'evidence_kind', header: 'Evidence', render: (r: WitnessRow) => r.evidence_kind },
            { key: 'risk_flag', header: 'Risk flag', render: (r: WitnessRow) => r.risk_flag },
          ]}
          emptyMessage="No data"
          rowKey={(r: WitnessRow, i: number) => String(`${r.witness_name}-${i}`)}
        />
      </Section>

      <Section title="Outcome mix" subtitle="Distribution by outcome label">
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome_label', header: 'Outcome', render: (r: OutcomeRow) => r.outcome_label },
            { key: 'events', header: 'Events', render: (r: OutcomeRow) => r.events },
            { key: 'avg_risk', header: 'Avg risk', render: (r: OutcomeRow) => r.avg_risk },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: OutcomeRow) => r.avg_csat },
            { key: 'followups', header: 'Followups', render: (r: OutcomeRow) => r.followups },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.outcome_label ?? i)}
        />
      </Section>

      <Section title="Signoff method effectiveness" subtitle="Which capture method gives the cleanest signoffs">
        <DataTable
          rows={methods}
          columns={[
            { key: 'signoff_method', header: 'Method', render: (r: MethodRow) => r.signoff_method },
            { key: 'events', header: 'Events', render: (r: MethodRow) => r.events },
            { key: 'clean_rate', header: 'Clean rate %', render: (r: MethodRow) => r.clean_rate },
            { key: 'avg_risk', header: 'Avg risk', render: (r: MethodRow) => r.avg_risk },
            { key: 'avg_witness_quality', header: 'Avg witness quality', render: (r: MethodRow) => r.avg_witness_quality },
          ]}
          emptyMessage="No data"
          rowKey={(r: MethodRow, i: number) => String(r.signoff_method ?? i)}
        />
      </Section>

      <Section title="High-risk queue" subtitle="Handovers needing founder review (risk >= 3.0 or rework/dispute)">
        <DataTable
          rows={highRisk}
          columns={[
            { key: 'handover_date', header: 'Date', render: (r: HighRiskRow) => r.handover_date },
            { key: 'engineer_code', header: 'Engineer', render: (r: HighRiskRow) => r.engineer_code },
            { key: 'hospital_name', header: 'Hospital', render: (r: HighRiskRow) => r.hospital_name },
            { key: 'equipment_label', header: 'Equipment', render: (r: HighRiskRow) => r.equipment_label },
            { key: 'signoff_status', header: 'Signoff', render: (r: HighRiskRow) => r.signoff_status },
            { key: 'dispute_risk', header: 'Risk', render: (r: HighRiskRow) => r.dispute_risk },
            { key: 'witness_count', header: 'Witnesses', render: (r: HighRiskRow) => r.witness_count },
            { key: 'outcome', header: 'Outcome', render: (r: HighRiskRow) => r.outcome },
          ]}
          emptyMessage="No data"
          rowKey={(r: HighRiskRow, i: number) => String(`${r.engineer_code}-${r.handover_date}-${i}`)}
        />
      </Section>

      <Section title="Witness role coverage" subtitle="Coverage and verification by role">
        <DataTable
          rows={roles}
          columns={[
            { key: 'witness_role', header: 'Role', render: (r: RoleRow) => r.witness_role },
            { key: 'total', header: 'Total', render: (r: RoleRow) => r.total },
            { key: 'verified', header: 'Verified', render: (r: RoleRow) => r.verified },
            { key: 'clean_signatures', header: 'Clean sigs', render: (r: RoleRow) => r.clean_signatures },
            { key: 'high_risk', header: 'High risk', render: (r: RoleRow) => r.high_risk },
          ]}
          emptyMessage="No data"
          rowKey={(r: RoleRow, i: number) => String(r.witness_role ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: number | string; tone?: 'warn' | 'danger' }) {
  const bg = tone === 'danger' ? '#fff5f5' : tone === 'warn' ? '#fffaf0' : '#f7fafc';
  const border = tone === 'danger' ? '#feb2b2' : tone === 'warn' ? '#fbd38d' : '#e2e8f0';
  return (
    <div style={{ background: bg, border: `1px solid ${border}`, borderRadius: '8px', padding: '14px' }}>
      <div style={{ fontSize: '12px', color: '#555', marginBottom: '4px' }}>{label}</div>
      <div style={{ fontSize: '22px', fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '28px' }}>
      <h2 style={{ fontSize: '17px', fontWeight: 700, marginBottom: '4px' }}>{title}</h2>
      {subtitle ? <p style={{ fontSize: '13px', color: '#666', marginBottom: '10px' }}>{subtitle}</p> : null}
      {children}
    </section>
  );
}
