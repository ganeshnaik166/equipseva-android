import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3">
      <div className="text-[11px] uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-neutral-900">{value}</div>
    </div>
  );
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [kpis, reasons, competitors, recent, byCity, ladder, recoverable] = await Promise.all([
    sb.rpc('founder_lost_deal_kpis_v2'),
    sb.rpc('founder_lost_deal_top_reasons_v2'),
    sb.rpc('founder_lost_deal_top_competitors_v2'),
    sb.rpc('founder_lost_deal_recent_v2'),
    sb.rpc('founder_lost_deal_by_city_v2'),
    sb.rpc('founder_lost_deal_action_ladder_v2'),
    sb.rpc('founder_lost_deal_recoverable_v2'),
  ]);

  const k: any = (kpis.data && kpis.data[0]) || {};
  const reasonRows: any[] = reasons.data || [];
  const competitorRows: any[] = competitors.data || [];
  const recentRows: any[] = recent.data || [];
  const cityRows: any[] = byCity.data || [];
  const ladderRows: any[] = ladder.data || [];
  const recoverableRows: any[] = recoverable.data || [];

  const topReason = reasonRows[0]?.lose_reason ?? "—";
  const top5LostValue = reasonRows.reduce((s, r) => s + Number(r.lost_value_rupees || 0), 0);
  const recoverableValue = recoverableRows.reduce((s, r) => s + Number(r.deal_value_rupees || 0), 0);
  const avgPriceGap = competitorRows.length
    ? (competitorRows.reduce((s, r) => s + Number(r.price_gap_pct || 0), 0) / competitorRows.length).toFixed(1)
    : '0';

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold text-neutral-900">Hospital Lost-Deal Post-Mortem</h1>
        <p className="text-sm text-neutral-600">Every lost AMC and sales deal — reason, competitor, gap, recovery ladder.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Lost deals (30d)" value={String(k.total_lost_30d ?? 0)} />
        <Kpi label="Lost value (30d)" value={formatRupees(Number(k.total_lost_value_30d_rupees ?? 0))} />
        <Kpi label="Lost deals (90d)" value={String(k.total_lost_90d ?? 0)} />
        <Kpi label="Lost value (90d)" value={formatRupees(Number(k.total_lost_value_90d_rupees ?? 0))} />
        <Kpi label="Avg deal value" value={formatRupees(Number(k.avg_deal_value_rupees ?? 0))} />
        <Kpi label="Could-have-won %" value={`${Number(k.pct_could_have_won ?? 0)}%`} />
        <Kpi label="Recovery rate" value={`${Number(k.recovery_rate_pct ?? 0)}%`} />
        <Kpi label="Distinct competitors" value={String(k.competitor_count ?? 0)} />
        <Kpi label="Top competitor" value={String(k.top_competitor ?? "—")} />
        <Kpi label="Open action items" value={String(k.open_actions ?? 0)} />
        <Kpi label="Top lose reason" value={topReason} />
        <Kpi label="Top-5 reasons lost value" value={formatRupees(top5LostValue)} />
        <Kpi label="Recoverable deals" value={String(recoverableRows.length)} />
        <Kpi label="Recoverable value" value={formatRupees(recoverableValue)} />
        <Kpi label="Avg price gap vs competitor" value={`${avgPriceGap}%`} />
        <Kpi label="Cities with losses" value={String(cityRows.length)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold text-neutral-900">Top-5 lose reasons (180d)</h2>
        <DataTable
          rows={reasonRows}
          rowKey={(r: any) => r.lose_reason}
          columns={[
            { key: 'lose_reason', header: 'Reason', render: (r: any) => r.lose_reason },
            { key: 'deals', header: 'Deals', render: (r: any) => String(r.deals) },
            { key: 'lost_value_rupees', header: 'Lost value', render: (r: any) => formatRupees(Number(r.lost_value_rupees || 0)) },
            { key: 'pct_of_total', header: '% of total', render: (r: any) => `${Number(r.pct_of_total || 0)}%` },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold text-neutral-900">Top competitors who won</h2>
        <DataTable
          rows={competitorRows}
          rowKey={(r: any) => r.competitor_won}
          columns={[
            { key: 'competitor_won', header: 'Competitor', render: (r: any) => r.competitor_won ?? "—" },
            { key: 'deals_lost', header: 'Deals lost', render: (r: any) => String(r.deals_lost) },
            { key: 'lost_value_rupees', header: 'Lost value', render: (r: any) => formatRupees(Number(r.lost_value_rupees || 0)) },
            { key: 'avg_competitor_price_rupees', header: 'Their price', render: (r: any) => formatRupees(Number(r.avg_competitor_price_rupees || 0)) },
            { key: 'our_avg_price_rupees', header: 'Our price', render: (r: any) => formatRupees(Number(r.our_avg_price_rupees || 0)) },
            { key: 'price_gap_pct', header: 'Price gap', render: (r: any) => `${Number(r.price_gap_pct || 0)}%` },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold text-neutral-900">Recent lost deals</h2>
        <DataTable
          rows={recentRows}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name },
            { key: 'hospital_city', header: 'City', render: (r: any) => r.hospital_city ?? "—" },
            { key: 'deal_type', header: 'Type', render: (r: any) => r.deal_type },
            { key: 'deal_value_rupees', header: 'Value', render: (r: any) => formatRupees(Number(r.deal_value_rupees || 0)) },
            { key: 'lose_reason', header: 'Reason', render: (r: any) => r.lose_reason },
            { key: 'competitor_won', header: 'Competitor', render: (r: any) => r.competitor_won ?? "—" },
            { key: 'lost_at', header: 'Lost', render: (r: any) => new Date(r.lost_at).toLocaleDateString() },
            { key: 'recovered', header: 'Recovered', render: (r: any) => r.recovered ? 'yes' : (r.could_we_have_won ? 'could-have' : 'no') },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold text-neutral-900">Losses by city</h2>
        <DataTable
          rows={cityRows}
          rowKey={(r: any) => r.hospital_city}
          columns={[
            { key: 'hospital_city', header: 'City', render: (r: any) => r.hospital_city },
            { key: 'deals', header: 'Deals', render: (r: any) => String(r.deals) },
            { key: 'lost_value_rupees', header: 'Lost value', render: (r: any) => formatRupees(Number(r.lost_value_rupees || 0)) },
            { key: 'top_reason', header: 'Top reason', render: (r: any) => r.top_reason },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold text-neutral-900">Founder action ladder</h2>
        <DataTable
          rows={ladderRows}
          rowKey={(r: any) => `${r.action_rung}-${r.action_label}`}
          columns={[
            { key: 'action_rung', header: 'Rung', render: (r: any) => String(r.action_rung) },
            { key: 'action_label', header: 'Action', render: (r: any) => r.action_label },
            { key: 'deals_affected', header: 'Deals', render: (r: any) => String(r.deals_affected) },
            { key: 'open_actions', header: 'Open', render: (r: any) => String(r.open_actions) },
            { key: 'done_actions', header: 'Done', render: (r: any) => String(r.done_actions) },
            { key: 'completion_pct', header: 'Done %', render: (r: any) => `${Number(r.completion_pct || 0)}%` },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold text-neutral-900">Recoverable deals (could-have-won, not yet recovered)</h2>
        <DataTable
          rows={recoverableRows}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name },
            { key: 'deal_value_rupees', header: 'Value', render: (r: any) => formatRupees(Number(r.deal_value_rupees || 0)) },
            { key: 'lose_reason', header: 'Reason', render: (r: any) => r.lose_reason },
            { key: 'fix_category', header: 'Fix area', render: (r: any) => r.fix_category ?? "—" },
            { key: 'lost_days_ago', header: 'Days ago', render: (r: any) => String(r.lost_days_ago) },
            { key: 'gap_analysis', header: 'Gap', render: (r: any) => r.gap_analysis ?? "—" },
          ]}
        />
      </section>
    </div>
  );
}
