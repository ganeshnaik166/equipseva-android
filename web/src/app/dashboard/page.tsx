import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatPct, formatRupees } from "@/lib/format";

export const metadata = { title: "Dashboard — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type HeroKpis = {
  gmv_7d_rupees: number | null;
  gmv_prior_7d_rupees: number | null;
  gmv_wow_pct: number | null;
  completed_jobs_7d: number | null;
  active_engineers_30d: number | null;
  open_disputes: number | null;
  pending_refund_authorizations: number | null;
  total_escrow_held_rupees: number | null;
  undeposited_tds_total_rupees: number | null;
  open_dpdp_grievances: number | null;
  amc_contracts_active: number | null;
  amc_contracts_pending_payment: number | null;
};

type DemandRow = { signal_count: number | null };
type SuperRow = { status: string; assignment_count: number | null; total_in_progress: number | null };
type TierMoveRow = { changed_at: string; new_tier: string; prev_tier: string };
type DailyActivityRow = {
  metric: string;
  count_today: number | null;
  count_yesterday: number | null;
  delta: number | null;
};

const DAILY_METRIC_LABEL: Record<string, string> = {
  new_repair_jobs: "New repair jobs",
  accepted_bids: "Accepted bids",
  completed_jobs: "Completed jobs",
  signed_dsr_reports: "Signed DSRs",
  new_amc_contracts: "New AMC contracts",
  new_demand_signals: "New demand signals",
  tier_promotions: "Tier promotions",
};

export default async function DashboardPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  // r597 — parallel-fetch the v0.5 pipeline KPIs alongside the existing
  // hero. Each RPC fails silently into a zeroed bucket so a single v0.5
  // outage doesn't break the legacy dashboard.
  const [heroRes, demandRes, superRes, tierMovesRes, dailyRes] = await Promise.all([
    supabase.rpc("founder_hero_kpis"),
    supabase.rpc("founder_demand_signal_dashboard"),
    supabase.rpc("founder_supervision_dashboard"),
    supabase.rpc("founder_tier_history_recent", { p_limit: 200 }),
    supabase.rpc("founder_daily_activity_summary"),
  ]);
  if (heroRes.error) {
    throw new Error(`founder_hero_kpis failed: ${heroRes.error.message}`);
  }
  const k: HeroKpis = (Array.isArray(heroRes.data) ? heroRes.data[0] : heroRes.data) ?? ({} as HeroKpis);

  // v0.5 pipeline aggregates (silent fail = 0):
  const demandRows = (demandRes.error ? [] : (demandRes.data ?? [])) as DemandRow[];
  const unresolvedSignals = demandRows.reduce((s, r) => s + (r.signal_count ?? 0), 0);
  const unresolvedGroups = demandRows.length;

  const superRows = (superRes.error ? [] : (superRes.data ?? [])) as SuperRow[];
  const supervisionInProgress = superRows[0]?.total_in_progress ?? 0;
  const supervisionPending = superRows.find((r) => r.status === "pending_supervisor_accept")
    ?.assignment_count ?? 0;

  const dailyRows = (dailyRes.error ? [] : (dailyRes.data ?? [])) as DailyActivityRow[];

  const tierMoves = (tierMovesRes.error ? [] : (tierMovesRes.data ?? [])) as TierMoveRow[];
  const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
  const tierMoves7d = tierMoves.filter(
    (r) => new Date(r.changed_at).getTime() >= sevenDaysAgo,
  );
  const tierRank: Record<string, number> = { none: 0, bronze: 1, silver: 2, gold: 3 };
  const promotions7d = tierMoves7d.filter(
    (r) => (tierRank[r.new_tier] ?? 0) > (tierRank[r.prev_tier] ?? 0),
  ).length;

  const generatedAt = new Date().toLocaleString("en-IN", {
    timeZone: "Asia/Kolkata",
  });

  // r527 — triage list of actionable items, surfaced as alert pills.
  // Sorted by stop-the-bleeding priority (refunds + disputes first).
  type AlertTone = "danger" | "warn" | "neutral";
  const alerts: { label: string; href: string; count: number; tone: AlertTone }[] = [
    {
      label: "Pending refund authorizations",
      href: "/refunds",
      count: k.pending_refund_authorizations ?? 0,
      tone: "warn" as AlertTone,
    },
    {
      label: "Open disputes",
      href: "/disputes",
      count: k.open_disputes ?? 0,
      tone: ((k.open_disputes ?? 0) > 0 ? "warn" : "neutral") as AlertTone,
    },
    {
      label: "DPDP grievances open",
      href: "/dpdp",
      count: k.open_dpdp_grievances ?? 0,
      tone: ((k.open_dpdp_grievances ?? 0) > 0 ? "danger" : "neutral") as AlertTone,
    },
    {
      label: "AMC pending payment",
      href: "/dashboard",
      count: k.amc_contracts_pending_payment ?? 0,
      tone: ((k.amc_contracts_pending_payment ?? 0) > 0 ? "warn" : "neutral") as AlertTone,
    },
  ].filter((a) => a.count > 0);

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Dashboard</h1>
        <span className="text-xs text-[var(--color-muted)]">
          generated {generatedAt} IST
        </span>
      </header>

      {alerts.length > 0 && (
        <section>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
            Triage now ({alerts.reduce((s, a) => s + a.count, 0)} pending)
          </h2>
          <div className="flex flex-wrap gap-2">
            {alerts.map((a) => (
              <a
                key={a.label}
                href={a.href}
                className={`rounded border px-3 py-1.5 text-sm ${
                  a.tone === "danger"
                    ? "border-[var(--color-danger)] bg-red-50 text-[var(--color-danger)] hover:bg-red-100"
                    : a.tone === "warn"
                      ? "border-[var(--color-warn)] bg-yellow-50 text-[var(--color-warn)] hover:bg-yellow-100"
                      : "border-[var(--color-border)] bg-white hover:bg-gray-50"
                }`}
              >
                <span className="font-semibold tabular-nums">{a.count}</span>{" "}
                <span>{a.label}</span>
              </a>
            ))}
          </div>
        </section>
      )}

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Money
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="GMV last 7 days"
            value={formatRupees(k.gmv_7d_rupees)}
            subtext={
              k.gmv_wow_pct != null ? `${formatPct(k.gmv_wow_pct)} WoW` : undefined
            }
            tone={k.gmv_wow_pct != null && k.gmv_wow_pct < 0 ? "warn" : "ok"}
          />
          <StatCard
            label="GMV prior 7 days"
            value={formatRupees(k.gmv_prior_7d_rupees)}
          />
          <StatCard
            label="Escrow held"
            value={formatRupees(k.total_escrow_held_rupees)}
          />
          <StatCard
            label="Undeposited TDS"
            value={formatRupees(k.undeposited_tds_total_rupees)}
            tone={
              (k.undeposited_tds_total_rupees ?? 0) > 100000 ? "warn" : "neutral"
            }
          />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Operations
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="Completed jobs (7d)"
            value={formatNumber(k.completed_jobs_7d)}
          />
          <StatCard
            label="Active engineers (30d)"
            value={formatNumber(k.active_engineers_30d)}
          />
          <StatCard
            label="Open disputes"
            value={formatNumber(k.open_disputes)}
            href="/disputes"
            tone={(k.open_disputes ?? 0) > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="Pending refund auths"
            value={formatNumber(k.pending_refund_authorizations)}
            tone={(k.pending_refund_authorizations ?? 0) > 0 ? "warn" : "ok"}
          />
        </div>
      </section>

      {/* r602 — Today vs yesterday strip. IST day window; future edge
          fn can email this same data at 08:00 IST. */}
      {dailyRows.length > 0 && (
        <section>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
            Today vs yesterday (IST)
          </h2>
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            {dailyRows.map((d) => {
              const delta = d.delta ?? 0;
              const tone =
                delta > 0
                  ? "ok"
                  : delta < 0
                    ? "warn"
                    : ("neutral" as const);
              const sign = delta > 0 ? "+" : "";
              return (
                <StatCard
                  key={d.metric}
                  label={DAILY_METRIC_LABEL[d.metric] ?? d.metric}
                  value={formatNumber(d.count_today)}
                  subtext={`${sign}${delta} vs ${formatNumber(d.count_yesterday)} yesterday`}
                  tone={tone}
                />
              );
            })}
          </div>
        </section>
      )}

      {/* r597 — v0.5 pipeline-health section. Links into the new
          surfaces (/demand-signals, /training, /tier-history) so the
          founder can drill from one glance. */}
      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          v0.5 pipeline health
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="Unresolved demand groups"
            value={formatNumber(unresolvedGroups)}
            subtext={
              unresolvedSignals > 0 ? `${formatNumber(unresolvedSignals)} signals` : undefined
            }
            tone={unresolvedGroups > 0 ? "warn" : "ok"}
            href="/demand-signals"
          />
          <StatCard
            label="Supervision in progress"
            value={formatNumber(supervisionInProgress)}
            subtext={supervisionPending > 0 ? `${supervisionPending} awaiting accept` : undefined}
            tone={supervisionPending > 0 ? "warn" : "ok"}
            href="/training"
          />
          <StatCard
            label="Tier promotions (7d)"
            value={formatNumber(promotions7d)}
            subtext={tierMoves7d.length > 0 ? `${tierMoves7d.length} total moves` : undefined}
            tone="ok"
            href="/tier-history"
          />
          <StatCard
            label="Engineer tier moves (in view)"
            value={formatNumber(tierMoves.length)}
            href="/tier-history"
          />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Compliance & AMC
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="Open DPDP grievances"
            value={formatNumber(k.open_dpdp_grievances)}
            tone={(k.open_dpdp_grievances ?? 0) > 0 ? "danger" : "ok"}
          />
          <StatCard
            label="AMC contracts active"
            value={formatNumber(k.amc_contracts_active)}
          />
          <StatCard
            label="AMC pending payment"
            value={formatNumber(k.amc_contracts_pending_payment)}
            tone={(k.amc_contracts_pending_payment ?? 0) > 0 ? "warn" : "neutral"}
          />
          <StatCard label="Risk flags" value="open" href="/risk" />
        </div>
      </section>
    </div>
  );
}
