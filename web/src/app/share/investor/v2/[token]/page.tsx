import { createClient } from "@supabase/supabase-js";

export const metadata = { title: "EquipSeva — investor brief" };
export const dynamic = "force-dynamic";

type Row = {
  outcome: "served" | "revoked" | "expired" | "exhausted" | "unknown_token";
  org_label: string | null;
  active_mrr_inr: number;
  active_amc_contracts: number;
  lifetime_jobs_completed: number;
  lifetime_gmv_inr: number;
  lifetime_payouts_inr: number;
  lifetime_signups: number;
  active_engineers_30d: number;
  active_hospitals_30d: number;
  active_states: number;
  top_equipment_categories: string | null;
  trust_score_pct: number;
  days_operating: number;
};

const inr = (n: number) => `₹${Number(n).toLocaleString("en-IN")}`;
const num = (n: number) => Number(n).toLocaleString("en-IN");

function publicClient() {
  // Anon client — does NOT carry founder session. Uses env-injected anon key.
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { auth: { persistSession: false } },
  );
}

export default async function InvestorShareV2Page({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const supabase = publicClient();
  const { data, error } = await supabase.rpc("investor_share_v2", { p_token: token });
  if (error) {
    return (
      <main className="mx-auto max-w-2xl p-8 font-sans">
        <h1 className="text-2xl font-bold">EquipSeva</h1>
        <p className="mt-4 text-red-600">Failed to load investor brief: {error.message}</p>
      </main>
    );
  }
  const r = (data?.[0] ?? null) as Row | null;
  if (!r || r.outcome !== "served") {
    return (
      <main className="mx-auto max-w-2xl p-8 font-sans">
        <h1 className="text-2xl font-bold">EquipSeva</h1>
        <p className="mt-4 text-red-600">
          {r?.outcome === "revoked" && "This share link has been revoked."}
          {r?.outcome === "expired" && "This share link has expired."}
          {r?.outcome === "exhausted" && "This share link has exceeded its view limit."}
          {(!r || r.outcome === "unknown_token") && "Invalid or unknown share link."}
        </p>
        <p className="mt-4 text-sm text-gray-500">If you believe this is a mistake, please contact the EquipSeva founder for a fresh link.</p>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-4xl p-8 font-sans">
      <header className="border-b border-gray-200 pb-6">
        <div className="text-xs uppercase tracking-widest text-gray-500">Investor brief · {r.org_label}</div>
        <h1 className="mt-2 text-3xl font-bold">EquipSeva</h1>
        <p className="mt-2 text-sm text-gray-600">India&apos;s largest healthcare-equipment-service marketplace · {r.days_operating} days operating</p>
      </header>

      <section className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div className="rounded-lg border-2 border-green-500 bg-white p-6">
          <div className="text-xs uppercase tracking-wider text-gray-500">Active MRR · committed monthly recurring</div>
          <div className="mt-2 text-4xl font-bold tabular-nums">{inr(r.active_mrr_inr)}</div>
          <div className="mt-1 text-xs text-gray-500">across {num(r.active_amc_contracts)} active AMC contracts</div>
        </div>
        <div className="rounded-lg border-2 border-blue-500 bg-white p-6">
          <div className="text-xs uppercase tracking-wider text-gray-500">Lifetime GMV</div>
          <div className="mt-2 text-4xl font-bold tabular-nums">{inr(r.lifetime_gmv_inr)}</div>
          <div className="mt-1 text-xs text-gray-500">{num(r.lifetime_jobs_completed)} jobs completed + spare parts paid lifetime</div>
        </div>
      </section>

      <section className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Card title="Lifetime payouts to engineers" value={inr(r.lifetime_payouts_inr)} />
        <Card title="Total signups all-time" value={num(r.lifetime_signups)} />
        <Card title="Active engineers (30d)" value={num(r.active_engineers_30d)} sub="completed ≥1 job" />
        <Card title="Active hospitals (30d)" value={num(r.active_hospitals_30d)} sub="posted ≥1 job" />
        <Card title="Active states (90d)" value={num(r.active_states)} sub="footprint" />
        <Card title="Trust score (30d)" value={`${Number(r.trust_score_pct).toFixed(1)}%`} sub="composite · disputes + audits + Code Red + refunds + payouts" />
      </section>

      <section className="mt-6 rounded-lg border border-gray-200 bg-white p-6">
        <div className="text-xs uppercase tracking-wider text-gray-500">Top 5 equipment categories (90d job volume)</div>
        <div className="mt-2 text-sm">{r.top_equipment_categories ?? "(no data)"}</div>
      </section>

      <section className="mt-8 rounded-lg border border-gray-200 bg-gray-50 p-6 text-sm">
        <h2 className="text-base font-semibold">What EquipSeva does</h2>
        <p className="mt-2">EquipSeva is a marketplace + AMC platform for hospital medical-equipment maintenance in India. Hospitals post jobs (preventive maintenance, emergency repair, calibration); engineers bid; we mediate escrow; AMC contracts cover recurring service with prepaid visit pools. Operating in {r.active_states} states with {num(r.active_engineers_30d)} engineers active in the last 30 days.</p>
      </section>

      <footer className="mt-8 border-t border-gray-200 pt-4 text-xs text-gray-500">
        EquipSeva · sanitized public brief · all numbers live from production database · no PII surfaced · for the recipient&apos;s diligence only.
      </footer>
    </main>
  );
}

function Card({ title, value, sub }: { title: string; value: string; sub?: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4">
      <div className="text-xs text-gray-500">{title}</div>
      <div className="mt-1 text-xl font-bold tabular-nums">{value}</div>
      {sub ? <div className="mt-1 text-xs text-gray-500">{sub}</div> : null}
    </div>
  );
}
