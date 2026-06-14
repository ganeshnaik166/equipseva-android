import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime, formatRupees, shortId } from "@/lib/format";
import { SetTierAction } from "./SetTierAction";

type TierDist = {
  tier: string;
  display_label: string;
  active_contracts: number | null;
  monthly_recurring_rupees: number | null;
  pending_payment_contracts: number | null;
};

const TIER_TONE: Record<string, string> = {
  gold: "bg-yellow-100 text-[var(--color-warn)]",
  silver: "bg-gray-200",
  bronze: "bg-orange-100",
  basic: "bg-gray-50 text-[var(--color-muted)]",
};

export const metadata = { title: "AMC contracts — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type AmcRow = {
  id: string;
  hospital_user_id: string;
  primary_engineer_id: string;
  status: string;
  visit_frequency: string;
  visits_per_year: number;
  monthly_fee_rupees: number;
  amc_tier?: string | null;
  start_date: string;
  end_date: string;
  scope_text: string | null;
  equipment_categories: string[] | null;
  auto_renew?: boolean | null;
  next_visit_at?: string | null;
  created_at?: string | null;
};

const STATUS_TONE: Record<string, "ok" | "warn" | "danger" | "neutral"> = {
  active: "ok",
  paused: "warn",
  expired: "neutral",
  cancelled: "neutral",
  renewal_failed: "danger",
  pending_payment: "warn",
};

export default async function AmcPage({
  searchParams,
}: {
  searchParams?: Promise<{ status?: string }>;
}) {
  await requireFounder();
  const params = (await searchParams) ?? {};
  const statusFilter = params.status ?? "active";

  const supabase = await getSupabaseServerClient();
  let query = supabase
    .from("amc_contracts")
    .select(
      "id, hospital_user_id, primary_engineer_id, status, visit_frequency, visits_per_year, monthly_fee_rupees, amc_tier, start_date, end_date, scope_text, equipment_categories, auto_renew, next_visit_at, created_at",
    )
    .order("created_at", { ascending: false })
    .limit(200);
  if (statusFilter !== "all") {
    query = query.eq("status", statusFilter);
  }

  const [rowsRes, distRes] = await Promise.all([
    query,
    supabase.rpc("founder_amc_tier_distribution"),
  ]);
  if (rowsRes.error) throw new Error(`amc_contracts: ${rowsRes.error.message}`);
  const rows = (rowsRes.data ?? []) as AmcRow[];
  const dist = (distRes.error ? [] : (distRes.data ?? [])) as TierDist[];

  const totalMrr = rows
    .filter((r) => r.status === "active")
    .reduce((s, r) => s + Number(r.monthly_fee_rupees ?? 0), 0);
  const totalAnnualVisits = rows
    .filter((r) => r.status === "active")
    .reduce((s, r) => s + (r.visits_per_year ?? 0), 0);
  const expiringSoon = rows.filter(
    (r) =>
      r.status === "active" &&
      r.end_date != null &&
      new Date(r.end_date).getTime() < Date.now() + 30 * 86400 * 1000,
  ).length;

  const STATUSES = [
    "active",
    "paused",
    "pending_payment",
    "renewal_failed",
    "expired",
    "cancelled",
    "all",
  ];

  const cols: Column<AmcRow>[] = [
    {
      key: "id",
      header: "Contract",
      render: (r) => (
        <code className="text-xs text-[var(--color-muted)]">{shortId(r.id)}</code>
      ),
    },
    {
      key: "hospital",
      header: "Hospital",
      render: (r) => (
        <Link
          href={`/hospitals/${r.hospital_user_id}`}
          className="text-[var(--color-accent)] hover:underline"
        >
          {shortId(r.hospital_user_id)}
        </Link>
      ),
    },
    {
      key: "engineer",
      header: "Primary engineer",
      render: (r) => (
        <code className="text-xs">{shortId(r.primary_engineer_id)}</code>
      ),
    },
    {
      key: "status",
      header: "Status",
      render: (r) => {
        const tone = STATUS_TONE[r.status] ?? "neutral";
        const cls =
          tone === "ok"
            ? "bg-green-100 text-[var(--color-ok)]"
            : tone === "warn"
              ? "bg-yellow-100 text-[var(--color-warn)]"
              : tone === "danger"
                ? "bg-red-100 text-[var(--color-danger)]"
                : "bg-gray-100";
        return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{r.status}</span>;
      },
    },
    {
      key: "tier",
      header: "Tier",
      render: (r) => {
        const tier = r.amc_tier ?? "basic";
        return (
          <div className="flex items-center gap-2">
            <span
              className={`rounded px-1.5 py-0.5 text-xs uppercase ${TIER_TONE[tier] ?? "bg-gray-100"}`}
            >
              {tier}
            </span>
            <SetTierAction contractId={r.id} currentTier={tier} />
          </div>
        );
      },
    },
    {
      key: "fee",
      header: "Monthly fee",
      render: (r) => formatRupees(r.monthly_fee_rupees),
    },
    {
      key: "freq",
      header: "Cadence",
      render: (r) => (
        <span className="text-xs">
          {r.visit_frequency} · {r.visits_per_year}/yr
        </span>
      ),
    },
    {
      key: "dates",
      header: "Window",
      render: (r) => (
        <span className="text-xs">
          {r.start_date} → {r.end_date}
        </span>
      ),
    },
    {
      key: "next",
      header: "Next visit",
      render: (r) => formatRelativeTime(r.next_visit_at ?? null),
    },
    {
      key: "renew",
      header: "Auto-renew",
      render: (r) =>
        r.auto_renew ? (
          <span className="text-xs text-[var(--color-ok)]">yes</span>
        ) : (
          <span className="text-xs text-[var(--color-muted)]">no</span>
        ),
    },
    {
      key: "scope",
      header: "Scope",
      render: (r) => (
        <details>
          <summary className="cursor-pointer text-xs text-[var(--color-muted)]">view</summary>
          <div className="mt-1 max-w-md space-y-1 text-xs">
            <div className="text-[var(--color-muted)]">
              {(r.equipment_categories ?? []).join(", ") || "—"}
            </div>
            <p className="whitespace-pre-wrap">{r.scope_text ?? "—"}</p>
          </div>
        </details>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC contracts</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {rows.length} match{rows.length === 1 ? "" : "es"}
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Active MRR" value={formatRupees(totalMrr)} tone="ok" />
          <StatCard label="Annual visits" value={formatNumber(totalAnnualVisits)} />
          <StatCard
            label="Expiring < 30 days"
            value={formatNumber(expiringSoon)}
            tone={expiringSoon > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="Filter"
            value={statusFilter}
            subtext="status"
          />
        </div>
      </section>

      {dist.length > 0 && (
        <section>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
            Tier distribution (r560 ladder)
          </h2>
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            {dist.map((d) => (
              <div
                key={d.tier}
                className="rounded border border-[var(--color-border)] bg-white p-4"
              >
                <div className="flex items-baseline justify-between">
                  <span
                    className={`rounded px-1.5 py-0.5 text-xs uppercase ${TIER_TONE[d.tier] ?? "bg-gray-100"}`}
                  >
                    {d.display_label}
                  </span>
                  <span className="text-xs text-[var(--color-muted)]">
                    {formatNumber(d.active_contracts)} active
                  </span>
                </div>
                <div className="mt-1 text-xl font-semibold tabular-nums">
                  {formatRupees(d.monthly_recurring_rupees)}
                  <span className="ml-1 text-xs font-normal text-[var(--color-muted)]">
                    MRR
                  </span>
                </div>
                {(d.pending_payment_contracts ?? 0) > 0 && (
                  <div className="text-xs text-[var(--color-warn)]">
                    {formatNumber(d.pending_payment_contracts)} pending payment
                  </div>
                )}
              </div>
            ))}
          </div>
        </section>
      )}

      <nav className="flex flex-wrap gap-2 text-sm">
        {STATUSES.map((s) => (
          <a
            key={s}
            href={`/amc?status=${s}`}
            className={`rounded border px-2 py-1 ${
              s === statusFilter
                ? "border-[var(--color-fg)] bg-[var(--color-fg)] text-white"
                : "border-[var(--color-border)] hover:bg-gray-50"
            }`}
          >
            {s}
          </a>
        ))}
      </nav>

      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.id}
        emptyMessage={
          statusFilter === "all"
            ? "No AMC contracts yet."
            : `No contracts with status="${statusFilter}".`
        }
      />
    </div>
  );
}
