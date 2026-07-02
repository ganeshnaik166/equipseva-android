import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalChainRfpPipelinePage() {
  const supabase = await getSupabaseServerClient();

  const [
    rfpsRes,
    intelRes,
    funnelRes,
    topValueRes,
    upcomingRes,
    winRateRes,
    monthlyRes,
  ] = await Promise.all([
    supabase.rpc('list_rfps_r2451'),
    supabase.rpc('list_competitor_intel_r2451'),
    supabase.rpc('stage_funnel_r2451'),
    supabase.rpc('top_value_rfps_r2451'),
    supabase.rpc('upcoming_decisions_r2451'),
    supabase.rpc('win_rate_by_kind_r2451'),
    supabase.rpc('monthly_pipeline_trend_r2451'),
  ]);

  const rfps = (rfpsRes.data ?? []) as any[];
  const intel = (intelRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const topValue = (topValueRes.data ?? []) as any[];
  const upcoming = (upcomingRes.data ?? []) as any[];
  const winRate = (winRateRes.data ?? []) as any[];
  const monthly = (monthlyRes.data ?? []) as any[];

  const rfpCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'rfp_external_ref', header: 'RFP Ref', render: (r: any) => r.rfp_external_ref ?? '-' },
    { key: 'rfp_kind', header: 'Kind', render: (r: any) => r.rfp_kind },
    { key: 'issued_at', header: 'Issued', render: (r: any) => r.issued_at ? String(r.issued_at).slice(0, 10) : '-' },
    { key: 'submission_due_at', header: 'Submit By', render: (r: any) => r.submission_due_at ? String(r.submission_due_at).slice(0, 10) : '-' },
    { key: 'decision_due_at', header: 'Decision By', render: (r: any) => r.decision_due_at ? String(r.decision_due_at).slice(0, 10) : '-' },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
    { key: 'our_position', header: 'Our Position', render: (r: any) => r.our_position ?? '-' },
    { key: 'win_probability_pct', header: 'Win %', render: (r: any) => r.win_probability_pct },
    { key: 'value_rupees', header: 'Value (Rs)', render: (r: any) => Number(r.value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const intelCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'rfp_external_ref', header: 'RFP Ref', render: (r: any) => r.rfp_external_ref ?? '-' },
    { key: 'competitor_name', header: 'Competitor', render: (r: any) => r.competitor_name },
    { key: 'strength', header: 'Strength', render: (r: any) => r.strength ?? '-' },
    { key: 'weakness', header: 'Weakness', render: (r: any) => r.weakness ?? '-' },
    { key: 'pricing_known_rupees', header: 'Their Price (Rs)', render: (r: any) => r.pricing_known_rupees != null ? Number(r.pricing_known_rupees).toLocaleString('en-IN') : '-' },
    { key: 'our_counter_strategy_md', header: 'Counter Strategy', render: (r: any) => r.our_counter_strategy_md ?? '-' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
    { key: 'rfps', header: 'RFPs', render: (r: any) => r.rfps },
    { key: 'total_value_rupees', header: 'Total Value (Rs)', render: (r: any) => Number(r.total_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'avg_win_probability_pct', header: 'Avg Win %', render: (r: any) => r.avg_win_probability_pct ?? '-' },
  ];

  const topValueCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'rfp_external_ref', header: 'RFP Ref', render: (r: any) => r.rfp_external_ref ?? '-' },
    { key: 'rfp_kind', header: 'Kind', render: (r: any) => r.rfp_kind },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
    { key: 'our_position', header: 'Position', render: (r: any) => r.our_position ?? '-' },
    { key: 'win_probability_pct', header: 'Win %', render: (r: any) => r.win_probability_pct },
    { key: 'value_rupees', header: 'Value (Rs)', render: (r: any) => Number(r.value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'expected_value_rupees', header: 'Expected (Rs)', render: (r: any) => Number(r.expected_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'rfp_external_ref', header: 'RFP Ref', render: (r: any) => r.rfp_external_ref ?? '-' },
    { key: 'rfp_kind', header: 'Kind', render: (r: any) => r.rfp_kind },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
    { key: 'decision_due_at', header: 'Decision By', render: (r: any) => r.decision_due_at ? String(r.decision_due_at).slice(0, 10) : '-' },
    { key: 'days_to_decision', header: 'Days Left', render: (r: any) => r.days_to_decision },
    { key: 'win_probability_pct', header: 'Win %', render: (r: any) => r.win_probability_pct },
    { key: 'value_rupees', header: 'Value (Rs)', render: (r: any) => Number(r.value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const winRateCols: Column<any>[] = [
    { key: 'rfp_kind', header: 'Kind', render: (r: any) => r.rfp_kind },
    { key: 'total_closed', header: 'Closed', render: (r: any) => r.total_closed },
    { key: 'won_count', header: 'Won', render: (r: any) => r.won_count },
    { key: 'lost_count', header: 'Lost', render: (r: any) => r.lost_count },
    { key: 'withdrawn_count', header: 'Withdrawn', render: (r: any) => r.withdrawn_count },
    { key: 'win_rate_pct', header: 'Win Rate %', render: (r: any) => r.win_rate_pct ?? '-' },
    { key: 'total_won_value_rupees', header: 'Won Value (Rs)', render: (r: any) => Number(r.total_won_value_rupees ?? 0).toLocaleString('en-IN') },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'rfps_received', header: 'RFPs Received', render: (r: any) => r.rfps_received },
    { key: 'total_value_rupees', header: 'Total Value (Rs)', render: (r: any) => Number(r.total_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'expected_value_rupees', header: 'Expected (Rs)', render: (r: any) => Number(r.expected_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'won_count', header: 'Won', render: (r: any) => r.won_count },
    { key: 'lost_count', header: 'Lost', render: (r: any) => r.lost_count },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Chain RFP Pipeline</h1>
      <p style={{ marginBottom: 24, color: '#555' }}>
        Chain & RFP & stage & shortlisted vendors & our position & win probability & decision date.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All RFPs</h2>
        <DataTable
          rows={rfps}
          columns={rfpCols}
          emptyMessage="No RFPs on file."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Stage Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No funnel data."
          rowKey={(r: any, i: number) => String(r.stage ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Value Open RFPs</h2>
        <DataTable
          rows={topValue}
          columns={topValueCols}
          emptyMessage="No open RFPs."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Upcoming Decisions</h2>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          emptyMessage="No upcoming decisions."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Win Rate by RFP Kind</h2>
        <DataTable
          rows={winRate}
          columns={winRateCols}
          emptyMessage="No win-rate data."
          rowKey={(r: any, i: number) => String(r.rfp_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Monthly Pipeline Trend</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          emptyMessage="No monthly data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Competitor Intel</h2>
        <DataTable
          rows={intel}
          columns={intelCols}
          emptyMessage="No competitor intel logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
