import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  engineers_scored: number;
  total_handovers: number;
  total_breaches: number;
  patient_complaints: number;
  suspension_review_count: number;
  coaching_required_count: number;
  avg_discipline_score: number;
  avg_nps_delta: number;
};

type ScoreRow = {
  engineer_code: string;
  engineer_name: string;
  region: string;
  handovers_total: number;
  quiet_breach_count: number;
  ward_disturbance_complaints: number;
  nps_delta: number;
  discipline_score: number;
  verdict: string;
};

type IncidentRow = {
  incident_at: string;
  engineer_code: string;
  hospital_code: string;
  ward: string;
  handover_type: string;
  breach_type: string;
  decibel_peak: number;
  patient_count_in_range: number;
  complaint_severity: string;
  customer_verdict: string;
  founder_action: string;
};

type VerdictRow = { verdict: string; engineer_count: number; pct_of_total: number };
type HeatRow = {
  breach_type: string;
  incidents: number;
  avg_decibel: number;
  patients_affected: number;
  complaints_filed: number;
};
type ImpactRow = {
  engineer_code: string;
  engineer_name: string;
  patient_complaints: number;
  total_patients_disturbed: number;
  worst_severity: string;
};
type ActionRow = { founder_action: string; incidents: number; engineers_touched: number };
type TopRow = {
  engineer_code: string;
  engineer_name: string;
  region: string;
  discipline_score: number;
  nps_delta: number;
  verdict: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, scoreRes, incRes, verdictRes, heatRes, impactRes, actionRes, topRes] =
    await Promise.all([
      supabase.rpc('r2878_kpis'),
      supabase.rpc('r2878_scorecard'),
      supabase.rpc('r2878_incidents'),
      supabase.rpc('r2878_verdict_mix'),
      supabase.rpc('r2878_breach_heatmap'),
      supabase.rpc('r2878_patient_impact'),
      supabase.rpc('r2878_action_ledger'),
      supabase.rpc('r2878_top_exemplary'),
    ]);

  const kpi: Kpi | null = (kpisRes.data?.[0] as Kpi) ?? null;
  const scorecard: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const incidents: IncidentRow[] = (incRes.data as IncidentRow[]) ?? [];
  const verdicts: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const heat: HeatRow[] = (heatRes.data as HeatRow[]) ?? [];
  const impact: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const actions: ActionRow[] = (actionRes.data as ActionRow[]) ?? [];
  const tops: TopRow[] = (topRes.data as TopRow[]) ?? [];

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">
          Engineer Monthly Customer Handover — Quiet-Hours Discipline
        </h1>
        <p className="text-sm text-gray-600">
          Round r2878. Tracks engineer behaviour during repair sign-off &amp; AMC monthly
          handover windows. Decibel peaks &gt;= 70 in patient-present zones, post-22:00 and
          pre-07:00 calls, and ward-disturbance complaints roll up into a 0–100
          discipline score per engineer per cycle. Score &lt; 40 triggers suspension review.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <KpiCard label="Engineers scored" value={kpi?.engineers_scored ?? 0} />
        <KpiCard label="Total handovers" value={kpi?.total_handovers ?? 0} />
        <KpiCard label="Total breaches" value={kpi?.total_breaches ?? 0} />
        <KpiCard label="Patient complaints" value={kpi?.patient_complaints ?? 0} />
        <KpiCard label="Suspension review" value={kpi?.suspension_review_count ?? 0} />
        <KpiCard label="Coaching required" value={kpi?.coaching_required_count ?? 0} />
        <KpiCard label="Avg discipline score" value={kpi?.avg_discipline_score ?? 0} />
        <KpiCard label="Avg NPS delta" value={kpi?.avg_nps_delta ?? 0} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Engineer scorecard (lowest discipline first)</h2>
        <DataTable
          rows={scorecard}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: ScoreRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Name', render: (r: ScoreRow) => r.engineer_name },
            { key: 'region', header: 'Region', render: (r: ScoreRow) => r.region },
            { key: 'handovers_total', header: 'Handovers', render: (r: ScoreRow) => r.handovers_total },
            { key: 'quiet_breach_count', header: 'Breaches', render: (r: ScoreRow) => r.quiet_breach_count },
            {
              key: 'ward_disturbance_complaints',
              header: 'Ward complaints',
              render: (r: ScoreRow) => r.ward_disturbance_complaints,
            },
            { key: 'nps_delta', header: 'NPS delta', render: (r: ScoreRow) => r.nps_delta },
            {
              key: 'discipline_score',
              header: 'Discipline',
              render: (r: ScoreRow) => r.discipline_score,
            },
            { key: 'verdict', header: 'Verdict', render: (r: ScoreRow) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: ScoreRow, i: number) => String(r.engineer_code ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent breach incidents</h2>
        <DataTable
          rows={incidents}
          columns={[
            {
              key: 'incident_at',
              header: 'When',
              render: (r: IncidentRow) => new Date(r.incident_at).toLocaleString(),
            },
            { key: 'engineer_code', header: 'Engineer', render: (r: IncidentRow) => r.engineer_code },
            { key: 'hospital_code', header: 'Hospital', render: (r: IncidentRow) => r.hospital_code },
            { key: 'ward', header: 'Ward', render: (r: IncidentRow) => r.ward },
            { key: 'handover_type', header: 'Handover', render: (r: IncidentRow) => r.handover_type },
            { key: 'breach_type', header: 'Breach', render: (r: IncidentRow) => r.breach_type },
            { key: 'decibel_peak', header: 'dB peak', render: (r: IncidentRow) => r.decibel_peak },
            {
              key: 'patient_count_in_range',
              header: 'Patients',
              render: (r: IncidentRow) => r.patient_count_in_range,
            },
            {
              key: 'complaint_severity',
              header: 'Severity',
              render: (r: IncidentRow) => r.complaint_severity,
            },
            {
              key: 'customer_verdict',
              header: 'Customer verdict',
              render: (r: IncidentRow) => r.customer_verdict,
            },
            {
              key: 'founder_action',
              header: 'Founder action',
              render: (r: IncidentRow) => r.founder_action,
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: IncidentRow, i: number) => String(i)}
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-lg font-medium">Verdict mix</h2>
          <DataTable
            rows={verdicts}
            columns={[
              { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
              {
                key: 'engineer_count',
                header: 'Engineers',
                render: (r: VerdictRow) => r.engineer_count,
              },
              {
                key: 'pct_of_total',
                header: '% of total',
                render: (r: VerdictRow) => `${r.pct_of_total}%`,
              },
            ]}
            emptyMessage="No data"
            rowKey={(r: VerdictRow, i: number) => String(r.verdict ?? i)}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-lg font-medium">Breach-type heatmap</h2>
          <DataTable
            rows={heat}
            columns={[
              { key: 'breach_type', header: 'Breach', render: (r: HeatRow) => r.breach_type },
              { key: 'incidents', header: 'Count', render: (r: HeatRow) => r.incidents },
              { key: 'avg_decibel', header: 'Avg dB', render: (r: HeatRow) => r.avg_decibel },
              {
                key: 'patients_affected',
                header: 'Patients',
                render: (r: HeatRow) => r.patients_affected,
              },
              {
                key: 'complaints_filed',
                header: 'Complaints',
                render: (r: HeatRow) => r.complaints_filed,
              },
            ]}
            emptyMessage="No data"
            rowKey={(r: HeatRow, i: number) => String(r.breach_type ?? i)}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Patient impact per engineer</h2>
        <DataTable
          rows={impact}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: ImpactRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Name', render: (r: ImpactRow) => r.engineer_name },
            {
              key: 'patient_complaints',
              header: 'Complaints',
              render: (r: ImpactRow) => r.patient_complaints,
            },
            {
              key: 'total_patients_disturbed',
              header: 'Patients disturbed',
              render: (r: ImpactRow) => r.total_patients_disturbed,
            },
            {
              key: 'worst_severity',
              header: 'Worst severity',
              render: (r: ImpactRow) => r.worst_severity,
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: ImpactRow, i: number) => String(r.engineer_code ?? i)}
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-lg font-medium">Founder action ledger</h2>
          <DataTable
            rows={actions}
            columns={[
              {
                key: 'founder_action',
                header: 'Action',
                render: (r: ActionRow) => r.founder_action,
              },
              { key: 'incidents', header: 'Incidents', render: (r: ActionRow) => r.incidents },
              {
                key: 'engineers_touched',
                header: 'Engineers',
                render: (r: ActionRow) => r.engineers_touched,
              },
            ]}
            emptyMessage="No data"
            rowKey={(r: ActionRow, i: number) => String(r.founder_action ?? i)}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-lg font-medium">Top exemplary engineers (score &gt;= 80)</h2>
          <DataTable
            rows={tops}
            columns={[
              { key: 'engineer_code', header: 'Engineer', render: (r: TopRow) => r.engineer_code },
              { key: 'engineer_name', header: 'Name', render: (r: TopRow) => r.engineer_name },
              { key: 'region', header: 'Region', render: (r: TopRow) => r.region },
              {
                key: 'discipline_score',
                header: 'Discipline',
                render: (r: TopRow) => r.discipline_score,
              },
              { key: 'nps_delta', header: 'NPS delta', render: (r: TopRow) => r.nps_delta },
              { key: 'verdict', header: 'Verdict', render: (r: TopRow) => r.verdict },
            ]}
            emptyMessage="No data"
            rowKey={(r: TopRow, i: number) => String(r.engineer_code ?? i)}
          />
        </div>
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}
