import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type AnnivRow = {
  id: string;
  engineer_user_id: string;
  hospital_user_id: string;
  relationship_started_on: string;
  milestone_years: number;
  milestone_date: string;
  status: string;
  days_until: number;
  gift_count: number;
};

type UpcomingRow = {
  id: string;
  engineer_user_id: string;
  hospital_user_id: string;
  milestone_years: number;
  milestone_date: string;
  days_until: number;
  status: string;
};

type RetentionRow = {
  engineer_user_id: string;
  total_anniversaries: number;
  celebrated: number;
  lapsed: number;
  total_gift_spend_rupees: number;
  renewed_count: number;
  referral_count: number;
  churned_count: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [annivRes, upcomingRes, retentionRes] = await Promise.all([
    sb.rpc('list_anniversaries_r2394'),
    sb.rpc('upcoming_anniversaries_r2394'),
    sb.rpc('retention_summary_per_engineer_r2394'),
  ]);

  const anniv: AnnivRow[] = (annivRes.data as AnnivRow[] | null) ?? [];
  const upcoming: UpcomingRow[] = (upcomingRes.data as UpcomingRow[] | null) ?? [];
  const retention: RetentionRow[] = (retentionRes.data as RetentionRow[] | null) ?? [];

  const annivCols: Column<AnnivRow>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id).slice(0, 8) },
    { key: 'relationship_started_on', header: 'Started', render: (r: any) => r.relationship_started_on ?? '—' },
    { key: 'milestone_years', header: 'Milestone (yrs)', render: (r: any) => r.milestone_years },
    { key: 'milestone_date', header: 'Milestone date', render: (r: any) => r.milestone_date ?? '—' },
    { key: 'days_until', header: 'Days until', render: (r: any) => r.days_until },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'gift_count', header: 'Gifts', render: (r: any) => r.gift_count },
  ];

  const upcomingCols: Column<UpcomingRow>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id).slice(0, 8) },
    { key: 'milestone_years', header: 'Years', render: (r: any) => r.milestone_years },
    { key: 'milestone_date', header: 'Date', render: (r: any) => r.milestone_date ?? '—' },
    { key: 'days_until', header: 'Days until', render: (r: any) => r.days_until },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const retentionCols: Column<RetentionRow>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'total_anniversaries', header: 'Total', render: (r: any) => r.total_anniversaries },
    { key: 'celebrated', header: 'Celebrated', render: (r: any) => r.celebrated },
    { key: 'lapsed', header: 'Lapsed', render: (r: any) => r.lapsed },
    { key: 'total_gift_spend_rupees', header: 'Gift spend (₹)', render: (r: any) => r.total_gift_spend_rupees },
    { key: 'renewed_count', header: 'Renewed', render: (r: any) => r.renewed_count },
    { key: 'referral_count', header: 'Referral', render: (r: any) => r.referral_count },
    { key: 'churned_count', header: 'Churned', render: (r: any) => r.churned_count },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Customer-Relationship Anniversary Log</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track engineer-hospital relationship anniversaries (1yr / 3yr / 5yr / 7yr / 10yr), the celebration gift sent, and the retention impact. Built to make engineers stickier with their hospital accounts.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All anniversaries ({anniv.length})</h2>
        <DataTable
          rows={anniv}
          columns={annivCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Upcoming in next 60 days ({upcoming.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Anniversaries where milestone_date is between today and today + 60 days and status is still 'upcoming'. Send a gift before they lapse.
        </p>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Retention summary per engineer ({retention.length})</h2>
        <DataTable
          rows={retention}
          columns={retentionCols}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>
    </div>
  );
}
