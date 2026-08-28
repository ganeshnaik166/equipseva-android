import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { cert_status: string; records: number; pct: number };
type EquipmentRow = {
  equipment_class: string;
  records: number;
  total_operators_required: number;
  total_operators_certified: number;
  avg_certification_pct: number | null;
  total_uncertified_use_incidents: number;
  avg_competency_score: number | null;
};
type MatrixRow = {
  risk_class: string;
  cert_status: string;
  records: number;
  avg_certification_pct: number | null;
};
type TrendRow = {
  period_month: string;
  records: number;
  total_operators_required: number;
  total_operators_certified: number;
  total_uncertified_use_incidents: number;
  worsening_records: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string | null;
  occurrences: number;
  pct: number;
};
type DigestRow = {
  hospital_name: string;
  records: number;
  total_uncertified_use_incidents: number;
  total_recert_due: number;
  avg_certification_pct: number | null;
  avg_competency_score: number | null;
};
type RiskRow = {
  hospital_name: string;
  equipment_class: string;
  risk_class: string;
  period_month: string;
  cert_status: string;
  operators_required: number | null;
  operators_certified: number | null;
  uncertified_use_incidents: number | null;
  competency_score: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    equipmentRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3738_cert_status_rollup'),
    supabase.rpc('founder_r3738_equipment_class_scorecard'),
    supabase.rpc('founder_r3738_risk_class_status_matrix'),
    supabase.rpc('founder_r3738_monthly_certification_trend'),
    supabase.rpc('founder_r3738_capa_status_board'),
    supabase.rpc('founder_r3738_root_cause_pareto'),
    supabase.rpc('founder_r3738_uncertified_use_digest'),
    supabase.rpc('founder_r3738_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const equipmentRows: EquipmentRow[] = (equipmentRes.data as EquipmentRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'cert_status', header: 'Certification Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const equipmentCols: Column<EquipmentRow>[] = [
    { key: 'equipment_class', header: 'Equipment Class' },
    { key: 'records', header: 'Records' },
    { key: 'total_operators_required', header: 'Operators Required' },
    { key: 'total_operators_certified', header: 'Operators Certified' },
    { key: 'avg_certification_pct', header: 'Avg Certification %' },
    { key: 'total_uncertified_use_incidents', header: 'Uncertified-Use Incidents' },
    { key: 'avg_competency_score', header: 'Avg Competency Score' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'risk_class', header: 'Risk Class' },
    { key: 'cert_status', header: 'Certification Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_certification_pct', header: 'Avg Certification %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'total_operators_required', header: 'Operators Required' },
    { key: 'total_operators_certified', header: 'Operators Certified' },
    { key: 'total_uncertified_use_incidents', header: 'Uncertified-Use Incidents' },
    { key: 'worsening_records', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'records', header: 'Records' },
    { key: 'total_uncertified_use_incidents', header: 'Uncertified-Use Incidents' },
    { key: 'total_recert_due', header: 'Recert Due' },
    { key: 'avg_certification_pct', header: 'Avg Certification %' },
    { key: 'avg_competency_score', header: 'Avg Competency Score' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'equipment_class', header: 'Equipment Class' },
    { key: 'risk_class', header: 'Risk Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'cert_status', header: 'Certification Status' },
    { key: 'operators_required', header: 'Operators Required' },
    { key: 'operators_certified', header: 'Operators Certified' },
    { key: 'uncertified_use_incidents', header: 'Uncertified-Use Incidents' },
    { key: 'competency_score', header: 'Competency Score' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Operator Training / Certification-of-Use Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Operator training-completion &amp; certification-of-use tracking for HIGH-RISK equipment
        classes (ventilators, defibrillators, radiotherapy units, and other life-support,
        radiation-emitting, surgical-powered, or diagnostic-imaging equipment) at customer
        hospitals &mdash; training delivered, operators certified vs required, re-certification
        due, and uncertified-use incidents &times; hospital &times; equipment class &times; period
        month. Founder-gated view: certification-status distribution, equipment-class scorecards,
        risk-class &times; status matrix, monthly certification trend, CAPA closure, root-cause
        pareto, an uncertified-use digest by hospital, and a high-risk queue of uncertified-use or
        partial-gap rows ordered by severity.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Certification-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No certification rows logged yet."
          rowKey={(r, i) => String(r.cert_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Equipment-class scorecard</h2>
        <DataTable
          rows={equipmentRows}
          columns={equipmentCols}
          emptyMessage="No equipment-class rollups."
          rowKey={(r, i) => String(r.equipment_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Risk class &times; certification status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by risk class."
          rowKey={(r, i) => `${r.risk_class}-${r.cert_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly certification trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Uncertified-use digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No uncertified-use risk identified."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk certification queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk certification rows."
          rowKey={(r, i) => `${r.hospital_name}-${r.equipment_class}-${i}`}
        />
      </section>
    </main>
  );
}
