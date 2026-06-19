import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Phone OTP funnel summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  requests_24h: number;
  requests_7d: number;
  requests_30d: number;
  unique_phones_24h: number;
  unique_phones_7d: number;
  verified_phones_7d: number;
  verify_rate_pct_7d: number;
  resend_phones_24h: number;
  avg_attempts_per_phone_24h: number;
  rate_limit_hits_24h: number;
  burst_phones_24h: number;
  anon_share_pct_7d: number;
};

function Kpi({ label, value, hint, tone }: { label: string; value: string; hint?: string; tone?: "ok" | "warn" | "danger" }) {
  const toneClass =
    tone === "danger" ? "text-[var(--color-danger)]" :
    tone === "warn"   ? "text-[var(--color-warn)]"   :
    tone === "ok"     ? "text-[var(--color-ok)]"     : "";
  return (
    <div className="rounded border border-[var(--color-border)] p-4">
      <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${toneClass}`}>{value}</div>
      {hint ? <div className="mt-1 text-xs text-[var(--color-muted)]">{hint}</div> : null}
    </div>
  );
}

export default async function PhoneOtpFunnelSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_phone_otp_funnel_summary");
  if (error) throw new Error(`founder_phone_otp_funnel_summary: ${error.message}`);
  const r = ((data ?? [])[0] ?? null) as Row | null;

  if (!r) {
    return (
      <div className="space-y-6">
        <header><h1 className="text-xl font-semibold">Phone OTP funnel summary</h1></header>
        <p className="text-sm text-[var(--color-muted)]">No OTP activity recorded yet.</p>
      </div>
    );
  }

  const verifyRate = Number(r.verify_rate_pct_7d);
  const verifyTone: "ok" | "warn" | "danger" =
    verifyRate >= 70 ? "ok" : verifyRate >= 50 ? "warn" : "danger";

  const bursts = Number(r.burst_phones_24h);
  const burstTone: "ok" | "warn" | "danger" =
    bursts === 0 ? "ok" : bursts <= 3 ? "warn" : "danger";

  const rlHits = Number(r.rate_limit_hits_24h);
  const rlTone: "ok" | "warn" | "danger" =
    rlHits === 0 ? "ok" : rlHits <= 5 ? "warn" : "danger";

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Phone OTP funnel summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          SMS-layer health BEFORE signup funnel · 5/hour/phone rate-limited
        </span>
      </header>

      <section>
        <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">Volume</h2>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <Kpi label="Requests 24h"   value={formatNumber(Number(r.requests_24h))}   hint="OTP send attempts" />
          <Kpi label="Requests 7d"    value={formatNumber(Number(r.requests_7d))}    />
          <Kpi label="Requests 30d"   value={formatNumber(Number(r.requests_30d))}   />
          <Kpi label="Unique phones 24h" value={formatNumber(Number(r.unique_phones_24h))} />
          <Kpi label="Unique phones 7d"  value={formatNumber(Number(r.unique_phones_7d))}  />
          <Kpi label="Anon share 7d"  value={`${Number(r.anon_share_pct_7d).toFixed(1)}%`} hint="user_id IS NULL (pre-login)" />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">Verify conversion</h2>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <Kpi label="Verified phones 7d" value={formatNumber(Number(r.verified_phones_7d))} hint="phone_confirmed_at ≥ request" />
          <Kpi label="Verify rate 7d"      value={`${verifyRate.toFixed(1)}%`} tone={verifyTone} hint="verified ÷ unique phones" />
          <Kpi label="Avg attempts / phone 24h" value={Number(r.avg_attempts_per_phone_24h).toFixed(2)} hint=">1 implies resend friction" />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">Abuse signal</h2>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <Kpi label="Resend phones 24h"   value={formatNumber(Number(r.resend_phones_24h))} hint="phones with ≥2 requests" />
          <Kpi label="Rate-limit hits 24h" value={formatNumber(rlHits)} tone={rlTone} hint="phones with ≥5 in one hour" />
          <Kpi label="Burst phones (1h)"   value={formatNumber(bursts)} tone={burstTone} hint="suspected bot / SIM-farm" />
        </div>
      </section>

      <p className="text-xs text-[var(--color-muted)]">
        Verify-rate &lt; 50% or sudden volume drop indicates Twilio outage. Burst-phones &gt; 3 in last hour
        indicates SIM-farm probe — block IP-hash via WAF.
      </p>
    </div>
  );
}
