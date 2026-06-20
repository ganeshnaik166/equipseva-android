import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

function Kpi({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-neutral-900">{value}</div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <section className="mt-8">
      <div className="mb-3">
        <h2 className="text-base font-semibold text-neutral-900">{title}</h2>
        {subtitle ? <p className="text-sm text-neutral-500">{subtitle}</p> : null}
      </div>
      {children}
    </section>
  );
}

export default async function FounderPartnershipsPipelinePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpisRes, funnelRes, activeRes, stalledRes, byTypeRes, recentRes, topRes] = await Promise.all([
    supabase.rpc('founder_partnerships_kpis'),
    supabase.rpc('founder_partnerships_funnel'),
    supabase.rpc('founder_partnerships_active'),
    supabase.rpc('founder_partnerships_stalled'),
    supabase.rpc('founder_partnerships_by_type'),
    supabase.rpc('founder_partnerships_recent_activity'),
    supabase.rpc('founder_partnerships_top_weighted'),
  ]);

  const k: any = Array.isArray(kpisRes.data) ? kpisRes.data[0] ?? {} : kpisRes.data ?? {};
  const funnel: any[] = funnelRes.data ?? [];
  const active: any[] = activeRes.data ?? [];
  const stalled: any[] = stalledRes.data ?? [];
  const byType: any[] = byTypeRes.data ?? [];
  const recent: any[] = recentRes.data ?? [];
  const top: any[] = topRes.data ?? [];

  return (
    <main className="mx-auto max-w-7xl px-4 py-6">
      <header className="mb-6">
        <h1 className="text-2xl font-bold text-neutral-900">Founder Partnerships Pipeline</h1>
        <p className="mt-1 text-sm text-neutral-600">
          OEMs, distributors, hospital chains, financiers — 7-stage funnel with commercial terms,
          expected revenue, and stalled-deal flags.
        </p>
      </header>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <Kpi label="Total deals" value={Number(k?.total_deals ?? 0).toLocaleString('en-IN')} />
        <Kpi label="Live deals" value={Number(k?.live_deals ?? 0).toLocaleString('en-IN')} />
        <Kpi label="Contract stage" value={Number(k?.contract_deals ?? 0).toLocaleString('en-IN')} />
        <Kpi label="Negotiation" value={Number(k?.negotiation_deals ?? 0).toLocaleString('en-IN')} />
        <Kpi label="Stalled" value={Number(k?.stalled_deals ?? 0).toLocaleString('en-IN')} />
        <Kpi label="Total expected ARR" value={formatRupees(Number(k?.total_expected_revenue_rupees ?? 0))} />
        <Kpi label="Live ARR" value={formatRupees(Number(k?.live_expected_revenue_rupees ?? 0))} />
        <Kpi label="Weighted pipeline" value={formatRupees(Number(k?.weighted_pipeline_rupees ?? 0))} />
        <Kpi label="OEM deals" value={Number(k?.oem_deals ?? 0).toLocaleString('en-IN')} />
        <Kpi label="Distributor deals" value={Number(k?.distributor_deals ?? 0).toLocaleString('en-IN')} />
        <Kpi label="Hospital chain deals" value={Number(k?.hospital_chain_deals ?? 0).toLocaleString('en-IN')} />
        <Kpi label="Financier deals" value={Number(k?.financier_deals ?? 0).toLocaleString('en-IN')} />
        <Kpi label="Exclusive deals" value={Number(k?.exclusive_deals ?? 0).toLocaleString('en-IN')} />
        <Kpi label="Signed last 30d" value={Number(k?.signed_last_30d ?? 0).toLocaleString('en-IN')} />
        <Kpi label="Avg days to contract" value={Number(k?.avg_days_to_contract ?? 0).toFixed(1)} />
        <Kpi label="Active owners" value={Number(k?.active_owners ?? 0).toLocaleString('en-IN')} />
      </div>

      <Section title="7-stage funnel" subtitle="Count, stalled, and expected ARR by stage">
        <DataTable
          rows={funnel}
          rowKey={(r: any) => r.stage}
          columns={[
            { key: 'stage_order', header: '#', render: (r: any) => <span className="text-neutral-500">{r.stage_order}</span> },
            { key: 'stage', header: 'Stage', render: (r: any) => <span className="font-medium capitalize">{String(r.stage).replace('_',' ')}</span> },
            { key: 'deal_count', header: 'Deals', render: (r: any) => Number(r.deal_count ?? 0).toLocaleString('en-IN') },
            { key: 'stalled_count', header: 'Stalled', render: (r: any) => Number(r.stalled_count ?? 0).toLocaleString('en-IN') },
            { key: 'expected_revenue_rupees', header: 'Expected ARR', render: (r: any) => formatRupees(Number(r.expected_revenue_rupees ?? 0)) },
          ]}
        />
      </Section>

      <Section title="Top weighted deals" subtitle="Probability-weighted ARR by stage (excludes stalled)">
        <DataTable
          rows={top}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'partner_name', header: 'Partner', render: (r: any) => <span className="font-medium">{r.partner_name}</span> },
            { key: 'partner_type', header: 'Type', render: (r: any) => <span className="capitalize">{String(r.partner_type).replace('_',' ')}</span> },
            { key: 'stage', header: 'Stage', render: (r: any) => <span className="capitalize">{r.stage}</span> },
            { key: 'expected_annual_revenue_rupees', header: 'Expected ARR', render: (r: any) => formatRupees(Number(r.expected_annual_revenue_rupees ?? 0)) },
            { key: 'weighted_revenue_rupees', header: 'Weighted', render: (r: any) => formatRupees(Number(r.weighted_revenue_rupees ?? 0)) },
            { key: 'exclusivity', header: 'Excl.', render: (r: any) => r.exclusivity ? 'Yes' : 'No' },
            { key: 'go_live_target_date', header: 'Go-live target', render: (r: any) => r.go_live_target_date ?? "—" },
          ]}
        />
      </Section>

      <Section title="Active deals" subtitle="Open (non-stalled) partnerships ranked by expected ARR">
        <DataTable
          rows={active}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'partner_name', header: 'Partner', render: (r: any) => <span className="font-medium">{r.partner_name}</span> },
            { key: 'partner_type', header: 'Type', render: (r: any) => <span className="capitalize">{String(r.partner_type).replace('_',' ')}</span> },
            { key: 'stage', header: 'Stage', render: (r: any) => <span className="capitalize">{r.stage}</span> },
            { key: 'region', header: 'Region', render: (r: any) => r.region ?? "—" },
            { key: 'expected_annual_revenue_rupees', header: 'Expected ARR', render: (r: any) => formatRupees(Number(r.expected_annual_revenue_rupees ?? 0)) },
            { key: 'revenue_share_pct', header: 'Rev share %', render: (r: any) => r.revenue_share_pct != null ? `${Number(r.revenue_share_pct).toFixed(1)}%` : "—" },
            { key: 'exclusivity', header: 'Excl.', render: (r: any) => r.exclusivity ? 'Yes' : 'No' },
            { key: 'days_since_activity', header: 'Days idle', render: (r: any) => <span className={Number(r.days_since_activity ?? 0) > 14 ? 'text-amber-600 font-medium' : ''}>{Number(r.days_since_activity ?? 0)}</span> },
          ]}
        />
      </Section>

      <Section title="By partner type" subtitle="Rollup across all stages">
        <DataTable
          rows={byType}
          rowKey={(r: any) => r.partner_type}
          columns={[
            { key: 'partner_type', header: 'Type', render: (r: any) => <span className="font-medium capitalize">{String(r.partner_type).replace('_',' ')}</span> },
            { key: 'deal_count', header: 'Deals', render: (r: any) => Number(r.deal_count ?? 0).toLocaleString('en-IN') },
            { key: 'live_count', header: 'Live', render: (r: any) => Number(r.live_count ?? 0).toLocaleString('en-IN') },
            { key: 'stalled_count', header: 'Stalled', render: (r: any) => Number(r.stalled_count ?? 0).toLocaleString('en-IN') },
            { key: 'expected_revenue_rupees', header: 'Expected ARR', render: (r: any) => formatRupees(Number(r.expected_revenue_rupees ?? 0)) },
            { key: 'avg_revenue_share_pct', header: 'Avg rev share %', render: (r: any) => Number(r.avg_revenue_share_pct ?? 0).toFixed(1) + '%' },
          ]}
        />
      </Section>

      <Section title="Stalled deals" subtitle="Flagged stalled — reason + days idle">
        <DataTable
          rows={stalled}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'partner_name', header: 'Partner', render: (r: any) => <span className="font-medium">{r.partner_name}</span> },
            { key: 'partner_type', header: 'Type', render: (r: any) => <span className="capitalize">{String(r.partner_type).replace('_',' ')}</span> },
            { key: 'stage', header: 'Stage', render: (r: any) => <span className="capitalize">{r.stage}</span> },
            { key: 'stalled_reason', header: 'Reason', render: (r: any) => <span className="text-neutral-600">{r.stalled_reason ?? "—"}</span> },
            { key: 'expected_annual_revenue_rupees', header: 'Expected ARR', render: (r: any) => formatRupees(Number(r.expected_annual_revenue_rupees ?? 0)) },
            { key: 'days_since_activity', header: 'Days idle', render: (r: any) => <span className="text-rose-600 font-medium">{Number(r.days_since_activity ?? 0)}</span> },
          ]}
        />
      </Section>

      <Section title="Recent activity" subtitle="Last 50 stage moves, term updates, and stalled flags">
        <DataTable
          rows={recent}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'created_at', header: 'When', render: (r: any) => new Date(r.created_at).toLocaleString('en-IN') },
            { key: 'partner_name', header: 'Partner', render: (r: any) => <span className="font-medium">{r.partner_name}</span> },
            { key: 'event_type', header: 'Event', render: (r: any) => <span className="capitalize">{String(r.event_type).replace('_',' ')}</span> },
            { key: 'from_stage', header: 'From', render: (r: any) => r.from_stage ?? "—" },
            { key: 'to_stage', header: 'To', render: (r: any) => r.to_stage ?? "—" },
            { key: 'note', header: 'Note', render: (r: any) => <span className="text-neutral-600">{r.note ?? "—"}</span> },
          ]}
        />
      </Section>
    </main>
  );
}
