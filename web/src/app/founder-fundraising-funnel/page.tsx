import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderFundraisingFunnelPage() {
  const supabase = await getSupabaseServerClient();

  const [funnel, actions, distribution, topArr, stalled, conversion, thisWeek] = await Promise.all([
    supabase.rpc('list_funnel_r2461'),
    supabase.rpc('list_stage_actions_r2461'),
    supabase.rpc('stage_distribution_r2461'),
    supabase.rpc('top_arr_offers_r2461'),
    supabase.rpc('stalled_investors_r2461'),
    supabase.rpc('conversion_rate_r2461'),
    supabase.rpc('this_week_actions_r2461'),
  ]);

  const fmtMoney = (v: number | null | undefined) =>
    v == null ? '-' : `Rs ${(v / 10000000).toFixed(2)} Cr`;

  const funnelCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
    { key: 'arr', header: 'ARR Offered', render: (r: any) => fmtMoney(r.arr_offered_rupees) },
    { key: 'val', header: 'Valuation', render: (r: any) => fmtMoney(r.valuation_offered_rupees) },
    { key: 'owner', header: 'Lead Owner', render: (r: any) => r.lead_owner_email },
    { key: 'intro', header: 'Intro', render: (r: any) => r.intro_at ? new Date(r.intro_at).toLocaleDateString() : '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleDateString() },
    { key: 'next_step', header: 'Next Step', render: (r: any) => r.next_step ?? '-' },
    { key: 'next_due', header: 'Due', render: (r: any) => r.next_step_due_at ? new Date(r.next_step_due_at).toLocaleDateString() : '-' },
  ];

  const distCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
    { key: 'investor_count', header: 'Investors', render: (r: any) => r.investor_count },
    { key: 'total_arr', header: 'Total ARR Offered', render: (r: any) => fmtMoney(r.total_arr_offered_rupees) },
  ];

  const topArrCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
    { key: 'arr', header: 'ARR', render: (r: any) => fmtMoney(r.arr_offered_rupees) },
    { key: 'val', header: 'Valuation', render: (r: any) => fmtMoney(r.valuation_offered_rupees) },
  ];

  const stalledCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name },
    { key: 'stage', header: 'Stuck In', render: (r: any) => r.stage },
    { key: 'days', header: 'Days Stalled', render: (r: any) => r.days_stalled },
    { key: 'owner', header: 'Owner', render: (r: any) => r.lead_owner_email },
  ];

  const weekCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'when', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleDateString() },
    { key: 'next', header: 'Next Step', render: (r: any) => r.next_step ?? '-' },
  ];

  const conv = (conversion.data ?? [])[0] ?? {};

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Founder > Fundraising Funnel</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Investor pipeline: intro => meeting => diligence => term sheet => close. ARR & valuation offers tracked.
      </p>

      <section style={{ marginBottom: 32, display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Intros</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{conv.total_intros ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Intro => Meeting</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{conv.intro_to_meeting_pct ?? 0}%</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Meeting => Diligence</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{conv.meeting_to_diligence_pct ?? 0}%</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Diligence => Term Sheet</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{conv.diligence_to_term_pct ?? 0}%</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Closed</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{conv.reached_closed ?? 0}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Investors</h2>
        <DataTable
          rows={funnel.data ?? []}
          columns={funnelCols}
          emptyMessage="No investors in funnel."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Stage Distribution</h2>
        <DataTable
          rows={distribution.data ?? []}
          columns={distCols}
          emptyMessage="No stage data."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top ARR Offers</h2>
        <DataTable
          rows={topArr.data ?? []}
          columns={topArrCols}
          emptyMessage="No ARR offers recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Stalled Investors</h2>
        <DataTable
          rows={stalled.data ?? []}
          columns={stalledCols}
          emptyMessage="No stalled investors. Nice."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>This Week Actions</h2>
        <DataTable
          rows={thisWeek.data ?? []}
          columns={weekCols}
          emptyMessage="No actions this week."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Stage Actions</h2>
        <DataTable
          rows={actions.data ?? []}
          columns={actionCols}
          emptyMessage="No actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
