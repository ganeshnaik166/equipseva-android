import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { currency_verdict: string; records: number; pct: number };
type ScoreRow = {
  region: string;
  total_records: number;
  current_count: number;
  update_pending: number;
  at_risk: number;
  recall_critical: number;
  not_available: number;
  safety_critical: number;
  current_pct: number;
};
type MatrixRow = { equipment_type: string; ifu_language: string; records: number; current_count: number; outdated_count: number };
type TrendRow = { days_bucket: string; records: number; at_risk: number; safety_critical: number };
type CapaRow = { capa_status: string; findings: number; avg_cost_rupees: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; total_cost_rupees: number; pct: number };
type RegRow = { regulatory_impact: string; findings: number; open_findings: number; total_cost_rupees: number };
type RiskRow = {
  hospital_name: string;
  engineer_name: string;
  equipment_type: string;
  ifu_document_ref: string;
  region: string;
  current_version_at_site: string;
  latest_oem_version: string;
  currency_verdict: string;
  days_since_oem_update: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [verdictRes, scoreRes, matrixRes, trendRes, capaRes, causeRes, regRes, riskRes] = await Promise.all([
    supabase.rpc('founder_r3392_currency_verdict_rollup'),
    supabase.rpc('founder_r3392_region_scorecard'),
    supabase.rpc('founder_r3392_equipment_language_matrix'),
    supabase.rpc('founder_r3392_staleness_trend'),
    supabase.rpc('founder_r3392_capa_status_board'),
    supabase.rpc('founder_r3392_root_cause_pareto'),
    supabase.rpc('founder_r3392_regulatory_impact_digest'),
    supabase.rpc('founder_r3392_high_risk_queue'),
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
    { key: 'currency_verdict', header: 'Currency Verdict' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];
  const scoreCols: Column<ScoreRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'total_records', header: 'Records' },
    { key: 'current_count', header: 'Current' },
    { key: 'update_pending', header: 'Update Pending' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'recall_critical', header: 'Recall Critical' },
    { key: 'not_available', header: 'Not Available' },
    { key: 'safety_critical', header: 'Safety-Critical' },
    { key: 'current_pct', header: 'Current %' },
  ];
  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'ifu_language', header: 'Language' },
    { key: 'records', header: 'Records' },
    { key: 'current_count', header: 'Current' },
    { key: 'outdated_count', header: 'Outdated' },
  ];
  const trendCols: Column<TrendRow>[] = [
    { key: 'days_bucket', header: 'Days Since OEM Update' },
    { key: 'records', header: 'Records' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'safety_critical', header: 'Safety-Critical' },
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
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'ifu_document_ref', header: 'IFU Ref' },
    { key: 'region', header: 'Region' },
    { key: 'current_version_at_site', header: 'Site Version' },
    { key: 'latest_oem_version', header: 'Latest OEM' },
    { key: 'currency_verdict', header: 'Verdict' },
    { key: 'days_since_oem_update', header: 'Days Behind' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        IFU / Instructions-for-Use &amp; Training-Material Version-Currency Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field IFU currency &mdash; equipment &times; IFU language &times; site vs latest OEM version &times;
        training-material currency &times; recall-related &amp; safety-critical updates &amp; CAPA. Founder-gated
        view: currency-verdict rollup, region scorecard, equipment &times; language matrix, and recall/safety-critical queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Currency verdict distribution</h2>
        <DataTable rows={verdictRows} columns={verdictCols} emptyMessage="No IFU records yet." rowKey={(r, i) => String(r.currency_verdict ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region scorecard</h2>
        <DataTable rows={scoreRows} columns={scoreCols} emptyMessage="No region rollups." rowKey={(r, i) => String(r.region ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment &times; IFU-language matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No matrix data." rowKey={(r, i) => `${r.equipment_type}-${r.ifu_language}-${i}`} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Staleness trend (days since OEM update)</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data." rowKey={(r, i) => String(r.days_bucket ?? i)} />
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Recall / safety-critical queue</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No at-risk IFU records." rowKey={(r, i) => `${r.ifu_document_ref}-${i}`} />
      </section>
    </main>
  );
}
