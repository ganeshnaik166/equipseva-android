import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_recos: number;
  total_accepted: number;
  acceptance_pct: number;
  upsell_gmv_rupees: number;
  avg_decision_hours: number;
  hospitals_at_risk: number;
};

type TopHospital = {
  id: string;
  hospital_name: string;
  amc_tier: string;
  acceptance_pct: number;
  monthly_upsell_gmv_rupees: number;
  uptime_pct: number;
  nps_score: number;
};

type AtRisk = {
  id: string;
  hospital_name: string;
  amc_tier: string;
  acceptance_pct: number;
  trailing3_acceptance_pct: number;
  retention_risk: string;
  nps_score: number;
};

type EngLead = {
  engineer_code: string;
  engineer_tier: string;
  recos: number;
  accepted: number;
  acceptance_pct: number;
  gmv_won_rupees: number;
};

type Rejection = {
  rejection_reason: string;
  rejections: number;
  lost_gmv_rupees: number;
  avg_decision_hours: number;
};

type Urgency = {
  urgency: string;
  recos: number;
  accepted: number;
  acceptance_pct: number;
  gmv_rupees: number;
};

type HighTicket = {
  id: string;
  hospital_name: string;
  spare_part_name: string;
  bundle_total_rupees: number;
  urgency: string;
  accepted: boolean;
  decision_hours: number | null;
};

type TierAcc = {
  amc_tier: string;
  hospitals: number;
  avg_acceptance_pct: number;
  total_gmv_rupees: number;
  avg_nps: number;
};

function rupees(n: number | null | undefined) {
  if (n == null) return '-';
  return '₹' + n.toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [kpisR, topR, riskR, engR, rejR, urgR, htR, tierR] = await Promise.all([
    sb.rpc('founder_r2892_kpis'),
    sb.rpc('founder_r2892_top_hospitals'),
    sb.rpc('founder_r2892_at_risk_hospitals'),
    sb.rpc('founder_r2892_engineer_leaderboard'),
    sb.rpc('founder_r2892_rejection_reasons'),
    sb.rpc('founder_r2892_urgency_mix'),
    sb.rpc('founder_r2892_high_ticket_recos'),
    sb.rpc('founder_r2892_tier_acceptance'),
  ]);

  const kpis: Kpis = (kpisR.data?.[0] ?? {
    total_recos: 0,
    total_accepted: 0,
    acceptance_pct: 0,
    upsell_gmv_rupees: 0,
    avg_decision_hours: 0,
    hospitals_at_risk: 0,
  }) as Kpis;

  const topHospitals: TopHospital[] = (topR.data ?? []) as TopHospital[];
  const atRisk: AtRisk[] = (riskR.data ?? []) as AtRisk[];
  const engLead: EngLead[] = (engR.data ?? []) as EngLead[];
  const rejections: Rejection[] = (rejR.data ?? []) as Rejection[];
  const urgency: Urgency[] = (urgR.data ?? []) as Urgency[];
  const highTicket: HighTicket[] = (htR.data ?? []) as HighTicket[];
  const tier: TierAcc[] = (tierR.data ?? []) as TierAcc[];

  const topCols: Column<TopHospital>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'amc_tier', header: 'AMC Tier', render: (r) => r.amc_tier },
    { key: 'acceptance_pct', header: 'Acceptance %', render: (r) => r.acceptance_pct + '%' },
    { key: 'monthly_upsell_gmv_rupees', header: 'Monthly Upsell GMV', render: (r) => rupees(r.monthly_upsell_gmv_rupees) },
    { key: 'uptime_pct', header: 'Uptime %', render: (r) => r.uptime_pct + '%' },
    { key: 'nps_score', header: 'NPS', render: (r) => String(r.nps_score) },
  ];

  const riskCols: Column<AtRisk>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'amc_tier', header: 'AMC Tier', render: (r) => r.amc_tier },
    { key: 'acceptance_pct', header: 'This Month %', render: (r) => r.acceptance_pct + '%' },
    { key: 'trailing3_acceptance_pct', header: 'Trailing 3M %', render: (r) => r.trailing3_acceptance_pct + '%' },
    { key: 'retention_risk', header: 'Risk', render: (r) => r.retention_risk },
    { key: 'nps_score', header: 'NPS', render: (r) => String(r.nps_score) },
  ];

  const engCols: Column<EngLead>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier },
    { key: 'recos', header: 'Recos', render: (r) => String(r.recos) },
    { key: 'accepted', header: 'Accepted', render: (r) => String(r.accepted) },
    { key: 'acceptance_pct', header: 'Acceptance %', render: (r) => r.acceptance_pct + '%' },
    { key: 'gmv_won_rupees', header: 'GMV Won', render: (r) => rupees(r.gmv_won_rupees) },
  ];

  const rejCols: Column<Rejection>[] = [
    { key: 'rejection_reason', header: 'Rejection Reason', render: (r) => r.rejection_reason },
    { key: 'rejections', header: 'Count', render: (r) => String(r.rejections) },
    { key: 'lost_gmv_rupees', header: 'Lost GMV', render: (r) => rupees(r.lost_gmv_rupees) },
    { key: 'avg_decision_hours', header: 'Avg Decision Hrs', render: (r) => String(r.avg_decision_hours) },
  ];

  const urgCols: Column<Urgency>[] = [
    { key: 'urgency', header: 'Urgency', render: (r) => r.urgency },
    { key: 'recos', header: 'Recos', render: (r) => String(r.recos) },
    { key: 'accepted', header: 'Accepted', render: (r) => String(r.accepted) },
    { key: 'acceptance_pct', header: 'Acceptance %', render: (r) => r.acceptance_pct + '%' },
    { key: 'gmv_rupees', header: 'GMV', render: (r) => rupees(r.gmv_rupees) },
  ];

  const htCols: Column<HighTicket>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'spare_part_name', header: 'Spare Part', render: (r) => r.spare_part_name },
    { key: 'bundle_total_rupees', header: 'Bundle', render: (r) => rupees(r.bundle_total_rupees) },
    { key: 'urgency', header: 'Urgency', render: (r) => r.urgency },
    { key: 'accepted', header: 'Accepted', render: (r) => (r.accepted ? 'yes' : 'no') },
    { key: 'decision_hours', header: 'Decision Hrs', render: (r) => (r.decision_hours == null ? '-' : String(r.decision_hours)) },
  ];

  const tierCols: Column<TierAcc>[] = [
    { key: 'amc_tier', header: 'AMC Tier', render: (r) => r.amc_tier },
    { key: 'hospitals', header: 'Hospitals', render: (r) => String(r.hospitals) },
    { key: 'avg_acceptance_pct', header: 'Avg Acceptance %', render: (r) => r.avg_acceptance_pct + '%' },
    { key: 'total_gmv_rupees', header: 'Total GMV', render: (r) => rupees(r.total_gmv_rupees) },
    { key: 'avg_nps', header: 'Avg NPS', render: (r) => String(r.avg_nps) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Customer Monthly Engineer-Recommended Spare-Part Upsell Acceptance
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Round r2892 — track field engineer monthly upsell recos to hospitals, decision velocity,
        acceptance %, and retention risk where acceptance &lt; 70%. Hospital outcomes hinge on accepting
        preventive spare bundles before failures cause downtime.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px,1fr))', gap: 12, marginBottom: 32 }}>
        <KpiCard label="Recos this month" value={String(kpis.total_recos)} />
        <KpiCard label="Accepted" value={String(kpis.total_accepted)} />
        <KpiCard label="Acceptance %" value={kpis.acceptance_pct + '%'} />
        <KpiCard label="Upsell GMV won" value={rupees(kpis.upsell_gmv_rupees)} />
        <KpiCard label="Avg decision hrs" value={String(kpis.avg_decision_hours)} />
        <KpiCard label="Hospitals at risk" value={String(kpis.hospitals_at_risk)} />
      </section>

      <Section title="Top hospitals by upsell GMV">
        <DataTable
          rows={topHospitals}
          columns={topCols}
          emptyMessage="No hospital data."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="At-risk hospitals (acceptance trending down)">
        <DataTable
          rows={atRisk}
          columns={riskCols}
          emptyMessage="No at-risk hospitals."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Engineer leaderboard (close rate & GMV won)">
        <DataTable
          rows={engLead}
          columns={engCols}
          emptyMessage="No engineer data."
          rowKey={(r, i) => String(r.engineer_code ?? i)}
        />
      </Section>

      <Section title="Rejection reasons (lost GMV)">
        <DataTable
          rows={rejections}
          columns={rejCols}
          emptyMessage="No rejections."
          rowKey={(r, i) => String(r.rejection_reason ?? i)}
        />
      </Section>

      <Section title="Urgency mix">
        <DataTable
          rows={urgency}
          columns={urgCols}
          emptyMessage="No urgency rows."
          rowKey={(r, i) => String(r.urgency ?? i)}
        />
      </Section>

      <Section title="High-ticket recos (>= ₹15,000 bundles)">
        <DataTable
          rows={highTicket}
          columns={htCols}
          emptyMessage="No high-ticket recos."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="AMC tier acceptance summary">
        <DataTable
          rows={tier}
          columns={tierCols}
          emptyMessage="No tier data."
          rowKey={(r, i) => String(r.amc_tier ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 6 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>{title}</h2>
      {children}
    </section>
  );
}
