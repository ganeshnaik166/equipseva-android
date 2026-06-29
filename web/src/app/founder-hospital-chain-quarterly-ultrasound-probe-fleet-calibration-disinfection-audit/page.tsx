import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type ChainRollup = {
  chain_name: string;
  probes_total: number;
  compliant_calibration: number;
  overdue_calibration: number;
  failed_recall: number;
  contamination_or_quarantine: number;
  fleet_value_inr: number;
  utilization_hours: number;
};

type OverdueProbe = {
  chain_name: string;
  hospital_site: string;
  probe_serial: string;
  probe_type: string;
  modality: string;
  calibration_status: string;
  next_calibration_due: string;
  days_past_due: number;
  fleet_value_inr: number;
};

type MethodMix = {
  disinfection_method: string;
  probe_count: number;
  compliant_count: number;
  flagged_count: number;
  share_pct: number;
};

type CriticalFinding = {
  probe_serial: string;
  chain_name: string;
  hospital_site: string;
  finding_code: string;
  severity: string;
  patient_safety_impact: string;
  remediation_status: string;
  cost_to_remediate_inr: number;
  detected_on: string;
  remediation_due: string;
  auditor_handle: string;
};

type ModalityRisk = {
  modality: string;
  probes_total: number;
  open_critical: number;
  open_major: number;
  high_or_critical_safety: number;
  total_remediation_cost_inr: number;
};

type AuditorProd = {
  auditor_handle: string;
  findings_logged: number;
  critical_findings: number;
  remediated: number;
  open_or_escalated: number;
  remediation_close_rate_pct: number;
};

type Summary = { metric: string; value: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [rollup, overdue, methodMix, critical, modality, auditor, summary] = await Promise.all([
    supabase.rpc('founder_r2967_chain_fleet_rollup'),
    supabase.rpc('founder_r2967_overdue_probes'),
    supabase.rpc('founder_r2967_disinfection_method_mix'),
    supabase.rpc('founder_r2967_critical_findings_open'),
    supabase.rpc('founder_r2967_modality_risk_heatmap'),
    supabase.rpc('founder_r2967_auditor_productivity'),
    supabase.rpc('founder_r2967_quarter_executive_summary'),
  ]);

  const rollupRows = (rollup.data ?? []) as ChainRollup[];
  const overdueRows = (overdue.data ?? []) as OverdueProbe[];
  const methodRows = (methodMix.data ?? []) as MethodMix[];
  const criticalRows = (critical.data ?? []) as CriticalFinding[];
  const modalityRows = (modality.data ?? []) as ModalityRisk[];
  const auditorRows = (auditor.data ?? []) as AuditorProd[];
  const summaryRows = (summary.data ?? []) as Summary[];

  const rollupCols: Column<ChainRollup>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Probes', accessor: (r) => r.probes_total },
    { header: 'Compliant', accessor: (r) => r.compliant_calibration },
    { header: 'Overdue', accessor: (r) => r.overdue_calibration },
    { header: 'Failed Recall', accessor: (r) => r.failed_recall },
    { header: 'Quarantined / Contam', accessor: (r) => r.contamination_or_quarantine },
    { header: 'Fleet Value (INR)', accessor: (r) => r.fleet_value_inr.toLocaleString('en-IN') },
    { header: 'Util Hrs (Q)', accessor: (r) => r.utilization_hours },
  ];

  const overdueCols: Column<OverdueProbe>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Site', accessor: (r) => r.hospital_site },
    { header: 'Probe Serial', accessor: (r) => r.probe_serial },
    { header: 'Type', accessor: (r) => r.probe_type },
    { header: 'Modality', accessor: (r) => r.modality },
    { header: 'Cal Status', accessor: (r) => r.calibration_status },
    { header: 'Due Date', accessor: (r) => r.next_calibration_due },
    { header: 'Days Past Due', accessor: (r) => r.days_past_due },
    { header: 'Fleet Value (INR)', accessor: (r) => r.fleet_value_inr.toLocaleString('en-IN') },
  ];

  const methodCols: Column<MethodMix>[] = [
    { header: 'Method', accessor: (r) => r.disinfection_method },
    { header: 'Probes', accessor: (r) => r.probe_count },
    { header: 'Compliant', accessor: (r) => r.compliant_count },
    { header: 'Flagged', accessor: (r) => r.flagged_count },
    { header: 'Share %', accessor: (r) => r.share_pct },
  ];

  const criticalCols: Column<CriticalFinding>[] = [
    { header: 'Probe', accessor: (r) => r.probe_serial },
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Site', accessor: (r) => r.hospital_site },
    { header: 'Finding', accessor: (r) => r.finding_code },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Safety Impact', accessor: (r) => r.patient_safety_impact },
    { header: 'Status', accessor: (r) => r.remediation_status },
    { header: 'Cost (INR)', accessor: (r) => r.cost_to_remediate_inr.toLocaleString('en-IN') },
    { header: 'Detected', accessor: (r) => r.detected_on },
    { header: 'Due', accessor: (r) => r.remediation_due },
    { header: 'Auditor', accessor: (r) => r.auditor_handle },
  ];

  const modalityCols: Column<ModalityRisk>[] = [
    { header: 'Modality', accessor: (r) => r.modality },
    { header: 'Probes', accessor: (r) => r.probes_total },
    { header: 'Open Critical', accessor: (r) => r.open_critical },
    { header: 'Open Major', accessor: (r) => r.open_major },
    { header: 'High/Crit Safety Impact', accessor: (r) => r.high_or_critical_safety },
    { header: 'Open Remediation (INR)', accessor: (r) => r.total_remediation_cost_inr.toLocaleString('en-IN') },
  ];

  const auditorCols: Column<AuditorProd>[] = [
    { header: 'Auditor', accessor: (r) => r.auditor_handle },
    { header: 'Findings', accessor: (r) => r.findings_logged },
    { header: 'Critical', accessor: (r) => r.critical_findings },
    { header: 'Remediated', accessor: (r) => r.remediated },
    { header: 'Open / Escalated', accessor: (r) => r.open_or_escalated },
    { header: 'Close Rate %', accessor: (r) => r.remediation_close_rate_pct },
  ];

  const summaryCols: Column<Summary>[] = [
    { header: 'Metric', accessor: (r) => r.metric },
    { header: 'Value', accessor: (r) => r.value },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Ultrasound-Probe Fleet Calibration &amp; Disinfection Audit</h1>
        <p className="text-sm text-gray-600 mt-1">
          Founder console r2967 — cross-chain view of probe calibration drift, disinfection compliance,
          recall holds, and remediation cost exposure for Q2 2026. Targets calibration overdue &gt;= 0 days
          and any safety impact &gt;= high.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter Executive Summary</h2>
        <DataTable
          rows={summaryRows}
          columns={summaryCols}
          emptyMessage="No summary available."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain Fleet Rollup</h2>
        <DataTable
          rows={rollupRows}
          columns={rollupCols}
          emptyMessage="No chains audited this quarter."
          rowKey={(r, i) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue & Failed-Recall Probes</h2>
        <DataTable
          rows={overdueRows}
          columns={overdueCols}
          emptyMessage="No probes overdue."
          rowKey={(r, i) => String(r.probe_serial ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Disinfection Method Mix</h2>
        <DataTable
          rows={methodRows}
          columns={methodCols}
          emptyMessage="No disinfection data."
          rowKey={(r, i) => String(r.disinfection_method ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical & Major Findings — Open</h2>
        <DataTable
          rows={criticalRows}
          columns={criticalCols}
          emptyMessage="No open critical/major findings."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Modality Risk Heatmap</h2>
        <DataTable
          rows={modalityRows}
          columns={modalityCols}
          emptyMessage="No modality data."
          rowKey={(r, i) => String(r.modality ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Auditor Productivity</h2>
        <DataTable
          rows={auditorRows}
          columns={auditorCols}
          emptyMessage="No auditor activity."
          rowKey={(r, i) => String(r.auditor_handle ?? i)}
        />
      </section>
    </div>
  );
}
