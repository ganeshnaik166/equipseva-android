import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtRupees(v: number | null | undefined) {
  if (v === null || v === undefined) return '-';
  const sign = v < 0 ? '-' : '';
  const abs = Math.abs(v);
  return sign + '₹' + abs.toLocaleString('en-IN');
}

function fmtDate(v: string | null | undefined) {
  if (!v) return '-';
  return new Date(v).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [amendments, revisions, owners, byKind, ttsDist, focus, statusBreak] = await Promise.all([
    supabase.rpc('list_amendments_r2423'),
    supabase.rpc('list_revisions_r2423'),
    supabase.rpc('top_negotiations_owners_r2423'),
    supabase.rpc('arr_delta_by_kind_r2423'),
    supabase.rpc('time_to_sign_distribution_r2423'),
    supabase.rpc('in_negotiation_focus_r2423'),
    supabase.rpc('status_breakdown_r2423'),
  ]);

  const amendmentsCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'amendment_kind', header: 'Kind', render: (r: any) => r.amendment_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'proposed_at', header: 'Proposed', render: (r: any) => fmtDate(r.proposed_at) },
    { key: 'signed_at', header: 'Signed', render: (r: any) => fmtDate(r.signed_at) },
    { key: 'arr_delta_rupees', header: 'ARR delta', render: (r: any) => fmtRupees(r.arr_delta_rupees) },
    { key: 'revision_count', header: 'Revs', render: (r: any) => r.revision_count },
    { key: 'negotiation_owner_email', header: 'Owner', render: (r: any) => r.negotiation_owner_email ?? '-' },
    { key: 'counterparty_owner_email', header: 'Counterparty', render: (r: any) => r.counterparty_owner_email ?? '-' },
    { key: 'blockers', header: 'Blockers', render: (r: any) => r.blockers ?? '-' },
  ];

  const revisionsCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'amendment_kind', header: 'Kind', render: (r: any) => r.amendment_kind },
    { key: 'revision_number', header: 'Rev #', render: (r: any) => r.revision_number },
    { key: 'proposed_by_side', header: 'By side', render: (r: any) => r.proposed_by_side },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'proposed_at', header: 'Proposed', render: (r: any) => fmtDate(r.proposed_at) },
    { key: 'changes_md', header: 'Changes', render: (r: any) => r.changes_md ?? '-' },
  ];

  const ownersCols: Column<any>[] = [
    { key: 'negotiation_owner_email', header: 'Owner', render: (r: any) => r.negotiation_owner_email },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'signed_count', header: 'Signed', render: (r: any) => r.signed_count },
    { key: 'arr_delta_open_rupees', header: 'ARR delta open', render: (r: any) => fmtRupees(r.arr_delta_open_rupees) },
    { key: 'arr_delta_signed_rupees', header: 'ARR delta signed', render: (r: any) => fmtRupees(r.arr_delta_signed_rupees) },
  ];

  const byKindCols: Column<any>[] = [
    { key: 'amendment_kind', header: 'Kind', render: (r: any) => r.amendment_kind },
    { key: 'count', header: 'Count', render: (r: any) => r.count },
    { key: 'arr_delta_total_rupees', header: 'ARR delta total', render: (r: any) => fmtRupees(r.arr_delta_total_rupees) },
    { key: 'arr_delta_signed_rupees', header: 'ARR delta signed', render: (r: any) => fmtRupees(r.arr_delta_signed_rupees) },
  ];

  const ttsCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket },
    { key: 'count', header: 'Count', render: (r: any) => r.count },
    { key: 'arr_delta_signed_rupees', header: 'ARR delta signed', render: (r: any) => fmtRupees(r.arr_delta_signed_rupees) },
  ];

  const focusCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'amendment_kind', header: 'Kind', render: (r: any) => r.amendment_kind },
    { key: 'days_open', header: 'Days open', render: (r: any) => r.days_open },
    { key: 'arr_delta_rupees', header: 'ARR delta', render: (r: any) => fmtRupees(r.arr_delta_rupees) },
    { key: 'revision_count', header: 'Revs', render: (r: any) => r.revision_count },
    { key: 'negotiation_owner_email', header: 'Owner', render: (r: any) => r.negotiation_owner_email ?? '-' },
    { key: 'blockers', header: 'Blockers', render: (r: any) => r.blockers ?? '-' },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'count', header: 'Count', render: (r: any) => r.count },
    { key: 'arr_delta_rupees', header: 'ARR delta', render: (r: any) => fmtRupees(r.arr_delta_rupees) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Contract Amendment Tracker</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>Track price & scope amendments across chain hospital contracts — signed ARR delta, in-negotiation focus list, owner load.</p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status breakdown</h2>
        <DataTable
          rows={(statusBreak.data ?? []) as any[]}
          columns={statusCols}
          emptyMessage="No amendments yet."
          rowKey={(r: any, i: number) => String(r.id ?? r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>In-negotiation focus list (highest ARR delta first)</h2>
        <DataTable
          rows={(focus.data ?? []) as any[]}
          columns={focusCols}
          emptyMessage="No open negotiations."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>ARR delta by amendment kind</h2>
        <DataTable
          rows={(byKind.data ?? []) as any[]}
          columns={byKindCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.id ?? r.amendment_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner workload & ARR delta</h2>
        <DataTable
          rows={(owners.data ?? []) as any[]}
          columns={ownersCols}
          emptyMessage="No owners yet."
          rowKey={(r: any, i: number) => String(r.id ?? r.negotiation_owner_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Time-to-sign distribution</h2>
        <DataTable
          rows={(ttsDist.data ?? []) as any[]}
          columns={ttsCols}
          emptyMessage="No signed amendments yet."
          rowKey={(r: any, i: number) => String(r.id ?? r.bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All amendments</h2>
        <DataTable
          rows={(amendments.data ?? []) as any[]}
          columns={amendmentsCols}
          emptyMessage="No amendments yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Revisions trail</h2>
        <DataTable
          rows={(revisions.data ?? []) as any[]}
          columns={revisionsCols}
          emptyMessage="No revisions yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
