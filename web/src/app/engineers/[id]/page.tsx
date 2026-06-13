import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatPct, formatRelativeTime, formatRupees, shortId } from "@/lib/format";

export const metadata = { title: "Engineer detail — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type LtvRow = {
  engineer_user_id: string;
  engineer_email: string | null;
  first_active_at: string | null;
  total_jobs_completed: number | null;
  total_gross_rupees: number | null;
  total_net_paid_rupees: number | null;
  total_tds_rupees: number | null;
  avg_rating: number | null;
  dispute_count: number | null;
  current_risk_score: number | null;
  risk_band: string | null;
};

type SlaRow = {
  engineer_user_id: string;
  engineer_email: string | null;
  jobs_completed_window: number | null;
  jobs_disputed_window: number | null;
  dispute_rate_pct: number | null;
  avg_accept_to_arrival_hrs: number | null;
  avg_arrival_to_complete_hrs: number | null;
  sla_breaches: number | null;
  on_time_pct: number | null;
  current_tier: string | null;
};

type AttendanceRow = {
  engineer_email: string | null;
  engineer_user_id?: string | null;
  job_location: string | null;
  arrival_location: string | null;
  distance_km: number | null;
  event_kind: string | null;
  created_at: string;
};

type AuditRow = {
  id: string;
  op_name: string;
  target_table: string | null;
  target_row_id: string | null;
  outcome: string | null;
  reason: string | null;
  created_at: string;
};

export default async function EngineerDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireFounder();
  const { id } = await params;
  const supabase = await getSupabaseServerClient();

  // Compose existing RPCs — no new SQL. LTV ranks all engineers; we
  // pull a wide window and find this one. SLA + attendance are similar.
  const [ltvRes, slaRes, attRes, auditRes] = await Promise.all([
    supabase.rpc("founder_engineer_ltv_ranked", { p_limit: 500 }),
    supabase.rpc("engineer_sla_board", { p_days: 90, p_limit: 500 }),
    supabase.rpc("founder_suspicious_attendance_recent", { p_days: 90, p_limit: 200 }),
    supabase
      .from("founder_action_log")
      .select("id, op_name, target_table, target_row_id, outcome, reason, created_at")
      .eq("target_row_id", id)
      .order("created_at", { ascending: false })
      .limit(50),
  ]);

  if (ltvRes.error) throw new Error(`engineer_ltv_ranked: ${ltvRes.error.message}`);
  if (slaRes.error) throw new Error(`engineer_sla_board: ${slaRes.error.message}`);
  if (attRes.error) throw new Error(`suspicious_attendance: ${attRes.error.message}`);

  const ltv = ((ltvRes.data ?? []) as LtvRow[]).find((r) => r.engineer_user_id === id);
  const sla = ((slaRes.data ?? []) as SlaRow[]).find((r) => r.engineer_user_id === id);
  const att = ((attRes.data ?? []) as AttendanceRow[]).filter(
    (r) => r.engineer_user_id === id || r.engineer_email === ltv?.engineer_email,
  );
  const audit = (auditRes.data ?? []) as AuditRow[];

  if (!ltv && !sla) {
    return (
      <div className="space-y-3">
        <h1 className="text-xl font-semibold">Engineer not found</h1>
        <p className="text-sm text-[var(--color-muted)]">
          No LTV or SLA rows match user_id <code>{id}</code>. They may be brand-new (no
          completed jobs yet) or a stale link.
        </p>
        <Link
          href="/engineers"
          className="inline-block rounded border border-[var(--color-border)] px-3 py-1 text-sm hover:bg-gray-50"
        >
          ← back to engineers
        </Link>
      </div>
    );
  }

  const email = ltv?.engineer_email ?? sla?.engineer_email ?? "(unknown email)";

  const attendanceCols: Column<AttendanceRow>[] = [
    {
      key: "when",
      header: "When",
      render: (r) => <span title={r.created_at}>{formatRelativeTime(r.created_at)}</span>,
    },
    { key: "kind", header: "Event", render: (r) => r.event_kind ?? "—" },
    {
      key: "dist",
      header: "Distance",
      render: (r) =>
        r.distance_km != null ? `${r.distance_km.toFixed(2)} km` : "—",
    },
    {
      key: "where",
      header: "Job → arrival",
      render: (r) => (
        <span className="text-xs text-[var(--color-muted)]">
          {r.job_location ?? "?"} → {r.arrival_location ?? "?"}
        </span>
      ),
    },
  ];

  const auditCols: Column<AuditRow>[] = [
    {
      key: "when",
      header: "When",
      render: (r) => <span title={r.created_at}>{formatRelativeTime(r.created_at)}</span>,
    },
    { key: "op", header: "Operation", render: (r) => <code className="text-xs">{r.op_name}</code> },
    {
      key: "outcome",
      header: "Outcome",
      render: (r) => (
        <span className="rounded bg-gray-100 px-1.5 py-0.5 text-xs">{r.outcome ?? "—"}</span>
      ),
    },
    { key: "reason", header: "Reason", render: (r) => <span className="text-xs">{r.reason ?? "—"}</span> },
  ];

  return (
    <div className="space-y-8">
      <header className="flex items-baseline justify-between">
        <div>
          <Link
            href="/engineers"
            className="text-xs text-[var(--color-muted)] hover:text-[var(--color-fg)]"
          >
            ← engineers
          </Link>
          <h1 className="mt-1 text-xl font-semibold">{email}</h1>
          <p className="text-xs text-[var(--color-muted)]">
            user_id <code>{id}</code>
          </p>
        </div>
        <div className="flex flex-col items-end gap-1">
          {sla?.current_tier && (
            <span className="rounded bg-gray-100 px-2 py-0.5 text-xs uppercase tracking-wider">
              {sla.current_tier}
            </span>
          )}
          {ltv?.risk_band && (
            <span
              className={`rounded px-2 py-0.5 text-xs ${
                ltv.risk_band.toLowerCase() === "red"
                  ? "bg-red-100 text-[var(--color-danger)]"
                  : ltv.risk_band.toLowerCase() === "amber" || ltv.risk_band.toLowerCase() === "yellow"
                    ? "bg-yellow-100 text-[var(--color-warn)]"
                    : "bg-green-100 text-[var(--color-ok)]"
              }`}
            >
              risk {ltv.current_risk_score ?? 0} · {ltv.risk_band}
            </span>
          )}
        </div>
      </header>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Lifetime
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="Jobs completed"
            value={formatNumber(ltv?.total_jobs_completed)}
            subtext={ltv?.first_active_at ? `since ${formatRelativeTime(ltv.first_active_at)}` : undefined}
          />
          <StatCard label="Gross earned" value={formatRupees(ltv?.total_gross_rupees)} />
          <StatCard label="Net paid out" value={formatRupees(ltv?.total_net_paid_rupees)} />
          <StatCard label="TDS withheld" value={formatRupees(ltv?.total_tds_rupees)} />
          <StatCard
            label="Avg rating"
            value={ltv?.avg_rating != null ? `${ltv.avg_rating.toFixed(2)}★` : "—"}
          />
          <StatCard
            label="Dispute count"
            value={formatNumber(ltv?.dispute_count)}
            tone={(ltv?.dispute_count ?? 0) > 0 ? "warn" : "ok"}
          />
        </div>
      </section>

      {sla && (
        <section>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
            SLA — last 90 days
          </h2>
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            <StatCard
              label="Completed (90d)"
              value={formatNumber(sla.jobs_completed_window)}
            />
            <StatCard
              label="Disputed (90d)"
              value={formatNumber(sla.jobs_disputed_window)}
              tone={(sla.jobs_disputed_window ?? 0) > 0 ? "warn" : "ok"}
            />
            <StatCard
              label="Dispute rate"
              value={formatPct(sla.dispute_rate_pct)}
              tone={
                (sla.dispute_rate_pct ?? 0) > 15
                  ? "danger"
                  : (sla.dispute_rate_pct ?? 0) > 5
                    ? "warn"
                    : "ok"
              }
            />
            <StatCard
              label="On-time"
              value={formatPct(sla.on_time_pct)}
              tone={(sla.on_time_pct ?? 0) >= 90 ? "ok" : (sla.on_time_pct ?? 0) >= 75 ? "warn" : "danger"}
            />
            <StatCard
              label="Avg accept → arrival"
              value={sla.avg_accept_to_arrival_hrs != null ? `${sla.avg_accept_to_arrival_hrs.toFixed(1)}h` : "—"}
              tone={(sla.avg_accept_to_arrival_hrs ?? 0) > 24 ? "warn" : "ok"}
            />
            <StatCard
              label="Avg arrival → complete"
              value={sla.avg_arrival_to_complete_hrs != null ? `${sla.avg_arrival_to_complete_hrs.toFixed(1)}h` : "—"}
              tone={(sla.avg_arrival_to_complete_hrs ?? 0) > 12 ? "warn" : "ok"}
            />
            <StatCard
              label="SLA breaches"
              value={formatNumber(sla.sla_breaches)}
              tone={(sla.sla_breaches ?? 0) > 0 ? "warn" : "ok"}
            />
          </div>
        </section>
      )}

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Suspicious attendance <span className="text-[var(--color-muted)]">({att.length})</span>
        </h2>
        <DataTable
          columns={attendanceCols}
          rows={att}
          rowKey={(r, i) => `${r.created_at}-${i}`}
          emptyMessage="No suspicious attendance events in last 90 days."
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Audit log targeting this user_id <span className="text-[var(--color-muted)]">({audit.length})</span>
        </h2>
        <p className="mb-2 text-xs text-[var(--color-muted)]">
          Founder actions where this user_id was the target_row_id. Note: actions
          targeting payouts/escrow rows owned by this engineer surface elsewhere; this
          list only catches direct user_id targets.
        </p>
        <DataTable
          columns={auditCols}
          rows={audit}
          rowKey={(r) => r.id}
          emptyMessage="No founder actions targeting this user_id."
        />
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-4 text-xs text-[var(--color-muted)]">
        <strong>Quick links</strong>
        <ul className="mt-1 flex gap-3">
          <li>
            <Link href={`/payouts?status=queued`} className="hover:text-[var(--color-fg)]">
              all queued payouts
            </Link>
          </li>
          <li>
            <Link href="/kyc" className="hover:text-[var(--color-fg)]">
              KYC renewals
            </Link>
          </li>
          <li>
            <Link href="/risk" className="hover:text-[var(--color-fg)]">
              risk flags
            </Link>
          </li>
        </ul>
      </section>
    </div>
  );
}
