import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Hospital portal v2 admin — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_self_service_requests: number;
  requests_submitted_count: number;
  requests_under_review_count: number;
  requests_approved_count: number;
  requests_rejected_count: number;
  requests_expired_count: number;
  requests_30d: number;
  top_request_kind: string | null;
  total_dispute_requests: number;
  disputes_submitted_count: number;
  disputes_resolved_count: number;
  disputes_escalated_count: number;
  disputes_30d: number;
  top_dispute_kind: string | null;
  active_feature_flags_total: number;
  hospitals_with_active_flags: number;
  session_logs_30d: number;
  rate_limited_attempts_30d: number;
  generated_at: string;
};

type Request = {
  id: string;
  hospital_user_id: string;
  amc_contract_id: string | null;
  request_kind: string;
  desired_tier: string | null;
  status: string;
  submitted_at: string;
  expires_at: string;
  age_days: number;
};

type Dispute = {
  id: string;
  hospital_user_id: string;
  dispute_kind: string;
  status: string;
  amount_claimed_rupees: number | null;
  submitted_at: string;
  age_days: number;
};

function Card({ label, value, sub, tone }: { label: string; value: string; sub?: string; tone?: "ok" | "warn" | "danger" }) {
  const t = tone === "ok" ? "text-[var(--color-ok)]" : tone === "warn" ? "text-[var(--color-warn)]" : tone === "danger" ? "text-[var(--color-danger)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${t}`}>{value}</div>
      {sub ? <div className="text-xs text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}
function rup(n: number | null): string { if (n === null) return "—"; return `₹${formatNumber(Math.round(n))}`; }

export default async function FounderHospitalPortalV2Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const [sRes, rRes, dRes] = await Promise.all([
    sb.rpc("founder_hospital_portal_v2_summary"),
    sb.rpc("founder_hospital_portal_v2_requests_recent", { p_limit: 100 }),
    sb.rpc("founder_hospital_portal_v2_disputes_recent", { p_limit: 100 }),
  ]);
  if (sRes.error) throw new Error(`hpv2_summary: ${sRes.error.message}`);
  if (rRes.error) throw new Error(`hpv2_requests: ${rRes.error.message}`);
  if (dRes.error) throw new Error(`hpv2_disputes: ${dRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const reqs = (rRes.data ?? []) as Request[];
  const disp = (dRes.data ?? []) as Dispute[];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Hospital portal v2 admin ★★★★ · v0.6 Phase 7 SHIPPED EARLY</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Self-service portal infrastructure for hospital_admin users. 4 tables (self_service_requests + dispute_requests + feature_flags + session_log) · 10 RPCs (founder admin + hospital-callable + cron). RLS-scoped to caller. 11 request kinds + 8 dispute kinds + 6 rollout bands.
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="Total self-service requests" value={formatNumber(s.total_self_service_requests)} />
          <Card label="Submitted" value={formatNumber(s.requests_submitted_count)} tone={s.requests_submitted_count > 0 ? "warn" : "ok"} />
          <Card label="Under review" value={formatNumber(s.requests_under_review_count)} />
          <Card label="Approved" value={formatNumber(s.requests_approved_count)} tone="ok" />
          <Card label="Rejected" value={formatNumber(s.requests_rejected_count)} />
          <Card label="Expired" value={formatNumber(s.requests_expired_count)} />
          <Card label="Requests 30d" value={formatNumber(s.requests_30d)} />
          <Card label="Top request kind" value={s.top_request_kind ?? "—"} />
          <Card label="Total disputes" value={formatNumber(s.total_dispute_requests)} />
          <Card label="Disputes submitted" value={formatNumber(s.disputes_submitted_count)} tone={s.disputes_submitted_count > 0 ? "warn" : "ok"} />
          <Card label="Disputes resolved" value={formatNumber(s.disputes_resolved_count)} />
          <Card label="Disputes escalated" value={formatNumber(s.disputes_escalated_count)} tone={s.disputes_escalated_count > 0 ? "danger" : "ok"} />
          <Card label="Disputes 30d" value={formatNumber(s.disputes_30d)} />
          <Card label="Top dispute kind" value={s.top_dispute_kind ?? "—"} />
          <Card label="Active feature flags" value={formatNumber(s.active_feature_flags_total)} />
          <Card label="Hospitals w/ flags" value={formatNumber(s.hospitals_with_active_flags)} />
          <Card label="Session logs 30d" value={formatNumber(s.session_logs_30d)} />
          <Card label="Rate-limited 30d" value={formatNumber(s.rate_limited_attempts_30d)} tone={s.rate_limited_attempts_30d > 0 ? "danger" : "ok"} />
        </section>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Recent self-service requests ({reqs.length})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">Hospital</th>
                <th className="py-2 pr-3">Request kind</th>
                <th className="py-2 pr-3">Desired tier</th>
                <th className="py-2 pr-3">Status</th>
                <th className="py-2 pr-3">Submitted</th>
                <th className="py-2 text-right">Age</th>
              </tr>
            </thead>
            <tbody>
              {reqs.map((r) => (
                <tr key={r.id} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{r.hospital_user_id.slice(0, 8)}</td>
                  <td className="py-2 pr-3 text-xs">{r.request_kind}</td>
                  <td className="py-2 pr-3 text-xs">{r.desired_tier ?? "—"}</td>
                  <td className={`py-2 pr-3 text-xs ${r.status === "approved" ? "text-[var(--color-ok)]" : r.status === "rejected" ? "text-[var(--color-danger)]" : "text-[var(--color-warn)]"}`}>{r.status}</td>
                  <td className="py-2 pr-3 text-xs">{new Date(r.submitted_at).toLocaleDateString("en-IN")}</td>
                  <td className={`py-2 text-xs text-right tabular-nums ${r.age_days > 7 ? "text-[var(--color-danger)] font-semibold" : ""}`}>{r.age_days}d</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Recent disputes ({disp.length})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">Hospital</th>
                <th className="py-2 pr-3">Kind</th>
                <th className="py-2 pr-3">Status</th>
                <th className="py-2 pr-3 text-right">Amount claimed</th>
                <th className="py-2 pr-3">Submitted</th>
                <th className="py-2 text-right">Age</th>
              </tr>
            </thead>
            <tbody>
              {disp.map((d) => (
                <tr key={d.id} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{d.hospital_user_id.slice(0, 8)}</td>
                  <td className="py-2 pr-3 text-xs">{d.dispute_kind}</td>
                  <td className={`py-2 pr-3 text-xs ${d.status === "accepted" ? "text-[var(--color-ok)]" : d.status === "escalated" || d.status === "rejected" ? "text-[var(--color-danger)]" : "text-[var(--color-warn)]"}`}>{d.status}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{rup(d.amount_claimed_rupees)}</td>
                  <td className="py-2 pr-3 text-xs">{new Date(d.submitted_at).toLocaleDateString("en-IN")}</td>
                  <td className={`py-2 text-xs text-right tabular-nums ${d.age_days > 14 ? "text-[var(--color-danger)] font-semibold" : ""}`}>{d.age_days}d</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <p className="text-xs text-[var(--color-muted)]">
        Hospital-callable RPCs (RLS-scoped to caller): <code>hospital_portal_submit_self_service_request</code> · <code>hospital_portal_submit_dispute</code> · <code>hospital_portal_my_requests</code> · <code>hospital_portal_my_disputes</code>. Founder write: <code>log_founder_hpv2_review_request</code> · <code>log_founder_hpv2_review_dispute</code>. Cron: <code>hospital_portal_v2_expire_stale_requests</code> (flips submitted → expired at &gt;14d).
      </p>
    </div>
  );
}
