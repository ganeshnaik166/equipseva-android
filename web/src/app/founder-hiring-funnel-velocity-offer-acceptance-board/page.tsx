import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StageRow = { funnel_stage_status: string; requisitions: number; pct: number };
type HospRow = {
  hospital_name: string;
  requisitions: number;
  sourced_total: number;
  offered_total: number;
  accepted_total: number;
  joined_total: number;
  avg_days_to_offer: number | null;
  acceptance_pct: number | null;
};
type MatrixRow = {
  role_family: string;
  source_channel: string;
  requisitions: number;
  offered_total: number;
  accepted_total: number;
  acceptance_pct: number | null;
};
type TrendRow = {
  opened_on: string;
  requisitions: number;
  sourced_total: number;
  offered_total: number;
  accepted_total: number;
  joined_total: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number | null;
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
type StallRow = {
  hospital_name: string;
  requisition_code: string;
  role_title: string;
  role_family: string;
  funnel_stage_status: string;
  days_to_offer: number | null;
  offer_acceptance_pct: number | null;
  source_channel: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    stageRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    stallRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3185_stage_status_rollup'),
    supabase.rpc('founder_r3185_hospital_scorecard'),
    supabase.rpc('founder_r3185_role_source_matrix'),
    supabase.rpc('founder_r3185_funnel_daily_trend'),
    supabase.rpc('founder_r3185_capa_status_board'),
    supabase.rpc('founder_r3185_root_cause_pareto'),
    supabase.rpc('founder_r3185_regulatory_impact_digest'),
    supabase.rpc('founder_r3185_stalled_requisitions_queue'),
  ]);

  const stageRows: StageRow[] = (stageRes.data as StageRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const stallRows: StallRow[] = (stallRes.data as StallRow[]) ?? [];

  const stageCols: Column<StageRow>[] = [
    { key: 'funnel_stage_status', header: 'Funnel Stage' },
    { key: 'requisitions', header: 'Requisitions' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital Site' },
    { key: 'requisitions', header: 'Reqs' },
    { key: 'sourced_total', header: 'Sourced' },
    { key: 'offered_total', header: 'Offered' },
    { key: 'accepted_total', header: 'Accepted' },
    { key: 'joined_total', header: 'Joined' },
    { key: 'avg_days_to_offer', header: 'Avg Days to Offer' },
    { key: 'acceptance_pct', header: 'Acceptance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'role_family', header: 'Role Family' },
    { key: 'source_channel', header: 'Source Channel' },
    { key: 'requisitions', header: 'Reqs' },
    { key: 'offered_total', header: 'Offered' },
    { key: 'accepted_total', header: 'Accepted' },
    { key: 'acceptance_pct', header: 'Acceptance %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'opened_on', header: 'Opened On' },
    { key: 'requisitions', header: 'Reqs' },
    { key: 'sourced_total', header: 'Sourced' },
    { key: 'offered_total', header: 'Offered' },
    { key: 'accepted_total', header: 'Accepted' },
    { key: 'joined_total', header: 'Joined' },
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
    { key: 'regulatory_impact', header: 'Compliance Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const stallCols: Column<StallRow>[] = [
    { key: 'hospital_name', header: 'Hospital Site' },
    { key: 'requisition_code', header: 'Req Code' },
    { key: 'role_title', header: 'Role' },
    { key: 'role_family', header: 'Family' },
    { key: 'funnel_stage_status', header: 'Stage' },
    { key: 'days_to_offer', header: 'Days to Offer' },
    { key: 'offer_acceptance_pct', header: 'Acceptance %' },
    { key: 'source_channel', header: 'Source' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Hiring-Funnel Velocity &amp; Offer-Acceptance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Hiring funnel log &mdash; role family &times; level &times; source channel &times;
        sourced/screened/interviewed/offered/accepted/joined &times; days-to-offer &times;
        offer-acceptance % &amp; CAPA closure. Founder-gated view: stage rollups, hospital-site
        scorecards, role &times; channel matrix, root-cause pareto, and stalled-requisition queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Funnel stage distribution</h2>
        <DataTable
          rows={stageRows}
          columns={stageCols}
          emptyMessage="No requisitions logged yet."
          rowKey={(r, i) => String(r.funnel_stage_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital-site hiring scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Role family &times; source channel matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No requisitions by channel."
          rowKey={(r, i) => `${r.role_family}-${r.source_channel}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Requisition-opening daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.opened_on ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Compliance impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No compliance-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Stalled / at-risk requisitions queue</h2>
        <DataTable
          rows={stallRows}
          columns={stallCols}
          emptyMessage="No stalled requisitions."
          rowKey={(r, i) => `${r.requisition_code}-${i}`}
        />
      </section>
    </main>
  );
}
