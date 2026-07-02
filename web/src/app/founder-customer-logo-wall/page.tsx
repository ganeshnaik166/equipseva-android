import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type LogoRow = {
  id: string;
  customer_name: string;
  customer_org_id: string | null;
  logo_url: string;
  display_status: string;
  tier: string;
  approved_by_founder: boolean;
  approved_at: string | null;
  display_order: number;
  permission_count: number;
  active_permission_count: number;
  latest_permission_type: string | null;
  created_at: string;
};

type SummaryRow = {
  total_logos: number;
  pending_count: number;
  approved_count: number;
  rejected_count: number;
  retired_count: number;
  marquee_count: number;
  with_active_permission: number;
  without_any_permission: number;
};

type AtRiskRow = {
  id: string;
  customer_name: string;
  display_status: string;
  tier: string;
  reason: string;
  latest_permission_type: string | null;
  latest_permission_at: string | null;
};

export default async function FounderCustomerLogoWallPage() {
  const sb = await getSupabaseServerClient();

  const logosRes = await sb.rpc('founder_logo_wall_list');
  const summaryRes = await sb.rpc('founder_logo_wall_summary');
  const atRiskRes = await sb.rpc('founder_logo_wall_at_risk');

  const logos: LogoRow[] = (logosRes.data as LogoRow[] | null) ?? [];
  const summary: SummaryRow | null = ((summaryRes.data as SummaryRow[] | null) ?? [])[0] ?? null;
  const atRisk: AtRiskRow[] = (atRiskRes.data as AtRiskRow[] | null) ?? [];

  const logoCols: Column<LogoRow>[] = [
    { key: 'customer_name', header: 'Customer', render: (r) => r.customer_name ?? '—' },
    { key: 'tier', header: 'Tier', render: (r) => r.tier ?? '—' },
    {
      key: 'display_status',
      header: 'Status',
      render: (r) => {
        const s = r.display_status ?? '—';
        const badge =
          s === 'approved' ? 'bg-green-100 text-green-800'
          : s === 'pending' ? 'bg-yellow-100 text-yellow-800'
          : s === 'rejected' ? 'bg-red-100 text-red-800'
          : 'bg-gray-100 text-gray-700';
        return <span className={`inline-block px-2 py-0.5 rounded text-xs ${badge}`}>{s}</span>;
      },
    },
    {
      key: 'approved_by_founder',
      header: 'Founder OK',
      render: (r) => (r.approved_by_founder ? 'yes' : 'no'),
    },
    {
      key: 'permission_count',
      header: 'Permissions',
      render: (r) => `${r.active_permission_count ?? 0} / ${r.permission_count ?? 0}`,
    },
    {
      key: 'latest_permission_type',
      header: 'Latest perm',
      render: (r) => r.latest_permission_type ?? '—',
    },
    {
      key: 'display_order',
      header: 'Order',
      render: (r) => String(r.display_order ?? '—'),
    },
    {
      key: 'created_at',
      header: 'Added',
      render: (r) => (r.created_at ? new Date(r.created_at).toLocaleDateString() : '—'),
    },
  ];

  const atRiskCols: Column<AtRiskRow>[] = [
    { key: 'customer_name', header: 'Customer', render: (r) => r.customer_name ?? '—' },
    { key: 'tier', header: 'Tier', render: (r) => r.tier ?? '—' },
    { key: 'reason', header: 'Reason', render: (r) => r.reason ?? '—' },
    { key: 'latest_permission_type', header: 'Last perm', render: (r) => r.latest_permission_type ?? '—' },
    {
      key: 'latest_permission_at',
      header: 'Last perm at',
      render: (r) => (r.latest_permission_at ? new Date(r.latest_permission_at).toLocaleDateString() : '—'),
    },
  ];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Customer Logo Wall</h1>
        <p className="text-sm text-gray-600">
          Showcase customer logos with permission ledger. Every logo needs founder approval and an active permission on file before public use.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Total logos</div>
          <div className="text-xl font-semibold">{summary?.total_logos ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Pending approval</div>
          <div className="text-xl font-semibold text-yellow-700">{summary?.pending_count ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Approved</div>
          <div className="text-xl font-semibold text-green-700">{summary?.approved_count ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Marquee tier</div>
          <div className="text-xl font-semibold">{summary?.marquee_count ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">With active permission</div>
          <div className="text-xl font-semibold">{summary?.with_active_permission ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Missing permission</div>
          <div className="text-xl font-semibold text-red-700">{summary?.without_any_permission ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Rejected</div>
          <div className="text-xl font-semibold">{summary?.rejected_count ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Retired</div>
          <div className="text-xl font-semibold">{summary?.retired_count ?? 0}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">At-risk approved logos</h2>
        <p className="text-xs text-gray-500">Approved logos with no active permission, revoked, expired, or inactive permission.</p>
        <DataTable<AtRiskRow>
          rows={atRisk}
          columns={atRiskCols}
          rowKey={(r) => r.id}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All logos</h2>
        <DataTable<LogoRow>
          rows={logos}
          columns={logoCols}
          rowKey={(r) => r.id}
        />
      </section>
    </div>
  );
}
