import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type PhotoRow = {
  id: string;
  engineer_user_id: string | null;
  hospital_user_id: string | null;
  photo_url: string;
  job_external_ref: string | null;
  captured_at: string;
  privacy_review_status: string;
  redaction_reason_md: string | null;
  archive_kind: string;
  dpdp_compliance_status: string;
  owner_email: string | null;
  status: string;
  notes: string | null;
  created_at: string;
};

type RetrievalRow = {
  id: string;
  photo_id: string;
  job_external_ref: string | null;
  requested_at: string;
  requester_email: string | null;
  request_kind: string;
  approval_at: string | null;
  owner_email: string | null;
  status: string;
  notes: string | null;
  created_at: string;
};

type RedactedRow = {
  job_external_ref: string | null;
  privacy_review_status: string;
  redaction_reason_md: string | null;
  dpdp_compliance_status: string;
  captured_at: string;
};

type ArchiveKindRow = {
  archive_kind: string;
  photo_count: number;
};

type DpdpSummary = {
  compliant_count: number;
  marginal_count: number;
  non_compliant_count: number;
  compliant_pct: number;
};

type RequestKindRow = {
  request_kind: string;
  request_count: number;
  approved_count: number;
};

type MonthlyRow = {
  month_label: string;
  request_count: number;
  approved_count: number;
  denied_count: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [photosRes, requestsRes, redactedRes, kindRes, dpdpRes, reqKindRes, monthlyRes] = await Promise.all([
    sb.rpc('list_photo_archive_r2586'),
    sb.rpc('list_retrieval_requests_r2586'),
    sb.rpc('top_redacted_photos_r2586'),
    sb.rpc('archive_kind_distribution_r2586'),
    sb.rpc('dpdp_compliance_summary_r2586'),
    sb.rpc('request_kind_breakdown_r2586'),
    sb.rpc('monthly_retrieval_trend_r2586'),
  ]);

  const photos: PhotoRow[] = (photosRes.data ?? []) as PhotoRow[];
  const requests: RetrievalRow[] = (requestsRes.data ?? []) as RetrievalRow[];
  const redacted: RedactedRow[] = (redactedRes.data ?? []) as RedactedRow[];
  const kinds: ArchiveKindRow[] = (kindRes.data ?? []) as ArchiveKindRow[];
  const dpdp: DpdpSummary = ((dpdpRes.data ?? [])[0] ?? {
    compliant_count: 0,
    marginal_count: 0,
    non_compliant_count: 0,
    compliant_pct: 0,
  }) as DpdpSummary;
  const reqKinds: RequestKindRow[] = (reqKindRes.data ?? []) as RequestKindRow[];
  const monthly: MonthlyRow[] = (monthlyRes.data ?? []) as MonthlyRow[];

  const photoCols: Column<PhotoRow>[] = [
    { key: 'captured', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleDateString() },
    { key: 'job', header: 'Job ref', render: (r: any) => r.job_external_ref ?? '—' },
    { key: 'privacy', header: 'Privacy', render: (r: any) => r.privacy_review_status },
    { key: 'archive', header: 'Archive', render: (r: any) => r.archive_kind },
    { key: 'dpdp', header: 'DPDP', render: (r: any) => r.dpdp_compliance_status },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const requestCols: Column<RetrievalRow>[] = [
    { key: 'requested', header: 'Requested', render: (r: any) => new Date(r.requested_at).toLocaleDateString() },
    { key: 'job', header: 'Job ref', render: (r: any) => r.job_external_ref ?? '—' },
    { key: 'kind', header: 'Kind', render: (r: any) => r.request_kind },
    { key: 'requester', header: 'Requester', render: (r: any) => r.requester_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'approved', header: 'Approved', render: (r: any) => (r.approval_at ? new Date(r.approval_at).toLocaleDateString() : '—') },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const redactedCols: Column<RedactedRow>[] = [
    { key: 'job', header: 'Job ref', render: (r: any) => r.job_external_ref ?? '—' },
    { key: 'privacy', header: 'Privacy', render: (r: any) => r.privacy_review_status },
    { key: 'dpdp', header: 'DPDP', render: (r: any) => r.dpdp_compliance_status },
    { key: 'reason', header: 'Reason', render: (r: any) => r.redaction_reason_md ?? '—' },
    { key: 'captured', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleDateString() },
  ];

  const kindCols: Column<ArchiveKindRow>[] = [
    { key: 'kind', header: 'Archive kind', render: (r: any) => r.archive_kind },
    { key: 'count', header: 'Photo count', render: (r: any) => String(r.photo_count) },
  ];

  const reqKindCols: Column<RequestKindRow>[] = [
    { key: 'kind', header: 'Request kind', render: (r: any) => r.request_kind },
    { key: 'count', header: 'Requests', render: (r: any) => String(r.request_count) },
    { key: 'approved', header: 'Approved', render: (r: any) => String(r.approved_count) },
  ];

  const monthlyCols: Column<MonthlyRow>[] = [
    { key: 'month', header: 'Month', render: (r: any) => r.month_label },
    { key: 'count', header: 'Requests', render: (r: any) => String(r.request_count) },
    { key: 'approved', header: 'Approved', render: (r: any) => String(r.approved_count) },
    { key: 'denied', header: 'Denied', render: (r: any) => String(r.denied_count) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Customer Photo Evidence Archive</h1>
        <p className="text-sm text-gray-500">r2586 · photo & job & privacy review & archive & retrieval & DPDP</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">DPDP compliant</div>
          <div className="text-2xl font-semibold text-green-600">{dpdp.compliant_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Marginal</div>
          <div className="text-2xl font-semibold text-amber-600">{dpdp.marginal_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Non-compliant</div>
          <div className="text-2xl font-semibold text-red-600">{dpdp.non_compliant_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Compliant %</div>
          <div className="text-2xl font-semibold">{dpdp.compliant_pct}%</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Photo archive</h2>
        <DataTable rows={photos} columns={photoCols} emptyMessage="No photos archived yet." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Retrieval requests</h2>
        <DataTable rows={requests} columns={requestCols} emptyMessage="No retrieval requests on file." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Redacted & rejected photos</h2>
        <DataTable rows={redacted} columns={redactedCols} emptyMessage="No redactions logged." rowKey={(r: any, i: number) => String(r.job_external_ref ?? i)} />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Archive kind distribution</h2>
          <DataTable rows={kinds} columns={kindCols} emptyMessage="No archive data." rowKey={(r: any, i: number) => String(r.archive_kind ?? i)} />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Request kind breakdown</h2>
          <DataTable rows={reqKinds} columns={reqKindCols} emptyMessage="No requests." rowKey={(r: any, i: number) => String(r.request_kind ?? i)} />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly retrieval trend</h2>
        <DataTable rows={monthly} columns={monthlyCols} emptyMessage="No monthly trend data." rowKey={(r: any, i: number) => String(r.month_label ?? i)} />
      </section>
    </main>
  );
}
