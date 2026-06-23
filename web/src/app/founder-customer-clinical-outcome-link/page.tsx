import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerClinicalOutcomeLinkPage() {
  const supabase = await getSupabaseServerClient();

  const [outcomes, publications, topStories, channels, monthly, topHospitals, kindDist] = await Promise.all([
    supabase.rpc('list_outcomes_r2448'),
    supabase.rpc('list_publications_r2448'),
    supabase.rpc('top_outcome_stories_r2448'),
    supabase.rpc('channel_breakdown_r2448'),
    supabase.rpc('monthly_publication_trend_r2448'),
    supabase.rpc('top_hospitals_by_outcomes_r2448'),
    supabase.rpc('outcome_kind_distribution_r2448'),
  ]);

  const outcomeCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    { key: 'observation', header: 'Period', render: (r: any) => `${r.observation_period_start} to ${r.observation_period_end}` },
    { key: 'uptime_pct', header: 'Uptime %', render: (r: any) => `${Number(r.uptime_pct).toFixed(2)}%` },
    { key: 'clinical_incident_count', header: 'Incidents', render: (r: any) => r.clinical_incident_count },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'dollar_value_estimate_rupees', header: 'Value (Rs)', render: (r: any) => Number(r.dollar_value_estimate_rupees).toLocaleString('en-IN') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const pubCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label ?? '-' },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel },
    { key: 'published_at', header: 'Published', render: (r: any) => new Date(r.published_at).toLocaleDateString('en-IN') },
    { key: 'audience_size', header: 'Audience', render: (r: any) => Number(r.audience_size).toLocaleString('en-IN') },
    { key: 'engagement_score', header: 'Engagement', render: (r: any) => `${r.engagement_score}/100` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topStoryCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'dollar_value_estimate_rupees', header: 'Value (Rs)', render: (r: any) => Number(r.dollar_value_estimate_rupees).toLocaleString('en-IN') },
    { key: 'publication_count', header: 'Publications', render: (r: any) => r.publication_count },
    { key: 'total_audience', header: 'Total Audience', render: (r: any) => Number(r.total_audience).toLocaleString('en-IN') },
    { key: 'avg_engagement', header: 'Avg Engagement', render: (r: any) => Number(r.avg_engagement).toFixed(1) },
  ];

  const channelCols: Column<any>[] = [
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel },
    { key: 'publication_count', header: 'Publications', render: (r: any) => r.publication_count },
    { key: 'total_audience', header: 'Audience', render: (r: any) => Number(r.total_audience).toLocaleString('en-IN') },
    { key: 'avg_engagement', header: 'Avg Engagement', render: (r: any) => Number(r.avg_engagement).toFixed(1) },
    { key: 'featured_count', header: 'Featured', render: (r: any) => r.featured_count },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start },
    { key: 'publication_count', header: 'Publications', render: (r: any) => r.publication_count },
    { key: 'total_audience', header: 'Audience', render: (r: any) => Number(r.total_audience).toLocaleString('en-IN') },
    { key: 'avg_engagement', header: 'Avg Engagement', render: (r: any) => Number(r.avg_engagement).toFixed(1) },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'outcome_count', header: 'Outcomes', render: (r: any) => r.outcome_count },
    { key: 'total_value_rupees', header: 'Total Value (Rs)', render: (r: any) => Number(r.total_value_rupees).toLocaleString('en-IN') },
    { key: 'avg_uptime', header: 'Avg Uptime %', render: (r: any) => `${Number(r.avg_uptime).toFixed(2)}%` },
    { key: 'total_incidents', header: 'Incidents', render: (r: any) => r.total_incidents },
  ];

  const kindCols: Column<any>[] = [
    { key: 'outcome_kind', header: 'Outcome Kind', render: (r: any) => r.outcome_kind },
    { key: 'outcome_count', header: 'Count', render: (r: any) => r.outcome_count },
    { key: 'total_value_rupees', header: 'Total Value (Rs)', render: (r: any) => Number(r.total_value_rupees).toLocaleString('en-IN') },
    { key: 'avg_uptime', header: 'Avg Uptime %', render: (r: any) => `${Number(r.avg_uptime).toFixed(2)}%` },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Clinical Outcome Link</h1>
        <p className="text-sm text-gray-600">Hospital & equipment uptime & clinical incident & outcome story & value narrative.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Clinical Outcomes</h2>
        <DataTable
          rows={outcomes.data ?? []}
          columns={outcomeCols}
          emptyMessage="No clinical outcomes recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Outcome Stories</h2>
        <DataTable
          rows={topStories.data ?? []}
          columns={topStoryCols}
          emptyMessage="No top stories yet."
          rowKey={(r: any, i: number) => String(r.outcome_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Publications</h2>
        <DataTable
          rows={publications.data ?? []}
          columns={pubCols}
          emptyMessage="No publications recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Channel Breakdown</h2>
        <DataTable
          rows={channels.data ?? []}
          columns={channelCols}
          emptyMessage="No channel data."
          rowKey={(r: any, i: number) => String(r.channel ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Publication Trend</h2>
        <DataTable
          rows={monthly.data ?? []}
          columns={monthlyCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Hospitals by Outcomes</h2>
        <DataTable
          rows={topHospitals.data ?? []}
          columns={hospitalCols}
          emptyMessage="No hospitals."
          rowKey={(r: any, i: number) => String(r.hospital_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Outcome Kind Distribution</h2>
        <DataTable
          rows={kindDist.data ?? []}
          columns={kindCols}
          emptyMessage="No distribution data."
          rowKey={(r: any, i: number) => String(r.outcome_kind ?? i)}
        />
      </section>
    </div>
  );
}
