import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { claim_status: string; claims: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_claims: number;
  resolved: number;
  escalated: number;
  rejected: number;
  sla_met_count: number;
  sla_breached: number;
  avg_tat_days: number | null;
  sla_compliance_pct: number | null;
};
type MatrixRow = {
  oem_name: string;
  claim_type: string;
  claims: number;
  resolved: number;
  avg_tat_days: number | null;
};
type TrendRow = {
  raised_date: string;
  claims_raised: number;
  resolved: number;
  escalated: number;
  rejected: number;
  avg_tat_days: number | null;
};
type CapaRow = {
  capa_status: string;
  actions: number;
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
  actions: number;
  open_actions: number;
  total_cost_rupees: number;
};
type QueueRow = {
  hospital_name: string;
  equipment_name: string;
  oem_name: string;
  claim_reference: string;
  raised_date: string;
  claim_status: string;
  escalation_level: string;
  tat_days: number | null;
  sla_met: boolean | null;
  claim_value_rupees: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3176_claim_status_rollup'),
    supabase.rpc('founder_r3176_hospital_scorecard'),
    supabase.rpc('founder_r3176_oem_claim_matrix'),
    supabase.rpc('founder_r3176_raised_daily_trend'),
    supabase.rpc('founder_r3176_capa_status_board'),
    supabase.rpc('founder_r3176_root_cause_pareto'),
    supabase.rpc('founder_r3176_regulatory_impact_digest'),
    supabase.rpc('founder_r3176_priority_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'claim_status', header: 'Status', render: (r) => r.claim_status },
    { key: 'claims', header: 'Claims', render: (r) => r.claims },
    { key: 'pct', header: 'Share %', render: (r) => r.pct },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'total_claims', header: 'Claims', render: (r) => r.total_claims },
    { key: 'resolved', header: 'Resolved', render: (r) => r.resolved },
    { key: 'escalated', header: 'Escalated', render: (r) => r.escalated },
    { key: 'rejected', header: 'Rejected', render: (r) => r.rejected },
    { key: 'sla_met_count', header: 'SLA Met', render: (r) => r.sla_met_count },
    { key: 'sla_breached', header: 'SLA Breached', render: (r) => r.sla_breached },
    { key: 'avg_tat_days', header: 'Avg TAT (days)', render: (r) => r.avg_tat_days ?? '—' },
    { key: 'sla_compliance_pct', header: 'SLA Compliance %', render: (r) => r.sla_compliance_pct ?? '—' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'oem_name', header: 'OEM', render: (r) => r.oem_name },
    { key: 'claim_type', header: 'Claim Type', render: (r) => r.claim_type },
    { key: 'claims', header: 'Claims', render: (r) => r.claims },
    { key: 'resolved', header: 'Resolved', render: (r) => r.resolved },
    { key: 'avg_tat_days', header: 'Avg TAT (days)', render: (r) => r.avg_tat_days ?? '—' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'raised_date', header: 'Raised Date', render: (r) => r.raised_date },
    { key: 'claims_raised', header: 'Raised', render: (r) => r.claims_raised },
    { key: 'resolved', header: 'Resolved', render: (r) => r.resolved },
    { key: 'escalated', header: 'Escalated', render: (r) => r.escalated },
    { key: 'rejected', header: 'Rejected', render: (r) => r.rejected },
    { key: 'avg_tat_days', header: 'Avg TAT (days)', render: (r) => r.avg_tat_days ?? '—' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status', render: (r) => r.capa_status },
    { key: 'actions', header: 'Actions', render: (r) => r.actions },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)', render: (r) => r.avg_cost_rupees ?? '—' },
    { key: 'overdue_flag', header: 'Overdue / Escalated', render: (r) => r.overdue_flag },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause', render: (r) => r.root_cause },
    { key: 'occurrences', header: 'Occurrences', render: (r) => r.occurrences },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)', render: (r) => r.total_cost_rupees },
    { key: 'pct', header: 'Share %', render: (r) => r.pct },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact', render: (r) => r.regulatory_impact },
    { key: 'actions', header: 'Actions', render: (r) => r.actions },
    { key: 'open_actions', header: 'Open', render: (r) => r.open_actions },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)', render: (r) => r.total_cost_rupees },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'equipment_name', header: 'Equipment', render: (r) => r.equipment_name },
    { key: 'oem_name', header: 'OEM', render: (r) => r.oem_name },
    { key: 'claim_reference', header: 'Claim Ref', render: (r) => r.claim_reference },
    { key: 'raised_date', header: 'Raised', render: (r) => r.raised_date },
    { key: 'claim_status', header: 'Status', render: (r) => r.claim_status },
    { key: 'escalation_level', header: 'Escalation', render: (r) => r.escalation_level },
    { key: 'tat_days', header: 'TAT (days)', render: (r) => r.tat_days ?? '—' },
    { key: 'sla_met', header: 'SLA Met', render: (r) => (r.sla_met === null ? '—' : r.sla_met ? 'yes' : 'no') },
    { key: 'claim_value_rupees', header: 'Claim Value (INR)', render: (r) => r.claim_value_rupees ?? '—' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Warranty-Claim &amp; OEM-Escalation Turnaround Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        OEM warranty-claim log — equipment &times; OEM &times; claim type &times; raised / ack /
        resolved dates &times; turnaround days &times; SLA-met &times; escalation level &amp; CAPA
        closure. Founder-gated view: claim-status rollup, hospital turnaround scorecards, OEM
        matrix, root-cause pareto, and regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Claim status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No warranty claims logged yet."
          rowKey={(r, i) => String(r.claim_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital turnaround scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. OEM &times; claim-type matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No claims by OEM."
          rowKey={(r, i) => `${r.oem_name}-${r.claim_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Claims-raised daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.raised_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk priority queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk claims."
          rowKey={(r, i) => `${r.claim_reference}-${i}`}
        />
      </section>
    </main>
  );
}
