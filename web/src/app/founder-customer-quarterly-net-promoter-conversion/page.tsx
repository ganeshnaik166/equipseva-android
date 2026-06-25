import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [conversions, actions, topPromoter, kindDist, funnel, trend, ownerLoad] = await Promise.all([
    supabase.rpc('list_conversions_r2628'),
    supabase.rpc('list_actions_r2628'),
    supabase.rpc('top_promoter_focus_r2628'),
    supabase.rpc('conversion_kind_distribution_r2628'),
    supabase.rpc('status_funnel_r2628'),
    supabase.rpc('quarterly_conversion_trend_r2628'),
    supabase.rpc('owner_load_r2628'),
  ]);

  const conversionCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'nps', header: 'NPS', render: (r: any) => r.nps },
    { key: 'promoter_to_referral_pct', header: 'Promoter → Referral %', render: (r: any) => `${r.promoter_to_referral_pct}%` },
    { key: 'detractor_to_churn_pct', header: 'Detractor → Churn %', render: (r: any) => `${r.detractor_to_churn_pct}%` },
    { key: 'converted_referrals_count', header: 'Referrals Won', render: (r: any) => r.converted_referrals_count },
    { key: 'churn_count', header: 'Churned', render: (r: any) => r.churn_count },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString() },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topPromoterCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'nps', header: 'NPS', render: (r: any) => r.nps },
    { key: 'promoter_to_referral_pct', header: 'Promoter → Referral %', render: (r: any) => `${r.promoter_to_referral_pct}%` },
    { key: 'converted_referrals_count', header: 'Referrals Won', render: (r: any) => r.converted_referrals_count },
  ];

  const kindCols: Column<any>[] = [
    { key: 'action_kind', header: 'Action Kind', render: (r: any) => r.action_kind },
    { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'nps', header: 'NPS', render: (r: any) => r.nps },
    { key: 'converted_referrals_count', header: 'Referrals Won', render: (r: any) => r.converted_referrals_count },
    { key: 'churn_count', header: 'Churned', render: (r: any) => r.churn_count },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'open_actions', header: 'Open', render: (r: any) => r.open_actions },
    { key: 'done_actions', header: 'Done', render: (r: any) => r.done_actions },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Customer Quarterly Net Promoter Conversion</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Track how NPS promoters convert into referrals & how detractors trend into churn each quarter.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Quarterly Conversions</h2>
        <DataTable
          rows={conversions.data ?? []}
          columns={conversionCols}
          emptyMessage="No conversion rows yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Conversion Actions Log</h2>
        <DataTable
          rows={actions.data ?? []}
          columns={actionCols}
          emptyMessage="No actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Promoter Focus</h2>
        <DataTable
          rows={topPromoter.data ?? []}
          columns={topPromoterCols}
          emptyMessage="No focus quarters"
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Action Kind Distribution</h2>
        <DataTable
          rows={kindDist.data ?? []}
          columns={kindCols}
          emptyMessage="No actions yet"
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status Funnel</h2>
        <DataTable
          rows={funnel.data ?? []}
          columns={funnelCols}
          emptyMessage="No status data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Quarterly Trend</h2>
        <DataTable
          rows={trend.data ?? []}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner Load</h2>
        <DataTable
          rows={ownerLoad.data ?? []}
          columns={ownerCols}
          emptyMessage="No owners assigned"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
