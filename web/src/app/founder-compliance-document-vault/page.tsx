import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder compliance document vault — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_docs: number;
  active_count: number;
  expired_count: number;
  renewed_count: number;
  revoked_count: number;
  renewal_due_30d_count: number;
  renewal_due_90d_count: number;
  renewal_overdue_count: number;
  by_kind_udyam: number;
  by_kind_gst: number;
  by_kind_cdsco: number;
  by_kind_nabh: number;
  by_kind_iso: number;
  oldest_active_age_days: number | null;
};

type DocRow = {
  id: string;
  doc_label: string;
  doc_kind: string | null;
  document_number: string | null;
  issued_by: string | null;
  issued_at: string | null;
  valid_until: string | null;
  status: string;
  storage_kind: string | null;
  storage_uri: string | null;
  renewal_due_date: string | null;
  days_until_renewal: number | null;
  age_days: number;
  notes: string | null;
  created_at: string;
};

type RenewalRow = {
  id: string;
  doc_label: string;
  doc_kind: string | null;
  renewal_due_date: string | null;
  days_until_renewal: number | null;
  status: string;
  issued_by: string | null;
  valid_until: string | null;
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
  active:   "text-[var(--color-ok)]",
  expired:  "text-[var(--color-danger)]",
  renewed:  "text-[var(--color-info)]",
  revoked:  "text-[var(--color-danger)]",
  draft:    "text-[var(--color-muted)]",
};

const STATUS_FILTERS = ["active", "expired", "renewed", "revoked", "draft"] as const;
const KIND_FILTERS = [
  "udyam_cert","gst_cert","cdsco_license","nabh_cert","iso_cert",
  "msme_cert","company_pan","board_resolution","founder_id_proof",
  "rbi_clearance","dpdp_consent_template","insurance_policy","other",
] as const;

function renewalTone(days: number | null): string {
  if (days == null) return "text-[var(--color-muted)]";
  if (days < 0)  return "text-[var(--color-danger)]";
  if (days <= 30) return "text-[var(--color-danger)]";
  if (days <= 90) return "text-[var(--color-warn)]";
  return "text-[var(--color-ok)]";
}

export default async function FounderComplianceDocumentVaultPage({
  searchParams,
}: {
  searchParams?: Promise<{ status?: string; kind?: string }>;
}) {
  await requireFounder();
  const sp = (await searchParams) ?? {};
  const statusParam =
    sp.status && (STATUS_FILTERS as readonly string[]).includes(sp.status) ? sp.status : null;
  const kindParam =
    sp.kind && (KIND_FILTERS as readonly string[]).includes(sp.kind) ? sp.kind : null;

  const supabase = await getSupabaseServerClient();
  const [summaryRes, recentRes, renewalRes] = await Promise.all([
    supabase.rpc("founder_compliance_document_vault_summary"),
    supabase.rpc("founder_compliance_documents_recent", {
      p_status: statusParam, p_kind: kindParam, p_limit: 100,
    }),
    supabase.rpc("founder_compliance_documents_renewal_due", { p_window_days: 30 }),
  ]);
  if (summaryRes.error) throw new Error(`founder_compliance_document_vault_summary: ${summaryRes.error.message}`);
  if (recentRes.error)  throw new Error(`founder_compliance_documents_recent: ${recentRes.error.message}`);
  if (renewalRes.error) throw new Error(`founder_compliance_documents_renewal_due: ${renewalRes.error.message}`);

  const s = ((summaryRes.data ?? [])[0] ?? {}) as SummaryRow;
  const rows = (recentRes.data ?? []) as DocRow[];
  const renewalDue = (renewalRes.data ?? []) as RenewalRow[];

  const hasRenewalAlerts = renewalDue.length > 0;
  const hasOverdue = (s.renewal_overdue_count ?? 0) > 0;

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder compliance document vault · r1358</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Regulatory document storage tracker. Every Udyam · GST · CDSCO · NABH · ISO · MSME · PAN ·
          board-res · ID-proof · RBI · DPDP · insurance certificate ships through here with issued-at ·
          valid-until · storage URI · renewal-due date. Founder-only. STABLE SECURITY DEFINER plpgsql.
        </p>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Pair with{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-action-items-cockpit">/founder-action-items-cockpit</a>{" "}
          (renewal followups) ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-decision-log">/founder-decision-log</a>{" "}
          (record revocation calls) ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-runbook">/founder-runbook</a>{" "}
          (renewal SOPs).
        </p>
      </header>

      {hasRenewalAlerts ? (
        <section className="rounded-lg border border-[var(--color-danger)] bg-[var(--color-surface)] p-4">
          <div className="text-xs uppercase tracking-wider text-[var(--color-danger)] font-semibold mb-2">
            Renewal-due within 30 days · {renewalDue.length} document{renewalDue.length === 1 ? "" : "s"}
          </div>
          <div className="space-y-2">
            {renewalDue.map((r) => (
              <div key={r.id} className="flex flex-wrap items-center gap-3 text-xs border-b border-[var(--color-border)] pb-2">
                <span className="font-mono font-semibold">{r.doc_label}</span>
                <span className="text-[var(--color-muted)]">{r.doc_kind ?? "—"}</span>
                <span className={`font-semibold ${renewalTone(r.days_until_renewal)}`}>
                  {r.days_until_renewal == null
                    ? "—"
                    : r.days_until_renewal < 0
                    ? `OVERDUE by ${Math.abs(r.days_until_renewal)}d`
                    : `due in ${r.days_until_renewal}d`}
                </span>
                <span className="text-[var(--color-muted)]">due {r.renewal_due_date ?? "—"}</span>
                <span className="text-[var(--color-muted)]">valid until {r.valid_until ?? "—"}</span>
                <span className="text-[var(--color-muted)]">issued by {r.issued_by ?? "—"}</span>
              </div>
            ))}
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Vault totals · status mix</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-7">
          <Card label="Total docs" value={formatNumber(s.total_docs ?? 0)} tone="border-[var(--color-accent)]" />
          <Card label="Active"   value={formatNumber(s.active_count ?? 0)}   tone="border-[var(--color-ok)]" />
          <Card label="Expired"  value={formatNumber(s.expired_count ?? 0)}  tone={s.expired_count ?? 0 > 0 ? "border-[var(--color-danger)]" : undefined} />
          <Card label="Renewed"  value={formatNumber(s.renewed_count ?? 0)}  tone="border-[var(--color-info)]" />
          <Card label="Revoked"  value={formatNumber(s.revoked_count ?? 0)}  tone={s.revoked_count ?? 0 > 0 ? "border-[var(--color-danger)]" : undefined} />
          <Card
            label="Oldest active"
            value={s.oldest_active_age_days != null ? `${s.oldest_active_age_days}d` : "—"}
            sub="age since registered"
          />
          <Card
            label="Renewal overdue"
            value={formatNumber(s.renewal_overdue_count ?? 0)}
            sub="past due-date"
            tone={hasOverdue ? "border-[var(--color-danger)]" : "border-[var(--color-ok)]"}
          />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Renewal cadence · kind breakdown</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-7">
          <Card
            label="Due 30d"
            value={formatNumber(s.renewal_due_30d_count ?? 0)}
            sub="next month"
            tone={s.renewal_due_30d_count ?? 0 > 0 ? "border-[var(--color-warn)]" : undefined}
          />
          <Card
            label="Due 90d"
            value={formatNumber(s.renewal_due_90d_count ?? 0)}
            sub="next quarter"
            tone={s.renewal_due_90d_count ?? 0 > 0 ? "border-[var(--color-warn)]" : undefined}
          />
          <Card label="Udyam"   value={formatNumber(s.by_kind_udyam ?? 0)}   sub="MSME register" />
          <Card label="GST"     value={formatNumber(s.by_kind_gst ?? 0)}     sub="tax cert" />
          <Card label="CDSCO"   value={formatNumber(s.by_kind_cdsco ?? 0)}   sub="medical-device license" />
          <Card label="NABH"    value={formatNumber(s.by_kind_nabh ?? 0)}    sub="hospital accred" />
          <Card label="ISO"     value={formatNumber(s.by_kind_iso ?? 0)}     sub="quality cert" />
        </div>
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)] mb-2">Status filter</div>
        <div className="flex flex-wrap items-center gap-2 text-xs mb-3">
          <a
            href={kindParam ? `/founder-compliance-document-vault?kind=${kindParam}` : "/founder-compliance-document-vault"}
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
              href={`/founder-compliance-document-vault?status=${st}${kindParam ? `&kind=${kindParam}` : ""}`}
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
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)] mb-2">Kind filter</div>
        <div className="flex flex-wrap items-center gap-2 text-xs">
          <a
            href={statusParam ? `/founder-compliance-document-vault?status=${statusParam}` : "/founder-compliance-document-vault"}
            className={`rounded border px-3 py-1 ${
              kindParam == null
                ? "border-[var(--color-accent)] text-[var(--color-accent)]"
                : "border-[var(--color-border)] text-[var(--color-muted)] hover:text-[var(--color-accent)]"
            }`}
          >
            all
          </a>
          {KIND_FILTERS.map((k) => (
            <a
              key={k}
              href={`/founder-compliance-document-vault?kind=${k}${statusParam ? `&status=${statusParam}` : ""}`}
              className={`rounded border px-3 py-1 ${
                kindParam === k
                  ? "border-[var(--color-accent)] text-[var(--color-accent)]"
                  : "border-[var(--color-border)] text-[var(--color-muted)] hover:text-[var(--color-accent)]"
              }`}
            >
              {k}
            </a>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">
          Document ledger {statusParam ? `· status=${statusParam}` : ""}{kindParam ? ` · kind=${kindParam}` : ""} (top 100, newest first)
        </h2>
        {rows.length === 0 ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 text-center text-sm">
            <span className="text-[var(--color-muted)]">No documents match this filter.</span>
            <div className="mt-2 text-xs text-[var(--color-muted)]">
              Register with{" "}
              <code className="font-mono">
                log_founder_compliance_doc_register(p_doc_label, p_doc_kind, ...)
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
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Status</th>
                  <th className="py-2 pr-3">Doc #</th>
                  <th className="py-2 pr-3">Issued by</th>
                  <th className="py-2 pr-3 tabular-nums">Issued at</th>
                  <th className="py-2 pr-3 tabular-nums">Valid until</th>
                  <th className="py-2 pr-3 tabular-nums">Renewal due</th>
                  <th className="py-2 pr-3 tabular-nums">Days</th>
                  <th className="py-2 pr-3">Storage</th>
                  <th className="py-2 pr-3 tabular-nums">Age</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 font-mono text-xs">{r.doc_label}</td>
                    <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{r.doc_kind ?? "—"}</td>
                    <td className={`py-2 pr-3 text-xs uppercase tracking-wider font-semibold ${STATUS_TONE[r.status] ?? "text-[var(--color-muted)]"}`}>
                      {r.status}
                    </td>
                    <td className="py-2 pr-3 text-xs font-mono">{r.document_number ?? "—"}</td>
                    <td className="py-2 pr-3 text-xs">{r.issued_by ?? "—"}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{r.issued_at ?? "—"}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{r.valid_until ?? "—"}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{r.renewal_due_date ?? "—"}</td>
                    <td className={`py-2 pr-3 tabular-nums text-xs font-semibold ${renewalTone(r.days_until_renewal)}`}>
                      {r.days_until_renewal == null
                        ? "—"
                        : r.days_until_renewal < 0
                        ? `${r.days_until_renewal}`
                        : `+${r.days_until_renewal}`}
                    </td>
                    <td className="py-2 pr-3 text-xs">
                      {r.storage_uri ? (
                        <a className="text-[var(--color-accent)] hover:underline font-mono truncate inline-block max-w-[14ch]" href={r.storage_uri} title={r.storage_uri}>
                          {r.storage_kind ?? "link"}
                        </a>
                      ) : (
                        <span className="text-[var(--color-muted)]">{r.storage_kind ?? "—"}</span>
                      )}
                    </td>
                    <td className="py-2 pr-3 tabular-nums text-xs text-[var(--color-muted)]">{r.age_days}d</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-1">
        <div className="font-semibold text-[var(--color-fg)] uppercase tracking-wider mb-1">Renewal discipline</div>
        <div>· Udyam · GST · CDSCO · NABH · ISO renewals must register {"<"} 30d before valid-until lapses.</div>
        <div>· Renewal-due alert section pings any active doc with renewal_due_date within 30 days.</div>
        <div>· On lapse, status auto-flips to expired (cron-driven) and a founder-action-item is filed.</div>
        <div>· storage_uri MUST be founder-controlled (drive_link · s3 · onedrive); physical_archive needs a folder ref.</div>
        <div>· Use log_founder_compliance_doc_renew(id, new_valid_until) to roll forward in one RPC call.</div>
      </section>
    </div>
  );
}
