import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder vendor contract vault — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_contracts: number;
  active_count: number;
  expiring_60d_count: number;
  expiring_30d_count: number;
  expired_count: number;
  renewed_count: number;
  terminated_count: number;
  total_active_value_rupees: number;
  monthly_burn_estimate_rupees: number;
  top_kind: string | null;
  top_kind_count: number;
  oldest_active_age_days: number | null;
  newest_active_age_days: number | null;
  renewal_due_count: number;
};

type ContractRow = {
  id: string;
  vendor_company_name: string;
  vendor_kind: string | null;
  contract_label: string;
  contract_value_rupees: number | null;
  contract_kind: string | null;
  payment_terms_days: number | null;
  status: string;
  signed_at: string | null;
  effective_at: string | null;
  expires_at: string | null;
  days_until_expiry: number | null;
  renewal_reminder_days: number | null;
  storage_uri: string | null;
  notes: string | null;
  age_days: number;
  created_at: string;
};

type RenewalRow = {
  id: string;
  vendor_company_name: string;
  vendor_kind: string | null;
  contract_label: string;
  contract_kind: string | null;
  contract_value_rupees: number | null;
  expires_at: string | null;
  days_until_expiry: number | null;
  status: string;
  renewal_reminder_days: number | null;
};

function Card({ label, value, tone, sub }: { label: string; value: string | number; tone?: string; sub?: string }) {
  return (
    <div className={`rounded-lg border ${tone ?? "border-[var(--color-border)]"} bg-[var(--color-surface)] p-4`}>
      <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-2xl font-bold tabular-nums">{value}</div>
      {sub ? <div className="mt-1 text-[10px] text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

const STATUS_TONE: Record<string, string> = {
  draft:      "text-[var(--color-muted)]",
  active:     "text-[var(--color-ok)]",
  expiring:   "text-[var(--color-warn)]",
  expired:    "text-[var(--color-danger)]",
  renewed:    "text-[var(--color-info)]",
  terminated: "text-[var(--color-danger)]",
};

const STATUS_FILTERS = ["draft","active","expiring","expired","renewed","terminated"] as const;

function expiryTone(days: number | null): string {
  if (days == null) return "text-[var(--color-muted)]";
  if (days < 0)  return "text-[var(--color-danger)]";
  if (days <= 30) return "text-[var(--color-danger)]";
  if (days <= 60) return "text-[var(--color-warn)]";
  return "text-[var(--color-ok)]";
}

export default async function FounderVendorContractVaultPage({
  searchParams,
}: {
  searchParams?: Promise<{ status?: string }>;
}) {
  await requireFounder();
  const sp = (await searchParams) ?? {};
  const statusParam =
    sp.status && (STATUS_FILTERS as readonly string[]).includes(sp.status) ? sp.status : null;

  const supabase = await getSupabaseServerClient();
  const [summaryRes, recentRes, renewalRes] = await Promise.all([
    supabase.rpc("founder_vendor_contract_vault_summary"),
    supabase.rpc("founder_vendor_contracts_recent", { p_status: statusParam, p_limit: 100 }),
    supabase.rpc("founder_vendor_contracts_renewal_due", { p_window_days: 60 }),
  ]);
  if (summaryRes.error) throw new Error(`founder_vendor_contract_vault_summary: ${summaryRes.error.message}`);
  if (recentRes.error)  throw new Error(`founder_vendor_contracts_recent: ${recentRes.error.message}`);
  if (renewalRes.error) throw new Error(`founder_vendor_contracts_renewal_due: ${renewalRes.error.message}`);

  const s = ((summaryRes.data ?? [])[0] ?? {}) as SummaryRow;
  const rows = (recentRes.data ?? []) as ContractRow[];
  const renewalDue = (renewalRes.data ?? []) as RenewalRow[];

  const hasRenewalAlerts = renewalDue.length > 0;

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder vendor contract vault · r1369</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Supplier contracts + renewal alerts. Every MSA · SOW · monthly subscription · annual bond ·
          one-time PO ships through here with signed-at · effective-at · expires-at · renewal reminder
          window · storage URI. Founder-only. STABLE SECURITY DEFINER plpgsql.
        </p>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Pair with{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-compliance-document-vault">/founder-compliance-document-vault</a>{" "}
          (regulatory docs) ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-action-items-cockpit">/founder-action-items-cockpit</a>{" "}
          (renewal followups) ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-decision-log">/founder-decision-log</a>{" "}
          (terminate / migrate calls) ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-partnerships-tracker">/founder-partnerships-tracker</a>{" "}
          (vendor relationships).
        </p>
      </header>

      {hasRenewalAlerts ? (
        <section className="rounded-lg border border-[var(--color-danger)] bg-[var(--color-surface)] p-4">
          <div className="text-xs uppercase tracking-wider text-[var(--color-danger)] font-semibold mb-2">
            Renewal-due within 60 days · {renewalDue.length} contract{renewalDue.length === 1 ? "" : "s"}
          </div>
          <div className="space-y-2">
            {renewalDue.map((r) => (
              <div key={r.id} className="flex flex-wrap items-center gap-3 text-xs border-b border-[var(--color-border)] pb-2">
                <span className="font-mono font-semibold">{r.contract_label}</span>
                <span className="text-[var(--color-muted)]">{r.vendor_company_name}</span>
                <span className="text-[var(--color-muted)]">{r.vendor_kind ?? "—"}</span>
                <span className="text-[var(--color-muted)]">{r.contract_kind ?? "—"}</span>
                <span className={`font-semibold ${expiryTone(r.days_until_expiry)}`}>
                  {r.days_until_expiry == null
                    ? "—"
                    : r.days_until_expiry < 0
                    ? `OVERDUE by ${Math.abs(r.days_until_expiry)}d`
                    : `expires in ${r.days_until_expiry}d`}
                </span>
                <span className="text-[var(--color-muted)]">expires {r.expires_at ?? "—"}</span>
                <span className="text-[var(--color-muted)] tabular-nums">
                  ₹{formatNumber(r.contract_value_rupees ?? 0)}
                </span>
              </div>
            ))}
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Vault totals · status mix</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-7">
          <Card label="Total contracts" value={formatNumber(s.total_contracts ?? 0)} tone="border-[var(--color-accent)]" />
          <Card label="Active"     value={formatNumber(s.active_count ?? 0)}     tone="border-[var(--color-ok)]" />
          <Card label="Expiring 60d" value={formatNumber(s.expiring_60d_count ?? 0)} sub="next 60d window" tone={(s.expiring_60d_count ?? 0) > 0 ? "border-[var(--color-warn)]" : undefined} />
          <Card label="Expiring 30d" value={formatNumber(s.expiring_30d_count ?? 0)} sub="next month" tone={(s.expiring_30d_count ?? 0) > 0 ? "border-[var(--color-danger)]" : undefined} />
          <Card label="Expired"    value={formatNumber(s.expired_count ?? 0)}    tone={(s.expired_count ?? 0) > 0 ? "border-[var(--color-danger)]" : undefined} />
          <Card label="Renewed"    value={formatNumber(s.renewed_count ?? 0)}    tone="border-[var(--color-info)]" />
          <Card label="Terminated" value={formatNumber(s.terminated_count ?? 0)} tone={(s.terminated_count ?? 0) > 0 ? "border-[var(--color-danger)]" : undefined} />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Cash exposure · burn · concentration</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-7">
          <Card label="Active value" value={`₹${formatNumber(s.total_active_value_rupees ?? 0)}`} sub="all active commitments" tone="border-[var(--color-accent)]" />
          <Card label="Monthly burn" value={`₹${formatNumber(Math.round(s.monthly_burn_estimate_rupees ?? 0))}`} sub="recurring · normalized" />
          <Card label="Top kind" value={s.top_kind ?? "—"} sub={`${formatNumber(s.top_kind_count ?? 0)} contracts`} />
          <Card label="Oldest active" value={s.oldest_active_age_days != null ? `${s.oldest_active_age_days}d` : "—"} sub="age since registered" />
          <Card label="Newest active" value={s.newest_active_age_days != null ? `${s.newest_active_age_days}d` : "—"} sub="latest sign date" />
          <Card label="Renewal due"  value={formatNumber(s.renewal_due_count ?? 0)} sub="within reminder window" tone={(s.renewal_due_count ?? 0) > 0 ? "border-[var(--color-warn)]" : undefined} />
          <Card label="Annualized burn" value={`₹${formatNumber(Math.round((s.monthly_burn_estimate_rupees ?? 0) * 12))}`} sub="12 · monthly est" />
        </div>
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)] mb-2">Status filter</div>
        <div className="flex flex-wrap items-center gap-2 text-xs">
          <a
            href="/founder-vendor-contract-vault"
            className={`rounded border px-3 py-1 ${
              statusParam == null
                ? "border-[var(--color-accent)] text-[var(--color-accent)]"
                : "border-[var(--color-border)] text-[var(--color-muted)] hover:text-[var(--color-accent)]"
            }`}
          >
            all
          </a>
          {STATUS_FILTERS.map((st) => (
            <a
              key={st}
              href={`/founder-vendor-contract-vault?status=${st}`}
              className={`rounded border px-3 py-1 ${
                statusParam === st
                  ? "border-[var(--color-accent)] text-[var(--color-accent)]"
                  : "border-[var(--color-border)] text-[var(--color-muted)] hover:text-[var(--color-accent)]"
              }`}
            >
              {st}
            </a>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">
          Contract ledger {statusParam ? `· status=${statusParam}` : ""} (top 100, newest first)
        </h2>
        {rows.length === 0 ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 text-center text-sm">
            <span className="text-[var(--color-muted)]">No contracts match this filter.</span>
            <div className="mt-2 text-xs text-[var(--color-muted)]">
              Register with{" "}
              <code className="font-mono">
                log_founder_vendor_contract_register(p_vendor_company_name, p_contract_label, ...)
              </code>
              .
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="py-2 pr-3">Label</th>
                  <th className="py-2 pr-3">Vendor</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Contract</th>
                  <th className="py-2 pr-3">Status</th>
                  <th className="py-2 pr-3 tabular-nums">Value</th>
                  <th className="py-2 pr-3 tabular-nums">Terms</th>
                  <th className="py-2 pr-3 tabular-nums">Signed</th>
                  <th className="py-2 pr-3 tabular-nums">Effective</th>
                  <th className="py-2 pr-3 tabular-nums">Expires</th>
                  <th className="py-2 pr-3 tabular-nums">Days</th>
                  <th className="py-2 pr-3 tabular-nums">Age</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 font-mono text-xs">{r.contract_label}</td>
                    <td className="py-2 pr-3">{r.vendor_company_name}</td>
                    <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">{r.vendor_kind ?? "—"}</td>
                    <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">{r.contract_kind ?? "—"}</td>
                    <td className={`py-2 pr-3 font-semibold ${STATUS_TONE[r.status] ?? "text-[var(--color-muted)]"}`}>{r.status}</td>
                    <td className="py-2 pr-3 tabular-nums">{r.contract_value_rupees != null ? `₹${formatNumber(r.contract_value_rupees)}` : "—"}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{r.payment_terms_days != null ? `${r.payment_terms_days}d` : "—"}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{r.signed_at ?? "—"}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{r.effective_at ?? "—"}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{r.expires_at ?? "—"}</td>
                    <td className={`py-2 pr-3 tabular-nums text-xs font-semibold ${expiryTone(r.days_until_expiry)}`}>
                      {r.days_until_expiry == null
                        ? "—"
                        : r.days_until_expiry < 0
                        ? `-${Math.abs(r.days_until_expiry)}`
                        : `${r.days_until_expiry}`}
                    </td>
                    <td className="py-2 pr-3 tabular-nums text-xs text-[var(--color-muted)]">{r.age_days}d</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)] font-semibold">Renewal discipline</div>
        <p>
          Every active contract carries a renewal_reminder_days window (default 60). Founder sweep:
          weekly check this page; any contract inside the window gets a written decision in
          /founder-decision-log before expiry — renew, terminate, migrate-supplier, or let-lapse.
          No silent expiries · no auto-renewals without sign-off.
        </p>
        <p>
          Days column rules: green {">"} 60d · amber 31-60d · red ≤ 30d · red OVERDUE if expires_at {"<"} today.
          Monthly burn = sum(monthly contracts) + sum(annual/12) + sum(bond/12); excludes one-time + msa + sow.
          Expiring status auto-set by founder when nearing window — manual signal, not cron-flipped.
        </p>
        <p>
          Storage URI policy: drive_link or S3 only · never plain attachments · every contract scanned
          PDF lives at a stable URL the founder controls. Vendor termination → set status=terminated
          + log decision in /founder-decision-log + close any open action items.
        </p>
      </section>
    </div>
  );
}
