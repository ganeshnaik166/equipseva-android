import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_audits: number;
  critical_drift: number;
  red_burn_risk: number;
  calibration_due: number;
  total_burn_incidents: number;
  exposed_patients: number;
  founder_reviewed_pct: number | null;
};

type HospitalRiskRow = {
  hospital_name: string;
  audits: number;
  avg_drift: number;
  max_burn_score: number;
  red_count: number;
  incidents: number;
};

type WardRow = {
  ward: string;
  audits: number;
  avg_drift: number;
  avg_burn_score: number;
  exposed: number;
};

type EngineerRow = {
  engineer_name: string;
  audits: number;
  severe_critical: number;
  calibrations_closed: number;
  founder_reviewed: number;
};

type TrendRow = {
  audit_month: string;
  audits: number;
  avg_drift: number;
  red_count: number;
  incidents: number;
};

type RemediationRow = {
  action_type: string;
  actions: number;
  resolved: number;
  in_progress: number;
  pending: number;
  total_parts_cost: number;
  total_labor_minutes: number;
};

type CriticalQueueRow = {
  hospital_name: string;
  warmer_asset_tag: string;
  ward: string;
  drift_celsius: number;
  burn_risk_score: number;
  burn_risk_band: string;
  status: string;
  engineer_name: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summary, hospitals, wards, engineers, trend, remediation, critical] = await Promise.all([
    supabase.rpc('r3070_summary'),
    supabase.rpc('r3070_hospital_risk'),
    supabase.rpc('r3070_ward_breakdown'),
    supabase.rpc('r3070_engineer_performance'),
    supabase.rpc('r3070_monthly_trend'),
    supabase.rpc('r3070_remediation_summary'),
    supabase.rpc('r3070_open_critical_queue'),
  ]);

  const s: SummaryRow | null = (summary.data?.[0] as SummaryRow) ?? null;
  const hospitalRows: HospitalRiskRow[] = (hospitals.data ?? []) as HospitalRiskRow[];
  const wardRows: WardRow[] = (wards.data ?? []) as WardRow[];
  const engineerRows: EngineerRow[] = (engineers.data ?? []) as EngineerRow[];
  const trendRows: TrendRow[] = (trend.data ?? []) as TrendRow[];
  const remediationRows: RemediationRow[] = (remediation.data ?? []) as RemediationRow[];
  const criticalRows: CriticalQueueRow[] = (critical.data ?? []) as CriticalQueueRow[];

  const hospitalColumns: Column<HospitalRiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_drift', header: 'Avg drift °C' },
    { key: 'max_burn_score', header: 'Max burn score' },
    { key: 'red_count', header: 'Red band' },
    { key: 'incidents', header: 'Burn incidents' },
  ];

  const wardColumns: Column<WardRow>[] = [
    { key: 'ward', header: 'Ward' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_drift', header: 'Avg drift °C' },
    { key: 'avg_burn_score', header: 'Avg burn score' },
    { key: 'exposed', header: 'Patients exposed' },
  ];

  const engineerColumns: Column<EngineerRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'audits', header: 'Audits' },
    { key: 'severe_critical', header: 'Severe / critical' },
    { key: 'calibrations_closed', header: 'Closed' },
    { key: 'founder_reviewed', header: 'Founder reviewed' },
  ];

  const trendColumns: Column<TrendRow>[] = [
    { key: 'audit_month', header: 'Month' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_drift', header: 'Avg drift °C' },
    { key: 'red_count', header: 'Red band' },
    { key: 'incidents', header: 'Incidents' },
  ];

  const remediationColumns: Column<RemediationRow>[] = [
    { key: 'action_type', header: 'Action' },
    { key: 'actions', header: 'Actions' },
    { key: 'resolved', header: 'Resolved' },
    { key: 'in_progress', header: 'In progress' },
    { key: 'pending', header: 'Pending' },
    { key: 'total_parts_cost', header: 'Parts ₹' },
    { key: 'total_labor_minutes', header: 'Labor mins' },
  ];

  const criticalColumns: Column<CriticalQueueRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'warmer_asset_tag', header: 'Asset' },
    { key: 'ward', header: 'Ward' },
    { key: 'drift_celsius', header: 'Drift °C' },
    { key: 'burn_risk_score', header: 'Burn score' },
    { key: 'burn_risk_band', header: 'Band' },
    { key: 'status', header: 'Status' },
    { key: 'engineer_name', header: 'Engineer' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">
          Engineer Monthly Customer Site Patient Warmer Skin-Sensor Drift &amp; Burn-Risk Audit
        </h1>
        <p className="text-sm text-gray-600">
          Round r3070 — founder review of skin-sensor drift &gt;= 1.5 °C and burn-risk bands.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Total audits</div>
          <div className="text-xl font-semibold">{s?.total_audits ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Severe/critical drift</div>
          <div className="text-xl font-semibold">{s?.critical_drift ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Red burn-risk</div>
          <div className="text-xl font-semibold">{s?.red_burn_risk ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Calibration due</div>
          <div className="text-xl font-semibold">{s?.calibration_due ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Burn incidents</div>
          <div className="text-xl font-semibold">{s?.total_burn_incidents ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Patients exposed</div>
          <div className="text-xl font-semibold">{s?.exposed_patients ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Founder reviewed %</div>
          <div className="text-xl font-semibold">{s?.founder_reviewed_pct ?? 0}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hospital risk</h2>
        <DataTable
          rows={hospitalRows}
          columns={hospitalColumns}
          emptyMessage="No hospital risk rows."
          rowKey={(r, i) => String((r as { hospital_name?: string }).hospital_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Ward breakdown</h2>
        <DataTable
          rows={wardRows}
          columns={wardColumns}
          emptyMessage="No ward rows."
          rowKey={(r, i) => String((r as { ward?: string }).ward ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer performance</h2>
        <DataTable
          rows={engineerRows}
          columns={engineerColumns}
          emptyMessage="No engineer rows."
          rowKey={(r, i) => String((r as { engineer_name?: string }).engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendColumns}
          emptyMessage="No trend rows."
          rowKey={(r, i) => String((r as { audit_month?: string }).audit_month ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Remediation summary</h2>
        <DataTable
          rows={remediationRows}
          columns={remediationColumns}
          emptyMessage="No remediation rows."
          rowKey={(r, i) => String((r as { action_type?: string }).action_type ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open critical queue (burn-risk &gt;= orange or status open/escalated)</h2>
        <DataTable
          rows={criticalRows}
          columns={criticalColumns}
          emptyMessage="No critical queue rows."
          rowKey={(r, i) => String((r as { warmer_asset_tag?: string }).warmer_asset_tag ?? i)}
        />
      </section>
    </div>
  );
}
