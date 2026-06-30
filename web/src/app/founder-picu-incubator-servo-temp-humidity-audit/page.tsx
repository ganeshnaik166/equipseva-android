import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type WardRow = {
  ward_code: string;
  total_audits: number;
  pass_count: number;
  conditional_count: number;
  fail_count: number;
  critical_risk_count: number;
  avg_air_drift_c: number | null;
  avg_humidity_drift_pp: number | null;
};

type ModelRow = {
  incubator_model: string;
  units_audited: number;
  max_air_drift_c: number | null;
  max_humidity_drift_pp: number | null;
  models_with_critical: number;
};

type AlarmRow = {
  alarm_self_test_result: string;
  result_count: number;
  units_with_codes: number;
  share_pct: number | null;
};

type SeverityRow = {
  severity: string;
  total_items: number;
  open_or_in_progress: number;
  closed_or_verified: number;
  escalated_count: number;
  total_cost_rupees: number;
};

type CategoryRow = {
  capa_category: string;
  item_count: number;
  open_count: number;
  avg_target_lead_days: number | null;
  total_actual_rupees: number;
};

type HospitalRow = {
  hospital_name: string;
  audits_this_quarter: number;
  critical_findings: number;
  open_p0_p1_capas: number;
  pass_rate_pct: number | null;
};

type BacklogRow = {
  capa_code: string;
  severity: string;
  capa_category: string;
  hospital_name: string;
  ward_code: string;
  asset_tag: string;
  target_close_date: string;
  days_to_target: number;
  owner_role: string;
  status: string;
};

type ConsumablesRow = {
  servo_probe_condition: string;
  units: number;
  avg_hepa_age_days: number | null;
  units_with_critical_risk: number;
};

function fmtNum(n: number | null | undefined, digits = 2): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(digits);
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return 'Rs. ' + Number(n).toLocaleString('en-IN');
}

export default async function FounderPicuIncubatorAuditPage() {
  const supabase = await getSupabaseServerClient();

  const [
    wardRes,
    modelRes,
    alarmRes,
    severityRes,
    categoryRes,
    hospitalRes,
    backlogRes,
    consumablesRes,
  ] = await Promise.all([
    supabase.rpc('rpc_picu_audit_ward_rollup_r3118'),
    supabase.rpc('rpc_picu_audit_model_drift_r3118'),
    supabase.rpc('rpc_picu_alarm_selftest_r3118'),
    supabase.rpc('rpc_picu_capa_severity_r3118'),
    supabase.rpc('rpc_picu_capa_category_r3118'),
    supabase.rpc('rpc_picu_hospital_scorecard_r3118'),
    supabase.rpc('rpc_picu_open_capa_backlog_r3118'),
    supabase.rpc('rpc_picu_consumables_risk_r3118'),
  ]);

  const wardRows = (wardRes.data ?? []) as WardRow[];
  const modelRows = (modelRes.data ?? []) as ModelRow[];
  const alarmRows = (alarmRes.data ?? []) as AlarmRow[];
  const severityRows = (severityRes.data ?? []) as SeverityRow[];
  const categoryRows = (categoryRes.data ?? []) as CategoryRow[];
  const hospitalRows = (hospitalRes.data ?? []) as HospitalRow[];
  const backlogRows = (backlogRes.data ?? []) as BacklogRow[];
  const consumablesRows = (consumablesRes.data ?? []) as ConsumablesRow[];

  const wardCols: Column<WardRow>[] = [
    { key: 'ward_code', header: 'Ward' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'pass_count', header: 'Pass' },
    { key: 'conditional_count', header: 'Conditional' },
    { key: 'fail_count', header: 'Fail / Rework' },
    { key: 'critical_risk_count', header: 'Critical risk' },
    { key: 'avg_air_drift_c', header: 'Avg air drift (C)', render: (r) => fmtNum(r.avg_air_drift_c, 2) },
    { key: 'avg_humidity_drift_pp', header: 'Avg RH drift (pp)', render: (r) => fmtNum(r.avg_humidity_drift_pp, 2) },
  ];

  const modelCols: Column<ModelRow>[] = [
    { key: 'incubator_model', header: 'Model' },
    { key: 'units_audited', header: 'Units' },
    { key: 'max_air_drift_c', header: 'Max air drift (C)', render: (r) => fmtNum(r.max_air_drift_c, 2) },
    { key: 'max_humidity_drift_pp', header: 'Max RH drift (pp)', render: (r) => fmtNum(r.max_humidity_drift_pp, 2) },
    { key: 'models_with_critical', header: 'Critical units' },
  ];

  const alarmCols: Column<AlarmRow>[] = [
    { key: 'alarm_self_test_result', header: 'Self-test result' },
    { key: 'result_count', header: 'Count' },
    { key: 'units_with_codes', header: 'With fail codes' },
    { key: 'share_pct', header: 'Share %', render: (r) => fmtNum(r.share_pct, 1) },
  ];

  const severityCols: Column<SeverityRow>[] = [
    { key: 'severity', header: 'Severity' },
    { key: 'total_items', header: 'Total' },
    { key: 'open_or_in_progress', header: 'Open / In progress' },
    { key: 'closed_or_verified', header: 'Closed / Verified' },
    { key: 'escalated_count', header: 'Escalated' },
    { key: 'total_cost_rupees', header: 'Spend', render: (r) => fmtRupees(r.total_cost_rupees) },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'capa_category', header: 'Category' },
    { key: 'item_count', header: 'Items' },
    { key: 'open_count', header: 'Open' },
    { key: 'avg_target_lead_days', header: 'Avg lead days', render: (r) => fmtNum(r.avg_target_lead_days, 1) },
    { key: 'total_actual_rupees', header: 'Actual spend', render: (r) => fmtRupees(r.total_actual_rupees) },
  ];

  const hospitalCols: Column<HospitalRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'audits_this_quarter', header: 'Audits' },
    { key: 'critical_findings', header: 'Critical findings' },
    { key: 'open_p0_p1_capas', header: 'Open P0/P1 CAPAs' },
    { key: 'pass_rate_pct', header: 'Pass rate %', render: (r) => fmtNum(r.pass_rate_pct, 1) },
  ];

  const backlogCols: Column<BacklogRow>[] = [
    { key: 'capa_code', header: 'CAPA' },
    { key: 'severity', header: 'Severity' },
    { key: 'capa_category', header: 'Category' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ward_code', header: 'Ward' },
    { key: 'asset_tag', header: 'Asset' },
    { key: 'target_close_date', header: 'Target close' },
    { key: 'days_to_target', header: 'Days to target' },
    { key: 'owner_role', header: 'Owner' },
    { key: 'status', header: 'Status' },
  ];

  const consumablesCols: Column<ConsumablesRow>[] = [
    { key: 'servo_probe_condition', header: 'Probe condition' },
    { key: 'units', header: 'Units' },
    { key: 'avg_hepa_age_days', header: 'Avg HEPA age (days)', render: (r) => fmtNum(r.avg_hepa_age_days, 0) },
    { key: 'units_with_critical_risk', header: 'Critical units' },
  ];

  const totalAudits = wardRows.reduce((a, r) => a + (r.total_audits ?? 0), 0);
  const totalCritical = wardRows.reduce((a, r) => a + (r.critical_risk_count ?? 0), 0);
  const openP0P1 = severityRows
    .filter((s) => s.severity === 'p0_neonatal_critical' || s.severity === 'p1_high')
    .reduce((a, r) => a + (r.open_or_in_progress ?? 0), 0);

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>
        PICU/NICU Incubator Servo-Temp & Humidity Calibration Audit
      </h1>
      <p style={{ fontSize: 13, color: '#555', marginBottom: 20 }}>
        Round r3118 · Quarterly NICU/PICU audit: air vs servo skin temperature, humidity drift,
        O2 mix, alarm self-test, neonatal safety CAPA. Air drift target ≤ 0.5C, RH drift ≤ 5pp,
        O2 drift ≤ 2pp.
      </p>

      <div style={{ display: 'flex', gap: 12, marginBottom: 24, flexWrap: 'wrap' }}>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6, minWidth: 140 }}>
          <div style={{ fontSize: 11, color: '#666' }}>Total audits</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{totalAudits}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6, minWidth: 140 }}>
          <div style={{ fontSize: 11, color: '#666' }}>Critical risk units</div>
          <div style={{ fontSize: 20, fontWeight: 600, color: totalCritical > 0 ? '#b00' : '#222' }}>
            {totalCritical}
          </div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6, minWidth: 140 }}>
          <div style={{ fontSize: 11, color: '#666' }}>Open P0/P1 CAPAs</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{openP0P1}</div>
        </div>
      </div>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8 }}>1. Ward-level audit rollup</h2>
        <DataTable
          rows={wardRows}
          columns={wardCols}
          emptyMessage="No ward audits recorded for this quarter."
          rowKey={(r, i) => String(r.ward_code ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8 }}>2. Model fleet drift (worst-first)</h2>
        <DataTable
          rows={modelRows}
          columns={modelCols}
          emptyMessage="No model-level drift data."
          rowKey={(r, i) => String(r.incubator_model ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8 }}>3. Alarm self-test outcomes</h2>
        <DataTable
          rows={alarmRows}
          columns={alarmCols}
          emptyMessage="No alarm self-test data."
          rowKey={(r, i) => String(r.alarm_self_test_result ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8 }}>4. CAPA by severity</h2>
        <DataTable
          rows={severityRows}
          columns={severityCols}
          emptyMessage="No CAPA items raised."
          rowKey={(r, i) => String(r.severity ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8 }}>5. CAPA by category</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No CAPA categories."
          rowKey={(r, i) => String(r.capa_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8 }}>6. Hospital safety scorecard</h2>
        <DataTable
          rows={hospitalRows}
          columns={hospitalCols}
          emptyMessage="No hospital scorecard data."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8 }}>7. Open CAPA backlog (P0 first)</h2>
        <DataTable
          rows={backlogRows}
          columns={backlogCols}
          emptyMessage="No open CAPA backlog — queue is clean."
          rowKey={(r, i) => String(r.capa_code ?? i)}
        />
      </section>

      <section style={{ marginBottom: 12 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8 }}>8. Servo probe & HEPA consumables risk</h2>
        <DataTable
          rows={consumablesRows}
          columns={consumablesCols}
          emptyMessage="No consumables data."
          rowKey={(r, i) => String(r.servo_probe_condition ?? i)}
        />
      </section>
    </div>
  );
}
