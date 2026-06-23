import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    callsRes,
    thankYouRes,
    topHospitalsRes,
    topicRes,
    outcomeRes,
    pendingTyRes,
    monthlyRes,
  ] = await Promise.all([
    supabase.rpc('list_reference_calls_r2480'),
    supabase.rpc('list_thank_you_log_r2480'),
    supabase.rpc('top_influencing_hospitals_r2480'),
    supabase.rpc('topic_breakdown_r2480'),
    supabase.rpc('outcome_summary_r2480'),
    supabase.rpc('pending_thank_yous_r2480'),
    supabase.rpc('monthly_revenue_influenced_r2480'),
  ]);

  const calls = callsRes.data ?? [];
  const thankYous = thankYouRes.data ?? [];
  const topHospitals = topHospitalsRes.data ?? [];
  const topics = topicRes.data ?? [];
  const outcomes = outcomeRes.data ?? [];
  const pendingTy = pendingTyRes.data ?? [];
  const monthly = monthlyRes.data ?? [];

  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');
  const fmtDate = (d: string | null | undefined) =>
    !d ? '-' : new Date(d).toLocaleDateString('en-IN');

  const callsCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'reference_topic', header: 'Topic', render: (r: any) => r.reference_topic },
    { key: 'willing', header: 'Willing', render: (r: any) => (r.willing ? 'yes' : 'no') },
    { key: 'prospect_name', header: 'Prospect', render: (r: any) => r.prospect_name ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'call_outcome', header: 'Outcome', render: (r: any) => r.call_outcome },
    { key: 'deal_influence', header: 'Influence', render: (r: any) => r.deal_influence },
    { key: 'influenced_revenue_rupees', header: 'Rev', render: (r: any) => fmtRupees(r.influenced_revenue_rupees) },
    { key: 'call_completed_at', header: 'Completed', render: (r: any) => fmtDate(r.call_completed_at) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const tyCols: Column<any>[] = [
    { key: 'prospect_name', header: 'Prospect', render: (r: any) => r.prospect_name ?? '-' },
    { key: 'reference_topic', header: 'Topic', render: (r: any) => r.reference_topic ?? '-' },
    { key: 'thank_you_sent_at', header: 'Sent', render: (r: any) => fmtDate(r.thank_you_sent_at) },
    { key: 'gift_kind', header: 'Gift', render: (r: any) => r.gift_kind },
    { key: 'gift_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.gift_value_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topHospCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'call_count', header: 'Calls', render: (r: any) => r.call_count },
    { key: 'completed_count', header: 'Done', render: (r: any) => r.completed_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'total_revenue_influenced_rupees', header: 'Revenue Influenced', render: (r: any) => fmtRupees(r.total_revenue_influenced_rupees) },
  ];

  const topicCols: Column<any>[] = [
    { key: 'reference_topic', header: 'Topic', render: (r: any) => r.reference_topic },
    { key: 'total_calls', header: 'Total', render: (r: any) => r.total_calls },
    { key: 'willing_count', header: 'Willing', render: (r: any) => r.willing_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'high_or_critical_count', header: 'High/Crit', render: (r: any) => r.high_or_critical_count },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.total_revenue_rupees) },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'call_outcome', header: 'Outcome', render: (r: any) => r.call_outcome },
    { key: 'count_total', header: 'Count', render: (r: any) => r.count_total },
    { key: 'pct_of_total', header: '%', render: (r: any) => `${r.pct_of_total}%` },
    { key: 'total_revenue_influenced_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.total_revenue_influenced_rupees) },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'prospect_name', header: 'Prospect', render: (r: any) => r.prospect_name ?? '-' },
    { key: 'reference_topic', header: 'Topic', render: (r: any) => r.reference_topic },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'call_completed_at', header: 'Call Done', render: (r: any) => fmtDate(r.call_completed_at) },
    { key: 'days_since_call', header: 'Days Ago', render: (r: any) => r.days_since_call },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'call_count', header: 'Calls', render: (r: any) => r.call_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'revenue_influenced_rupees', header: 'Revenue Influenced', render: (r: any) => fmtRupees(r.revenue_influenced_rupees) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Customer Reference Call Program (r2480)
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Hospital references & deal influence => thank-you discipline => revenue attribution
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Reference Calls</h2>
        <DataTable
          rows={calls}
          columns={callsCols}
          emptyMessage="No reference calls logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Thank-You Log</h2>
        <DataTable
          rows={thankYous}
          columns={tyCols}
          emptyMessage="No thank-you gestures logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pending Thank-Yous</h2>
        <DataTable
          rows={pendingTy}
          columns={pendingCols}
          emptyMessage="All caught up — no pending thank-yous"
          rowKey={(r: any, i: number) => String(r.reference_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Influencing Hospitals</h2>
        <DataTable
          rows={topHospitals}
          columns={topHospCols}
          emptyMessage="No hospital data yet"
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Topic Breakdown</h2>
        <DataTable
          rows={topics}
          columns={topicCols}
          emptyMessage="No topics yet"
          rowKey={(r: any, i: number) => String(r.reference_topic ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Outcome Summary</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeCols}
          emptyMessage="No outcomes yet"
          rowKey={(r: any, i: number) => String(r.call_outcome ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Revenue Influenced</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          emptyMessage="No monthly data yet"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>
    </div>
  );
}
