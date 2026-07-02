import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Incident = {
  id: string;
  incident_month: string;
  engineer_code: string;
  engineer_tier: string;
  hospital_name: string;
  city: string;
  incident_date: string;
  incident_type: string;
  severity: string;
  damage_estimate_rupees: number;
  reimbursement_status: string;
  reimbursed_rupees: number;
  payout_clawback_rupees: number;
  customer_satisfaction: string;
  photo_evidence_count: number;
  resolution_days: number | null;
};

type Scorecard = {
  id: string;
  scorecard_month: string;
  engineer_code: string;
  engineer_tier: string;
  jobs_completed: number;
  incidents_logged: number;
  damage_rate_pct: number;
  total_damage_rupees: number;
  total_clawback_rupees: number;
  net_payout_impact_rupees: number;
  training_required: boolean;
  warning_letter_issued: boolean;
  probation_status: string;
  coaching_session_count: number;
  trend_vs_prev_month: string;
};

type Offender = {
  engineer_code: string;
  engineer_tier: string;
  incidents: number;
  total_damage_rupees: number;
  total_clawback_rupees: number;
  severe_count: number;
};

type SeverityRow = {
  severity: string;
  incident_count: number;
  total_damage_rupees: number;
  avg_damage_rupees: number;
};

type TypeRow = {
  incident_type: string;
  count: number;
  total_rupees: number;
  denied_disputed: number;
};

type CityRow = {
  city: string;
  incidents: number;
  total_damage_rupees: number;
  unresolved: number;
};

type TrendRow = {
  trend: string;
  engineer_count: number;
  avg_damage_rate: number;
  total_clawback: number;
};

type Kpi = {
  total_incidents: number;
  total_damage_rupees: number;
  total_clawback_rupees: number;
  engineers_on_probation: number;
  severe_incidents: number;
  pending_reimbursement: number;
};

function rupees(n: number | null | undefined): string {
  if (n == null) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, incidentsRes, offendersRes, severityRes, probationRes, typeRes, cityRes, trendRes] = await Promise.all([
    supabase.rpc('founder_r2894_kpi_overview'),
    supabase.rpc('founder_r2894_recent_incidents'),
    supabase.rpc('founder_r2894_worst_offenders'),
    supabase.rpc('founder_r2894_severity_breakdown'),
    supabase.rpc('founder_r2894_probation_scorecards'),
    supabase.rpc('founder_r2894_incident_type_distribution'),
    supabase.rpc('founder_r2894_city_hotspots'),
    supabase.rpc('founder_r2894_trend_analysis'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? {
    total_incidents: 0,
    total_damage_rupees: 0,
    total_clawback_rupees: 0,
    engineers_on_probation: 0,
    severe_incidents: 0,
    pending_reimbursement: 0,
  };
  const incidents: Incident[] = (incidentsRes.data as Incident[]) ?? [];
  const offenders: Offender[] = (offendersRes.data as Offender[]) ?? [];
  const severity: SeverityRow[] = (severityRes.data as SeverityRow[]) ?? [];
  const probation: Scorecard[] = (probationRes.data as Scorecard[]) ?? [];
  const types: TypeRow[] = (typeRes.data as TypeRow[]) ?? [];
  const cities: CityRow[] = (cityRes.data as CityRow[]) ?? [];
  const trends: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];

  const incidentCols: Column<Incident>[] = [
    { key: 'incident_date', header: 'Date', render: (r) => new Date(r.incident_date).toLocaleDateString('en-IN') },
    { key: 'engineer_code', header: 'Engineer' },
    { key: 'engineer_tier', header: 'Tier' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'city', header: 'City' },
    { key: 'incident_type', header: 'Type' },
    { key: 'severity', header: 'Severity' },
    { key: 'damage_estimate_rupees', header: 'Damage', render: (r) => rupees(r.damage_estimate_rupees) },
    { key: 'reimbursement_status', header: 'Status' },
    { key: 'payout_clawback_rupees', header: 'Clawback', render: (r) => rupees(r.payout_clawback_rupees) },
    { key: 'customer_satisfaction', header: 'Customer' },
  ];

  const offenderCols: Column<Offender>[] = [
    { key: 'engineer_code', header: 'Engineer' },
    { key: 'engineer_tier', header: 'Tier' },
    { key: 'incidents', header: 'Incidents' },
    { key: 'total_damage_rupees', header: 'Total Damage', render: (r) => rupees(r.total_damage_rupees) },
    { key: 'total_clawback_rupees', header: 'Clawback', render: (r) => rupees(r.total_clawback_rupees) },
    { key: 'severe_count', header: 'Severe' },
  ];

  const severityCols: Column<SeverityRow>[] = [
    { key: 'severity', header: 'Severity' },
    { key: 'incident_count', header: 'Count' },
    { key: 'total_damage_rupees', header: 'Total', render: (r) => rupees(r.total_damage_rupees) },
    { key: 'avg_damage_rupees', header: 'Avg', render: (r) => rupees(r.avg_damage_rupees) },
  ];

  const probationCols: Column<Scorecard>[] = [
    { key: 'engineer_code', header: 'Engineer' },
    { key: 'engineer_tier', header: 'Tier' },
    { key: 'jobs_completed', header: 'Jobs' },
    { key: 'incidents_logged', header: 'Incidents' },
    { key: 'damage_rate_pct', header: 'Rate %', render: (r) => r.damage_rate_pct + '%' },
    { key: 'total_damage_rupees', header: 'Damage', render: (r) => rupees(r.total_damage_rupees) },
    { key: 'net_payout_impact_rupees', header: 'Net Impact', render: (r) => rupees(r.net_payout_impact_rupees) },
    { key: 'probation_status', header: 'Status' },
    { key: 'coaching_session_count', header: 'Coaching' },
    { key: 'trend_vs_prev_month', header: 'Trend' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'incident_type', header: 'Type' },
    { key: 'count', header: 'Count' },
    { key: 'total_rupees', header: 'Total', render: (r) => rupees(r.total_rupees) },
    { key: 'denied_disputed', header: 'Denied/Disputed' },
  ];

  const cityCols: Column<CityRow>[] = [
    { key: 'city', header: 'City' },
    { key: 'incidents', header: 'Incidents' },
    { key: 'total_damage_rupees', header: 'Damage', render: (r) => rupees(r.total_damage_rupees) },
    { key: 'unresolved', header: 'Unresolved' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'trend', header: 'Trend' },
    { key: 'engineer_count', header: 'Engineers' },
    { key: 'avg_damage_rate', header: 'Avg Rate %', render: (r) => r.avg_damage_rate + '%' },
    { key: 'total_clawback', header: 'Clawback', render: (r) => rupees(r.total_clawback) },
  ];

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Customer Premises Damage Incident Log</h1>
        <p className="text-sm text-gray-600 mt-1">
          Founder accountability surface — every dent, scratch & drop at customer premises tied to the engineer who caused it.
          Clawback tracking, probation ladder & monthly trend signal who needs coaching, a warning letter, or removal.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <KpiCard label="Total Incidents" value={String(kpi.total_incidents)} />
        <KpiCard label="Total Damage" value={rupees(kpi.total_damage_rupees)} />
        <KpiCard label="Clawback Recovered" value={rupees(kpi.total_clawback_rupees)} />
        <KpiCard label="On Probation" value={String(kpi.engineers_on_probation)} />
        <KpiCard label="Severe Incidents" value={String(kpi.severe_incidents)} />
        <KpiCard label="Pending Reimbursement" value={String(kpi.pending_reimbursement)} />
      </section>

      <Section title="Recent Incidents (Last 25)">
        <DataTable
          rows={incidents}
          columns={incidentCols}
          emptyMessage="No incidents logged."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Worst Offenders (by Damage Total)">
        <DataTable
          rows={offenders}
          columns={offenderCols}
          emptyMessage="No engineers flagged."
          rowKey={(r, i) => String(r.engineer_code ?? i)}
        />
      </Section>

      <Section title="Severity Breakdown">
        <DataTable
          rows={severity}
          columns={severityCols}
          emptyMessage="No severity data."
          rowKey={(r, i) => String(r.severity ?? i)}
        />
      </Section>

      <Section title="Engineers on Watch / Probation / Final Warning">
        <DataTable
          rows={probation}
          columns={probationCols}
          emptyMessage="No engineers on probation."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Incident Type Distribution">
        <DataTable
          rows={types}
          columns={typeCols}
          emptyMessage="No incident types."
          rowKey={(r, i) => String(r.incident_type ?? i)}
        />
      </Section>

      <Section title="City-wise Damage Hotspots">
        <DataTable
          rows={cities}
          columns={cityCols}
          emptyMessage="No city data."
          rowKey={(r, i) => String(r.city ?? i)}
        />
      </Section>

      <Section title="Month-over-Month Trend Analysis">
        <DataTable
          rows={trends}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.trend ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-3">
      <h2 className="text-lg font-semibold">{title}</h2>
      {children}
    </section>
  );
}
