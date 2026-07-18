import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { incident_verdict: string; incidents: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_incidents: number;
  sev1: number;
  saved: number;
  credit_issued: number;
  churn_open: number;
  lost: number;
  total_sla_penalty_rupees: number;
  save_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  severity: string;
  incidents: number;
  saved: number;
  avg_restore_hours: number | null;
  total_sla_penalty_rupees: number;
};
type TrendRow = {
  reported_date: string;
  incidents: number;
  sev1: number;
  warrooms: number;
  lost: number;
  total_sla_penalty_rupees: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause_category: string;
  incidents: number;
  total_sla_penalty_rupees: number;
  pct: number;
};
type AccountRow = {
  account_tier: string;
  incidents: number;
  sev1: number;
  churn_threat_incidents: number;
  lost: number;
  total_sla_penalty_rupees: number;
  avg_restore_hours: number | null;
};
type RiskRow = {
  hospital_name: string;
  incident_code: string;
  equipment_type: string;
  severity: string;
  reported_date: string;
  relationship_risk: string;
  incident_verdict: string;
  sla_penalty_risk_rupees: number | null;
  lead_engineer: string;
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
    accountRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3292_incident_verdict_rollup'),
    supabase.rpc('founder_r3292_hospital_scorecard'),
    supabase.rpc('founder_r3292_equipment_severity_matrix'),
    supabase.rpc('founder_r3292_daily_incident_trend'),
    supabase.rpc('founder_r3292_capa_status_board'),
    supabase.rpc('founder_r3292_root_cause_pareto'),
    supabase.rpc('founder_r3292_account_risk_digest'),
    supabase.rpc('founder_r3292_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const accountRows: AccountRow[] = (accountRes.data as AccountRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'incident_verdict', header: 'Verdict' },
    { key: 'incidents', header: 'Incidents' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_incidents', header: 'Incidents' },
    { key: 'sev1', header: 'Sev1' },
    { key: 'saved', header: 'Saved' },
    { key: 'credit_issued', header: 'Saved w/ Credit' },
    { key: 'churn_open', header: 'Escalated / Churn Open' },
    { key: 'lost', header: 'Lost' },
    { key: 'total_sla_penalty_rupees', header: 'SLA Penalty Risk (INR)' },
    { key: 'save_pct', header: 'Save %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'severity', header: 'Severity' },
    { key: 'incidents', header: 'Incidents' },
    { key: 'saved', header: 'Saved' },
    { key: 'avg_restore_hours', header: 'Avg Restore (h)' },
    { key: 'total_sla_penalty_rupees', header: 'SLA Penalty Risk (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'reported_date', header: 'Date' },
    { key: 'incidents', header: 'Incidents' },
    { key: 'sev1', header: 'Sev1' },
    { key: 'warrooms', header: 'War-Rooms' },
    { key: 'lost', header: 'Lost' },
    { key: 'total_sla_penalty_rupees', header: 'SLA Penalty Risk (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause_category', header: 'Root Cause' },
    { key: 'incidents', header: 'Incidents' },
    { key: 'total_sla_penalty_rupees', header: 'SLA Penalty Risk (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const accountCols: Column<AccountRow>[] = [
    { key: 'account_tier', header: 'Account Tier' },
    { key: 'incidents', header: 'Incidents' },
    { key: 'sev1', header: 'Sev1' },
    { key: 'churn_threat_incidents', header: 'Churn-Threat' },
    { key: 'lost', header: 'Lost' },
    { key: 'total_sla_penalty_rupees', header: 'SLA Penalty Risk (INR)' },
    { key: 'avg_restore_hours', header: 'Avg Restore (h)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'incident_code', header: 'Incident' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'severity', header: 'Severity' },
    { key: 'reported_date', header: 'Reported' },
    { key: 'relationship_risk', header: 'Relationship Risk' },
    { key: 'incident_verdict', header: 'Verdict' },
    { key: 'sla_penalty_risk_rupees', header: 'SLA Penalty Risk (INR)' },
    { key: 'lead_engineer', header: 'Lead Engineer' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Major-Incident Escalation &amp; Customer Account-Save War-Room Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        When critical equipment is down at a key hospital and the SLA &amp; relationship are at
        risk, a war-room is convened. This founder-gated view tracks account tier &times; equipment
        type &times; severity &times; SLA-penalty risk &times; relationship risk &times; root cause
        &times; incident verdict, plus preventive &amp; relationship CAPA actions &mdash; incident
        verdicts, hospital save-rate scorecards, root-cause pareto, and an account-tier commercial
        risk digest across platinum, gold, silver &amp; strategic-logo accounts.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Incident verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No major incidents logged yet."
          rowKey={(r, i) => String(r.incident_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital account-save scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment &times; severity matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No incidents by equipment."
          rowKey={(r, i) => `${r.equipment_type}-${r.severity}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily incident trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.reported_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA actions."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Account-tier commercial risk digest</h2>
        <DataTable
          rows={accountRows}
          columns={accountCols}
          emptyMessage="No account-tier rollups."
          rowKey={(r, i) => String(r.account_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk incident queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk incidents."
          rowKey={(r, i) => `${r.incident_code}-${r.reported_date}-${i}`}
        />
      </section>
    </main>
  );
}
