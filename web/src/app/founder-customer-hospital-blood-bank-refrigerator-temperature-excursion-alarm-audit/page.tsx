import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { event_verdict: string; events: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_events: number;
  within_range: number;
  excursions: number;
  product_loss: number;
  recalls: number;
  units_affected: number;
  compliance_pct: number;
};
type MatrixRow = {
  appliance_type: string;
  alarm_type: string;
  events: number;
  avg_excursion_c: number;
};
type TrendRow = {
  event_date: string;
  within_range: number;
  excursions: number;
  product_loss: number;
  recalls: number;
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
  blood_bank_code: string;
  appliance_asset_tag: string;
  event_date: string;
  event_verdict: string;
  alarm_type: string;
  excursion_peak_c: number | null;
  units_affected: number;
  product_impact: string;
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
    supabase.rpc('founder_r3134_event_verdict_rollup'),
    supabase.rpc('founder_r3134_hospital_scorecard'),
    supabase.rpc('founder_r3134_appliance_alarm_matrix'),
    supabase.rpc('founder_r3134_excursion_daily_trend'),
    supabase.rpc('founder_r3134_capa_status_board'),
    supabase.rpc('founder_r3134_root_cause_pareto'),
    supabase.rpc('founder_r3134_regulatory_impact_digest'),
    supabase.rpc('founder_r3134_high_risk_events'),
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
    { key: 'event_verdict', header: 'Verdict' },
    { key: 'events', header: 'Events' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_events', header: 'Events' },
    { key: 'within_range', header: 'In Range' },
    { key: 'excursions', header: 'Excursions' },
    { key: 'product_loss', header: 'Product Loss' },
    { key: 'recalls', header: 'Recalls' },
    { key: 'units_affected', header: 'Units Affected' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'appliance_type', header: 'Appliance' },
    { key: 'alarm_type', header: 'Alarm' },
    { key: 'events', header: 'Events' },
    { key: 'avg_excursion_c', header: 'Avg Peak °C' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'event_date', header: 'Date' },
    { key: 'within_range', header: 'In Range' },
    { key: 'excursions', header: 'Excursions' },
    { key: 'product_loss', header: 'Product Loss' },
    { key: 'recalls', header: 'Recalls' },
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
    { key: 'blood_bank_code', header: 'Blood Bank' },
    { key: 'appliance_asset_tag', header: 'Asset' },
    { key: 'event_date', header: 'Date' },
    { key: 'event_verdict', header: 'Verdict' },
    { key: 'alarm_type', header: 'Alarm' },
    { key: 'excursion_peak_c', header: 'Peak °C' },
    { key: 'units_affected', header: 'Units' },
    { key: 'product_impact', header: 'Product Impact' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Blood Bank Refrigerator Temperature Excursion &amp; Alarm Compliance Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Cold-chain event log — appliance type &times; setpoint &times; excursion &times; alarm response &times;
        product impact &amp; CAPA closure. Founder-gated view: event verdicts, hospital scorecards,
        root-cause pareto, and regulatory-impact digest across NABH, CDSCO blood-bank licence and
        haemovigilance surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Event verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No cold-chain events logged yet."
          rowKey={(r, i) => String(r.event_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital cold-chain scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Appliance type &times; alarm matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No events by appliance."
          rowKey={(r, i) => `${r.appliance_type}-${r.alarm_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily excursion trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.event_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk events queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk events."
          rowKey={(r, i) => `${r.appliance_asset_tag}-${r.event_date}-${i}`}
        />
      </section>
    </main>
  );
}
