import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Compliment = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  hospital_user_id: string;
  hospital_email: string | null;
  compliment_text: string;
  received_at: string;
  source: string;
  sentiment: string;
  used_in_review: boolean;
  used_at: string | null;
  response_count: number;
};

type TopEngineer = {
  engineer_user_id: string;
  engineer_email: string | null;
  compliment_count: number;
  very_positive_count: number;
  positive_count: number;
  used_in_review_count: number;
  last_received_at: string | null;
};

type Summary = {
  total_compliments: number;
  very_positive_count: number;
  positive_count: number;
  unique_engineers: number;
  unique_hospitals: number;
  used_in_review_count: number;
  with_response_count: number;
  call_count: number;
  email_count: number;
  in_person_count: number;
  sms_count: number;
  whatsapp_count: number;
};

function fmtDate(s: string | null) {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return s;
  }
}

function trunc(s: string, n: number) {
  if (!s) return '';
  return s.length > n ? s.slice(0, n) + '…' : s;
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [complimentsRes, topRes, summaryRes] = await Promise.all([
    sb.rpc('list_compliments_r1724', { p_limit: 100 }),
    sb.rpc('top_complimented_engineers_r1724', { p_days: 90, p_limit: 20 }),
    sb.rpc('recent_compliment_summary_r1724', { p_days: 30 }),
  ]);

  const compliments: Compliment[] = (complimentsRes.data as Compliment[] | null) ?? [];
  const top: TopEngineer[] = (topRes.data as TopEngineer[] | null) ?? [];
  const summaryRow: Summary | null =
    Array.isArray(summaryRes.data) && summaryRes.data.length > 0
      ? (summaryRes.data[0] as Summary)
      : (summaryRes.data as Summary | null);

  const complimentCols: Column<Compliment>[] = [
    { key: 'received_at', header: 'Received', render: (r: any) => fmtDate(r.received_at) },
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id?.slice(0, 8) },
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id?.slice(0, 8) },
    { key: 'source', header: 'Source', render: (r: any) => r.source },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment.replace('_', ' ') },
    { key: 'text', header: 'Compliment', render: (r: any) => trunc(r.compliment_text, 120) },
    { key: 'used', header: 'In Review', render: (r: any) => (r.used_in_review ? 'yes' : 'no') },
    { key: 'responses', header: 'Responses', render: (r: any) => String(r.response_count ?? 0) },
  ];

  const topCols: Column<TopEngineer>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id?.slice(0, 8) },
    { key: 'count', header: 'Total', render: (r: any) => String(r.compliment_count) },
    { key: 'vp', header: 'Very Positive', render: (r: any) => String(r.very_positive_count) },
    { key: 'p', header: 'Positive', render: (r: any) => String(r.positive_count) },
    { key: 'used', header: 'Used in Review', render: (r: any) => String(r.used_in_review_count) },
    { key: 'last', header: 'Last Received', render: (r: any) => fmtDate(r.last_received_at) },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold tracking-tight">Engineer Customer Compliments Log</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Hospital praise & thank-you notes per engineer. Drives performance review and recognition responses
          (thank-you call, newsletter feature, cash bonus, badge).
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Last 30 days summary</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-6">
          <SummaryCard label="Total" value={summaryRow?.total_compliments ?? 0} />
          <SummaryCard label="Very Positive" value={summaryRow?.very_positive_count ?? 0} />
          <SummaryCard label="Positive" value={summaryRow?.positive_count ?? 0} />
          <SummaryCard label="Engineers" value={summaryRow?.unique_engineers ?? 0} />
          <SummaryCard label="Hospitals" value={summaryRow?.unique_hospitals ?? 0} />
          <SummaryCard label="Used in Review" value={summaryRow?.used_in_review_count ?? 0} />
          <SummaryCard label="With Response" value={summaryRow?.with_response_count ?? 0} />
          <SummaryCard label="Call" value={summaryRow?.call_count ?? 0} />
          <SummaryCard label="Email" value={summaryRow?.email_count ?? 0} />
          <SummaryCard label="In Person" value={summaryRow?.in_person_count ?? 0} />
          <SummaryCard label="SMS" value={summaryRow?.sms_count ?? 0} />
          <SummaryCard label="WhatsApp" value={summaryRow?.whatsapp_count ?? 0} />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top complimented engineers (last 90 days)</h2>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
          emptyMessage="No compliments logged in the last 90 days."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent compliments</h2>
        <DataTable
          rows={compliments}
          columns={complimentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No compliments logged yet."
        />
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-4 text-sm text-[var(--color-muted)]">
        <p className="font-medium text-[var(--color-foreground)]">RPCs available</p>
        <ul className="mt-2 list-disc space-y-1 pl-5">
          <li>list_compliments_r1724(p_limit)</li>
          <li>log_compliment_r1724(engineer, hospital, text, source, sentiment)</li>
          <li>list_responses_r1724(compliment_id)</li>
          <li>add_response_r1724(compliment_id, response_type, by_email, note)</li>
          <li>mark_used_in_review_r1724(compliment_id)</li>
          <li>top_complimented_engineers_r1724(days, limit)</li>
          <li>recent_compliment_summary_r1724(days)</li>
        </ul>
      </section>
    </div>
  );
}

function SummaryCard({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded border border-[var(--color-border)] bg-white p-3">
      <div className="text-xs text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-xl font-semibold tabular-nums">{value}</div>
    </div>
  );
}
