import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder compliance audit vault — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_events: number;
  events_24h: number;
  events_7d: number;
  events_30d: number;
  critical_count: number;
  high_count: number;
  medium_count: number;
  by_kind_founder_action: number;
  by_kind_payment_anomaly: number;
  by_kind_suspicious_login: number;
  by_kind_integrity_violation: number;
  total_violations: number;
  open_violations: number;
  resolved_violations: number;
  false_positive_violations: number;
  oldest_open_violation_age_days: number | null;
};

type EventRow = {
  id: string;
  event_kind: string;
  severity: string;
  source_table: string | null;
  source_record_id: string | null;
  performed_by: string | null;
  ip_hash: string | null;
  user_agent_hash: string | null;
  notes: string | null;
  occurred_at: string;
  age_seconds: number;
};

type ViolationRow = {
  id: string;
  audit_event_id: string;
  violation_kind: string;
  status: string;
  assigned_to: string | null;
  resolved_at: string | null;
  resolution_note: string | null;
  created_at: string;
  age_days: number;
  event_kind: string | null;
  event_severity: string | null;
  event_notes: string | null;
  event_occurred_at: string | null;
};

type OpenViolationRow = {
  id: string;
  audit_event_id: string;
  violation_kind: string;
  status: string;
  created_at: string;
  age_days: number;
  event_kind: string | null;
  event_severity: string | null;
  event_notes: string | null;
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

const SEVERITY_TONE: Record<string, string> = {
  critical: "text-[var(--color-danger)]",
  high:     "text-[var(--color-danger)]",
  medium:   "text-[var(--color-warn)]",
  low:      "text-[var(--color-info)]",
  info:     "text-[var(--color-muted)]",
};

const STATUS_TONE: Record<string, string> = {
  detected:       "text-[var(--color-danger)]",
  investigating:  "text-[var(--color-warn)]",
  contained:      "text-[var(--color-info)]",
  resolved:       "text-[var(--color-ok)]",
  false_positive: "text-[var(--color-muted)]",
};

const KIND_FILTERS = [
  "founder_action","engineer_status_change","hospital_data_export",
  "payment_anomaly","suspicious_login","rls_policy_change",
  "schema_migration","data_export","privacy_request","integrity_violation",
] as const;

const SEVERITY_FILTERS = ["info","low","medium","high","critical"] as const;

function fmtAge(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`;
  return `${Math.floor(seconds / 86400)}d`;
}

export default async function FounderComplianceAuditVaultPage({
  searchParams,
}: {
  searchParams?: Promise<{ kind?: string; severity?: string }>;
}) {
  await requireFounder();
  const sp = (await searchParams) ?? {};
  const kindParam =
    sp.kind && (KIND_FILTERS as readonly string[]).includes(sp.kind) ? sp.kind : null;
  const severityParam =
    sp.severity && (SEVERITY_FILTERS as readonly string[]).includes(sp.severity) ? sp.severity : null;

  const supabase = await getSupabaseServerClient();
  const [summaryRes, eventsRes, violationsRes, openRes] = await Promise.all([
    supabase.rpc("founder_compliance_audit_vault_summary"),
    supabase.rpc("founder_compliance_audit_events_recent", {
      p_kind: kindParam, p_severity: severityParam, p_limit: 100,
    }),
    supabase.rpc("founder_compliance_integrity_violations_recent", {
      p_status: null, p_limit: 100,
    }),
    supabase.rpc("founder_compliance_open_violations"),
  ]);
  if (summaryRes.error)    throw new Error(`founder_compliance_audit_vault_summary: ${summaryRes.error.message}`);
  if (eventsRes.error)     throw new Error(`founder_compliance_audit_events_recent: ${eventsRes.error.message}`);
  if (violationsRes.error) throw new Error(`founder_compliance_integrity_violations_recent: ${violationsRes.error.message}`);
  if (openRes.error)       throw new Error(`founder_compliance_open_violations: ${openRes.error.message}`);

  const s = ((summaryRes.data ?? [])[0] ?? {}) as SummaryRow;
  const events = (eventsRes.data ?? []) as EventRow[];
  const violations = (violationsRes.data ?? []) as ViolationRow[];
  const openViolations = (openRes.data ?? []) as OpenViolationRow[];

  const hasOpenViolations = openViolations.length > 0;
  const hasCritical = (s.critical_count ?? 0) > 0;

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder compliance audit vault · r1423</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Combined audit trail + activity log + integrity ledger. Every founder action ·
          engineer status change · hospital data export · payment anomaly · suspicious login ·
          RLS policy change · schema migration · privacy request flows through one append-only
          ledger. Integrity violations are tracked separately with status lifecycle.
          Founder-only. STABLE SECURITY DEFINER plpgsql throughout.
        </p>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Pair with{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-compliance-document-vault">/founder-compliance-document-vault</a>{" "}
          (regulatory docs) ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-decision-log">/founder-decision-log</a>{" "}
          (founder calls) ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-incidents">/founder-incidents</a>{" "}
          (live incidents).
        </p>
      </header>

      {hasOpenViolations ? (
        <section className="rounded-lg border border-[var(--color-danger)] bg-[var(--color-surface)] p-4">
          <div className="text-xs uppercase tracking-wider text-[var(--color-danger)] font-semibold mb-2">
            Open integrity violations · {openViolations.length}
          </div>
          <div className="space-y-2">
            {openViolations.map((v) => (
              <div key={v.id} className="flex flex-wrap items-center gap-3 text-xs border-b border-[var(--color-border)] pb-2">
                <span className="font-mono font-semibold">{v.violation_kind}</span>
                <span className={`uppercase tracking-wider font-semibold ${STATUS_TONE[v.status] ?? "text-[var(--color-muted)]"}`}>
                  {v.status}
                </span>
                <span className={`font-semibold uppercase tracking-wider ${SEVERITY_TONE[v.event_severity ?? "info"] ?? "text-[var(--color-muted)]"}`}>
                  {v.event_severity ?? "info"}
                </span>
                <span className="text-[var(--color-muted)] font-mono">{v.event_kind ?? "—"}</span>
                <span className="text-[var(--color-muted)]">age {v.age_days}d</span>
                {v.event_notes ? <span className="text-[var(--color-muted)] truncate max-w-[42ch]">{v.event_notes}</span> : null}
              </div>
            ))}
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Event volume · severity</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          <Card label="Total events" value={formatNumber(s.total_events ?? 0)} tone="border-[var(--color-accent)]" />
          <Card label="Events 24h" value={formatNumber(s.events_24h ?? 0)} sub="last day" />
          <Card label="Events 7d"  value={formatNumber(s.events_7d ?? 0)}  sub="last week" />
          <Card label="Events 30d" value={formatNumber(s.events_30d ?? 0)} sub="last month" />
          <Card
            label="Critical"
            value={formatNumber(s.critical_count ?? 0)}
            tone={hasCritical ? "border-[var(--color-danger)]" : undefined}
            sub="lifetime"
          />
          <Card label="High"   value={formatNumber(s.high_count ?? 0)}   sub="lifetime" tone={s.high_count > 0 ? "border-[var(--color-danger)]" : undefined} />
          <Card label="Medium" value={formatNumber(s.medium_count ?? 0)} sub="lifetime" tone={s.medium_count > 0 ? "border-[var(--color-warn)]" : undefined} />
          <Card
            label="Oldest open"
            value={s.oldest_open_violation_age_days != null ? `${s.oldest_open_violation_age_days}d` : "—"}
            sub="violation age"
            tone={(s.oldest_open_violation_age_days ?? 0) > 7 ? "border-[var(--color-danger)]" : undefined}
          />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Event-kind mix · violation ledger</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          <Card label="Founder action"      value={formatNumber(s.by_kind_founder_action ?? 0)}      sub="logged calls" />
          <Card label="Payment anomaly"     value={formatNumber(s.by_kind_payment_anomaly ?? 0)}     sub="$ red-flags" tone={s.by_kind_payment_anomaly > 0 ? "border-[var(--color-warn)]" : undefined} />
          <Card label="Suspicious login"    value={formatNumber(s.by_kind_suspicious_login ?? 0)}    sub="auth alerts" tone={s.by_kind_suspicious_login > 0 ? "border-[var(--color-warn)]" : undefined} />
          <Card label="Integrity violation" value={formatNumber(s.by_kind_integrity_violation ?? 0)} sub="flagged" />
          <Card label="Total violations"    value={formatNumber(s.total_violations ?? 0)}            tone="border-[var(--color-accent)]" />
          <Card label="Open violations"     value={formatNumber(s.open_violations ?? 0)}             tone={hasOpenViolations ? "border-[var(--color-danger)]" : "border-[var(--color-ok)]"} sub="needs action" />
          <Card label="Resolved"            value={formatNumber(s.resolved_violations ?? 0)}         tone="border-[var(--color-ok)]" sub="closed clean" />
          <Card label="False positive"      value={formatNumber(s.false_positive_violations ?? 0)}   sub="dismissed" />
        </div>
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)] mb-2">Event-kind filter</div>
        <div className="flex flex-wrap items-center gap-2 text-xs mb-3">
          <a
            href={severityParam ? `/founder-compliance-audit-vault?severity=${severityParam}` : "/founder-compliance-audit-vault"}
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
              href={`/founder-compliance-audit-vault?kind=${k}${severityParam ? `&severity=${severityParam}` : ""}`}
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
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)] mb-2">Severity filter</div>
        <div className="flex flex-wrap items-center gap-2 text-xs">
          <a
            href={kindParam ? `/founder-compliance-audit-vault?kind=${kindParam}` : "/founder-compliance-audit-vault"}
            className={`rounded border px-3 py-1 ${
              severityParam == null
                ? "border-[var(--color-accent)] text-[var(--color-accent)]"
                : "border-[var(--color-border)] text-[var(--color-muted)] hover:text-[var(--color-accent)]"
            }`}
          >
            all
          </a>
          {SEVERITY_FILTERS.map((sv) => (
            <a
              key={sv}
              href={`/founder-compliance-audit-vault?severity=${sv}${kindParam ? `&kind=${kindParam}` : ""}`}
              className={`rounded border px-3 py-1 ${
                severityParam === sv
                  ? "border-[var(--color-accent)] text-[var(--color-accent)]"
                  : "border-[var(--color-border)] text-[var(--color-muted)] hover:text-[var(--color-accent)]"
              }`}
            >
              {sv}
            </a>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">
          Audit events feed {kindParam ? `· kind=${kindParam}` : ""}{severityParam ? ` · severity=${severityParam}` : ""} (top 100, newest first)
        </h2>
        {events.length === 0 ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 text-center text-sm">
            <span className="text-[var(--color-muted)]">No audit events match this filter.</span>
            <div className="mt-2 text-xs text-[var(--color-muted)]">
              Record with{" "}
              <code className="font-mono">
                log_founder_audit_record_event(p_event_kind, p_severity, ...)
              </code>
              .
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Severity</th>
                  <th className="py-2 pr-3">Source table</th>
                  <th className="py-2 pr-3">Source id</th>
                  <th className="py-2 pr-3">IP hash</th>
                  <th className="py-2 pr-3">UA hash</th>
                  <th className="py-2 pr-3">Notes</th>
                  <th className="py-2 pr-3 tabular-nums">Occurred</th>
                  <th className="py-2 pr-3 tabular-nums">Age</th>
                </tr>
              </thead>
              <tbody>
                {events.map((e) => (
                  <tr key={e.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 font-mono text-xs">{e.event_kind}</td>
                    <td className={`py-2 pr-3 text-xs uppercase tracking-wider font-semibold ${SEVERITY_TONE[e.severity] ?? "text-[var(--color-muted)]"}`}>
                      {e.severity}
                    </td>
                    <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{e.source_table ?? "—"}</td>
                    <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)] truncate max-w-[12ch]" title={e.source_record_id ?? ""}>
                      {e.source_record_id ? e.source_record_id.slice(0, 8) : "—"}
                    </td>
                    <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)] truncate max-w-[10ch]" title={e.ip_hash ?? ""}>
                      {e.ip_hash ? e.ip_hash.slice(0, 8) : "—"}
                    </td>
                    <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)] truncate max-w-[10ch]" title={e.user_agent_hash ?? ""}>
                      {e.user_agent_hash ? e.user_agent_hash.slice(0, 8) : "—"}
                    </td>
                    <td className="py-2 pr-3 text-xs truncate max-w-[32ch]" title={e.notes ?? ""}>{e.notes ?? "—"}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{e.occurred_at.slice(0, 19).replace("T", " ")}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs text-[var(--color-muted)]">{fmtAge(e.age_seconds)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">
          Integrity violations ledger (top 100, newest first)
        </h2>
        {violations.length === 0 ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 text-center text-sm">
            <span className="text-[var(--color-muted)]">No integrity violations recorded. Clean ledger.</span>
            <div className="mt-2 text-xs text-[var(--color-muted)]">
              Flag with{" "}
              <code className="font-mono">
                log_founder_audit_record_violation(p_audit_event_id, p_violation_kind, ...)
              </code>
              .
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="py-2 pr-3">Violation kind</th>
                  <th className="py-2 pr-3">Status</th>
                  <th className="py-2 pr-3">Event kind</th>
                  <th className="py-2 pr-3">Event severity</th>
                  <th className="py-2 pr-3">Event notes</th>
                  <th className="py-2 pr-3">Resolution</th>
                  <th className="py-2 pr-3 tabular-nums">Created</th>
                  <th className="py-2 pr-3 tabular-nums">Age</th>
                  <th className="py-2 pr-3 tabular-nums">Resolved</th>
                </tr>
              </thead>
              <tbody>
                {violations.map((v) => (
                  <tr key={v.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 font-mono text-xs">{v.violation_kind}</td>
                    <td className={`py-2 pr-3 text-xs uppercase tracking-wider font-semibold ${STATUS_TONE[v.status] ?? "text-[var(--color-muted)]"}`}>
                      {v.status}
                    </td>
                    <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{v.event_kind ?? "—"}</td>
                    <td className={`py-2 pr-3 text-xs uppercase tracking-wider font-semibold ${SEVERITY_TONE[v.event_severity ?? "info"] ?? "text-[var(--color-muted)]"}`}>
                      {v.event_severity ?? "—"}
                    </td>
                    <td className="py-2 pr-3 text-xs truncate max-w-[28ch]" title={v.event_notes ?? ""}>{v.event_notes ?? "—"}</td>
                    <td className="py-2 pr-3 text-xs truncate max-w-[24ch]" title={v.resolution_note ?? ""}>{v.resolution_note ?? "—"}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{v.created_at.slice(0, 19).replace("T", " ")}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs text-[var(--color-muted)]">{v.age_days}d</td>
                    <td className="py-2 pr-3 tabular-nums text-xs text-[var(--color-muted)]">
                      {v.resolved_at ? v.resolved_at.slice(0, 10) : "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-1">
        <div className="font-semibold text-[var(--color-fg)] uppercase tracking-wider mb-1">Audit discipline</div>
        <div>· Every founder action (RPC call modifying state) MUST emit an audit event with before/after jsonb.</div>
        <div>· IP and user-agent are SHA-256 hashed at the edge — never store raw values (DPDP minimization).</div>
        <div>· Critical-severity events page founder within 5 min via founder_incidents pipeline.</div>
        <div>· Open violations older than 7 days trigger an automatic founder-action-item.</div>
        <div>· Use log_founder_audit_resolve_violation(id, status, note) to close — append-only, status only advances.</div>
        <div>· Ledger is RLS-locked to is_founder() — table grants are SELECT-only to authenticated, all writes via SECDEF RPC.</div>
      </section>
    </div>
  );
}
