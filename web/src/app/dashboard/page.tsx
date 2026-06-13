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

export default async function DashboardPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const { data, error } = await supabase.rpc("founder_hero_kpis");
  if (error) {
    throw new Error(`founder_hero_kpis failed: ${error.message}`);
  }
  const k: HeroKpis = (Array.isArray(data) ? data[0] : data) ?? ({} as HeroKpis);

  const generatedAt = new Date().toLocaleString("en-IN", {
    timeZone: "Asia/Kolkata",
  });

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Dashboard</h1>
        <span className="text-xs text-[var(--color-muted)]">
          generated {generatedAt} IST
        </span>
      </header>

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
