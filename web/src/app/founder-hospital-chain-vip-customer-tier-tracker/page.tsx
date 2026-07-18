import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainVipCustomerTierTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [tiersRes, eventsRes, topValueRes, upcomingRes, tierDistRes, satSummaryRes, statusBreakdownRes] = await Promise.all([
    supabase.rpc('list_vip_tiers_r2471'),
    supabase.rpc('list_white_glove_events_r2471'),
    supabase.rpc('top_value_chains_r2471'),
    supabase.rpc('upcoming_exec_qbrs_r2471'),
    supabase.rpc('tier_distribution_r2471'),
    supabase.rpc('white_glove_satisfaction_summary_r2471'),
    supabase.rpc('status_breakdown_r2471'),
  ]);

  const tiers = (tiersRes.data ?? []) as any[];
  const events = (eventsRes.data ?? []) as any[];
  const topValue = (topValueRes.data ?? []) as any[];
  const upcoming = (upcomingRes.data ?? []) as any[];
  const tierDist = (tierDistRes.data ?? []) as any[];
  const satSummary = (satSummaryRes.data ?? []) as any[];
  const statusBreakdown = (statusBreakdownRes.data ?? []) as any[];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString('en-IN') : '-');
  const fmtRupees = (v: any) => (v == null ? '-' : '₹' + Number(v).toLocaleString('en-IN'));

  const tierColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'vip_tier', header: 'Tier', render: (r: any) => String(r.vip_tier).toUpperCase() },
    { key: 'monthly_value_rupees', header: 'Monthly Value', render: (r: any) => fmtRupees(r.monthly_value_rupees) },
    { key: 'white_glove_sla_minutes', header: 'SLA (min)', render: (r: any) => r.white_glove_sla_minutes },
    { key: 'dedicated_rep_email', header: 'Dedicated Rep', render: (r: any) => r.dedicated_rep_email ?? '-' },
    { key: 'exec_qbr_cadence_days', header: 'QBR Cadence (d)', render: (r: any) => r.exec_qbr_cadence_days },
    { key: 'last_exec_qbr_at', header: 'Last QBR', render: (r: any) => fmtDate(r.last_exec_qbr_at) },
    { key: 'next_exec_qbr_due_at', header: 'Next QBR Due', render: (r: any) => fmtDate(r.next_exec_qbr_due_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const eventColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'vip_tier', header: 'Tier', render: (r: any) => String(r.vip_tier).toUpperCase() },
    { key: 'event_at', header: 'When', render: (r: any) => fmtDate(r.event_at) },
    { key: 'event_kind', header: 'Kind', render: (r: any) => r.event_kind },
    { key: 'summary', header: 'Summary', render: (r: any) => r.summary },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'customer_satisfaction', header: 'CSAT (0-10)', render: (r: any) => r.customer_satisfaction ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const topValueColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'vip_tier', header: 'Tier', render: (r: any) => String(r.vip_tier).toUpperCase() },
    { key: 'monthly_value_rupees', header: 'Monthly Value', render: (r: any) => fmtRupees(r.monthly_value_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'next_exec_qbr_due_at', header: 'Next QBR', render: (r: any) => fmtDate(r.next_exec_qbr_due_at) },
  ];

  const upcomingColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'vip_tier', header: 'Tier', render: (r: any) => String(r.vip_tier).toUpperCase() },
    { key: 'next_exec_qbr_due_at', header: 'Due', render: (r: any) => fmtDate(r.next_exec_qbr_due_at) },
    { key: 'days_until', header: 'Days Until', render: (r: any) => r.days_until },
    { key: 'dedicated_rep_email', header: 'Rep', render: (r: any) => r.dedicated_rep_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const tierDistColumns: Column<any>[] = [
    { key: 'vip_tier', header: 'Tier', render: (r: any) => String(r.vip_tier).toUpperCase() },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'total_monthly_value_rupees', header: 'Total Monthly Value', render: (r: any) => fmtRupees(r.total_monthly_value_rupees) },
    { key: 'avg_sla_minutes', header: 'Avg SLA (min)', render: (r: any) => r.avg_sla_minutes },
  ];

  const satColumns: Column<any>[] = [
    { key: 'event_kind', header: 'Event Kind', render: (r: any) => r.event_kind },
    { key: 'event_count', header: 'Count', render: (r: any) => r.event_count },
    { key: 'avg_satisfaction', header: 'Avg CSAT', render: (r: any) => r.avg_satisfaction ?? '-' },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'planned_count', header: 'Planned', render: (r: any) => r.planned_count },
  ];

  const statusColumns: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'total_monthly_value_rupees', header: 'Total Monthly Value', render: (r: any) => fmtRupees(r.total_monthly_value_rupees) },
  ];

  return (
    <main style={{ padding: '24px', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Hospital Chain VIP Customer Tier Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Chain &gt; tier (gold/platinum/diamond) &gt; white-glove SLAs &gt; dedicated rep &gt; exec QBR cadence.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Tier Distribution</h2>
        <DataTable
          rows={tierDist}
          columns={tierDistColumns}
          emptyMessage="No tier data yet."
          rowKey={(r: any, i: number) => String(r.vip_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Status Breakdown</h2>
        <DataTable
          rows={statusBreakdown}
          columns={statusColumns}
          emptyMessage="No status data yet."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top Value Chains</h2>
        <DataTable
          rows={topValue}
          columns={topValueColumns}
          emptyMessage="No chains yet."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Upcoming Exec QBRs</h2>
        <DataTable
          rows={upcoming}
          columns={upcomingColumns}
          emptyMessage="No upcoming QBRs."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>White-Glove Satisfaction Summary</h2>
        <DataTable
          rows={satSummary}
          columns={satColumns}
          emptyMessage="No event data yet."
          rowKey={(r: any, i: number) => String(r.event_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>All VIP Tiers</h2>
        <DataTable
          rows={tiers}
          columns={tierColumns}
          emptyMessage="No VIP chains tracked yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>White-Glove Events</h2>
        <DataTable
          rows={events}
          columns={eventColumns}
          emptyMessage="No events logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
