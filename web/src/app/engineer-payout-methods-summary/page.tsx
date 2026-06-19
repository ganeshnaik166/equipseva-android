import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer payout methods summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_methods: number;
  distinct_engineers: number;
  default_methods: number;
  upi_methods: number;
  bank_methods: number;
  verified_methods: number;
  unverified_methods: number;
  invalid_methods: number;
  razorpay_bound_methods: number;
  added_7d: number;
  added_30d: number;
  updated_7d: number;
};

function Card({ label, value, tone, hint }: { label: string; value: string; tone?: "ok" | "warn" | "danger" | "muted"; hint?: string }) {
  const toneClass =
    tone === "ok" ? "text-[var(--color-ok)]"
    : tone === "warn" ? "text-[var(--color-warn)]"
    : tone === "danger" ? "text-[var(--color-danger)]"
    : tone === "muted" ? "text-[var(--color-muted)]"
    : "";
  return (
    <div className="rounded border border-[var(--color-border)] bg-white p-3">
      <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${toneClass}`}>{value}</div>
      {hint ? <div className="mt-1 text-[10px] text-[var(--color-muted)]">{hint}</div> : null}
    </div>
  );
}

export default async function EngineerPayoutMethodsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_payout_methods_summary");
  if (error) throw new Error(`founder_engineer_payout_methods_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;

  const total = r?.total_methods ?? 0;
  const verified = r?.verified_methods ?? 0;
  const invalid = r?.invalid_methods ?? 0;
  const upi = r?.upi_methods ?? 0;
  const bank = r?.bank_methods ?? 0;
  const verifiedPct = total > 0 ? Math.round((verified / total) * 1000) / 10 : 0;
  const invalidPct = total > 0 ? Math.round((invalid / total) * 1000) / 10 : 0;
  const upiPct = total > 0 ? Math.round((upi / total) * 1000) / 10 : 0;
  const bankPct = total > 0 ? Math.round((bank / total) * 1000) / 10 : 0;

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer payout methods summary</h1>
        <span className="text-xs text-[var(--color-muted)]">Registry of UPI/bank destinations per engineer · verification health</span>
      </header>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-[var(--color-muted)]">Registry size</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="Total methods" value={formatNumber(r?.total_methods ?? 0)} />
          <Card label="Distinct engineers" value={formatNumber(r?.distinct_engineers ?? 0)} />
          <Card label="Default methods" value={formatNumber(r?.default_methods ?? 0)} hint="One default per engineer (partial unique index)" />
          <Card label="Razorpay-bound" value={formatNumber(r?.razorpay_bound_methods ?? 0)} hint="Cached fund_account_id from RazorpayX" />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-[var(--color-muted)]">Kind mix</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="UPI methods" value={formatNumber(upi)} hint={`${upiPct}% of registry`} />
          <Card label="Bank methods" value={formatNumber(bank)} hint={`${bankPct}% of registry`} />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-[var(--color-muted)]">Verification health</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <Card label="Verified" value={formatNumber(verified)} tone="ok" hint={`${verifiedPct}% of registry`} />
          <Card label="Unverified" value={formatNumber(r?.unverified_methods ?? 0)} tone="warn" hint="Pending first successful payout" />
          <Card label="Invalid" value={formatNumber(invalid)} tone={invalid > 0 ? "danger" : "muted"} hint={`${invalidPct}% rejected by RazorpayX`} />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-[var(--color-muted)]">Recent activity</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <Card label="Added 7d" value={formatNumber(r?.added_7d ?? 0)} />
          <Card label="Added 30d" value={formatNumber(r?.added_30d ?? 0)} />
          <Card label="Updated 7d" value={formatNumber(r?.updated_7d ?? 0)} hint="Includes verification status flips" />
        </div>
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>Why this surface.</strong> Distinct from <a href="/payouts" className="underline">/payouts</a> (ledger of release-due payments)
        and <a href="/engineer-payout-history" className="underline">/engineer-payout-history</a> (admin events). This is the registry
        of destinations themselves — UPI VPA or bank IFSC+account per engineer. Verified methods come from a successful first
        RazorpayX payout; invalid methods block all future payouts for that engineer. Pair with <a href="/payout-method-coverage" className="underline">/payout-method-coverage</a> for
        the earning-engineer-side view.
      </section>
    </div>
  );
}
