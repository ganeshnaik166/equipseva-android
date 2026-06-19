import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";
import { registerHospitalChain } from "./actions";

export const metadata = { title: "Hospital Chains Bulk Import — EquipSeva Founder" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_chains: number;
  prospecting_count: number;
  negotiating_count: number;
  signed_count: number;
  onboarding_count: number;
  live_count: number;
  churned_count: number;
  total_hospitals_onboarded: number;
  target_hospitals: number;
  mrr_from_chains_rupees: number;
  acquisition_velocity_hospitals_per_week: number;
};

type ChainRow = {
  id: string;
  chain_name: string;
  status: string;
  default_amc_tier: string | null;
  default_monthly_fee_rupees: number | null;
  total_hospitals_target: number;
  hospitals_onboarded_count: number;
  mrr_contribution_rupees: number;
  signer_name: string | null;
  signer_email: string | null;
  created_at: string;
};

export default async function HospitalChainsBulkImportPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, recentRes] = await Promise.all([
    supabase.rpc("founder_hospital_chains_summary"),
    supabase.rpc("founder_hospital_chains_recent", { p_limit: 50 }),
  ]);

  const summary: SummaryRow | null =
    Array.isArray(summaryRes.data) && summaryRes.data.length > 0
      ? (summaryRes.data[0] as SummaryRow)
      : null;
  const chains: ChainRow[] = (recentRes.data as ChainRow[] | null) ?? [];

  const onboardProgress =
    summary && summary.target_hospitals > 0
      ? Math.round((summary.total_hospitals_onboarded / summary.target_hospitals) * 100)
      : 0;

  return (
    <main className="mx-auto max-w-7xl space-y-6 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Chains — Bulk Import</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Register multi-hospital chains as single sales units, then bulk-onboard member hospitals
          with AMC affidavit drafts pre-populated from the chain defaults.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-5">
        <Card label="Total chains" value={formatNumber(summary?.total_chains ?? 0)} />
        <Card
          label="Prospecting"
          value={formatNumber(summary?.prospecting_count ?? 0)}
          tone="info"
        />
        <Card
          label="Negotiating"
          value={formatNumber(summary?.negotiating_count ?? 0)}
          tone="warn"
        />
        <Card label="Signed" value={formatNumber(summary?.signed_count ?? 0)} tone="accent" />
        <Card
          label="Onboarding"
          value={formatNumber(summary?.onboarding_count ?? 0)}
          tone="accent"
        />
        <Card label="Live" value={formatNumber(summary?.live_count ?? 0)} tone="ok" />
        <Card label="Churned" value={formatNumber(summary?.churned_count ?? 0)} tone="danger" />
        <Card
          label="Hospitals onboarded"
          value={`${formatNumber(summary?.total_hospitals_onboarded ?? 0)} / ${formatNumber(
            summary?.target_hospitals ?? 0,
          )}`}
          sub={`${onboardProgress}% of target`}
        />
        <Card
          label="MRR from chains"
          value={`₹${formatNumber(Math.round(summary?.mrr_from_chains_rupees ?? 0))}`}
          tone="ok"
        />
        <Card
          label="Acquisition velocity"
          value={`${(summary?.acquisition_velocity_hospitals_per_week ?? 0).toFixed(2)} / wk`}
          sub="last 90d"
        />
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
        <h2 className="mb-3 text-lg font-semibold">Register new chain</h2>
        <form action={registerHospitalChain} className="grid grid-cols-1 gap-3 md:grid-cols-2">
          <Field name="chain_name" label="Chain name" required placeholder="Apollo Hospitals" />
          <Field name="signer_name" label="Signer name" placeholder="Dr. P. Reddy" />
          <Field
            name="signer_email"
            label="Signer email"
            type="email"
            placeholder="legal@apollo.com"
          />
          <Field name="signer_phone" label="Signer phone" placeholder="+91 98xxxxxxxx" />
          <div className="flex flex-col gap-1">
            <label className="text-xs text-[var(--color-muted)]">Default AMC tier</label>
            <select
              name="amc_tier"
              className="rounded border border-[var(--color-border)] bg-[var(--color-bg)] px-3 py-2 text-sm"
              defaultValue=""
            >
              <option value="">— select —</option>
              <option value="starter">Starter</option>
              <option value="growth">Growth</option>
              <option value="enterprise">Enterprise</option>
            </select>
          </div>
          <Field
            name="monthly_fee_rupees"
            label="Default monthly fee (₹)"
            type="number"
            placeholder="25000"
          />
          <Field
            name="target_hospitals"
            label="Target hospitals"
            type="number"
            placeholder="12"
          />
          <div className="md:col-span-2">
            <button
              type="submit"
              className="rounded bg-[var(--color-accent)] px-4 py-2 text-sm font-medium text-white hover:opacity-90"
            >
              Register chain
            </button>
          </div>
        </form>
        <p className="mt-3 text-xs text-[var(--color-muted)]">
          Per-hospital import currently requires individual org_id; bulk-CSV provisioning ships in
          next round.
        </p>
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
        <div className="mb-3 flex items-baseline justify-between">
          <h2 className="text-lg font-semibold">Recent chains</h2>
          <span className="text-xs text-[var(--color-muted)]">{chains.length} shown</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="text-left text-xs text-[var(--color-muted)]">
              <tr>
                <th className="py-2 pr-3">Chain</th>
                <th className="py-2 pr-3">Status</th>
                <th className="py-2 pr-3">Tier</th>
                <th className="py-2 pr-3">Target</th>
                <th className="py-2 pr-3">Onboarded</th>
                <th className="py-2 pr-3">Progress</th>
                <th className="py-2 pr-3">MRR contribution</th>
                <th className="py-2 pr-3">Signer</th>
              </tr>
            </thead>
            <tbody>
              {chains.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-6 text-center text-[var(--color-muted)]">
                    No chains registered yet — use the form above to add the first one.
                  </td>
                </tr>
              ) : (
                chains.map((c) => {
                  const pct =
                    c.total_hospitals_target > 0
                      ? Math.round(
                          (c.hospitals_onboarded_count / c.total_hospitals_target) * 100,
                        )
                      : 0;
                  return (
                    <tr key={c.id} className="border-t border-[var(--color-border)]">
                      <td className="py-2 pr-3 font-medium">{c.chain_name}</td>
                      <td className="py-2 pr-3">
                        <StatusBadge status={c.status} />
                      </td>
                      <td className="py-2 pr-3 text-[var(--color-muted)]">
                        {c.default_amc_tier ?? "—"}
                      </td>
                      <td className="py-2 pr-3">{formatNumber(c.total_hospitals_target)}</td>
                      <td className="py-2 pr-3">{formatNumber(c.hospitals_onboarded_count)}</td>
                      <td className="py-2 pr-3 text-[var(--color-muted)]">{pct}%</td>
                      <td className="py-2 pr-3">
                        ₹{formatNumber(Math.round(c.mrr_contribution_rupees ?? 0))}
                      </td>
                      <td className="py-2 pr-3 text-[var(--color-muted)]">
                        {c.signer_name ?? c.signer_email ?? "—"}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}

function Card({
  label,
  value,
  sub,
  tone,
}: {
  label: string;
  value: string;
  sub?: string;
  tone?: "ok" | "warn" | "danger" | "info" | "accent";
}) {
  const toneClass =
    tone === "ok"
      ? "text-[var(--color-ok)]"
      : tone === "warn"
        ? "text-[var(--color-warn)]"
        : tone === "danger"
          ? "text-[var(--color-danger)]"
          : tone === "info"
            ? "text-[var(--color-info)]"
            : tone === "accent"
              ? "text-[var(--color-accent)]"
              : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-xl font-semibold ${toneClass}`}>{value}</div>
      {sub ? <div className="mt-1 text-xs text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function Field({
  name,
  label,
  type = "text",
  placeholder,
  required,
}: {
  name: string;
  label: string;
  type?: string;
  placeholder?: string;
  required?: boolean;
}) {
  return (
    <div className="flex flex-col gap-1">
      <label className="text-xs text-[var(--color-muted)]" htmlFor={name}>
        {label}
        {required ? " *" : ""}
      </label>
      <input
        id={name}
        name={name}
        type={type}
        required={required}
        placeholder={placeholder}
        className="rounded border border-[var(--color-border)] bg-[var(--color-bg)] px-3 py-2 text-sm"
      />
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const tone =
    status === "live"
      ? "text-[var(--color-ok)]"
      : status === "churned"
        ? "text-[var(--color-danger)]"
        : status === "negotiating"
          ? "text-[var(--color-warn)]"
          : status === "signed" || status === "onboarding"
            ? "text-[var(--color-accent)]"
            : "text-[var(--color-info)]";
  return <span className={`text-xs font-medium ${tone}`}>{status}</span>;
}

