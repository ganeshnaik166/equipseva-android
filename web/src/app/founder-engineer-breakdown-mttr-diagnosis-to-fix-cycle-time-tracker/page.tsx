import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { mttr_verdict: string; tickets: number; pct: number };
type ScoreRow = {
  engineer_name: string;
  tickets: number;
  avg_mttr_hours: number;
  sla_met_count: number;
  first_visit_resolved_count: number;
  parts_delays: number;
  breaches: number;
  sla_met_pct: number;
};
type MatrixRow = { equipment_type: string; severity: string; tickets: number; avg_mttr_hours: number; breaches: number };
type TrendRow = { breakdown_date: string; tickets: number; avg_mttr_hours: number; sla_met: number; breaches: number };
type CapaRow = { capa_status: string; findings: number; avg_cost_rupees: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; total_cost_rupees: number; pct: number };
type ImpactRow = { sla_impact: string; findings: number; open_findings: number; total_cost_rupees: number };
type RiskRow = {
  hospital_name: string;
  engineer_name: string;
  ticket_code: string;
  equipment_type: string;
  severity: string;
  breakdown_date: string;
  total_mttr_hours: number;
  parts_wait_hours: number;
  mttr_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [verdictRes, scoreRes, matrixRes, trendRes, capaRes, causeRes, impactRes, riskRes] = await Promise.all([
    supabase.rpc('founder_r3400_mttr_verdict_rollup'),
    supabase.rpc('founder_r3400_engineer_scorecard'),
    supabase.rpc('founder_r3400_equipment_severity_matrix'),
    supabase.rpc('founder_r3400_daily_breakdown_trend'),
    supabase.rpc('founder_r3400_capa_status_board'),
    supabase.rpc('founder_r3400_root_cause_pareto'),
    supabase.rpc('founder_r3400_sla_impact_digest'),
    supabase.rpc('founder_r3400_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'mttr_verdict', header: 'MTTR Verdict' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'pct', header: 'Share %' },
  ];
  const scoreCols: Column<ScoreRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'avg_mttr_hours', header: 'Avg MTTR (h)' },
    { key: 'sla_met_count', header: 'SLA Met' },
    { key: 'first_visit_resolved_count', header: 'First-Visit Fix' },
    { key: 'parts_delays', header: 'Parts Delays' },
    { key: 'breaches', header: 'Breaches' },
    { key: 'sla_met_pct', header: 'SLA Met %' },
  ];
  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'severity', header: 'Severity' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'avg_mttr_hours', header: 'Avg MTTR (h)' },
    { key: 'breaches', header: 'Breaches' },
  ];
  const trendCols: Column<TrendRow>[] = [
    { key: 'breakdown_date', header: 'Date' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'avg_mttr_hours', header: 'Avg MTTR (h)' },
    { key: 'sla_met', header: 'SLA Met' },
    { key: 'breaches', header: 'Breaches' },
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
  const impactCols: Column<ImpactRow>[] = [
    { key: 'sla_impact', header: 'SLA Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];
  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'ticket_code', header: 'Ticket' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'severity', header: 'Severity' },
    { key: 'breakdown_date', header: 'Date' },
    { key: 'total_mttr_hours', header: 'MTTR (h)' },
    { key: 'parts_wait_hours', header: 'Parts Wait (h)' },
    { key: 'mttr_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Breakdown MTTR / Diagnosis-to-Fix Cycle-Time Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Breakdown cycle time &mdash; equipment &times; severity &times; response &times; diagnosis &times;
        parts-wait &times; repair &times; total MTTR &times; first-visit-resolved &times; SLA adherence &amp; CAPA.
        Founder-gated view: MTTR-verdict rollup, engineer scorecard, equipment &times; severity matrix, and
        SLA-breach/escalation queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. MTTR verdict distribution</h2>
        <DataTable rows={verdictRows} columns={verdictCols} emptyMessage="No breakdowns yet." rowKey={(r, i) => String(r.mttr_verdict ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer MTTR scorecard</h2>
        <DataTable rows={scoreRows} columns={scoreCols} emptyMessage="No engineer rollups." rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment &times; severity matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No matrix data." rowKey={(r, i) => `${r.equipment_type}-${r.severity}-${i}`} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily breakdown trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data." rowKey={(r, i) => String(r.breakdown_date ?? i)} />
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. SLA-impact digest</h2>
        <DataTable rows={impactRows} columns={impactCols} emptyMessage="No SLA-impact rollups." rowKey={(r, i) => String(r.sla_impact ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. SLA-breach / escalation queue</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No at-risk breakdowns." rowKey={(r, i) => `${r.ticket_code}-${i}`} />
      </section>
    </main>
  );
}
