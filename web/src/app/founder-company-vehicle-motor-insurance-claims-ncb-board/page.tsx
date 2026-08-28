import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { policy_status: string; records: number; pct: number };
type VehicleTypeRow = {
  vehicle_type: string;
  records: number;
  active_ncb_intact: number;
  active_ncb_eroded: number;
  claim_in_process: number;
  renewal_due: number;
  lapsed: number;
  claims_filed_total: number;
  claim_amount_total: number | null;
  avg_ncb_pct: number | null;
};
type MatrixRow = {
  policy_class: string;
  policy_status: string;
  records: number;
  avg_idv_rupees: number | null;
};
type TrendRow = {
  period_month: string;
  records: number;
  claims_filed_total: number;
  claim_amount_total: number | null;
  at_fault_accidents_total: number;
  ncb_eroded_records: number;
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
  vehicle_type: string;
  records: number;
  ncb_eroded_records: number;
  avg_ncb_pct: number | null;
  at_fault_accidents_total: number;
  claim_amount_total: number | null;
};
type RiskRow = {
  vehicle_registration: string;
  vehicle_type: string;
  period_month: string;
  policy_class: string;
  policy_status: string;
  policy_renewal_date: string | null;
  claim_amount_rupees: number | null;
  at_fault_accidents: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    vehicleTypeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3745_policy_status_rollup'),
    supabase.rpc('founder_r3745_vehicle_type_scorecard'),
    supabase.rpc('founder_r3745_policy_class_status_matrix'),
    supabase.rpc('founder_r3745_monthly_claims_trend'),
    supabase.rpc('founder_r3745_capa_status_board'),
    supabase.rpc('founder_r3745_root_cause_pareto'),
    supabase.rpc('founder_r3745_ncb_erosion_digest'),
    supabase.rpc('founder_r3745_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const vehicleTypeRows: VehicleTypeRow[] = (vehicleTypeRes.data as VehicleTypeRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'policy_status', header: 'Policy Status' },
    { key: 'records', header: 'Policies' },
    { key: 'pct', header: 'Share %' },
  ];

  const vehicleTypeCols: Column<VehicleTypeRow>[] = [
    { key: 'vehicle_type', header: 'Vehicle Type' },
    { key: 'records', header: 'Policies' },
    { key: 'active_ncb_intact', header: 'NCB Intact' },
    { key: 'active_ncb_eroded', header: 'NCB Eroded' },
    { key: 'claim_in_process', header: 'Claim In Process' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'lapsed', header: 'Lapsed' },
    { key: 'claims_filed_total', header: 'Claims Filed' },
    { key: 'claim_amount_total', header: 'Claim Amount Total (Rs)' },
    { key: 'avg_ncb_pct', header: 'Avg NCB %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'policy_class', header: 'Policy Class' },
    { key: 'policy_status', header: 'Policy Status' },
    { key: 'records', header: 'Policies' },
    { key: 'avg_idv_rupees', header: 'Avg IDV (Rs)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Policies' },
    { key: 'claims_filed_total', header: 'Claims Filed' },
    { key: 'claim_amount_total', header: 'Claim Amount Total (Rs)' },
    { key: 'at_fault_accidents_total', header: 'At-Fault Accidents' },
    { key: 'ncb_eroded_records', header: 'NCB-Eroded Records' },
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
    { key: 'vehicle_type', header: 'Vehicle Type' },
    { key: 'records', header: 'NCB-Eroded Vehicles' },
    { key: 'ncb_eroded_records', header: 'NCB-Eroded Records' },
    { key: 'avg_ncb_pct', header: 'Avg NCB %' },
    { key: 'at_fault_accidents_total', header: 'At-Fault Accidents' },
    { key: 'claim_amount_total', header: 'Claim Amount Total (Rs)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'vehicle_registration', header: 'Vehicle Registration' },
    { key: 'vehicle_type', header: 'Vehicle Type' },
    { key: 'period_month', header: 'Month' },
    { key: 'policy_class', header: 'Policy Class' },
    { key: 'policy_status', header: 'Policy Status' },
    { key: 'policy_renewal_date', header: 'Renewal Date' },
    { key: 'claim_amount_rupees', header: 'Claim Amount (Rs)' },
    { key: 'at_fault_accidents', header: 'At-Fault Accidents' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Company Vehicle Motor-Insurance Claims &amp; NCB Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Company-owned fleet vehicle motor-insurance policies, claims, and no-claim-bonus (NCB)
        tracking per vehicle &mdash; renewal, claims filed, IDV vs claim settlement, and NCB
        erosion. Distinct from any D&amp;O insurance board, any insurance-broker-performance
        -scorecard page, and any engineer-vehicle-fuel-log page, which is fuel not insurance.
        Founder-gated view: policy-status distribution, vehicle-type scorecards, policy-class
        &times; status matrix, monthly claims trend, CAPA status board, root-cause pareto, an
        NCB-erosion digest, and a high-risk queue of lapsed &amp; claim-in-process policies.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Policy-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No motor-insurance policy rows logged yet."
          rowKey={(r, i) => String(r.policy_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Vehicle-type scorecard</h2>
        <DataTable
          rows={vehicleTypeRows}
          columns={vehicleTypeCols}
          emptyMessage="No vehicle-type rollups."
          rowKey={(r, i) => String(r.vehicle_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Policy class &times; policy status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No policies by class."
          rowKey={(r, i) => `${r.policy_class}-${r.policy_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly claims trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. NCB-erosion digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No NCB-erosion records."
          rowKey={(r, i) => String(r.vehicle_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk policy queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk policies."
          rowKey={(r, i) => `${r.vehicle_registration}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
