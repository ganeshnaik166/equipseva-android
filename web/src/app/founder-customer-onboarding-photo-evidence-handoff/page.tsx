import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [photosRes, packetsRes, pendingRes, kindRes, summaryRes, trendRes, ownerRes] = await Promise.all([
    supabase.rpc('list_photos_r2552'),
    supabase.rpc('list_packets_r2552'),
    supabase.rpc('pending_signoff_focus_r2552'),
    supabase.rpc('photo_kind_breakdown_r2552'),
    supabase.rpc('packet_completion_summary_r2552'),
    supabase.rpc('monthly_handoff_trend_r2552'),
    supabase.rpc('owner_load_r2552'),
  ]);

  const photos: any[] = photosRes.data ?? [];
  const packets: any[] = packetsRes.data ?? [];
  const pending: any[] = pendingRes.data ?? [];
  const kinds: any[] = kindRes.data ?? [];
  const summary: any[] = summaryRes.data ?? [];
  const trend: any[] = trendRes.data ?? [];
  const owners: any[] = ownerRes.data ?? [];

  const photoCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'photo_kind', header: 'Kind', render: (r: any) => r.photo_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '—' },
    { key: 'captured_by_email', header: 'Captured By', render: (r: any) => r.captured_by_email ?? '—' },
    { key: 'signed_off_by_email', header: 'Signed Off By', render: (r: any) => r.signed_off_by_email ?? '—' },
    { key: 'asset_register_ref', header: 'Asset Ref', render: (r: any) => r.asset_register_ref ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const packetCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'photo_count', header: 'Photos', render: (r: any) => r.photo_count },
    { key: 'signoff_count', header: 'Signoffs', render: (r: any) => r.signoff_count },
    { key: 'asset_register_synced', header: 'Asset Synced', render: (r: any) => r.asset_register_synced ? 'yes' : 'no' },
    { key: 'founder_review_required', header: 'Founder Review', render: (r: any) => r.founder_review_required ? 'yes' : 'no' },
    { key: 'packet_ready_at', header: 'Ready At', render: (r: any) => r.packet_ready_at ? new Date(r.packet_ready_at).toLocaleString() : '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'photo_kind', header: 'Kind', render: (r: any) => r.photo_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '—' },
    { key: 'hours_open', header: 'Hours Open', render: (r: any) => r.hours_open },
  ];

  const kindCols: Column<any>[] = [
    { key: 'photo_kind', header: 'Kind', render: (r: any) => r.photo_kind },
    { key: 'total_photos', header: 'Total', render: (r: any) => r.total_photos },
    { key: 'signed_off', header: 'Signed Off', render: (r: any) => r.signed_off },
    { key: 'pending', header: 'Pending', render: (r: any) => r.pending },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'packets', header: 'Packets', render: (r: any) => r.packets },
    { key: 'total_photos', header: 'Photos', render: (r: any) => r.total_photos },
    { key: 'total_signoffs', header: 'Signoffs', render: (r: any) => r.total_signoffs },
    { key: 'asset_synced', header: 'Asset Synced', render: (r: any) => r.asset_synced },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'packets', header: 'Packets', render: (r: any) => r.packets },
    { key: 'complete', header: 'Complete', render: (r: any) => r.complete },
    { key: 'escalated', header: 'Escalated', render: (r: any) => r.escalated },
    { key: 'total_photos', header: 'Photos', render: (r: any) => r.total_photos },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'captured_by_email', header: 'Captured By', render: (r: any) => r.captured_by_email },
    { key: 'photos', header: 'Photos', render: (r: any) => r.photos },
    { key: 'signed_off', header: 'Signed Off', render: (r: any) => r.signed_off },
    { key: 'pending', header: 'Pending', render: (r: any) => r.pending },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Customer Onboarding — Photo Evidence & Handoff</h1>
        <p className="text-sm text-gray-600">
          Hospital × onboarding photos × signoff × asset register × handover proof packets.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Onboarding Photos</h2>
        <DataTable
          rows={photos}
          columns={photoCols}
          emptyMessage="No onboarding photos captured yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Handover Proof Packets</h2>
        <DataTable
          rows={packets}
          columns={packetCols}
          emptyMessage="No proof packets compiled yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Pending Signoff Focus</h2>
        <DataTable
          rows={pending}
          columns={pendingCols}
          emptyMessage="No pending signoffs."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Photo Kind Breakdown</h2>
        <DataTable
          rows={kinds}
          columns={kindCols}
          emptyMessage="No photos to break down."
          rowKey={(r: any, i: number) => String(r.photo_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Packet Completion Summary</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No packets yet."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Monthly Handoff Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No monthly trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Owner Load (Captured By)</h2>
        <DataTable
          rows={owners}
          columns={ownerCols}
          emptyMessage="No owner load data."
          rowKey={(r: any, i: number) => String(r.captured_by_email ?? i)}
        />
      </section>
    </main>
  );
}
