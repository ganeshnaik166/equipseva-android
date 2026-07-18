import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  compliant: number;
  major_nc: number;
  critical: number;
  cross_conn_fail: number;
  purity_fail: number;
  alarm_fail: number;
  compliance_pct: number;
};
type GasZoneRow = {
  gas_type: string;
  clinical_zone: string;
  audits: number;
  compliant: number;
  avg_pressure_bar: number;
  avg_purity_pct: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  compliant: number;
  major_nc: number;
  critical: number;
  cross_conn_fail: number;
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
  outlet_location: string;
  gas_type: string;
  clinical_zone: string;
  audit_date: string;
  audit_verdict: string;
  cross_connection_test: string | null;
  purity_verdict: string | null;
  area_alarm_test: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    gasZoneRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3155_verdict_rollup'),
    supabase.rpc('founder_r3155_hospital_scorecard'),
    supabase.rpc('founder_r3155_gas_zone_matrix'),
    supabase.rpc('founder_r3155_daily_trend'),
    supabase.rpc('founder_r3155_capa_status_board'),
    supabase.rpc('founder_r3155_root_cause_pareto'),
    supabase.rpc('founder_r3155_regulatory_impact_digest'),
    supabase.rpc('founder_r3155_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const gasZoneRows: GasZoneRow[] = (gasZoneRes.data as GasZoneRow[]) ?? [];
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
    { key: 'compliant', header: 'Compliant' },
    { key: 'major_nc', header: 'Major NC' },
    { key: 'critical', header: 'Critical' },
    { key: 'cross_conn_fail', header: 'Cross-Conn Fail' },
    { key: 'purity_fail', header: 'Purity Fail' },
    { key: 'alarm_fail', header: 'Alarm Fail' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const gasZoneCols: Column<GasZoneRow>[] = [
    { key: 'gas_type', header: 'Gas' },
    { key: 'clinical_zone', header: 'Zone' },
    { key: 'audits', header: 'Audits' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'avg_pressure_bar', header: 'Avg Pressure (bar)' },
    { key: 'avg_purity_pct', header: 'Avg Purity %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'major_nc', header: 'Major NC' },
    { key: 'critical', header: 'Critical' },
    { key: 'cross_conn_fail', header: 'Cross-Conn Fail' },
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
    { key: 'outlet_location', header: 'Outlet' },
    { key: 'gas_type', header: 'Gas' },
    { key: 'clinical_zone', header: 'Zone' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'cross_connection_test', header: 'Cross-Conn' },
    { key: 'purity_verdict', header: 'Purity' },
    { key: 'area_alarm_test', header: 'Alarm' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Medical-Gas Pipeline (MGPS) Pressure &amp; Purity Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        MGPS outlet audit log — gas type &times; clinical zone &times; line pressure &times; purity %
        &times; cross-connection &times; area-alarm &times; valve label &amp; CAPA closure. Founder-gated
        view: audit verdicts, hospital scorecards, root-cause pareto, and regulatory-impact digest across
        NABH, CDSCO &amp; ISO 7396 surfaces.
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital compliance scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Gas type &times; clinical zone matrix</h2>
        <DataTable
          rows={gasZoneRows}
          columns={gasZoneCols}
          emptyMessage="No audits by gas/zone."
          rowKey={(r, i) => `${r.gas_type}-${r.clinical_zone}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk outlet queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk outlets."
          rowKey={(r, i) => `${r.hospital_name}-${r.outlet_location}-${i}`}
        />
      </section>
    </main>
  );
}
