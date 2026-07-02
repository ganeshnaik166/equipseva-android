import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Stream = {
  id: string;
  customer_user_id: string;
  customer_email: string | null;
  stream_name: string;
  stream_classification: string;
  recognition_policy: string;
  policy_basis: string;
  gross_amount_paise: number;
  recognized_to_date_paise: number;
  deferred_balance_paise: number;
  recognition_start_date: string | null;
  recognition_end_date: string | null;
  term_months: number | null;
  invoice_reference: string | null;
  is_policy_compliant: boolean;
  notes: string | null;
  created_at: string;
};

type Finding = {
  id: string;
  stream_id: string;
  stream_name: string | null;
  customer_user_id: string;
  customer_email: string | null;
  finding_type: string;
  severity: string;
  description: string;
  recommended_action: string | null;
  variance_paise: number;
  status: string;
  resolved_by_email: string | null;
  resolved_at: string | null;
  resolution_notes: string | null;
  detected_at: string;
};

type ByClass = {
  stream_classification: string;
  stream_count: number;
  total_gross_paise: number;
  total_recognized_paise: number;
  total_deferred_paise: number;
  compliant_count: number;
  non_compliant_count: number;
};

type ByPolicy = {
  recognition_policy: string;
  stream_count: number;
  total_gross_paise: number;
  total_recognized_paise: number;
  total_deferred_paise: number;
  pct_recognized: number;
};

type BySeverity = {
  severity: string;
  finding_count: number;
  open_count: number;
  resolved_count: number;
  total_variance_paise: number;
};

type TopOffender = {
  customer_user_id: string;
  customer_email: string | null;
  total_streams: number;
  non_compliant_streams: number;
  open_findings: number;
  total_variance_paise: number;
};

type Totals = {
  total_streams: number;
  compliant_streams: number;
  non_compliant_streams: number;
  total_gross_paise: number;
  total_recognized_paise: number;
  total_deferred_paise: number;
  total_findings: number;
  open_findings: number;
  critical_findings: number;
  total_variance_paise: number;
  compliance_pct: number;
};

function rupees(paise: number | null | undefined): string {
  const v = Number(paise ?? 0);
  return '₹' + (v / 100).toLocaleString('en-IN', { maximumFractionDigits: 2 });
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [streamsRes, findingsRes, classRes, policyRes, sevRes, offenderRes, totalsRes] = await Promise.all([
    sb.rpc('founder_r2292_list_revenue_streams'),
    sb.rpc('founder_r2292_list_findings'),
    sb.rpc('founder_r2292_by_classification'),
    sb.rpc('founder_r2292_by_policy'),
    sb.rpc('founder_r2292_findings_by_severity'),
    sb.rpc('founder_r2292_top_offenders'),
    sb.rpc('founder_r2292_compliance_totals'),
  ]);

  const streams: Stream[] = (streamsRes.data as Stream[] | null) ?? [];
  const findings: Finding[] = (findingsRes.data as Finding[] | null) ?? [];
  const byClass: ByClass[] = (classRes.data as ByClass[] | null) ?? [];
  const byPolicy: ByPolicy[] = (policyRes.data as ByPolicy[] | null) ?? [];
  const bySev: BySeverity[] = (sevRes.data as BySeverity[] | null) ?? [];
  const offenders: TopOffender[] = (offenderRes.data as TopOffender[] | null) ?? [];
  const totalsRow = (totalsRes.data as Totals[] | null)?.[0];
  const totals: Totals = totalsRow ?? {
    total_streams: 0,
    compliant_streams: 0,
    non_compliant_streams: 0,
    total_gross_paise: 0,
    total_recognized_paise: 0,
    total_deferred_paise: 0,
    total_findings: 0,
    open_findings: 0,
    critical_findings: 0,
    total_variance_paise: 0,
    compliance_pct: 0,
  };

  const streamCols: Column<Stream>[] = [
    { key: 'customer_email', header: 'Customer', render: (r) => r.customer_email ?? r.customer_user_id.slice(0, 8) },
    { key: 'stream_name', header: 'Stream', render: (r) => r.stream_name },
    { key: 'stream_classification', header: 'Class', render: (r) => r.stream_classification },
    { key: 'recognition_policy', header: 'Policy', render: (r) => r.recognition_policy },
    { key: 'gross_amount_paise', header: 'Gross', render: (r) => rupees(r.gross_amount_paise) },
    { key: 'recognized_to_date_paise', header: 'Recognized', render: (r) => rupees(r.recognized_to_date_paise) },
    { key: 'deferred_balance_paise', header: 'Deferred', render: (r) => rupees(r.deferred_balance_paise) },
    { key: 'is_policy_compliant', header: 'Compliant', render: (r) => (r.is_policy_compliant ? 'yes' : 'NO') },
    { key: 'term_months', header: 'Term', render: (r) => (r.term_months ? r.term_months + ' mo' : '—') },
  ];

  const findingCols: Column<Finding>[] = [
    { key: 'customer_email', header: 'Customer', render: (r) => r.customer_email ?? r.customer_user_id.slice(0, 8) },
    { key: 'stream_name', header: 'Stream', render: (r) => r.stream_name ?? '—' },
    { key: 'finding_type', header: 'Finding', render: (r) => r.finding_type },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'variance_paise', header: 'Variance', render: (r) => rupees(r.variance_paise) },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'description', header: 'Description', render: (r) => r.description },
    { key: 'detected_at', header: 'Detected', render: (r) => new Date(r.detected_at).toLocaleDateString('en-IN') },
  ];

  const classCols: Column<ByClass>[] = [
    { key: 'stream_classification', header: 'Classification', render: (r) => r.stream_classification },
    { key: 'stream_count', header: 'Streams', render: (r) => String(r.stream_count) },
    { key: 'total_gross_paise', header: 'Gross', render: (r) => rupees(r.total_gross_paise) },
    { key: 'total_recognized_paise', header: 'Recognized', render: (r) => rupees(r.total_recognized_paise) },
    { key: 'total_deferred_paise', header: 'Deferred', render: (r) => rupees(r.total_deferred_paise) },
    { key: 'compliant_count', header: 'Compliant', render: (r) => String(r.compliant_count) },
    { key: 'non_compliant_count', header: 'Non-Compliant', render: (r) => String(r.non_compliant_count) },
  ];

  const policyCols: Column<ByPolicy>[] = [
    { key: 'recognition_policy', header: 'Policy', render: (r) => r.recognition_policy },
    { key: 'stream_count', header: 'Streams', render: (r) => String(r.stream_count) },
    { key: 'total_gross_paise', header: 'Gross', render: (r) => rupees(r.total_gross_paise) },
    { key: 'total_recognized_paise', header: 'Recognized', render: (r) => rupees(r.total_recognized_paise) },
    { key: 'total_deferred_paise', header: 'Deferred', render: (r) => rupees(r.total_deferred_paise) },
    { key: 'pct_recognized', header: '% Recognized', render: (r) => String(r.pct_recognized) + '%' },
  ];

  const sevCols: Column<BySeverity>[] = [
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'finding_count', header: 'Total', render: (r) => String(r.finding_count) },
    { key: 'open_count', header: 'Open', render: (r) => String(r.open_count) },
    { key: 'resolved_count', header: 'Resolved', render: (r) => String(r.resolved_count) },
    { key: 'total_variance_paise', header: 'Variance', render: (r) => rupees(r.total_variance_paise) },
  ];

  const offenderCols: Column<TopOffender>[] = [
    { key: 'customer_email', header: 'Customer', render: (r) => r.customer_email ?? r.customer_user_id.slice(0, 8) },
    { key: 'total_streams', header: 'Streams', render: (r) => String(r.total_streams) },
    { key: 'non_compliant_streams', header: 'Non-Compliant', render: (r) => String(r.non_compliant_streams) },
    { key: 'open_findings', header: 'Open Findings', render: (r) => String(r.open_findings) },
    { key: 'total_variance_paise', header: 'Variance', render: (r) => rupees(r.total_variance_paise) },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Customer Revenue Recognition Policy Compliance</h1>
        <p className="text-sm text-gray-600 mt-1">
          Each customer revenue stream classified (subscription / transaction / one-time / usage-based / milestone) &amp; audited against its recognition policy. Variance &gt;= 0 flags policy mismatch.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total Streams</div>
          <div className="text-2xl font-semibold">{totals.total_streams}</div>
          <div className="text-xs text-gray-500 mt-1">
            {totals.compliant_streams} compliant · {totals.non_compliant_streams} non-compliant
          </div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Compliance %</div>
          <div className="text-2xl font-semibold">{totals.compliance_pct}%</div>
          <div className="text-xs text-gray-500 mt-1">streams adhering to policy</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Gross / Recognized</div>
          <div className="text-2xl font-semibold">{rupees(totals.total_recognized_paise)}</div>
          <div className="text-xs text-gray-500 mt-1">
            of {rupees(totals.total_gross_paise)} · deferred {rupees(totals.total_deferred_paise)}
          </div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Audit Findings</div>
          <div className="text-2xl font-semibold">{totals.open_findings}</div>
          <div className="text-xs text-gray-500 mt-1">
            {totals.critical_findings} critical · variance {rupees(totals.total_variance_paise)}
          </div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Classification</h2>
        <DataTable<ByClass> rows={byClass} columns={classCols} rowKey={(r) => r.stream_classification} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Recognition Policy</h2>
        <DataTable<ByPolicy> rows={byPolicy} columns={policyCols} rowKey={(r) => r.recognition_policy} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Findings By Severity</h2>
        <DataTable<BySeverity> rows={bySev} columns={sevCols} rowKey={(r) => r.severity} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Offenders</h2>
        <DataTable<TopOffender> rows={offenders} columns={offenderCols} rowKey={(r) => r.customer_user_id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Revenue Streams</h2>
        <DataTable<Stream> rows={streams} columns={streamCols} rowKey={(r) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audit Findings</h2>
        <DataTable<Finding> rows={findings} columns={findingCols} rowKey={(r) => r.id} />
      </section>
    </div>
  );
}
