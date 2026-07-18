import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { ramp_verdict: string; referrals: number; pct: number };
type ReferrerRow = {
  referrer_engineer_name: string;
  total_referrals: number;
  retained: number;
  churned: number;
  avg_jobs_30d: number;
  avg_quality_score: number;
  total_bonus_rupees: number;
};
type MatrixRow = {
  referral_source: string;
  specialization: string;
  referrals: number;
  retained: number;
  avg_jobs_90d: number;
};
type TrendRow = {
  referral_date: string;
  referrals: number;
  onboarded: number;
  retained: number;
  avg_quality: number;
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
type QueueRow = {
  hospital_name: string;
  referrer_engineer_name: string;
  referred_engineer_name: string;
  referral_code: string;
  referral_date: string;
  bonus_stage: string;
  jobs_first_30_days: number;
  quality_score: number | null;
  ramp_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    referrerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3212_ramp_verdict_rollup'),
    supabase.rpc('founder_r3212_referrer_scorecard'),
    supabase.rpc('founder_r3212_source_specialization_matrix'),
    supabase.rpc('founder_r3212_referral_daily_trend'),
    supabase.rpc('founder_r3212_capa_status_board'),
    supabase.rpc('founder_r3212_root_cause_pareto'),
    supabase.rpc('founder_r3212_regulatory_impact_digest'),
    supabase.rpc('founder_r3212_stalled_ramp_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const referrerRows: ReferrerRow[] = (referrerRes.data as ReferrerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'ramp_verdict', header: 'Ramp Verdict' },
    { key: 'referrals', header: 'Referrals' },
    { key: 'pct', header: 'Share %' },
  ];

  const referrerCols: Column<ReferrerRow>[] = [
    { key: 'referrer_engineer_name', header: 'Referrer' },
    { key: 'total_referrals', header: 'Referrals' },
    { key: 'retained', header: 'Retained' },
    { key: 'churned', header: 'Churned' },
    { key: 'avg_jobs_30d', header: 'Avg Jobs 30d' },
    { key: 'avg_quality_score', header: 'Avg Quality' },
    { key: 'total_bonus_rupees', header: 'Bonus Paid (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'referral_source', header: 'Source' },
    { key: 'specialization', header: 'Specialization' },
    { key: 'referrals', header: 'Referrals' },
    { key: 'retained', header: 'Retained' },
    { key: 'avg_jobs_90d', header: 'Avg Jobs 90d' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'referral_date', header: 'Date' },
    { key: 'referrals', header: 'Referrals' },
    { key: 'onboarded', header: 'Onboarded' },
    { key: 'retained', header: 'Retained' },
    { key: 'avg_quality', header: 'Avg Quality' },
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

  const queueCols: Column<QueueRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'referrer_engineer_name', header: 'Referrer' },
    { key: 'referred_engineer_name', header: 'Referred' },
    { key: 'referral_code', header: 'Code' },
    { key: 'referral_date', header: 'Date' },
    { key: 'bonus_stage', header: 'Bonus Stage' },
    { key: 'jobs_first_30_days', header: 'Jobs 30d' },
    { key: 'quality_score', header: 'Quality' },
    { key: 'ramp_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Referral-Program Effectiveness &amp; New-Engineer Ramp Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Referral funnel &amp; ramp log &mdash; referrer &times; referred &times; bonus stage &times;
        30/60/90-day job volume &times; quality &times; retention &amp; CAPA closure. Founder-gated view:
        ramp verdicts, referrer scorecards, source &times; specialization matrix, root-cause pareto,
        and a stalled-ramp intervention queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Ramp verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No referrals logged yet."
          rowKey={(r, i) => String(r.ramp_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Referrer scorecard</h2>
        <DataTable
          rows={referrerRows}
          columns={referrerCols}
          emptyMessage="No referrer rollups."
          rowKey={(r, i) => String(r.referrer_engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Source &times; specialization matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No referrals by source."
          rowKey={(r, i) => `${r.referral_source}-${r.specialization}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Referral daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.referral_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Stalled-ramp intervention queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No stalled ramps."
          rowKey={(r, i) => `${r.referral_code}-${r.referral_date}-${i}`}
        />
      </section>
    </main>
  );
}
