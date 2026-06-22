import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [cancellations, topCauses, recentRemedies] = await Promise.all([
    sb.rpc('r1936_list_cancellations', { p_limit: 200 }),
    sb.rpc('r1936_top_causes'),
    sb.rpc('r1936_recent_remedies', { p_limit: 100 }),
  ]);

  const cancellationCols: Column<any>[] = [
    { key: 'cancelled_at', header: 'Cancelled At', render: (r: any) => r.cancelled_at ? new Date(r.cancelled_at).toLocaleString() : '—' },
    { key: 'cancellation_side', header: 'Side', render: (r: any) => String(r.cancellation_side ?? '—') },
    { key: 'cause_category', header: 'Category', render: (r: any) => String(r.cause_category ?? '—') },
    { key: 'cause_md', header: 'Cause', render: (r: any) => String(r.cause_md ?? '—') },
    { key: 'financial_impact_rupees', header: 'Impact (rupees)', render: (r: any) => String(r.financial_impact_rupees ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'repair_job_id', header: 'Job ID', render: (r: any) => String(r.repair_job_id ?? '—') },
  ];

  const topCausesCols: Column<any>[] = [
    { key: 'cause_category', header: 'Category', render: (r: any) => String(r.cause_category ?? '—') },
    { key: 'cnt', header: 'Count', render: (r: any) => String(r.cnt ?? 0) },
    { key: 'total_impact_rupees', header: 'Total Impact (rupees)', render: (r: any) => String(r.total_impact_rupees ?? 0) },
  ];

  const remedyCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '—') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '—') },
    { key: 'outcome_md', header: 'Outcome', render: (r: any) => String(r.outcome_md ?? '—') },
    { key: 'cancellation_id', header: 'Cancellation ID', render: (r: any) => String(r.cancellation_id ?? '—') },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Engineer Repair Job Cancellation Causes</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track why repair jobs get cancelled across hospital, engineer, founder, and system sides & the remedies applied.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Cancellation Causes</h2>
        <DataTable
          rows={(topCauses.data ?? []) as any[]}
          columns={topCausesCols}
          rowKey={(r: any, i: number) => String(r.cause_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Cancellations</h2>
        <DataTable
          rows={(cancellations.data ?? []) as any[]}
          columns={cancellationCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Remedy Actions</h2>
        <DataTable
          rows={(recentRemedies.data ?? []) as any[]}
          columns={remedyCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
