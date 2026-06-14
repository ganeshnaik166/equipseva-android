import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime, formatRupees, shortId } from "@/lib/format";
import { RevokeBountyButton } from "./RevokeBountyButton";

export const metadata = { title: "Referrals — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Dashboard = {
  total_referrals: number | null;
  pending_bounties: number | null;
  paid_bounties: number | null;
  revoked_bounties: number | null;
  queued_bounty_value: number | null;
  paid_bounty_value: number | null;
};

type RefRow = {
  id: string;
  referrer_user_id: string;
  referee_user_id: string;
  referral_code_used: string;
  referee_first_job_id: string | null;
  referee_first_completed_at: string | null;
  bounty_eligible: boolean;
  bounty_amount_rupees: number;
  bounty_revoked: boolean;
  bounty_revoke_reason: string | null;
  bounty_revoked_at: string | null;
  created_at: string;
};

type PayoutRow = {
  id: string;
  referral_id: string;
  beneficiary_user_id: string;
  amount_rupees: number;
  status: string;
  utr: string | null;
  mode: string | null;
  cancelled_reason: string | null;
  queued_at: string;
  paid_at: string | null;
};

export default async function ReferralsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [dashRes, refsRes, payoutsRes] = await Promise.all([
    supabase.rpc("founder_referral_dashboard"),
    supabase
      .from("engineer_referrals")
      .select(
        "id, referrer_user_id, referee_user_id, referral_code_used, referee_first_job_id, referee_first_completed_at, bounty_eligible, bounty_amount_rupees, bounty_revoked, bounty_revoke_reason, bounty_revoked_at, created_at",
      )
      .order("created_at", { ascending: false })
      .limit(200),
    supabase
      .from("referral_bounty_payouts")
      .select(
        "id, referral_id, beneficiary_user_id, amount_rupees, status, utr, mode, cancelled_reason, queued_at, paid_at",
      )
      .order("queued_at", { ascending: false })
      .limit(200),
  ]);

  if (dashRes.error)
    throw new Error(`founder_referral_dashboard: ${dashRes.error.message}`);
  const dash: Dashboard =
    (Array.isArray(dashRes.data) ? dashRes.data[0] : dashRes.data) ?? ({} as Dashboard);
  const refs = (refsRes.error ? [] : (refsRes.data ?? [])) as RefRow[];
  const payouts = (payoutsRes.error ? [] : (payoutsRes.data ?? [])) as PayoutRow[];
  const payoutByRefId = new Map(payouts.map((p) => [p.referral_id, p]));

  const refCols: Column<RefRow>[] = [
    {
      key: "when",
      header: "Registered",
      render: (r) => <span title={r.created_at}>{formatRelativeTime(r.created_at)}</span>,
    },
    {
      key: "referrer",
      header: "Referrer",
      render: (r) => (
        <Link
          href={`/engineers/${r.referrer_user_id}`}
          className="text-[var(--color-accent)] hover:underline"
        >
          {shortId(r.referrer_user_id)}
        </Link>
      ),
    },
    {
      key: "referee",
      header: "Referee",
      render: (r) => (
        <Link
          href={`/engineers/${r.referee_user_id}`}
          className="text-[var(--color-accent)] hover:underline"
        >
          {shortId(r.referee_user_id)}
        </Link>
      ),
    },
    {
      key: "first",
      header: "Referee 1st completed",
      render: (r) => formatRelativeTime(r.referee_first_completed_at),
    },
    {
      key: "amount",
      header: "Bounty",
      render: (r) => formatRupees(r.bounty_amount_rupees),
    },
    {
      key: "status",
      header: "Status",
      render: (r) => {
        if (r.bounty_revoked) {
          return (
            <span
              className="rounded bg-red-100 px-1.5 py-0.5 text-xs text-[var(--color-danger)]"
              title={r.bounty_revoke_reason ?? ""}
            >
              revoked
            </span>
          );
        }
        if (r.bounty_eligible) {
          const p = payoutByRefId.get(r.id);
          if (p?.status === "paid") {
            return (
              <span className="rounded bg-green-100 px-1.5 py-0.5 text-xs text-[var(--color-ok)]">
                paid {p.utr ? `(${p.utr})` : ""}
              </span>
            );
          }
          return (
            <span className="rounded bg-yellow-100 px-1.5 py-0.5 text-xs text-[var(--color-warn)]">
              eligible
            </span>
          );
        }
        return (
          <span className="rounded bg-gray-100 px-1.5 py-0.5 text-xs">
            pending evaluation
          </span>
        );
      },
    },
    {
      key: "act",
      header: "Action",
      render: (r) =>
        !r.bounty_revoked ? (
          <RevokeBountyButton referralId={r.id} />
        ) : (
          <span className="text-xs text-[var(--color-muted)]">—</span>
        ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer referrals</h1>
        <span className="text-xs text-[var(--color-muted)]">
          ₹{(dash.queued_bounty_value ?? 0).toLocaleString("en-IN")} queued ·{" "}
          ₹{(dash.paid_bounty_value ?? 0).toLocaleString("en-IN")} paid lifetime
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="Total referrals"
            value={formatNumber(dash.total_referrals)}
          />
          <StatCard
            label="Pending evaluation"
            value={formatNumber(dash.pending_bounties)}
            tone={(dash.pending_bounties ?? 0) > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="Bounties paid"
            value={formatNumber(dash.paid_bounties)}
            subtext={formatRupees(dash.paid_bounty_value)}
            tone="ok"
          />
          <StatCard
            label="Bounties revoked"
            value={formatNumber(dash.revoked_bounties)}
            tone={(dash.revoked_bounties ?? 0) > 0 ? "warn" : "ok"}
          />
        </div>
      </section>

      <DataTable
        columns={refCols}
        rows={refs}
        rowKey={(r) => r.id}
        emptyMessage="No referrals yet — referee signup must call register_engineer_referral RPC."
      />

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Daily cron at 04:47 UTC evaluates pending referrals — gates: referee&rsquo;s
        first job completed + escrow released + NO open r498 collusion flag pairing
        referrer/referee + NO open r501 duplicate-account flag. Bounty mints as a
        queued row in <code>referral_bounty_payouts</code>; payout settles via the
        existing engineer payouts queue (Cashfree). Founder can revoke any row with
        a ≥10-char reason — cancels the queued payout AND logs to founder_action_log.
      </section>
    </div>
  );
}
