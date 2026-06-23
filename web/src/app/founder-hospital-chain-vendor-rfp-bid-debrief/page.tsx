import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    debriefsRes,
    updatesRes,
    lossesRes,
    kindRes,
    competitorRes,
    monthlyRes,
    funnelRes,
  ] = await Promise.all([
    supabase.rpc('list_debriefs_r2551'),
    supabase.rpc('list_playbook_updates_r2551'),
    supabase.rpc('top_loss_debriefs_r2551'),
    supabase.rpc('kind_breakdown_r2551'),
    supabase.rpc('competitor_winner_summary_r2551'),
    supabase.rpc('monthly_debrief_trend_r2551'),
    supabase.rpc('update_status_funnel_r2551'),
  ]);

  const debriefs = (debriefsRes.data ?? []) as any[];
  const updates = (updatesRes.data ?? []) as any[];
  const losses = (lossesRes.data ?? []) as any[];
  const kinds = (kindRes.data ?? []) as any[];
  const competitors = (competitorRes.data ?? []) as any[];
  const monthly = (monthlyRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];

  const debriefCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'rfp_external_ref', header: 'RFP Ref', render: (r: any) => r.rfp_external_ref ?? '—' },
    { key: 'debriefed_at', header: 'Debriefed', render: (r: any) => new Date(r.debriefed_at).toLocaleDateString() },
    { key: 'debrief_kind', header: 'Kind', render: (r: any) => r.debrief_kind },
    { key: 'our_position', header: 'Position', render: (r: any) => r.our_position },
    { key: 'competitor_winner', header: 'Winner', render: (r: any) => r.competitor_winner ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const updateCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'update_kind', header: 'Kind', render: (r: any) => r.update_kind },
    { key: 'update_summary_md', header: 'Summary', render: (r: any) => r.update_summary_md ?? '—' },
    { key: 'target_at', header: 'Target', render: (r: any) => r.target_at ? new Date(r.target_at).toLocaleDateString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const lossCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'debriefed_at', header: 'Debriefed', render: (r: any) => new Date(r.debriefed_at).toLocaleDateString() },
    { key: 'competitor_winner', header: 'Winner', render: (r: any) => r.competitor_winner ?? '—' },
    { key: 'competitor_strengths_md', header: 'Strengths', render: (r: any) => r.competitor_strengths_md ?? '—' },
    { key: 'playbook_update_md', header: 'Playbook', render: (r: any) => r.playbook_update_md ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const kindCols: Column<any>[] = [
    { key: 'debrief_kind', header: 'Kind', render: (r: any) => r.debrief_kind },
    { key: 'debrief_count', header: 'Count', render: (r: any) => String(r.debrief_count) },
    { key: 'closed_count', header: 'Closed', render: (r: any) => String(r.closed_count) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count) },
  ];

  const competitorCols: Column<any>[] = [
    { key: 'competitor_winner', header: 'Competitor', render: (r: any) => r.competitor_winner },
    { key: 'loss_count', header: 'Losses', render: (r: any) => String(r.loss_count) },
    { key: 'last_loss_at', header: 'Last Loss', render: (r: any) => r.last_loss_at ? new Date(r.last_loss_at).toLocaleDateString() : '—' },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start },
    { key: 'debriefs_logged', header: 'Logged', render: (r: any) => String(r.debriefs_logged) },
    { key: 'wins', header: 'Wins', render: (r: any) => String(r.wins) },
    { key: 'losses', header: 'Losses', render: (r: any) => String(r.losses) },
    { key: 'no_decisions', header: 'No Decision', render: (r: any) => String(r.no_decisions) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'update_count', header: 'Count', render: (r: any) => String(r.update_count) },
    { key: 'done_count', header: 'Done', render: (r: any) => String(r.done_count) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 4 }}>
        Hospital Chain — RFP Bid Debriefs
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Chain × RFP we lost or won × debrief × competitor learnings × playbook update.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Debriefs</h2>
        <DataTable
          rows={debriefs}
          columns={debriefCols}
          emptyMessage="No debriefs logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Playbook Updates</h2>
        <DataTable
          rows={updates}
          columns={updateCols}
          emptyMessage="No playbook updates."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Loss Debriefs</h2>
        <DataTable
          rows={losses}
          columns={lossCols}
          emptyMessage="No losses logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Debrief Kind Breakdown</h2>
        <DataTable
          rows={kinds}
          columns={kindCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.debrief_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Competitor Winner Summary</h2>
        <DataTable
          rows={competitors}
          columns={competitorCols}
          emptyMessage="No competitor losses recorded."
          rowKey={(r: any, i: number) => String(r.competitor_winner ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Debrief Trend</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          emptyMessage="No monthly data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Playbook Update Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No updates."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>
    </div>
  );
}
