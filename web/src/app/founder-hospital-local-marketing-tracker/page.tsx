import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalLocalMarketingTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [activitiesRes, roiRes, topGenRes, recentConvRes] = await Promise.all([
    sb.rpc('list_activities_r1727', { p_limit: 100 }),
    sb.rpc('roi_summary_per_activity_r1727'),
    sb.rpc('top_lead_generators_r1727', { p_limit: 10 }),
    sb.rpc('recent_conversions_r1727', { p_limit: 50 }),
  ]);

  const activities = (activitiesRes.data ?? []) as any[];
  const roi = (roiRes.data ?? []) as any[];
  const topGen = (topGenRes.data ?? []) as any[];
  const recentConv = (recentConvRes.data ?? []) as any[];

  const activityCols: Column<any>[] = [
    { key: 'activity_date', header: 'Date', render: (r: any) => String(r.activity_date ?? '') },
    { key: 'activity_type', header: 'Type', render: (r: any) => String(r.activity_type ?? '') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '') },
    { key: 'spend_rupees', header: 'Spend (Rs)', render: (r: any) => String(r.spend_rupees ?? 0) },
    { key: 'leads_generated', header: 'Leads', render: (r: any) => String(r.leads_generated ?? 0) },
    { key: 'conversions', header: 'Conv', render: (r: any) => String(r.conversions ?? 0) },
    { key: 'lead_owner_email', header: 'Owner', render: (r: any) => String(r.lead_owner_email ?? '') },
  ];

  const roiCols: Column<any>[] = [
    { key: 'activity_date', header: 'Date', render: (r: any) => String(r.activity_date ?? '') },
    { key: 'activity_type', header: 'Type', render: (r: any) => String(r.activity_type ?? '') },
    { key: 'spend_rupees', header: 'Spend (Rs)', render: (r: any) => String(r.spend_rupees ?? 0) },
    { key: 'leads_generated', header: 'Leads', render: (r: any) => String(r.leads_generated ?? 0) },
    { key: 'conversions', header: 'Conv', render: (r: any) => String(r.conversions ?? 0) },
    { key: 'total_conversion_value_rupees', header: 'Value (Rs)', render: (r: any) => String(r.total_conversion_value_rupees ?? 0) },
    { key: 'roi_multiplier', header: 'ROI x', render: (r: any) => String(r.roi_multiplier ?? 0) },
  ];

  const topGenCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '') },
    { key: 'total_activities', header: 'Activities', render: (r: any) => String(r.total_activities ?? 0) },
    { key: 'total_leads', header: 'Leads', render: (r: any) => String(r.total_leads ?? 0) },
    { key: 'total_conversions', header: 'Conv', render: (r: any) => String(r.total_conversions ?? 0) },
    { key: 'total_spend_rupees', header: 'Spend (Rs)', render: (r: any) => String(r.total_spend_rupees ?? 0) },
  ];

  const recentConvCols: Column<any>[] = [
    { key: 'recorded_at', header: 'When', render: (r: any) => String(r.recorded_at ?? '').slice(0, 19) },
    { key: 'activity_type', header: 'Type', render: (r: any) => String(r.activity_type ?? '') },
    { key: 'lead_name', header: 'Lead', render: (r: any) => String(r.lead_name ?? '') },
    { key: 'lead_org', header: 'Org', render: (r: any) => String(r.lead_org ?? '') },
    { key: 'conversion_value_rupees', header: 'Value (Rs)', render: (r: any) => String(r.conversion_value_rupees ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Local Marketing Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-hospital BTL events, doctor referrals, OPD signage. Track spend, leads, conversions and ROI (target ROI &gt;= 2x).
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent activities</h2>
        <DataTable rows={activities} columns={activityCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>ROI per activity</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>ROI multiplier = total conversion value ÷ spend. Flag activities with ROI &lt; 1.</p>
        <DataTable rows={roi} columns={roiCols} rowKey={(r: any, i: number) => String(r.activity_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top lead generators</h2>
        <DataTable rows={topGen} columns={topGenCols} rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent conversions</h2>
        <DataTable rows={recentConv} columns={recentConvCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
