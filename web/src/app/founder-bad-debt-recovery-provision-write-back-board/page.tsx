import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  recovery_status: string;
  entries: number;
  total_write_offs_rupees: number;
  total_recoveries_rupees: number;
  pct: number;
};
type SegmentRow = {
  customer_segment: string;
  entries: number;
  total_gross_receivables_rupees: number;
  total_opening_rupees: number;
  total_write_offs_rupees: number;
  total_recoveries_rupees: number;
  total_write_backs_rupees: number;
  total_closing_rupees: number;
  avg_recovery_rate_pct: number;
  avg_coverage_pct: number;
};
type MatrixRow = {
  customer_segment: string;
  recovery_status: string;
  entries: number;
  total_recoveries_rupees: number;
  total_write_offs_rupees: number;
  avg_recovery_rate_pct: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_write_offs_rupees: number;
  total_recoveries_rupees: number;
  total_write_backs_rupees: number;
  avg_recovery_rate_pct: number;
  avg_coverage_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  total_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type OutlookRow = {
  recovery_outlook: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  business_unit: string;
  ledger_ref: string;
  customer_segment: string;
  period_month: string;
  recovery_status: string;
  write_offs_rupees: number;
  recovery_rate_pct: number | null;
  provision_coverage_pct: number | null;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    segmentRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    outlookRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3619_recovery_status_rollup'),
    supabase.rpc('founder_r3619_segment_scorecard'),
    supabase.rpc('founder_r3619_segment_status_matrix'),
    supabase.rpc('founder_r3619_monthly_recovery_trend'),
    supabase.rpc('founder_r3619_capa_status_board'),
    supabase.rpc('founder_r3619_root_cause_pareto'),
    supabase.rpc('founder_r3619_recovery_impact_digest'),
    supabase.rpc('founder_r3619_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const segmentRows: SegmentRow[] = (segmentRes.data as SegmentRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const outlookRows: OutlookRow[] = (outlookRes.data as OutlookRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'recovery_status', header: 'Recovery Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_write_offs_rupees', header: 'Write-Offs (INR)' },
    { key: 'total_recoveries_rupees', header: 'Recoveries (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const segmentCols: Column<SegmentRow>[] = [
    { key: 'customer_segment', header: 'Customer Segment' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_gross_receivables_rupees', header: 'Gross Receivables (INR)' },
    { key: 'total_opening_rupees', header: 'Opening Provision (INR)' },
    { key: 'total_write_offs_rupees', header: 'Write-Offs (INR)' },
    { key: 'total_recoveries_rupees', header: 'Recoveries (INR)' },
    { key: 'total_write_backs_rupees', header: 'Write-Backs (INR)' },
    { key: 'total_closing_rupees', header: 'Closing Provision (INR)' },
    { key: 'avg_recovery_rate_pct', header: 'Avg Recovery %' },
    { key: 'avg_coverage_pct', header: 'Avg Coverage %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'customer_segment', header: 'Customer Segment' },
    { key: 'recovery_status', header: 'Recovery Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_recoveries_rupees', header: 'Recoveries (INR)' },
    { key: 'total_write_offs_rupees', header: 'Write-Offs (INR)' },
    { key: 'avg_recovery_rate_pct', header: 'Avg Recovery %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_write_offs_rupees', header: 'Write-Offs (INR)' },
    { key: 'total_recoveries_rupees', header: 'Recoveries (INR)' },
    { key: 'total_write_backs_rupees', header: 'Write-Backs (INR)' },
    { key: 'avg_recovery_rate_pct', header: 'Avg Recovery %' },
    { key: 'avg_coverage_pct', header: 'Avg Coverage %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const outlookCols: Column<OutlookRow>[] = [
    { key: 'recovery_outlook', header: 'Recovery Outlook' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'ledger_ref', header: 'Ledger Ref' },
    { key: 'customer_segment', header: 'Segment' },
    { key: 'period_month', header: 'Month' },
    { key: 'recovery_status', header: 'Status' },
    { key: 'write_offs_rupees', header: 'Write-Offs (INR)' },
    { key: 'recovery_rate_pct', header: 'Recovery %' },
    { key: 'provision_coverage_pct', header: 'Coverage %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Bad-Debt Recovery / Provision Write-Back Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated bad-debt recovery ledger — customer segment (government hospitals, private
        hospital chains, standalone clinics, diagnostic labs, medical colleges, dealers &amp;
        distributors) &times; period &times; opening provision &times; write-offs &times; recoveries
        &times; write-backs &times; closing provision &times; recovery-rate &times; provision-coverage
        &amp; CAPA closure. Movement view: recovery-status distribution, segment scorecards,
        segment &times; status matrix, monthly trend, root-cause pareto, recovery-impact digest, and a
        high-risk queue for deteriorating &amp; write-off-heavy books.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Recovery-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No recovery entries logged yet."
          rowKey={(r, i) => String(r.recovery_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Customer-segment scorecard</h2>
        <DataTable
          rows={segmentRows}
          columns={segmentCols}
          emptyMessage="No segment rollups."
          rowKey={(r, i) => String(r.customer_segment ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Segment &times; recovery-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by segment."
          rowKey={(r, i) => `${r.customer_segment}-${r.recovery_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly recovery trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Recovery-impact digest</h2>
        <DataTable
          rows={outlookRows}
          columns={outlookCols}
          emptyMessage="No recovery-impact rollups."
          rowKey={(r, i) => String(r.recovery_outlook ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk recovery queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk books."
          rowKey={(r, i) => `${r.ledger_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
