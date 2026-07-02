import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Incident = {
  incident_code: string;
  engineer_name: string;
  customer_name: string;
  hospital_name: string;
  incident_date: string;
  severity: string;
  category: string;
  apology_status: string;
  resolution_status: string;
  repeat_risk_level: string;
};

type EngineerSummary = {
  engineer_code: string;
  engineer_name: string;
  total_incidents: number;
  severe_or_critical_count: number;
  open_incidents: number;
  avg_csat: number;
  repeat_risk_score: number;
  coaching_status: string;
  recommended_action: string;
};

type SeverityRow = {
  severity: string;
  incident_count: number;
  avg_csat: number;
};

type CategoryRow = {
  category: string;
  incident_count: number;
  witness_count: number;
};

type ApologyRow = {
  apology_status: string;
  incident_count: number;
};

type HighRiskRow = {
  engineer_code: string;
  engineer_name: string;
  repeat_risk_score: number;
  recommended_action: string;
  coaching_status: string;
  last_coaching_date: string | null;
};

type MonthlyRow = {
  incident_month: string;
  incident_count: number;
  severe_count: number;
  avg_csat: number;
};

type Kpi = {
  total_incidents: number;
  critical_count: number;
  open_count: number;
  avg_csat: number;
  high_risk_engineers: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, incidentsRes, engineersRes, severityRes, categoryRes, apologyRes, highRiskRes, monthlyRes] = await Promise.all([
    supabase.rpc('founder_r2806_kpi_summary'),
    supabase.rpc('founder_r2806_list_incidents'),
    supabase.rpc('founder_r2806_engineer_summary'),
    supabase.rpc('founder_r2806_severity_breakdown'),
    supabase.rpc('founder_r2806_category_breakdown'),
    supabase.rpc('founder_r2806_apology_distribution'),
    supabase.rpc('founder_r2806_high_risk_engineers'),
    supabase.rpc('founder_r2806_monthly_trend'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? {
    total_incidents: 0,
    critical_count: 0,
    open_count: 0,
    avg_csat: 0,
    high_risk_engineers: 0,
  };

  const incidents: Incident[] = (incidentsRes.data as Incident[]) ?? [];
  const engineers: EngineerSummary[] = (engineersRes.data as EngineerSummary[]) ?? [];
  const severity: SeverityRow[] = (severityRes.data as SeverityRow[]) ?? [];
  const category: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const apology: ApologyRow[] = (apologyRes.data as ApologyRow[]) ?? [];
  const highRisk: HighRiskRow[] = (highRiskRes.data as HighRiskRow[]) ?? [];
  const monthly: MonthlyRow[] = (monthlyRes.data as MonthlyRow[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Engineer Monthly Customer Rude Incident Tracker</h1>
        <p className="text-sm text-gray-600">Track engineer rudeness incidents: severity, witness, apology, resolution, repeat risk.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Total Incidents</div>
          <div className="text-2xl font-bold">{kpi.total_incidents}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Severe / Critical</div>
          <div className="text-2xl font-bold">{kpi.critical_count}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Open / Investigating</div>
          <div className="text-2xl font-bold">{kpi.open_count}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Avg CSAT</div>
          <div className="text-2xl font-bold">{Number(kpi.avg_csat).toFixed(2)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">High Risk Engineers (score &gt;= 70)</div>
          <div className="text-2xl font-bold">{kpi.high_risk_engineers}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Incidents</h2>
        <DataTable
          rows={incidents}
          columns={[
            { key: 'incident_code', header: 'Code', render: (r: Incident) => r.incident_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: Incident) => r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: Incident) => r.customer_name },
            { key: 'hospital_name', header: 'Hospital', render: (r: Incident) => r.hospital_name },
            { key: 'incident_date', header: 'Date', render: (r: Incident) => r.incident_date },
            { key: 'severity', header: 'Severity', render: (r: Incident) => r.severity },
            { key: 'category', header: 'Category', render: (r: Incident) => r.category },
            { key: 'apology_status', header: 'Apology', render: (r: Incident) => r.apology_status },
            { key: 'resolution_status', header: 'Resolution', render: (r: Incident) => r.resolution_status },
            { key: 'repeat_risk_level', header: 'Repeat Risk', render: (r: Incident) => r.repeat_risk_level },
          ]}
          emptyMessage="No data"
          rowKey={(r: Incident, i: number) => String(r.incident_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Summary (sorted by repeat risk score)</h2>
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: EngineerSummary) => r.engineer_code },
            { key: 'engineer_name', header: 'Name', render: (r: EngineerSummary) => r.engineer_name },
            { key: 'total_incidents', header: 'Total', render: (r: EngineerSummary) => r.total_incidents },
            { key: 'severe_or_critical_count', header: 'Severe', render: (r: EngineerSummary) => r.severe_or_critical_count },
            { key: 'open_incidents', header: 'Open', render: (r: EngineerSummary) => r.open_incidents },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: EngineerSummary) => Number(r.avg_csat).toFixed(2) },
            { key: 'repeat_risk_score', header: 'Risk Score', render: (r: EngineerSummary) => r.repeat_risk_score },
            { key: 'coaching_status', header: 'Coaching', render: (r: EngineerSummary) => r.coaching_status },
            { key: 'recommended_action', header: 'Action', render: (r: EngineerSummary) => r.recommended_action },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerSummary, i: number) => String(r.engineer_code ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Severity Breakdown</h2>
          <DataTable
            rows={severity}
            columns={[
              { key: 'severity', header: 'Severity', render: (r: SeverityRow) => r.severity },
              { key: 'incident_count', header: 'Count', render: (r: SeverityRow) => r.incident_count },
              { key: 'avg_csat', header: 'Avg CSAT', render: (r: SeverityRow) => Number(r.avg_csat).toFixed(2) },
            ]}
            emptyMessage="No data"
            rowKey={(r: SeverityRow, i: number) => String(r.severity ?? i)}
          />
        </div>

        <div>
          <h2 className="text-lg font-semibold mb-2">Category Breakdown</h2>
          <DataTable
            rows={category}
            columns={[
              { key: 'category', header: 'Category', render: (r: CategoryRow) => r.category },
              { key: 'incident_count', header: 'Count', render: (r: CategoryRow) => r.incident_count },
              { key: 'witness_count', header: 'With Witness', render: (r: CategoryRow) => r.witness_count },
            ]}
            emptyMessage="No data"
            rowKey={(r: CategoryRow, i: number) => String(r.category ?? i)}
          />
        </div>
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Apology Status Distribution</h2>
          <DataTable
            rows={apology}
            columns={[
              { key: 'apology_status', header: 'Status', render: (r: ApologyRow) => r.apology_status },
              { key: 'incident_count', header: 'Count', render: (r: ApologyRow) => r.incident_count },
            ]}
            emptyMessage="No data"
            rowKey={(r: ApologyRow, i: number) => String(r.apology_status ?? i)}
          />
        </div>

        <div>
          <h2 className="text-lg font-semibold mb-2">Monthly Trend</h2>
          <DataTable
            rows={monthly}
            columns={[
              { key: 'incident_month', header: 'Month', render: (r: MonthlyRow) => r.incident_month },
              { key: 'incident_count', header: 'Total', render: (r: MonthlyRow) => r.incident_count },
              { key: 'severe_count', header: 'Severe', render: (r: MonthlyRow) => r.severe_count },
              { key: 'avg_csat', header: 'Avg CSAT', render: (r: MonthlyRow) => Number(r.avg_csat).toFixed(2) },
            ]}
            emptyMessage="No data"
            rowKey={(r: MonthlyRow, i: number) => String(r.incident_month ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">High Risk Engineers (score &gt;= 50)</h2>
        <DataTable
          rows={highRisk}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: HighRiskRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Name', render: (r: HighRiskRow) => r.engineer_name },
            { key: 'repeat_risk_score', header: 'Risk Score', render: (r: HighRiskRow) => r.repeat_risk_score },
            { key: 'recommended_action', header: 'Action', render: (r: HighRiskRow) => r.recommended_action },
            { key: 'coaching_status', header: 'Coaching', render: (r: HighRiskRow) => r.coaching_status },
            { key: 'last_coaching_date', header: 'Last Coached', render: (r: HighRiskRow) => r.last_coaching_date ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: HighRiskRow, i: number) => String(r.engineer_code ?? i)}
        />
      </section>
    </div>
  );
}
