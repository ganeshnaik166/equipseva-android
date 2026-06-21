import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderVendorMasterPage() {
  const sb = await getSupabaseServerClient();

  const [vendorsRes, topRes, underReviewRes, reviewsRes] = await Promise.all([
    sb.rpc('list_vendors_r1738'),
    sb.rpc('top_performing_vendors_r1738'),
    sb.rpc('vendors_under_review_r1738'),
    sb.rpc('list_reviews_r1738', { p_vendor_id: null }),
  ]);

  const vendors: any[] = Array.isArray(vendorsRes.data) ? vendorsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const underReview: any[] = Array.isArray(underReviewRes.data) ? underReviewRes.data : [];
  const reviews: any[] = Array.isArray(reviewsRes.data) ? reviewsRes.data : [];

  const totalVendors = vendors.length;
  const activeVendors = vendors.filter((v) => v.status === 'active').length;
  const blockedVendors = vendors.filter((v) => v.status === 'blocked').length;
  const droppedVendors = vendors.filter((v) => v.status === 'dropped').length;

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString('en-IN') : '—');
  const fmtDateTime = (v: any) => (v ? new Date(v).toLocaleString('en-IN') : '—');

  const vendorColumns: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => <span className="font-medium">{r.vendor_name ?? '—'}</span> },
    { key: 'vendor_category', header: 'Category', render: (r: any) => <span className="text-xs uppercase tracking-wide text-gray-600">{r.vendor_category ?? '—'}</span> },
    { key: 'primary_contact_email', header: 'Email', render: (r: any) => <span className="text-sm">{r.primary_contact_email ?? '—'}</span> },
    { key: 'primary_contact_phone', header: 'Phone', render: (r: any) => <span className="text-sm">{r.primary_contact_phone ?? '—'}</span> },
    { key: 'payment_terms_days', header: 'Terms (days)', render: (r: any) => <span className="text-sm">{r.payment_terms_days ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <StatusPill status={r.status} /> },
    { key: 'performance_score', header: 'Score', render: (r: any) => <span className="text-sm font-mono">{r.performance_score ?? '—'}</span> },
    { key: 'onboarded_at', header: 'Onboarded', render: (r: any) => <span className="text-xs text-gray-600">{fmtDate(r.onboarded_at)}</span> },
    { key: 'last_review_at', header: 'Last Review', render: (r: any) => <span className="text-xs text-gray-600">{fmtDate(r.last_review_at)}</span> },
  ];

  const topColumns: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => <span className="font-medium">{r.vendor_name ?? '—'}</span> },
    { key: 'vendor_category', header: 'Category', render: (r: any) => <span className="text-xs uppercase tracking-wide text-gray-600">{r.vendor_category ?? '—'}</span> },
    { key: 'performance_score', header: 'Score', render: (r: any) => <span className="text-sm font-mono font-semibold">{r.performance_score ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <StatusPill status={r.status} /> },
    { key: 'onboarded_at', header: 'Onboarded', render: (r: any) => <span className="text-xs text-gray-600">{fmtDate(r.onboarded_at)}</span> },
  ];

  const underReviewColumns: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => <span className="font-medium">{r.vendor_name ?? '—'}</span> },
    { key: 'vendor_category', header: 'Category', render: (r: any) => <span className="text-xs uppercase tracking-wide text-gray-600">{r.vendor_category ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <StatusPill status={r.status} /> },
    { key: 'review_count', header: 'Reviews', render: (r: any) => <span className="text-sm font-mono">{r.review_count ?? 0}</span> },
    { key: 'last_review_at', header: 'Last Review', render: (r: any) => <span className="text-xs text-gray-600">{fmtDate(r.last_review_at)}</span> },
  ];

  const reviewColumns: Column<any>[] = [
    { key: 'at', header: 'When', render: (r: any) => <span className="text-xs text-gray-600">{fmtDateTime(r.at)}</span> },
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => <span className="font-medium">{r.vendor_name ?? '—'}</span> },
    { key: 'reviewer_email', header: 'Reviewer', render: (r: any) => <span className="text-sm">{r.reviewer_email ?? '—'}</span> },
    { key: 'decision', header: 'Decision', render: (r: any) => <DecisionPill decision={r.decision} /> },
    { key: 'decision_note', header: 'Note', render: (r: any) => <span className="text-sm text-gray-700">{r.decision_note ?? '—'}</span> },
  ];

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold tracking-tight">Founder Vendor Master</h1>
        <p className="text-sm text-gray-600">
          Master list of all vendors across spare parts, tools, software, legal, accounting, marketing & logistics.
          Track performance scores (1 ≤ score ≤ 10), review history, and lifecycle status.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Stat label="Total Vendors" value={totalVendors} />
        <Stat label="Active" value={activeVendors} tone="green" />
        <Stat label="Blocked" value={blockedVendors} tone="red" />
        <Stat label="Dropped" value={droppedVendors} tone="gray" />
      </section>

      <section className="space-y-3">
        <div className="flex items-baseline justify-between">
          <h2 className="text-lg font-semibold">All Vendors</h2>
          <span className="text-xs text-gray-500">{totalVendors} total</span>
        </div>
        <DataTable
          rows={vendors}
          columns={vendorColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <div className="flex items-baseline justify-between">
          <h2 className="text-lg font-semibold">Top Performing Vendors</h2>
          <span className="text-xs text-gray-500">Score &gt;= cutoff, active only</span>
        </div>
        <DataTable
          rows={top}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <div className="flex items-baseline justify-between">
          <h2 className="text-lg font-semibold">Vendors Under Review</h2>
          <span className="text-xs text-gray-500">Status = under_review or blocked</span>
        </div>
        <DataTable
          rows={underReview}
          columns={underReviewColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <div className="flex items-baseline justify-between">
          <h2 className="text-lg font-semibold">Recent Review Notes</h2>
          <span className="text-xs text-gray-500">Latest 200</span>
        </div>
        <DataTable
          rows={reviews}
          columns={reviewColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <footer className="text-xs text-gray-500 border-t pt-4">
        Round 1738 · Founder Vendor Master · data via SECDEF RPCs gated by is_founder()
      </footer>
    </div>
  );
}

function Stat({ label, value, tone }: { label: string; value: number; tone?: 'green' | 'red' | 'gray' }) {
  const color =
    tone === 'green' ? 'text-green-700 bg-green-50 border-green-200' :
    tone === 'red' ? 'text-red-700 bg-red-50 border-red-200' :
    tone === 'gray' ? 'text-gray-700 bg-gray-50 border-gray-200' :
    'text-gray-900 bg-white border-gray-200';
  return (
    <div className={`rounded-lg border px-4 py-3 ${color}`}>
      <div className="text-xs uppercase tracking-wide opacity-70">{label}</div>
      <div className="text-2xl font-semibold mt-1">{value}</div>
    </div>
  );
}

function StatusPill({ status }: { status: string | null }) {
  const s = status ?? 'unknown';
  const color =
    s === 'active' ? 'bg-green-100 text-green-800' :
    s === 'under_review' ? 'bg-amber-100 text-amber-800' :
    s === 'blocked' ? 'bg-red-100 text-red-800' :
    s === 'dropped' ? 'bg-gray-200 text-gray-700' :
    'bg-gray-100 text-gray-700';
  return <span className={`inline-flex rounded px-2 py-0.5 text-xs font-medium ${color}`}>{s}</span>;
}

function DecisionPill({ decision }: { decision: string | null }) {
  const d = decision ?? 'unknown';
  const color =
    d === 'approve' ? 'bg-green-100 text-green-800' :
    d === 'upgrade' ? 'bg-blue-100 text-blue-800' :
    d === 'concern' ? 'bg-amber-100 text-amber-800' :
    d === 'block' ? 'bg-red-100 text-red-800' :
    'bg-gray-100 text-gray-700';
  return <span className={`inline-flex rounded px-2 py-0.5 text-xs font-medium ${color}`}>{d}</span>;
}
