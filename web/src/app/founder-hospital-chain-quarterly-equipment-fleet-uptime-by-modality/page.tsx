import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_chains: number;
  total_fleet: number;
  avg_uptime: number;
  total_breaches: number;
  total_revenue_lost: number;
  red_cohorts: number;
};

type UptimeRow = {
  id: string;
  chain_name: string;
  hospital_count: number;
  modality: string;
  asset_cohort: string;
  quarter: string;
  fleet_size: number;
  uptime_pct: number;
  sla_target_pct: number;
  sla_breach_count: number;
  mttr_hours: number;
  mtbf_hours: number;
  revenue_lost_rupees: number;
  risk_level: string;
};

type ModalityRow = {
  modality: string;
  fleet_size: number;
  avg_uptime: number;
  total_breaches: number;
  revenue_lost_rupees: number;
};

type ChainRow = {
  chain_name: string;
  hospital_count: number;
  avg_uptime: number;
  total_breaches: number;
  red_cohorts: number;
};

type CohortRow = {
  asset_cohort: string;
  fleet_size: number;
  avg_uptime: number;
  avg_mttr: number;
  red_cohorts: number;
};

type InterventionRow = {
  id: string;
  chain_name: string;
  modality: string;
  quarter: string;
  intervention_type: string;
  initiated_at: string;
  cost_rupees: number;
  uptime_delta_pct: number;
  outcome: string;
  followup_required: boolean;
  notes: string | null;
};

type RoiRow = {
  intervention_type: string;
  total_cost: number;
  avg_uptime_delta: number;
  successful_count: number;
  pending_count: number;
};

type OutcomeRow = {
  outcome: string;
  count: number;
  total_cost: number;
  avg_delta: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  if (n >= 10000000) return '₹' + (n / 10000000).toFixed(2) + ' Cr';
  if (n >= 100000) return '₹' + (n / 100000).toFixed(2) + ' L';
  return '₹' + n.toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  if (n == null) return '-';
  return Number(n).toFixed(2) + '%';
}

function riskBadge(level: string): string {
  const map: Record<string, string> = { green: '#16a34a', yellow: '#ca8a04', orange: '#ea580c', red: '#dc2626' };
  return map[level] || '#6b7280';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [kpi, uptime, byMod, byChain, cohort, interventions, roi, outcomes] = await Promise.all([
    supabase.rpc('f_r2843_kpi_summary'),
    supabase.rpc('f_r2843_uptime_rows'),
    supabase.rpc('f_r2843_by_modality'),
    supabase.rpc('f_r2843_by_chain'),
    supabase.rpc('f_r2843_cohort_risk'),
    supabase.rpc('f_r2843_interventions'),
    supabase.rpc('f_r2843_intervention_roi'),
    supabase.rpc('f_r2843_outcome_mix'),
  ]);

  const k: KpiRow = (kpi.data?.[0] as KpiRow) || {
    total_chains: 0, total_fleet: 0, avg_uptime: 0, total_breaches: 0, total_revenue_lost: 0, red_cohorts: 0,
  };
  const uptimeRows: UptimeRow[] = (uptime.data as UptimeRow[]) || [];
  const modRows: ModalityRow[] = (byMod.data as ModalityRow[]) || [];
  const chainRows: ChainRow[] = (byChain.data as ChainRow[]) || [];
  const cohortRows: CohortRow[] = (cohort.data as CohortRow[]) || [];
  const intRows: InterventionRow[] = (interventions.data as InterventionRow[]) || [];
  const roiRows: RoiRow[] = (roi.data as RoiRow[]) || [];
  const outcomeRows: OutcomeRow[] = (outcomes.data as OutcomeRow[]) || [];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Hospital Chain Quarterly Equipment Fleet Uptime by Modality
      </h1>
      <p style={{ color: '#6b7280', marginBottom: 20 }}>
        Chain × modality × asset cohort · uptime, SLA breaches, interventions, outcomes
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12, marginBottom: 24 }}>
        <Kpi label="Chains" value={String(k.total_chains)} />
        <Kpi label="Fleet Assets" value={k.total_fleet.toLocaleString('en-IN')} />
        <Kpi label="Avg Uptime" value={pct(k.avg_uptime)} />
        <Kpi label="SLA Breaches" value={String(k.total_breaches)} />
        <Kpi label="Revenue Lost" value={fmtRupees(k.total_revenue_lost)} />
        <Kpi label="Red Cohorts" value={String(k.red_cohorts)} accent="#dc2626" />
      </div>

      <Section title="Fleet uptime by chain & modality cohort">
        <DataTable
          rows={uptimeRows}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: UptimeRow) => r.chain_name },
            { key: 'modality', header: 'Modality', render: (r: UptimeRow) => r.modality.toUpperCase() },
            { key: 'asset_cohort', header: 'Cohort', render: (r: UptimeRow) => r.asset_cohort },
            { key: 'quarter', header: 'Quarter', render: (r: UptimeRow) => r.quarter },
            { key: 'fleet_size', header: 'Fleet', render: (r: UptimeRow) => String(r.fleet_size) },
            { key: 'uptime_pct', header: 'Uptime', render: (r: UptimeRow) => pct(r.uptime_pct) },
            { key: 'sla_target_pct', header: 'SLA Target', render: (r: UptimeRow) => pct(r.sla_target_pct) },
            { key: 'sla_breach_count', header: 'Breaches', render: (r: UptimeRow) => String(r.sla_breach_count) },
            { key: 'mttr_hours', header: 'MTTR (h)', render: (r: UptimeRow) => String(r.mttr_hours) },
            { key: 'mtbf_hours', header: 'MTBF (h)', render: (r: UptimeRow) => String(r.mtbf_hours) },
            { key: 'revenue_lost_rupees', header: 'Revenue Lost', render: (r: UptimeRow) => fmtRupees(r.revenue_lost_rupees) },
            {
              key: 'risk_level',
              header: 'Risk',
              render: (r: UptimeRow) => (
                <span style={{ background: riskBadge(r.risk_level), color: 'white', padding: '2px 8px', borderRadius: 4, fontSize: 12 }}>
                  {r.risk_level}
                </span>
              ),
            },
          ]}
        />
      </Section>

      <Section title="Rollup by modality (uptime & loss)">
        <DataTable
          rows={modRows}
          rowKey={(r, i) => String(r.modality ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'modality', header: 'Modality', render: (r: ModalityRow) => r.modality.toUpperCase() },
            { key: 'fleet_size', header: 'Fleet', render: (r: ModalityRow) => String(r.fleet_size) },
            { key: 'avg_uptime', header: 'Avg Uptime', render: (r: ModalityRow) => pct(r.avg_uptime) },
            { key: 'total_breaches', header: 'Breaches', render: (r: ModalityRow) => String(r.total_breaches) },
            { key: 'revenue_lost_rupees', header: 'Revenue Lost', render: (r: ModalityRow) => fmtRupees(r.revenue_lost_rupees) },
          ]}
        />
      </Section>

      <Section title="Rollup by chain">
        <DataTable
          rows={chainRows}
          rowKey={(r, i) => String(r.chain_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name },
            { key: 'hospital_count', header: 'Hospitals', render: (r: ChainRow) => String(r.hospital_count) },
            { key: 'avg_uptime', header: 'Avg Uptime', render: (r: ChainRow) => pct(r.avg_uptime) },
            { key: 'total_breaches', header: 'Breaches', render: (r: ChainRow) => String(r.total_breaches) },
            { key: 'red_cohorts', header: 'Red Cohorts', render: (r: ChainRow) => String(r.red_cohorts) },
          ]}
        />
      </Section>

      <Section title="Asset cohort risk (uptime & MTTR <= benchmark)">
        <DataTable
          rows={cohortRows}
          rowKey={(r, i) => String(r.asset_cohort ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'asset_cohort', header: 'Cohort', render: (r: CohortRow) => r.asset_cohort },
            { key: 'fleet_size', header: 'Fleet', render: (r: CohortRow) => String(r.fleet_size) },
            { key: 'avg_uptime', header: 'Avg Uptime', render: (r: CohortRow) => pct(r.avg_uptime) },
            { key: 'avg_mttr', header: 'Avg MTTR (h)', render: (r: CohortRow) => String(r.avg_mttr) },
            { key: 'red_cohorts', header: 'Red Cohorts', render: (r: CohortRow) => String(r.red_cohorts) },
          ]}
        />
      </Section>

      <Section title="Interventions ledger">
        <DataTable
          rows={intRows}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: InterventionRow) => r.chain_name },
            { key: 'modality', header: 'Modality', render: (r: InterventionRow) => r.modality.toUpperCase() },
            { key: 'intervention_type', header: 'Type', render: (r: InterventionRow) => r.intervention_type.replace(/_/g, ' ') },
            { key: 'initiated_at', header: 'Initiated', render: (r: InterventionRow) => r.initiated_at },
            { key: 'cost_rupees', header: 'Cost', render: (r: InterventionRow) => fmtRupees(r.cost_rupees) },
            { key: 'uptime_delta_pct', header: 'Uptime Delta', render: (r: InterventionRow) => pct(r.uptime_delta_pct) },
            { key: 'outcome', header: 'Outcome', render: (r: InterventionRow) => r.outcome },
            { key: 'followup_required', header: 'Follow-up', render: (r: InterventionRow) => (r.followup_required ? 'yes' : 'no') },
            { key: 'notes', header: 'Notes', render: (r: InterventionRow) => r.notes || '' },
          ]}
        />
      </Section>

      <Section title="Intervention ROI by type">
        <DataTable
          rows={roiRows}
          rowKey={(r, i) => String(r.intervention_type ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'intervention_type', header: 'Type', render: (r: RoiRow) => r.intervention_type.replace(/_/g, ' ') },
            { key: 'total_cost', header: 'Total Cost', render: (r: RoiRow) => fmtRupees(r.total_cost) },
            { key: 'avg_uptime_delta', header: 'Avg Delta', render: (r: RoiRow) => pct(r.avg_uptime_delta) },
            { key: 'successful_count', header: 'Successful', render: (r: RoiRow) => String(r.successful_count) },
            { key: 'pending_count', header: 'Pending', render: (r: RoiRow) => String(r.pending_count) },
          ]}
        />
      </Section>

      <Section title="Outcome mix">
        <DataTable
          rows={outcomeRows}
          rowKey={(r, i) => String(r.outcome ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
            { key: 'count', header: 'Count', render: (r: OutcomeRow) => String(r.count) },
            { key: 'total_cost', header: 'Total Cost', render: (r: OutcomeRow) => fmtRupees(r.total_cost) },
            { key: 'avg_delta', header: 'Avg Delta', render: (r: OutcomeRow) => pct(r.avg_delta) },
          ]}
        />
      </Section>
    </div>
  );
}

function Kpi({ label, value, accent }: { label: string; value: string; accent?: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: 'white' }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, color: accent || '#111827', marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>{title}</h2>
      {children}
    </section>
  );
}
