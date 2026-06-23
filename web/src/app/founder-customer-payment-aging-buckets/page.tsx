import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerPaymentAgingBucketsPage() {
  const supabase = await getSupabaseServerClient();

  const [aging, actions, buckets, dunning, topHospitals, writeOffs, calendar] = await Promise.all([
    supabase.rpc('list_aging_r2452'),
    supabase.rpc('list_collection_actions_r2452'),
    supabase.rpc('age_bucket_summary_r2452'),
    supabase.rpc('dunning_level_breakdown_r2452'),
    supabase.rpc('top_overdue_hospitals_r2452'),
    supabase.rpc('write_off_candidates_r2452'),
    supabase.rpc('this_week_action_calendar_r2452'),
  ]);

  const agingRows = (aging.data ?? []) as any[];
  const actionRows = (actions.data ?? []) as any[];
  const bucketRows = (buckets.data ?? []) as any[];
  const dunningRows = (dunning.data ?? []) as any[];
  const topRows = (topHospitals.data ?? []) as any[];
  const writeOffRows = (writeOffs.data ?? []) as any[];
  const calendarRows = (calendar.data ?? []) as any[];

  const fmtRupees = (n: number | null | undefined) => {
    if (n == null) return '-';
    return '₹' + (Number(n) / 100).toLocaleString('en-IN', { maximumFractionDigits: 2 });
  };
  const fmtDate = (d: string | null | undefined) => (d ? new Date(d).toLocaleDateString('en-IN') : '-');
  const fmtDateTime = (d: string | null | undefined) => (d ? new Date(d).toLocaleString('en-IN') : '-');

  const agingCols: Column<any>[] = [
    { key: 'invoice_external_ref', header: 'Invoice', render: (r: any) => r.invoice_external_ref },
    { key: 'invoice_due_at', header: 'Due', render: (r: any) => fmtDate(r.invoice_due_at) },
    { key: 'amount', header: 'Amount', render: (r: any) => fmtRupees(r.invoice_amount_rupees) },
    { key: 'days_overdue', header: 'Days overdue', render: (r: any) => String(r.days_overdue ?? 0) },
    { key: 'age_bucket', header: 'Bucket', render: (r: any) => r.age_bucket },
    { key: 'dunning_level', header: 'Dunning', render: (r: any) => r.dunning_level },
    { key: 'probability_collect_pct', header: 'Collect %', render: (r: any) => String(r.probability_collect_pct) + '%' },
    { key: 'write_off_candidate', header: 'Write-off?', render: (r: any) => (r.write_off_candidate ? 'yes' : 'no') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'invoice_external_ref', header: 'Invoice', render: (r: any) => r.invoice_external_ref },
    { key: 'action_at', header: 'When', render: (r: any) => fmtDateTime(r.action_at) },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'action_summary', header: 'Summary', render: (r: any) => r.action_summary },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => fmtDateTime(r.follow_up_at) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const bucketCols: Column<any>[] = [
    { key: 'age_bucket', header: 'Bucket', render: (r: any) => r.age_bucket },
    { key: 'invoice_count', header: 'Invoices', render: (r: any) => String(r.invoice_count) },
    { key: 'total_amount_rupees', header: 'Total', render: (r: any) => fmtRupees(r.total_amount_rupees) },
    { key: 'avg_probability_pct', header: 'Avg collect %', render: (r: any) => String(r.avg_probability_pct ?? 0) + '%' },
  ];

  const dunningCols: Column<any>[] = [
    { key: 'dunning_level', header: 'Dunning level', render: (r: any) => r.dunning_level },
    { key: 'invoice_count', header: 'Invoices', render: (r: any) => String(r.invoice_count) },
    { key: 'total_amount_rupees', header: 'Total', render: (r: any) => fmtRupees(r.total_amount_rupees) },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'invoice_count', header: 'Invoices', render: (r: any) => String(r.invoice_count) },
    { key: 'total_overdue_rupees', header: 'Total overdue', render: (r: any) => fmtRupees(r.total_overdue_rupees) },
    { key: 'max_days_overdue', header: 'Max days late', render: (r: any) => String(r.max_days_overdue ?? 0) },
  ];

  const writeOffCols: Column<any>[] = [
    { key: 'invoice_external_ref', header: 'Invoice', render: (r: any) => r.invoice_external_ref },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'invoice_amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.invoice_amount_rupees) },
    { key: 'days_overdue', header: 'Days late', render: (r: any) => String(r.days_overdue ?? 0) },
    { key: 'dunning_level', header: 'Dunning', render: (r: any) => r.dunning_level },
    { key: 'probability_collect_pct', header: 'Collect %', render: (r: any) => String(r.probability_collect_pct) + '%' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const calendarCols: Column<any>[] = [
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => fmtDateTime(r.follow_up_at) },
    { key: 'invoice_external_ref', header: 'Invoice', render: (r: any) => r.invoice_external_ref },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Last outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'action_summary', header: 'Summary', render: (r: any) => r.action_summary },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Customer payment aging buckets</h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Invoice aging & dunning. Track promise-to-pay, probability of collection & write-off candidates.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Age bucket summary</h2>
        <DataTable
          rows={bucketRows}
          columns={bucketCols}
          emptyMessage="No invoices tracked."
          rowKey={(r: any, i: number) => String(r.age_bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Dunning level breakdown</h2>
        <DataTable
          rows={dunningRows}
          columns={dunningCols}
          emptyMessage="No dunning levels recorded."
          rowKey={(r: any, i: number) => String(r.dunning_level ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top overdue hospitals</h2>
        <DataTable
          rows={topRows}
          columns={topCols}
          emptyMessage="No overdue hospitals."
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Write-off candidates</h2>
        <DataTable
          rows={writeOffRows}
          columns={writeOffCols}
          emptyMessage="No write-off candidates."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>This week action calendar</h2>
        <DataTable
          rows={calendarRows}
          columns={calendarCols}
          emptyMessage="No follow-ups in the next 7 days."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All aging invoices</h2>
        <DataTable
          rows={agingRows}
          columns={agingCols}
          emptyMessage="No invoices."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent collection actions</h2>
        <DataTable
          rows={actionRows}
          columns={actionCols}
          emptyMessage="No collection actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
