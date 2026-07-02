import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { call_status: string; n: number; avg_score: number | null; total_duration_min: number };
type SentRow = { sentiment: string; outcome: string; n: number; avg_score: number | null };
type VelRow = { velocity_band: string; n: number; completed_n: number };
type InvRow = { investor_firm: string; investor_lead: string; n_calls: number; avg_score: number | null; best_outcome: string };
type RefTypeRow = { reference_type: string; n: number; avg_score: number | null; won_n: number };
type SlaRow = { sla_band: string; action_status: string; n: number; avg_ageing: number | null };
type OwnerRow = { action_owner: string; open_n: number; breached_n: number; completed_n: number };
type PriRow = { priority_band: string; action_type: string; n: number; overdue_n: number };
type HotRow = { action_owner: string; action_type: string; priority_band: string; sla_band: string; ageing_days: number | null; founder_notes: string | null };

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    statusRes,
    sentRes,
    velRes,
    invRes,
    refTypeRes,
    slaRes,
    ownerRes,
    priRes,
    hotRes,
  ] = await Promise.all([
    sb.rpc('rpc_r3131_outreach_status_pipeline'),
    sb.rpc('rpc_r3131_sentiment_outcome_matrix'),
    sb.rpc('rpc_r3131_velocity_rollup'),
    sb.rpc('rpc_r3131_top_investors'),
    sb.rpc('rpc_r3131_reference_type_performance'),
    sb.rpc('rpc_r3131_followup_sla_rollup'),
    sb.rpc('rpc_r3131_action_owner_load'),
    sb.rpc('rpc_r3131_priority_action_matrix'),
    sb.rpc('rpc_r3131_hot_followups'),
  ]);

  const statusRows = (statusRes.data ?? []) as StatusRow[];
  const sentRows = (sentRes.data ?? []) as SentRow[];
  const velRows = (velRes.data ?? []) as VelRow[];
  const invRows = (invRes.data ?? []) as InvRow[];
  const refTypeRows = (refTypeRes.data ?? []) as RefTypeRow[];
  const slaRows = (slaRes.data ?? []) as SlaRow[];
  const ownerRows = (ownerRes.data ?? []) as OwnerRow[];
  const priRows = (priRes.data ?? []) as PriRow[];
  const hotRows = (hotRes.data ?? []) as HotRow[];

  const statusCols: Column<StatusRow>[] = [
    { key: 'call_status', header: 'Call status', render: (r) => r.call_status },
    { key: 'n', header: 'Calls', render: (r) => r.n },
    { key: 'avg_score', header: 'Avg score (0-10)', render: (r) => r.avg_score ?? '-' },
    { key: 'total_duration_min', header: 'Total mins', render: (r) => r.total_duration_min },
  ];

  const sentCols: Column<SentRow>[] = [
    { key: 'sentiment', header: 'Sentiment', render: (r) => r.sentiment },
    { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
    { key: 'n', header: 'Calls', render: (r) => r.n },
    { key: 'avg_score', header: 'Avg score', render: (r) => r.avg_score ?? '-' },
  ];

  const velCols: Column<VelRow>[] = [
    { key: 'velocity_band', header: 'Velocity band', render: (r) => r.velocity_band },
    { key: 'n', header: 'Total', render: (r) => r.n },
    { key: 'completed_n', header: 'Completed', render: (r) => r.completed_n },
  ];

  const invCols: Column<InvRow>[] = [
    { key: 'investor_firm', header: 'Investor firm', render: (r) => r.investor_firm },
    { key: 'investor_lead', header: 'Lead', render: (r) => r.investor_lead },
    { key: 'n_calls', header: 'Calls', render: (r) => r.n_calls },
    { key: 'avg_score', header: 'Avg score', render: (r) => r.avg_score ?? '-' },
    { key: 'best_outcome', header: 'Best outcome', render: (r) => r.best_outcome },
  ];

  const refTypeCols: Column<RefTypeRow>[] = [
    { key: 'reference_type', header: 'Reference type', render: (r) => r.reference_type },
    { key: 'n', header: 'Calls', render: (r) => r.n },
    { key: 'avg_score', header: 'Avg score', render: (r) => r.avg_score ?? '-' },
    { key: 'won_n', header: 'Closed-won', render: (r) => r.won_n },
  ];

  const slaCols: Column<SlaRow>[] = [
    { key: 'sla_band', header: 'SLA band', render: (r) => r.sla_band },
    { key: 'action_status', header: 'Action status', render: (r) => r.action_status },
    { key: 'n', header: 'Actions', render: (r) => r.n },
    { key: 'avg_ageing', header: 'Avg ageing (days)', render: (r) => r.avg_ageing ?? '-' },
  ];

  const ownerCols: Column<OwnerRow>[] = [
    { key: 'action_owner', header: 'Action owner', render: (r) => r.action_owner },
    { key: 'open_n', header: 'Open', render: (r) => r.open_n },
    { key: 'breached_n', header: 'Breached', render: (r) => r.breached_n },
    { key: 'completed_n', header: 'Completed', render: (r) => r.completed_n },
  ];

  const priCols: Column<PriRow>[] = [
    { key: 'priority_band', header: 'Priority', render: (r) => r.priority_band },
    { key: 'action_type', header: 'Action type', render: (r) => r.action_type },
    { key: 'n', header: 'Total', render: (r) => r.n },
    { key: 'overdue_n', header: 'Overdue/breached', render: (r) => r.overdue_n },
  ];

  const hotCols: Column<HotRow>[] = [
    { key: 'action_owner', header: 'Owner', render: (r) => r.action_owner },
    { key: 'action_type', header: 'Action', render: (r) => r.action_type },
    { key: 'priority_band', header: 'Priority', render: (r) => r.priority_band },
    { key: 'sla_band', header: 'SLA', render: (r) => r.sla_band },
    { key: 'ageing_days', header: 'Ageing (d)', render: (r) => r.ageing_days ?? '-' },
    { key: 'founder_notes', header: 'Notes', render: (r) => r.founder_notes ?? '' },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Founder Investor Reference Call Outreach Tracker</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Quarterly view of founder-led investor reference calls — pipeline, sentiment, velocity, follow-up SLA.
        </p>
      </header>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">1. Outreach pipeline by call status</h2>
        <DataTable<StatusRow>
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No outreach pipeline rows."
          rowKey={(r, i) => String((r as { call_status?: string }).call_status ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">2. Sentiment × outcome matrix</h2>
        <DataTable<SentRow>
          rows={sentRows}
          columns={sentCols}
          emptyMessage="No sentiment matrix rows."
          rowKey={(r, i) => `${r.sentiment}-${r.outcome}-${i}`}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">3. Velocity band rollup</h2>
        <DataTable<VelRow>
          rows={velRows}
          columns={velCols}
          emptyMessage="No velocity rollup rows."
          rowKey={(r, i) => `${r.velocity_band}-${i}`}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">4. Top investor leads by avg score</h2>
        <DataTable<InvRow>
          rows={invRows}
          columns={invCols}
          emptyMessage="No investor leads."
          rowKey={(r, i) => `${r.investor_firm}-${r.investor_lead}-${i}`}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">5. Reference-type performance</h2>
        <DataTable<RefTypeRow>
          rows={refTypeRows}
          columns={refTypeCols}
          emptyMessage="No reference-type rows."
          rowKey={(r, i) => `${r.reference_type}-${i}`}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">6. Follow-up SLA rollup</h2>
        <DataTable<SlaRow>
          rows={slaRows}
          columns={slaCols}
          emptyMessage="No SLA rollup rows."
          rowKey={(r, i) => `${r.sla_band}-${r.action_status}-${i}`}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">7. Action owner load</h2>
        <DataTable<OwnerRow>
          rows={ownerRows}
          columns={ownerCols}
          emptyMessage="No owner-load rows."
          rowKey={(r, i) => `${r.action_owner}-${i}`}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">8. Priority × action-type matrix</h2>
        <DataTable<PriRow>
          rows={priRows}
          columns={priCols}
          emptyMessage="No priority matrix rows."
          rowKey={(r, i) => `${r.priority_band}-${r.action_type}-${i}`}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">9. Hot follow-ups (breached / at-risk)</h2>
        <DataTable<HotRow>
          rows={hotRows}
          columns={hotCols}
          emptyMessage="No hot follow-ups."
          rowKey={(r, i) => `${r.action_owner}-${r.action_type}-${i}`}
        />
      </section>
    </main>
  );
}
