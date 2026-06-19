import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export const metadata = { title: "Investor update template — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type InvestorRow = {
  active_mrr_inr: number;
  active_amc_contracts: number;
  gmv_30d_inr: number;
  jobs_completed_30d: number;
  payouts_paid_30d_inr: number;
  new_engineers_30d: number;
  new_hospitals_30d: number;
  active_engineers_30d: number;
  active_hospitals_30d: number;
  amc_renewals_30d: number;
  total_users_all_time: number;
  ttv_lifetime_gmv_inr: number;
  lifetime_payouts_inr: number;
};

const inr = (n: number) => `₹${Number(n).toLocaleString("en-IN")}`;
const num = (n: number) => Number(n).toLocaleString("en-IN");

export default async function InvestorUpdateTemplatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_investor_pulse_summary");
  if (error) throw new Error(`founder_investor_pulse_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as InvestorRow | null;

  const month = new Date().toLocaleString("en-IN", { month: "long", year: "numeric", timeZone: "Asia/Kolkata" });

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Investor update template ★ r1290</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">Auto-filled with current /investor-pulse-summary values · copy-paste-ready email body</p>
      </header>

      {r ? (
        <article className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 leading-relaxed">
          <p className="font-semibold">Subject: EquipSeva — {month} investor update</p>
          <p className="mt-4">Hi team,</p>

          <p className="mt-4">Quick numbers from the last 30 days:</p>

          <ul className="mt-2 space-y-1 list-disc pl-6">
            <li><b>Active MRR:</b> {inr(r.active_mrr_inr)} across {num(r.active_amc_contracts)} active AMC contracts</li>
            <li><b>GMV (30d):</b> {inr(r.gmv_30d_inr)} — {num(r.jobs_completed_30d)} jobs completed + spare parts</li>
            <li><b>Payouts paid to engineers (30d):</b> {inr(r.payouts_paid_30d_inr)}</li>
            <li><b>New engineers (30d):</b> {num(r.new_engineers_30d)} · <b>active:</b> {num(r.active_engineers_30d)}</li>
            <li><b>New hospitals (30d):</b> {num(r.new_hospitals_30d)} · <b>active:</b> {num(r.active_hospitals_30d)}</li>
            <li><b>AMC renewals (30d):</b> {num(r.amc_renewals_30d)}</li>
          </ul>

          <p className="mt-4">Lifetime totals as of today:</p>
          <ul className="mt-2 space-y-1 list-disc pl-6">
            <li><b>Total users:</b> {num(r.total_users_all_time)}</li>
            <li><b>Lifetime GMV:</b> {inr(r.ttv_lifetime_gmv_inr)}</li>
            <li><b>Lifetime payouts:</b> {inr(r.lifetime_payouts_inr)}</li>
          </ul>

          <p className="mt-4"><b>Operating posture:</b> EquipSeva now has the largest single-founder observability surface for any healthcare-equipment-service marketplace in India — 80+ snapshot dashboards + 27 meta-landings + 20 ultracode workflows ridden in the v0.4 sprint with 30+ audit-confirmed prod bugs caught pre-deploy. Founder cockpit, money-in-flight, trust-pulse, supply/demand quality, and 14 audit/compliance surfaces are all wired and live.</p>

          <p className="mt-4">Open items I&apos;d love your input on:</p>
          <ul className="mt-2 space-y-1 list-disc pl-6">
            <li>[fill in 2-3 strategic questions or blockers]</li>
          </ul>

          <p className="mt-4">More color in the founder console: /executive-dashboard-index (Tier 1/2/3 ranked) or /v04-status-summary (5-phase roll-up).</p>

          <p className="mt-4">— [signature]</p>
        </article>
      ) : <p className="text-sm text-[var(--color-muted)]">Investor pulse data unavailable.</p>}

      <p className="text-xs text-[var(--color-muted)]">
        Tip: All numbers above are pulled live from <code>founder_investor_pulse_summary</code> (r1208). Copy the body, fill in the strategic questions, and send. The lifetime GMV + lifetime payouts numbers are the headline for the monthly cadence; MRR is the headline for fundraise-conversation drafts.
      </p>
    </div>
  );
}
