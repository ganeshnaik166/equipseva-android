import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_items: number;
  existential_items: number;
  major_items: number;
  net_revenue_impact_lakhs: number;
  concerned_items: number;
  engagements_logged: number;
  hours_spent: number;
};

type Ministry = { ministry: string; items: number; net_impact_lakhs: number };
type Stage = { stage: string; items: number };
type TopImpact = {
  policy_code: string;
  policy_title: string;
  impact: string;
  stance: string;
  est_revenue_impact_lakhs: number;
  business_move: string;
};
type Engagement = {
  policy_code: string;
  engaged_on: string;
  channel: string;
  counterparty: string;
  outcome: string;
  hours_spent: number;
  notes: string;
};
type Concerned = {
  policy_code: string;
  policy_title: string;
  ministry: string;
  stage: string;
  owner: string;
  business_move: string;
  reviewed_on: string;
};
type Summary = {
  channel: string;
  engagements: number;
  total_hours: number;
  resolved_count: number;
};
type AllItem = {
  policy_code: string;
  policy_title: string;
  ministry: string;
  stage: string;
  impact: string;
  stance: string;
  engagement_mode: string;
  est_revenue_impact_lakhs: number;
  owner: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, ministryRes, stageRes, topRes, engRes, concRes, summRes, allRes] = await Promise.all([
    supabase.rpc('f_policy_kpis_r2817'),
    supabase.rpc('f_policy_by_ministry_r2817'),
    supabase.rpc('f_policy_by_stage_r2817'),
    supabase.rpc('f_policy_top_impact_r2817'),
    supabase.rpc('f_policy_engagement_log_r2817'),
    supabase.rpc('f_policy_concerned_items_r2817'),
    supabase.rpc('f_policy_engagement_summary_r2817'),
    supabase.rpc('f_policy_all_items_r2817'),
  ]);

  const kpi: Kpi = (kpisRes.data?.[0] ?? {
    total_items: 0,
    existential_items: 0,
    major_items: 0,
    net_revenue_impact_lakhs: 0,
    concerned_items: 0,
    engagements_logged: 0,
    hours_spent: 0,
  }) as Kpi;

  const ministries: Ministry[] = (ministryRes.data ?? []) as Ministry[];
  const stages: Stage[] = (stageRes.data ?? []) as Stage[];
  const tops: TopImpact[] = (topRes.data ?? []) as TopImpact[];
  const engagements: Engagement[] = (engRes.data ?? []) as Engagement[];
  const concerned: Concerned[] = (concRes.data ?? []) as Concerned[];
  const summary: Summary[] = (summRes.data ?? []) as Summary[];
  const allItems: AllItem[] = (allRes.data ?? []) as AllItem[];

  const kpiCards = [
    { label: 'Tracked items', value: String(kpi.total_items) },
    { label: 'Existential', value: String(kpi.existential_items) },
    { label: 'Major impact', value: String(kpi.major_items) },
    { label: 'Net revenue Rs lakhs', value: Number(kpi.net_revenue_impact_lakhs).toFixed(2) },
    { label: 'Concerned stance', value: String(kpi.concerned_items) },
    { label: 'Engagements', value: String(kpi.engagements_logged) },
    { label: 'Hours spent', value: Number(kpi.hours_spent).toFixed(1) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 4 }}>
        Quarterly India Policy Watch
      </h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Track policy moves across ministry, stage, impact, stance and engagement; map each to a
        concrete business move.
      </p>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(170px, 1fr))',
          gap: 12,
          marginBottom: 24,
        }}
      >
        {kpiCards.map((k) => (
          <div
            key={k.label}
            style={{
              border: '1px solid #e5e7eb',
              borderRadius: 8,
              padding: 12,
              background: '#fafafa',
            }}
          >
            <div style={{ fontSize: 12, color: '#6b7280' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '16px 0 8px' }}>By ministry</h2>
      <DataTable
        rows={ministries}
        columns={[
          { key: 'ministry', header: 'Ministry', render: (r: Ministry) => r.ministry },
          { key: 'items', header: 'Items', render: (r: Ministry) => r.items },
          {
            key: 'net_impact_lakhs',
            header: 'Net impact Rs lakhs',
            render: (r: Ministry) => Number(r.net_impact_lakhs).toFixed(2),
          },
        ]}
        emptyMessage="No data"
        rowKey={(r: Ministry, i: number) => String(r.ministry ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>By stage</h2>
      <DataTable
        rows={stages}
        columns={[
          { key: 'stage', header: 'Stage', render: (r: Stage) => r.stage },
          { key: 'items', header: 'Items', render: (r: Stage) => r.items },
        ]}
        emptyMessage="No data"
        rowKey={(r: Stage, i: number) => String(r.stage ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>
        Top revenue impact items
      </h2>
      <DataTable
        rows={tops}
        columns={[
          { key: 'policy_code', header: 'Code', render: (r: TopImpact) => r.policy_code },
          { key: 'policy_title', header: 'Title', render: (r: TopImpact) => r.policy_title },
          { key: 'impact', header: 'Impact', render: (r: TopImpact) => r.impact },
          { key: 'stance', header: 'Stance', render: (r: TopImpact) => r.stance },
          {
            key: 'est_revenue_impact_lakhs',
            header: 'Rs lakhs',
            render: (r: TopImpact) => Number(r.est_revenue_impact_lakhs).toFixed(2),
          },
          { key: 'business_move', header: 'Business move', render: (r: TopImpact) => r.business_move },
        ]}
        emptyMessage="No data"
        rowKey={(r: TopImpact, i: number) => String(r.policy_code ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>
        Concerned and opposed items
      </h2>
      <DataTable
        rows={concerned}
        columns={[
          { key: 'policy_code', header: 'Code', render: (r: Concerned) => r.policy_code },
          { key: 'policy_title', header: 'Title', render: (r: Concerned) => r.policy_title },
          { key: 'ministry', header: 'Ministry', render: (r: Concerned) => r.ministry },
          { key: 'stage', header: 'Stage', render: (r: Concerned) => r.stage },
          { key: 'owner', header: 'Owner', render: (r: Concerned) => r.owner },
          { key: 'business_move', header: 'Move', render: (r: Concerned) => r.business_move },
          { key: 'reviewed_on', header: 'Reviewed', render: (r: Concerned) => r.reviewed_on },
        ]}
        emptyMessage="No data"
        rowKey={(r: Concerned, i: number) => String(r.policy_code ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Engagement log</h2>
      <DataTable
        rows={engagements}
        columns={[
          { key: 'policy_code', header: 'Code', render: (r: Engagement) => r.policy_code },
          { key: 'engaged_on', header: 'Date', render: (r: Engagement) => r.engaged_on },
          { key: 'channel', header: 'Channel', render: (r: Engagement) => r.channel },
          { key: 'counterparty', header: 'Counterparty', render: (r: Engagement) => r.counterparty },
          { key: 'outcome', header: 'Outcome', render: (r: Engagement) => r.outcome },
          {
            key: 'hours_spent',
            header: 'Hrs',
            render: (r: Engagement) => Number(r.hours_spent).toFixed(1),
          },
          { key: 'notes', header: 'Notes', render: (r: Engagement) => r.notes },
        ]}
        emptyMessage="No data"
        rowKey={(r: Engagement, i: number) => String(`${r.policy_code}-${r.engaged_on}-${i}`)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>
        Engagement summary by channel
      </h2>
      <DataTable
        rows={summary}
        columns={[
          { key: 'channel', header: 'Channel', render: (r: Summary) => r.channel },
          { key: 'engagements', header: 'Count', render: (r: Summary) => r.engagements },
          {
            key: 'total_hours',
            header: 'Hours',
            render: (r: Summary) => Number(r.total_hours).toFixed(1),
          },
          { key: 'resolved_count', header: 'Resolved', render: (r: Summary) => r.resolved_count },
        ]}
        emptyMessage="No data"
        rowKey={(r: Summary, i: number) => String(r.channel ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>All tracked items</h2>
      <DataTable
        rows={allItems}
        columns={[
          { key: 'policy_code', header: 'Code', render: (r: AllItem) => r.policy_code },
          { key: 'policy_title', header: 'Title', render: (r: AllItem) => r.policy_title },
          { key: 'ministry', header: 'Ministry', render: (r: AllItem) => r.ministry },
          { key: 'stage', header: 'Stage', render: (r: AllItem) => r.stage },
          { key: 'impact', header: 'Impact', render: (r: AllItem) => r.impact },
          { key: 'stance', header: 'Stance', render: (r: AllItem) => r.stance },
          { key: 'engagement_mode', header: 'Engagement', render: (r: AllItem) => r.engagement_mode },
          {
            key: 'est_revenue_impact_lakhs',
            header: 'Rs lakhs',
            render: (r: AllItem) => Number(r.est_revenue_impact_lakhs).toFixed(2),
          },
          { key: 'owner', header: 'Owner', render: (r: AllItem) => r.owner },
        ]}
        emptyMessage="No data"
        rowKey={(r: AllItem, i: number) => String(r.policy_code ?? i)}
      />
    </main>
  );
}
