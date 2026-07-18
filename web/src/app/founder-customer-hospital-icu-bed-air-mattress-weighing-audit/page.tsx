import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  fit_for_use: number;
  restricted: number;
  out_of_service: number;
  cpr_faults: number;
  rail_faults: number;
  scale_faults: number;
  fit_pct: number;
};
type ModelRow = {
  bed_model: string;
  air_mattress_mode: string;
  audits: number;
  fit_for_use: number;
  avg_battery_backup_min: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  fit_for_use: number;
  cpr_faults: number;
  rail_faults: number;
  battery_faults: number;
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
  icu_ward_code: string;
  bed_asset_tag: string;
  bed_model: string;
  audit_date: string;
  audit_verdict: string;
  cpr_release_result: string | null;
  side_rail_lock_result: string | null;
  battery_backup_result: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    modelRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3211_verdict_rollup'),
    supabase.rpc('founder_r3211_hospital_scorecard'),
    supabase.rpc('founder_r3211_bed_model_matrix'),
    supabase.rpc('founder_r3211_daily_trend'),
    supabase.rpc('founder_r3211_capa_status_board'),
    supabase.rpc('founder_r3211_root_cause_pareto'),
    supabase.rpc('founder_r3211_regulatory_impact_digest'),
    supabase.rpc('founder_r3211_high_risk_beds'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const modelRows: ModelRow[] = (modelRes.data as ModelRow[]) ?? [];
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
    { key: 'total_audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit for Use' },
    { key: 'restricted', header: 'Restricted' },
    { key: 'out_of_service', header: 'Out of Service' },
    { key: 'cpr_faults', header: 'CPR Faults' },
    { key: 'rail_faults', header: 'Rail Faults' },
    { key: 'scale_faults', header: 'Scale Faults' },
    { key: 'fit_pct', header: 'Fit %' },
  ];

  const modelCols: Column<ModelRow>[] = [
    { key: 'bed_model', header: 'Bed Model' },
    { key: 'air_mattress_mode', header: 'Mattress Mode' },
    { key: 'audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit for Use' },
    { key: 'avg_battery_backup_min', header: 'Avg Battery (min)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit for Use' },
    { key: 'cpr_faults', header: 'CPR Faults' },
    { key: 'rail_faults', header: 'Rail Faults' },
    { key: 'battery_faults', header: 'Battery Faults' },
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
    { key: 'icu_ward_code', header: 'Ward' },
    { key: 'bed_asset_tag', header: 'Asset' },
    { key: 'bed_model', header: 'Model' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'cpr_release_result', header: 'CPR' },
    { key: 'side_rail_lock_result', header: 'Rail' },
    { key: 'battery_backup_result', header: 'Battery' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital ICU Bed, Air-Mattress &amp; Patient-Weighing Function Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        ICU bed function audit — head/foot articulation &times; CPR release &times; side-rail lock &times;
        air-mattress pressure cycling &times; weighing-scale accuracy &times; battery backup &amp; castor
        brakes with CAPA closure. Founder-gated view: audit verdicts, hospital scorecards,
        root-cause pareto, and regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No bed audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital bed fitness scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Bed model &times; mattress mode matrix</h2>
        <DataTable
          rows={modelRows}
          columns={modelCols}
          emptyMessage="No audits by bed model."
          rowKey={(r, i) => `${r.bed_model}-${r.air_mattress_mode}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily audit trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk beds queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk beds."
          rowKey={(r, i) => `${r.bed_asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
