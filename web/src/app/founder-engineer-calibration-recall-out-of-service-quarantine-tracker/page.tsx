import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StateRow = { service_state: string; assets: number; pct: number };
type ReasonRow = {
  recall_reason: string;
  total_assets: number;
  quarantined_count: number;
  out_of_service_count: number;
  condemned_count: number;
  critical_risk: number;
  avg_days_overdue: number;
};
type MatrixRow = {
  recall_reason: string;
  clinical_risk: string;
  assets: number;
  quarantined_count: number;
  avg_days_overdue: number;
};
type TrendRow = {
  recall_month: string;
  assets: number;
  quarantined_count: number;
  out_of_service_count: number;
  avg_days_overdue: number;
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
type RiskDigestRow = {
  clinical_risk: string;
  assets: number;
  quarantined_count: number;
  out_of_service_count: number;
  condemned_count: number;
  avg_days_overdue: number;
};
type QueueRow = {
  engineer_name: string;
  hospital_name: string;
  device_model: string;
  asset_tag: string;
  recall_reason: string;
  calibration_due: string | null;
  days_overdue: number | null;
  service_state: string;
  disposition: string;
  clinical_risk: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    stateRes,
    reasonRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3536_service_state_rollup'),
    supabase.rpc('founder_r3536_recall_reason_scorecard'),
    supabase.rpc('founder_r3536_reason_risk_matrix'),
    supabase.rpc('founder_r3536_monthly_recall_trend'),
    supabase.rpc('founder_r3536_capa_status_board'),
    supabase.rpc('founder_r3536_root_cause_pareto'),
    supabase.rpc('founder_r3536_clinical_risk_digest'),
    supabase.rpc('founder_r3536_high_risk_queue'),
  ]);

  const stateRows: StateRow[] = (stateRes.data as StateRow[]) ?? [];
  const reasonRows: ReasonRow[] = (reasonRes.data as ReasonRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: RiskDigestRow[] = (digestRes.data as RiskDigestRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const stateCols: Column<StateRow>[] = [
    { key: 'service_state', header: 'Service State' },
    { key: 'assets', header: 'Assets' },
    { key: 'pct', header: 'Share %' },
  ];

  const reasonCols: Column<ReasonRow>[] = [
    { key: 'recall_reason', header: 'Recall Reason' },
    { key: 'total_assets', header: 'Assets' },
    { key: 'quarantined_count', header: 'Quarantined' },
    { key: 'out_of_service_count', header: 'Out of Service' },
    { key: 'condemned_count', header: 'Condemned' },
    { key: 'critical_risk', header: 'Critical Risk' },
    { key: 'avg_days_overdue', header: 'Avg Days Overdue' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'recall_reason', header: 'Recall Reason' },
    { key: 'clinical_risk', header: 'Clinical Risk' },
    { key: 'assets', header: 'Assets' },
    { key: 'quarantined_count', header: 'Quarantined' },
    { key: 'avg_days_overdue', header: 'Avg Days Overdue' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'recall_month', header: 'Cal-Due Month' },
    { key: 'assets', header: 'Assets' },
    { key: 'quarantined_count', header: 'Quarantined' },
    { key: 'out_of_service_count', header: 'Out of Service' },
    { key: 'avg_days_overdue', header: 'Avg Days Overdue' },
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

  const digestCols: Column<RiskDigestRow>[] = [
    { key: 'clinical_risk', header: 'Clinical Risk' },
    { key: 'assets', header: 'Assets' },
    { key: 'quarantined_count', header: 'Quarantined' },
    { key: 'out_of_service_count', header: 'Out of Service' },
    { key: 'condemned_count', header: 'Condemned' },
    { key: 'avg_days_overdue', header: 'Avg Days Overdue' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_model', header: 'Device Model' },
    { key: 'asset_tag', header: 'Asset Tag' },
    { key: 'recall_reason', header: 'Recall Reason' },
    { key: 'calibration_due', header: 'Cal Due' },
    { key: 'days_overdue', header: 'Days Overdue' },
    { key: 'service_state', header: 'State' },
    { key: 'disposition', header: 'Disposition' },
    { key: 'clinical_risk', header: 'Risk' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Calibration-Recall / Out-of-Service Quarantine Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field calibration-recall log — assets pulled on calibration-overdue, failed verification,
        suspected damage, vendor recall notices, drift &amp; statutory-due triggers, then routed
        through service-state (in-service &rarr; flagged &rarr; quarantined &rarr; out-of-service
        &rarr; recalibrated / condemned) and disposition (recalibrate, repair, replace,
        extend-with-risk, condemn) &times; clinical-risk &times; days-overdue &amp; CAPA closure.
        Founder-gated view: service-state rollups, recall-reason scorecards, root-cause pareto,
        and clinical-risk impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Service-state distribution</h2>
        <DataTable
          rows={stateRows}
          columns={stateCols}
          emptyMessage="No recall assets logged yet."
          rowKey={(r, i) => String(r.service_state ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Recall-reason scorecard</h2>
        <DataTable
          rows={reasonRows}
          columns={reasonCols}
          emptyMessage="No recall-reason rollups."
          rowKey={(r, i) => String(r.recall_reason ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Recall reason &times; clinical risk matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No assets by reason and risk."
          rowKey={(r, i) => `${r.recall_reason}-${r.clinical_risk}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly recall trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.recall_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Clinical-risk impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No clinical-risk rollups."
          rowKey={(r, i) => String(r.clinical_risk ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk recall queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk recall assets."
          rowKey={(r, i) => `${r.asset_tag}-${i}`}
        />
      </section>
    </main>
  );
}
