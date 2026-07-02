import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_incidents: number;
  near_miss: number;
  recordable: number;
  lost_time: number;
  critical_severity: number;
  total_downtime_min: number;
  avg_safety_score: number;
};

type Incident = {
  incident_date: string;
  engineer_name: string;
  city: string;
  incident_kind: string;
  severity: string;
  root_cause: string;
  outcome: string;
  downtime_minutes: number;
  hospital_partner: string | null;
};

type RootCause = {
  root_cause: string;
  incident_count: number;
  total_downtime_min: number;
  share_pct: number;
};

type Severity = {
  severity: string;
  incident_count: number;
  share_pct: number;
};

type Scorecard = {
  engineer_name: string;
  city: string;
  total_incidents: number;
  near_miss_count: number;
  recordable_count: number;
  ppe_compliance_pct: number;
  training_hours: number;
  safety_score: number;
  status: string;
};

type AtRisk = {
  engineer_name: string;
  city: string;
  safety_score: number;
  ppe_compliance_pct: number;
  status: string;
};

type Corrective = {
  incident_date: string;
  engineer_name: string;
  corrective_action: string;
  prevention_measure: string;
  outcome: string;
};

type CityRow = {
  city: string;
  incidents: number;
  total_downtime_min: number;
  avg_score: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, incidentsRes, rootRes, sevRes, scoreRes, riskRes, corrRes, cityRes] = await Promise.all([
    supabase.rpc('founder_r2698_safety_kpis'),
    supabase.rpc('founder_r2698_incident_list'),
    supabase.rpc('founder_r2698_root_cause_breakdown'),
    supabase.rpc('founder_r2698_severity_mix'),
    supabase.rpc('founder_r2698_engineer_scorecard'),
    supabase.rpc('founder_r2698_at_risk_engineers'),
    supabase.rpc('founder_r2698_corrective_actions'),
    supabase.rpc('founder_r2698_city_rollup'),
  ]);

  const kpis: Kpis = (kpisRes.data?.[0] as Kpis) ?? {
    total_incidents: 0,
    near_miss: 0,
    recordable: 0,
    lost_time: 0,
    critical_severity: 0,
    total_downtime_min: 0,
    avg_safety_score: 0,
  };
  const incidents: Incident[] = (incidentsRes.data as Incident[]) ?? [];
  const roots: RootCause[] = (rootRes.data as RootCause[]) ?? [];
  const sevs: Severity[] = (sevRes.data as Severity[]) ?? [];
  const scores: Scorecard[] = (scoreRes.data as Scorecard[]) ?? [];
  const risks: AtRisk[] = (riskRes.data as AtRisk[]) ?? [];
  const corrs: Corrective[] = (corrRes.data as Corrective[]) ?? [];
  const cities: CityRow[] = (cityRes.data as CityRow[]) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Safety Incident & Near-Miss Log</h1>
        <p className="text-sm text-gray-600">
          Round r2698 — incident kind × severity × root cause × corrective action × outcome × prevention
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Kpi label="Total Incidents" value={kpis.total_incidents} />
        <Kpi label="Near Misses" value={kpis.near_miss} />
        <Kpi label="Recordable" value={kpis.recordable} />
        <Kpi label="Lost Time" value={kpis.lost_time} />
        <Kpi label="Critical (S1)" value={kpis.critical_severity} />
        <Kpi label="Downtime (min)" value={kpis.total_downtime_min} />
        <Kpi label="Avg Safety Score" value={kpis.avg_safety_score} />
        <Kpi label="Engineers Tracked" value={scores.length} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Incident Log</h2>
        <DataTable
          rows={incidents}
          columns={[
            { key: 'incident_date', header: 'Date', render: (r: Incident) => <span>{r.incident_date}</span> },
            { key: 'engineer_name', header: 'Engineer', render: (r: Incident) => <span>{r.engineer_name}</span> },
            { key: 'city', header: 'City', render: (r: Incident) => <span>{r.city}</span> },
            { key: 'incident_kind', header: 'Kind', render: (r: Incident) => <span>{r.incident_kind}</span> },
            { key: 'severity', header: 'Severity', render: (r: Incident) => <span>{r.severity}</span> },
            { key: 'root_cause', header: 'Root Cause', render: (r: Incident) => <span>{r.root_cause}</span> },
            { key: 'outcome', header: 'Outcome', render: (r: Incident) => <span>{r.outcome}</span> },
            { key: 'downtime_minutes', header: 'Downtime min', render: (r: Incident) => <span>{r.downtime_minutes}</span> },
            { key: 'hospital_partner', header: 'Hospital', render: (r: Incident) => <span>{r.hospital_partner ?? '—'}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Incident, i: number) => String(i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Root Cause Breakdown</h2>
          <DataTable
            rows={roots}
            columns={[
              { key: 'root_cause', header: 'Root Cause', render: (r: RootCause) => <span>{r.root_cause}</span> },
              { key: 'incident_count', header: 'Count', render: (r: RootCause) => <span>{r.incident_count}</span> },
              { key: 'total_downtime_min', header: 'Downtime min', render: (r: RootCause) => <span>{r.total_downtime_min}</span> },
              { key: 'share_pct', header: 'Share %', render: (r: RootCause) => <span>{r.share_pct}</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: RootCause, i: number) => String(i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Severity Mix</h2>
          <DataTable
            rows={sevs}
            columns={[
              { key: 'severity', header: 'Severity', render: (r: Severity) => <span>{r.severity}</span> },
              { key: 'incident_count', header: 'Count', render: (r: Severity) => <span>{r.incident_count}</span> },
              { key: 'share_pct', header: 'Share %', render: (r: Severity) => <span>{r.share_pct}</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: Severity, i: number) => String(i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Monthly Scorecard</h2>
        <DataTable
          rows={scores}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Scorecard) => <span>{r.engineer_name}</span> },
            { key: 'city', header: 'City', render: (r: Scorecard) => <span>{r.city}</span> },
            { key: 'total_incidents', header: 'Incidents', render: (r: Scorecard) => <span>{r.total_incidents}</span> },
            { key: 'near_miss_count', header: 'Near Miss', render: (r: Scorecard) => <span>{r.near_miss_count}</span> },
            { key: 'recordable_count', header: 'Recordable', render: (r: Scorecard) => <span>{r.recordable_count}</span> },
            { key: 'ppe_compliance_pct', header: 'PPE %', render: (r: Scorecard) => <span>{r.ppe_compliance_pct}</span> },
            { key: 'training_hours', header: 'Training hrs', render: (r: Scorecard) => <span>{r.training_hours}</span> },
            { key: 'safety_score', header: 'Score', render: (r: Scorecard) => <span>{r.safety_score}</span> },
            { key: 'status', header: 'Status', render: (r: Scorecard) => <span>{r.status}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Scorecard, i: number) => String(i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">At-Risk Engineers (score &lt;= watch)</h2>
          <DataTable
            rows={risks}
            columns={[
              { key: 'engineer_name', header: 'Engineer', render: (r: AtRisk) => <span>{r.engineer_name}</span> },
              { key: 'city', header: 'City', render: (r: AtRisk) => <span>{r.city}</span> },
              { key: 'safety_score', header: 'Score', render: (r: AtRisk) => <span>{r.safety_score}</span> },
              { key: 'ppe_compliance_pct', header: 'PPE %', render: (r: AtRisk) => <span>{r.ppe_compliance_pct}</span> },
              { key: 'status', header: 'Status', render: (r: AtRisk) => <span>{r.status}</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: AtRisk, i: number) => String(i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">City Rollup</h2>
          <DataTable
            rows={cities}
            columns={[
              { key: 'city', header: 'City', render: (r: CityRow) => <span>{r.city}</span> },
              { key: 'incidents', header: 'Incidents', render: (r: CityRow) => <span>{r.incidents}</span> },
              { key: 'total_downtime_min', header: 'Downtime min', render: (r: CityRow) => <span>{r.total_downtime_min}</span> },
              { key: 'avg_score', header: 'Avg Score', render: (r: CityRow) => <span>{r.avg_score}</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: CityRow, i: number) => String(i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Corrective Actions & Prevention</h2>
        <DataTable
          rows={corrs}
          columns={[
            { key: 'incident_date', header: 'Date', render: (r: Corrective) => <span>{r.incident_date}</span> },
            { key: 'engineer_name', header: 'Engineer', render: (r: Corrective) => <span>{r.engineer_name}</span> },
            { key: 'corrective_action', header: 'Corrective Action', render: (r: Corrective) => <span>{r.corrective_action}</span> },
            { key: 'prevention_measure', header: 'Prevention', render: (r: Corrective) => <span>{r.prevention_measure}</span> },
            { key: 'outcome', header: 'Outcome', render: (r: Corrective) => <span>{r.outcome}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Corrective, i: number) => String(i)}
        />
      </section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-lg border bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}
