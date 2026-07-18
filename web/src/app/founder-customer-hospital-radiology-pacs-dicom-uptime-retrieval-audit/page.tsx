import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  audits: number;
  compliant: number;
  watch: number;
  major_critical: number;
  avg_send_success: number;
  avg_retrieval_sec: number;
  avg_storage_pct: number;
  total_downtime_min: number;
  compliance_pct: number;
};
type ModalityRow = {
  modality: string;
  audits: number;
  total_studies: number;
  avg_send_success: number;
  avg_retrieval_sec: number;
  avg_storage_pct: number;
  avg_turnaround_hrs: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  avg_send_success: number;
  avg_retrieval_sec: number;
  total_downtime_min: number;
  backups_verified: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  pacs_node_code: string;
  modality: string;
  audit_date: string;
  audit_verdict: string;
  dicom_send_success_pct: number;
  retrieval_time_seconds: number;
  storage_used_pct: number;
  downtime_minutes: number;
  backup_verified: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    modalityRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3175_verdict_rollup'),
    supabase.rpc('founder_r3175_hospital_scorecard'),
    supabase.rpc('founder_r3175_modality_matrix'),
    supabase.rpc('founder_r3175_daily_trend'),
    supabase.rpc('founder_r3175_capa_status_board'),
    supabase.rpc('founder_r3175_root_cause_pareto'),
    supabase.rpc('founder_r3175_regulatory_impact_digest'),
    supabase.rpc('founder_r3175_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const modalityRows: ModalityRow[] = (modalityRes.data as ModalityRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'audits', header: 'Audits' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'watch', header: 'Watch' },
    { key: 'major_critical', header: 'Major / Critical' },
    { key: 'avg_send_success', header: 'Avg Send %' },
    { key: 'avg_retrieval_sec', header: 'Avg Retrieval s' },
    { key: 'avg_storage_pct', header: 'Avg Storage %' },
    { key: 'total_downtime_min', header: 'Downtime min' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const modalityCols: Column<ModalityRow>[] = [
    { key: 'modality', header: 'Modality' },
    { key: 'audits', header: 'Audits' },
    { key: 'total_studies', header: 'Studies' },
    { key: 'avg_send_success', header: 'Avg Send %' },
    { key: 'avg_retrieval_sec', header: 'Avg Retrieval s' },
    { key: 'avg_storage_pct', header: 'Avg Storage %' },
    { key: 'avg_turnaround_hrs', header: 'Avg Turnaround h' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_send_success', header: 'Avg Send %' },
    { key: 'avg_retrieval_sec', header: 'Avg Retrieval s' },
    { key: 'total_downtime_min', header: 'Downtime min' },
    { key: 'backups_verified', header: 'Backups OK' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
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
    { key: 'pacs_node_code', header: 'Node' },
    { key: 'modality', header: 'Modality' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'dicom_send_success_pct', header: 'Send %' },
    { key: 'retrieval_time_seconds', header: 'Retrieval s' },
    { key: 'storage_used_pct', header: 'Storage %' },
    { key: 'downtime_minutes', header: 'Downtime min' },
    { key: 'backup_verified', header: 'Backup' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Radiology PACS / DICOM Uptime &amp; Image-Retrieval Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        PACS QA log — modality &times; study volume &times; DICOM send-success &times; retrieval time &times;
        storage used &times; downtime &times; backup verified &times; report-turnaround &amp; verdict, with CAPA
        closure. Founder-gated view: audit verdicts, hospital scorecards, modality matrix, root-cause pareto,
        and regulatory-impact digest across NABH &amp; ABDM surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital PACS scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Modality performance matrix</h2>
        <DataTable
          rows={modalityRows}
          columns={modalityCols}
          emptyMessage="No modality data."
          rowKey={(r, i) => `${r.modality}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily uptime &amp; retrieval trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.audit_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk / priority queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk audits."
          rowKey={(r, i) => `${r.pacs_node_code}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
