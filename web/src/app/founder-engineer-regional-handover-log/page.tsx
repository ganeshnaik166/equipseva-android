import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_handovers: number;
  active_handovers: number;
  completed_handovers: number;
  blocked_handovers: number;
  avg_days_to_complete: number;
  total_items_pending: number;
  critical_items_pending: number;
};

type HandoverRow = {
  id: string;
  outgoing_email: string | null;
  incoming_email: string | null;
  handover_reason: string;
  from_region: string;
  to_region: string | null;
  effective_date: string;
  status: string;
  accounts_count: number;
  amc_contracts_count: number;
  open_jobs_count: number;
  tools_returned_count: number;
  tools_assigned_count: number;
  created_at: string;
};

type KindRow = {
  item_kind: string;
  total_items: number;
  transferred_items: number;
  pending_items: number;
  critical_pending: number;
};

type ReasonRow = {
  handover_reason: string;
  total: number;
  completed: number;
  avg_accounts: number;
  avg_amc_contracts: number;
};

type BlockedRow = {
  id: string;
  outgoing_email: string | null;
  from_region: string;
  status: string;
  open_jobs_count: number;
  tools_pending: number;
  effective_date: string;
  notes: string | null;
};

type ChurnRow = {
  region: string;
  exits_count: number;
  arrivals_count: number;
  net_flow: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, listRes, kindRes, reasonRes, blockedRes, churnRes] = await Promise.all([
    sb.rpc('fn_r2286_handover_summary'),
    sb.rpc('fn_r2286_list_handovers', { p_limit: 50 }),
    sb.rpc('fn_r2286_items_by_kind'),
    sb.rpc('fn_r2286_handovers_by_reason'),
    sb.rpc('fn_r2286_blocked_handovers'),
    sb.rpc('fn_r2286_region_churn'),
  ]);

  const summary: SummaryRow | null = (summaryRes.data?.[0] as SummaryRow) ?? null;
  const handovers: HandoverRow[] = (listRes.data as HandoverRow[]) ?? [];
  const kinds: KindRow[] = (kindRes.data as KindRow[]) ?? [];
  const reasons: ReasonRow[] = (reasonRes.data as ReasonRow[]) ?? [];
  const blocked: BlockedRow[] = (blockedRes.data as BlockedRow[]) ?? [];
  const churn: ChurnRow[] = (churnRes.data as ChurnRow[]) ?? [];

  const handoverCols: Column<HandoverRow>[] = [
    { key: 'outgoing_email', header: 'Outgoing', render: (r) => r.outgoing_email ?? '—' },
    { key: 'incoming_email', header: 'Incoming', render: (r) => r.incoming_email ?? '—' },
    { key: 'handover_reason', header: 'Reason', render: (r) => r.handover_reason },
    { key: 'from_region', header: 'From', render: (r) => r.from_region },
    { key: 'to_region', header: 'To', render: (r) => r.to_region ?? '—' },
    { key: 'effective_date', header: 'Effective', render: (r) => r.effective_date },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'accounts_count', header: 'Accts', render: (r) => r.accounts_count },
    { key: 'amc_contracts_count', header: 'AMCs', render: (r) => r.amc_contracts_count },
    { key: 'open_jobs_count', header: 'Open Jobs', render: (r) => r.open_jobs_count },
    {
      key: 'tools_returned_count',
      header: 'Tools',
      render: (r) => `${r.tools_returned_count} / ${r.tools_assigned_count}`,
    },
  ];

  const kindCols: Column<KindRow>[] = [
    { key: 'item_kind', header: 'Kind', render: (r) => r.item_kind },
    { key: 'total_items', header: 'Total', render: (r) => r.total_items },
    { key: 'transferred_items', header: 'Transferred', render: (r) => r.transferred_items },
    { key: 'pending_items', header: 'Pending', render: (r) => r.pending_items },
    { key: 'critical_pending', header: 'Critical Pending', render: (r) => r.critical_pending },
  ];

  const reasonCols: Column<ReasonRow>[] = [
    { key: 'handover_reason', header: 'Reason', render: (r) => r.handover_reason },
    { key: 'total', header: 'Total', render: (r) => r.total },
    { key: 'completed', header: 'Completed', render: (r) => r.completed },
    { key: 'avg_accounts', header: 'Avg Accounts', render: (r) => Number(r.avg_accounts).toFixed(1) },
    { key: 'avg_amc_contracts', header: 'Avg AMCs', render: (r) => Number(r.avg_amc_contracts).toFixed(1) },
  ];

  const blockedCols: Column<BlockedRow>[] = [
    { key: 'outgoing_email', header: 'Outgoing', render: (r) => r.outgoing_email ?? '—' },
    { key: 'from_region', header: 'Region', render: (r) => r.from_region },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'open_jobs_count', header: 'Open Jobs', render: (r) => r.open_jobs_count },
    { key: 'tools_pending', header: 'Tools Pending', render: (r) => r.tools_pending },
    { key: 'effective_date', header: 'Effective', render: (r) => r.effective_date },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  const churnCols: Column<ChurnRow>[] = [
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'exits_count', header: 'Exits', render: (r) => r.exits_count },
    { key: 'arrivals_count', header: 'Arrivals', render: (r) => r.arrivals_count },
    {
      key: 'net_flow',
      header: 'Net',
      render: (r) => (r.net_flow > 0 ? `+${r.net_flow}` : String(r.net_flow)),
    },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer Regional Handover Log
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Structured handover when an engineer moves regions or leaves: accounts & AMCs reassigned, open
        jobs closed out, tools returned, knowledge transferred. Founder oversight prevents silent
        handover gaps &gt;= critical risk.
      </p>

      {summary ? (
        <section
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: 12,
            marginBottom: 24,
          }}
        >
          <Kpi label="Total Handovers" value={summary.total_handovers} />
          <Kpi label="Active" value={summary.active_handovers} />
          <Kpi label="Completed" value={summary.completed_handovers} />
          <Kpi label="Blocked" value={summary.blocked_handovers} tone="warn" />
          <Kpi label="Avg Days to Close" value={Number(summary.avg_days_to_complete).toFixed(1)} />
          <Kpi label="Items Pending" value={summary.total_items_pending} />
          <Kpi label="Critical Pending" value={summary.critical_items_pending} tone="danger" />
        </section>
      ) : null}

      <Section title="Blocked / At-Risk Handovers">
        <DataTable<BlockedRow> columns={blockedCols} rows={blocked} rowKey={(r) => r.id} />
      </Section>

      <Section title="Handovers (most recent)">
        <DataTable<HandoverRow> columns={handoverCols} rows={handovers} rowKey={(r) => r.id} />
      </Section>

      <Section title="Items by Kind">
        <DataTable<KindRow> columns={kindCols} rows={kinds} rowKey={(r) => r.item_kind} />
      </Section>

      <Section title="Handovers by Reason">
        <DataTable<ReasonRow> columns={reasonCols} rows={reasons} rowKey={(r) => r.handover_reason} />
      </Section>

      <Section title="Region Churn (exits vs arrivals)">
        <DataTable<ChurnRow> columns={churnCols} rows={churn} rowKey={(r) => r.region} />
      </Section>
    </main>
  );
}

function Kpi({ label, value, tone }: { label: string; value: number | string; tone?: 'warn' | 'danger' }) {
  const color = tone === 'danger' ? '#b91c1c' : tone === 'warn' ? '#b45309' : '#111';
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, color }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>{title}</h2>
      {children}
    </section>
  );
}
