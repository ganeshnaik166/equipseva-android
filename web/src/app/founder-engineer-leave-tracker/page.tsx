import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type SummaryRow = {
  total_requests: number;
  submitted_requests: number;
  approved_requests: number;
  rejected_requests: number;
  cancelled_requests: number;
  expired_requests: number;
  pending_review: number;
  total_days_approved: number;
  total_days_pending: number;
  unique_engineers_with_requests: number;
  engineers_currently_on_leave: number;
  casual_kind_count: number;
  sick_kind_count: number;
  paid_kind_count: number;
  unpaid_kind_count: number;
  requests_last_30d: number;
};

type BalanceRow = {
  id: string;
  engineer_user_id: string;
  casual_leave_total_days: number;
  casual_leave_used_days: number;
  sick_leave_total_days: number;
  sick_leave_used_days: number;
  paid_leave_total_days: number;
  paid_leave_used_days: number;
  period_year: number;
  notes: string | null;
  updated_at: string;
};

type RequestRow = {
  id: string;
  engineer_user_id: string;
  leave_kind: string;
  start_date: string;
  end_date: string;
  total_days: number;
  reason: string | null;
  status: string;
  approved_by: string | null;
  approved_at: string | null;
  founder_response: string | null;
  submitted_at: string;
};

type PendingRow = {
  id: string;
  engineer_user_id: string;
  leave_kind: string;
  start_date: string;
  end_date: string;
  total_days: number;
  reason: string | null;
  submitted_at: string;
  days_waiting: number;
};

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, balancesRes, requestsRes, pendingRes] = await Promise.all([
    supabase.rpc("founder_engineer_leave_summary"),
    supabase.rpc("founder_engineer_leave_balances_recent", { p_limit: 50 }),
    supabase.rpc("founder_engineer_leave_requests_recent", { p_limit: 50 }),
    supabase.rpc("founder_engineer_leave_requests_pending"),
  ]);

  const s: SummaryRow = (summaryRes.data?.[0] as SummaryRow) ?? {
    total_requests: 0, submitted_requests: 0, approved_requests: 0,
    rejected_requests: 0, cancelled_requests: 0, expired_requests: 0,
    pending_review: 0, total_days_approved: 0, total_days_pending: 0,
    unique_engineers_with_requests: 0, engineers_currently_on_leave: 0,
    casual_kind_count: 0, sick_kind_count: 0, paid_kind_count: 0,
    unpaid_kind_count: 0, requests_last_30d: 0,
  };
  const balances: BalanceRow[] = (balancesRes.data as BalanceRow[]) ?? [];
  const requests: RequestRow[] = (requestsRes.data as RequestRow[]) ?? [];
  const pending: PendingRow[] = (pendingRes.data as PendingRow[]) ?? [];

  const cards = [
    { label: "Total requests", value: formatNumber(s.total_requests) },
    { label: "Submitted", value: formatNumber(s.submitted_requests) },
    { label: "Approved", value: formatNumber(s.approved_requests) },
    { label: "Rejected", value: formatNumber(s.rejected_requests) },
    { label: "Cancelled", value: formatNumber(s.cancelled_requests) },
    { label: "Expired", value: formatNumber(s.expired_requests) },
    { label: "Pending review", value: formatNumber(s.pending_review) },
    { label: "Days approved", value: formatNumber(s.total_days_approved) },
    { label: "Days pending", value: formatNumber(s.total_days_pending) },
    { label: "Engineers w/ requests", value: formatNumber(s.unique_engineers_with_requests) },
    { label: "On leave today", value: formatNumber(s.engineers_currently_on_leave) },
    { label: "Casual", value: formatNumber(s.casual_kind_count) },
    { label: "Sick", value: formatNumber(s.sick_kind_count) },
    { label: "Paid", value: formatNumber(s.paid_kind_count) },
    { label: "Unpaid", value: formatNumber(s.unpaid_kind_count) },
    { label: "Requests (30d)", value: formatNumber(s.requests_last_30d) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Leave Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Time-off requests, leave balances, and approval pipeline for field engineers.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">KPI summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {cards.map((c) => (
            <div key={c.label} className="rounded-lg border border-gray-200 bg-white p-4">
              <div className="text-xs uppercase tracking-wide text-gray-500">{c.label}</div>
              <div className="mt-1 text-xl font-semibold tabular-nums">{c.value}</div>
            </div>
          ))}
        </div>
      </section>

      {pending.length > 0 && (
        <section className="rounded-lg border border-amber-300 bg-amber-50 p-4">
          <h2 className="text-base font-semibold text-amber-900 mb-2">
            Pending approval ({pending.length})
          </h2>
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="text-amber-900">
                <tr>
                  <th className="px-2 py-1 text-left">Engineer</th>
                  <th className="px-2 py-1 text-left">Kind</th>
                  <th className="px-2 py-1 text-left">Start</th>
                  <th className="px-2 py-1 text-left">End</th>
                  <th className="px-2 py-1 text-right">Days</th>
                  <th className="px-2 py-1 text-left">Reason</th>
                  <th className="px-2 py-1 text-right">Waiting (d)</th>
                </tr>
              </thead>
              <tbody>
                {pending.map((p) => (
                  <tr key={p.id} className="border-t border-amber-200">
                    <td className="px-2 py-1 font-mono text-xs">{p.engineer_user_id.slice(0, 8)}</td>
                    <td className="px-2 py-1">{p.leave_kind}</td>
                    <td className="px-2 py-1">{p.start_date}</td>
                    <td className="px-2 py-1">{p.end_date}</td>
                    <td className="px-2 py-1 text-right tabular-nums">{formatNumber(p.total_days)}</td>
                    <td className="px-2 py-1 text-gray-700">{p.reason ?? "—"}</td>
                    <td className="px-2 py-1 text-right tabular-nums font-semibold">
                      {p.days_waiting.toFixed(1)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-3">Leave balances ledger</h2>
        <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50 text-gray-600">
              <tr>
                <th className="px-3 py-2 text-left">Engineer</th>
                <th className="px-3 py-2 text-right">Casual used/total</th>
                <th className="px-3 py-2 text-right">Sick used/total</th>
                <th className="px-3 py-2 text-right">Paid used/total</th>
                <th className="px-3 py-2 text-left">Period</th>
                <th className="px-3 py-2 text-left">Notes</th>
                <th className="px-3 py-2 text-left">Updated</th>
              </tr>
            </thead>
            <tbody>
              {balances.length === 0 ? (
                <tr><td colSpan={7} className="px-3 py-4 text-gray-500 text-center">No balances seeded.</td></tr>
              ) : balances.map((b) => (
                <tr key={b.id} className="border-t border-gray-100">
                  <td className="px-3 py-2 font-mono text-xs">{b.engineer_user_id.slice(0, 8)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {b.casual_leave_used_days} / {b.casual_leave_total_days}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {b.sick_leave_used_days} / {b.sick_leave_total_days}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {b.paid_leave_used_days} / {b.paid_leave_total_days}
                  </td>
                  <td className="px-3 py-2">{b.period_year}</td>
                  <td className="px-3 py-2 text-gray-600">{b.notes ?? "—"}</td>
                  <td className="px-3 py-2 text-gray-500">{new Date(b.updated_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Requests feed (latest 50)</h2>
        <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50 text-gray-600">
              <tr>
                <th className="px-3 py-2 text-left">Engineer</th>
                <th className="px-3 py-2 text-left">Kind</th>
                <th className="px-3 py-2 text-left">Start</th>
                <th className="px-3 py-2 text-left">End</th>
                <th className="px-3 py-2 text-right">Days</th>
                <th className="px-3 py-2 text-left">Status</th>
                <th className="px-3 py-2 text-left">Reason</th>
                <th className="px-3 py-2 text-left">Response</th>
                <th className="px-3 py-2 text-left">Submitted</th>
              </tr>
            </thead>
            <tbody>
              {requests.length === 0 ? (
                <tr><td colSpan={9} className="px-3 py-4 text-gray-500 text-center">No requests filed yet.</td></tr>
              ) : requests.map((r) => (
                <tr key={r.id} className="border-t border-gray-100">
                  <td className="px-3 py-2 font-mono text-xs">{r.engineer_user_id.slice(0, 8)}</td>
                  <td className="px-3 py-2">{r.leave_kind}</td>
                  <td className="px-3 py-2">{r.start_date}</td>
                  <td className="px-3 py-2">{r.end_date}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.total_days)}</td>
                  <td className="px-3 py-2">{r.status}</td>
                  <td className="px-3 py-2 text-gray-700">{r.reason ?? "—"}</td>
                  <td className="px-3 py-2 text-gray-700">{r.founder_response ?? "—"}</td>
                  <td className="px-3 py-2 text-gray-500">{new Date(r.submitted_at).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
