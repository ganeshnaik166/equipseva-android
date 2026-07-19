import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { entitlement_verdict: string; licenses: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_licenses: number;
  active: number;
  expired: number;
  grace_period: number;
  reactivation_pending: number;
  unused_paid: number;
  compliant_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  license_module: string;
  licenses: number;
  compliant: number;
  expired_or_grace: number;
  avg_days_to_expiry: number | null;
};
type TrendRow = {
  expiry_date: string;
  licenses: number;
  expiring_soon: number;
  expired: number;
  reactivation_pending: number;
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
  device_code: string;
  equipment_type: string;
  license_module: string;
  license_type: string;
  activation_status: string;
  expiry_date: string | null;
  days_to_expiry: number | null;
  entitlement_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3368_entitlement_verdict_rollup'),
    supabase.rpc('founder_r3368_hospital_scorecard'),
    supabase.rpc('founder_r3368_equipment_module_matrix'),
    supabase.rpc('founder_r3368_expiry_date_trend'),
    supabase.rpc('founder_r3368_capa_status_board'),
    supabase.rpc('founder_r3368_root_cause_pareto'),
    supabase.rpc('founder_r3368_regulatory_impact_digest'),
    supabase.rpc('founder_r3368_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'entitlement_verdict', header: 'Entitlement Verdict' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_licenses', header: 'Licenses' },
    { key: 'active', header: 'Active' },
    { key: 'expired', header: 'Expired' },
    { key: 'grace_period', header: 'Grace' },
    { key: 'reactivation_pending', header: 'Reactivation Pending' },
    { key: 'unused_paid', header: 'Unused Paid' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment Type' },
    { key: 'license_module', header: 'License Module' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'expired_or_grace', header: 'Expired / Grace' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'expiry_date', header: 'Expiry Date' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'expiring_soon', header: 'Expiring Soon (0-90d)' },
    { key: 'expired', header: 'Expired' },
    { key: 'reactivation_pending', header: 'Reactivation Pending' },
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
    { key: 'device_code', header: 'Device' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'license_module', header: 'Module' },
    { key: 'license_type', header: 'License Type' },
    { key: 'activation_status', header: 'Activation' },
    { key: 'expiry_date', header: 'Expiry' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'entitlement_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Device Software-License &amp; Feature-Key Entitlement Compliance Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Post-service entitlement log — equipment type &times; license module &times; license type
        &times; activation status &times; expiry &amp; days-to-expiry &times; post-service
        reactivation &times; unused-paid rationalization &times; entitlement verdict &amp; CAPA
        closure. Founder-gated view: verdict rollups, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across vendor-contract &amp; CDSCO software surfaces. Engineers
        must confirm licensed modules and feature keys are valid and reactivated after service so
        advanced imaging, lab, and monitoring features stay live.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Entitlement verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No device licenses logged yet."
          rowKey={(r, i) => String(r.entitlement_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital entitlement scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment type &times; license module matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No licenses by equipment/module."
          rowKey={(r, i) => `${r.equipment_type}-${r.license_module}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Expiry-date trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No dated licenses."
          rowKey={(r, i) => String(r.expiry_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk entitlement queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk licenses."
          rowKey={(r, i) => `${r.device_code}-${i}`}
        />
      </section>
    </main>
  );
}
