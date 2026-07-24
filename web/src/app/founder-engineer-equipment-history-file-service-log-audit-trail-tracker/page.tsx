import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { ehf_verdict: string; devices: number; pct: number };
type ScoreRow = {
  hospital_name: string;
  total_devices: number;
  complete_ready: number;
  minor_gaps: number;
  records_missing: number;
  not_maintained: number;
  missing_install: number;
  calibration_gaps: number;
  avg_completeness_pct: number;
  ready_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  engineer_name: string;
  devices: number;
  accreditation_ready_count: number;
  avg_completeness_pct: number;
  total_missing_records: number;
};
type TrendRow = {
  last_updated_date: string;
  devices: number;
  complete_ready: number;
  records_missing: number;
  avg_completeness_pct: number;
};
type CapaRow = { capa_status: string; findings: number; avg_cost_rupees: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; total_cost_rupees: number; pct: number };
type RegRow = { regulatory_impact: string; findings: number; open_findings: number; total_cost_rupees: number };
type RiskRow = {
  hospital_name: string;
  engineer_name: string;
  device_code: string;
  equipment_type: string;
  ehf_verdict: string;
  missing_records: number;
  completeness_pct: number;
  accreditation_ready: boolean;
  last_updated_date: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [verdictRes, scoreRes, matrixRes, trendRes, capaRes, causeRes, regRes, riskRes] = await Promise.all([
    supabase.rpc('founder_r3388_ehf_verdict_rollup'),
    supabase.rpc('founder_r3388_hospital_scorecard'),
    supabase.rpc('founder_r3388_equipment_engineer_matrix'),
    supabase.rpc('founder_r3388_daily_update_trend'),
    supabase.rpc('founder_r3388_capa_status_board'),
    supabase.rpc('founder_r3388_root_cause_pareto'),
    supabase.rpc('founder_r3388_regulatory_impact_digest'),
    supabase.rpc('founder_r3388_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'ehf_verdict', header: 'EHF Verdict' },
    { key: 'devices', header: 'Devices' },
    { key: 'pct', header: 'Share %' },
  ];
  const scoreCols: Column<ScoreRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_devices', header: 'Devices' },
    { key: 'complete_ready', header: 'Audit-Ready' },
    { key: 'minor_gaps', header: 'Minor Gaps' },
    { key: 'records_missing', header: 'Records Missing' },
    { key: 'not_maintained', header: 'Not Maintained' },
    { key: 'missing_install', header: 'No Install Rec' },
    { key: 'calibration_gaps', header: 'Cal Gaps' },
    { key: 'avg_completeness_pct', header: 'Avg Complete %' },
    { key: 'ready_pct', header: 'Ready %' },
  ];
  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'devices', header: 'Devices' },
    { key: 'accreditation_ready_count', header: 'Accred-Ready' },
    { key: 'avg_completeness_pct', header: 'Avg Complete %' },
    { key: 'total_missing_records', header: 'Missing Records' },
  ];
  const trendCols: Column<TrendRow>[] = [
    { key: 'last_updated_date', header: 'Updated' },
    { key: 'devices', header: 'Devices' },
    { key: 'complete_ready', header: 'Audit-Ready' },
    { key: 'records_missing', header: 'Records Missing' },
    { key: 'avg_completeness_pct', header: 'Avg Complete %' },
  ];
  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];
  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];
  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];
  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'device_code', header: 'Device' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'ehf_verdict', header: 'Verdict' },
    { key: 'missing_records', header: 'Missing Records' },
    { key: 'completeness_pct', header: 'Complete %' },
    { key: 'accreditation_ready', header: 'Accred-Ready' },
    { key: 'last_updated_date', header: 'Updated' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Equipment History-File &amp; Service-Log Audit-Trail Completeness Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-device equipment-history-file (EHF) &mdash; install record &times; service logs &times; parts
        &times; calibration &times; incidents &times; audit-trail integrity &amp; accreditation readiness &amp; CAPA.
        Founder-gated view: verdict rollup, hospital scorecard, equipment &times; engineer matrix, and
        record-reconstruction queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. EHF verdict distribution</h2>
        <DataTable rows={verdictRows} columns={verdictCols} emptyMessage="No devices audited yet." rowKey={(r, i) => String(r.ehf_verdict ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital EHF scorecard</h2>
        <DataTable rows={scoreRows} columns={scoreCols} emptyMessage="No hospital rollups." rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment &times; engineer matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No matrix data." rowKey={(r, i) => `${r.equipment_type}-${r.engineer_name}-${i}`} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily update trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data." rowKey={(r, i) => String(r.last_updated_date ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable rows={capaRows} columns={capaCols} emptyMessage="No CAPA findings." rowKey={(r, i) => String(r.capa_status ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable rows={causeRows} columns={causeCols} emptyMessage="No root-cause data." rowKey={(r, i) => String(r.root_cause ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable rows={regRows} columns={regCols} emptyMessage="No regulatory-impact rollups." rowKey={(r, i) => String(r.regulatory_impact ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Record-reconstruction queue</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No at-risk history files." rowKey={(r, i) => `${r.device_code}-${i}`} />
      </section>
    </main>
  );
}
