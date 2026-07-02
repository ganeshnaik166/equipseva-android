import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_listings: number;
  total_replaceable: number;
  total_annual_spend_rupees: number;
  pending_actions: number;
  in_progress_actions: number;
  done_actions: number;
  projected_saving_rupees: number;
  realized_saving_rupees: number;
};

type Listing = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  vendor_name: string;
  equipment_category: string;
  annual_spend_rupees: number;
  contract_end: string | null;
  replaceable: boolean;
  created_at: string;
};

type ActionRow = {
  id: string;
  listing_id: string;
  vendor_name: string;
  hospital_email: string | null;
  action_type: string;
  decided_at: string;
  decided_by_email: string | null;
  status: string;
  projected_saving_rupees: number;
};

type TopRow = {
  id: string;
  vendor_name: string;
  equipment_category: string;
  hospital_email: string | null;
  annual_spend_rupees: number;
  contract_end: string | null;
};

function fmtRupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined) {
  if (!s) return '—';
  try { return new Date(s).toLocaleDateString('en-IN'); } catch { return s; }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [sumRes, listRes, actRes, topRes] = await Promise.all([
    sb.rpc('savings_summary_r1683'),
    sb.rpc('list_listings_r1683'),
    sb.rpc('list_actions_r1683'),
    sb.rpc('replaceable_vendors_top_n_r1683', { p_limit: 10 }),
  ]);

  const summary: Summary = (sumRes.data?.[0] ?? {
    total_listings: 0, total_replaceable: 0, total_annual_spend_rupees: 0,
    pending_actions: 0, in_progress_actions: 0, done_actions: 0,
    projected_saving_rupees: 0, realized_saving_rupees: 0,
  }) as Summary;
  const listings: Listing[] = (listRes.data ?? []) as Listing[];
  const actions: ActionRow[] = (actRes.data ?? []) as ActionRow[];
  const topReplaceable: TopRow[] = (topRes.data ?? []) as TopRow[];

  const listingCols: Column<Listing>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id?.slice(0, 8) ?? '—' },
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => r.vendor_name },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category },
    { key: 'annual_spend_rupees', header: 'Annual Spend', render: (r: any) => fmtRupees(r.annual_spend_rupees) },
    { key: 'contract_end', header: 'Contract End', render: (r: any) => fmtDate(r.contract_end) },
    { key: 'replaceable', header: 'Replaceable', render: (r: any) => r.replaceable ? 'Yes' : 'No' },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => r.vendor_name },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'projected_saving_rupees', header: 'Projected Saving', render: (r: any) => fmtRupees(r.projected_saving_rupees) },
    { key: 'decided_at', header: 'Decided', render: (r: any) => fmtDate(r.decided_at) },
    { key: 'decided_by_email', header: 'By', render: (r: any) => r.decided_by_email ?? '—' },
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => r.vendor_name },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'annual_spend_rupees', header: 'Annual Spend', render: (r: any) => fmtRupees(r.annual_spend_rupees) },
    { key: 'contract_end', header: 'Contract End', render: (r: any) => fmtDate(r.contract_end) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Vendor Consolidation Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Per-hospital vendor sprawl & consolidation pipeline (replaceable share &gt;0 = opportunity).
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">KPIs</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="border rounded-lg p-4">
            <div className="text-xs text-gray-500">Listings</div>
            <div className="text-2xl font-bold">{summary.total_listings}</div>
          </div>
          <div className="border rounded-lg p-4">
            <div className="text-xs text-gray-500">Replaceable</div>
            <div className="text-2xl font-bold">{summary.total_replaceable}</div>
          </div>
          <div className="border rounded-lg p-4">
            <div className="text-xs text-gray-500">Total Annual Spend</div>
            <div className="text-2xl font-bold">{fmtRupees(summary.total_annual_spend_rupees)}</div>
          </div>
          <div className="border rounded-lg p-4">
            <div className="text-xs text-gray-500">Projected Savings</div>
            <div className="text-2xl font-bold">{fmtRupees(summary.projected_saving_rupees)}</div>
          </div>
          <div className="border rounded-lg p-4">
            <div className="text-xs text-gray-500">Realized Savings</div>
            <div className="text-2xl font-bold">{fmtRupees(summary.realized_saving_rupees)}</div>
          </div>
          <div className="border rounded-lg p-4">
            <div className="text-xs text-gray-500">Pending Actions</div>
            <div className="text-2xl font-bold">{summary.pending_actions}</div>
          </div>
          <div className="border rounded-lg p-4">
            <div className="text-xs text-gray-500">In Progress</div>
            <div className="text-2xl font-bold">{summary.in_progress_actions}</div>
          </div>
          <div className="border rounded-lg p-4">
            <div className="text-xs text-gray-500">Done</div>
            <div className="text-2xl font-bold">{summary.done_actions}</div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Replaceable Vendors</h2>
        <DataTable
          rows={topReplaceable}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Vendor Listings</h2>
        <DataTable
          rows={listings}
          columns={listingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Action Queue</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
