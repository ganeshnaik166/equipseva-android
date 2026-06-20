import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Customer case study tracker — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_case_studies: number;
  draft_count: number;
  permission_pending_count: number;
  permission_granted_count: number;
  published_count: number;
  retired_count: number;
  permission_denied_count: number;
  in_pitch_deck_count: number;
  in_website_count: number;
  in_press_count: number;
  total_references: number;
  positive_outcomes: number;
  negative_outcomes: number;
  pending_references: number;
  conversion_rate_pct: number;
};

type CaseStudy = {
  id: string;
  case_study_label: string;
  hospital_user_id: string | null;
  case_study_kind: string;
  status: string;
  permission_granted_at: string | null;
  permission_signed_by: string | null;
  headline: string | null;
  body_md: string | null;
  kpis_snapshot: Record<string, unknown> | null;
  publication_uris: string[] | null;
  use_in_pitch_deck: boolean;
  use_in_website: boolean;
  use_in_press: boolean;
  published_at: string | null;
  retired_at: string | null;
  created_at: string;
  updated_at: string;
};

type Ref = {
  id: string;
  case_study_id: string;
  referrer_contact_name: string | null;
  referrer_contact_email: string | null;
  prospect_name: string | null;
  reference_call_at: string | null;
  outcome: string;
  notes: string | null;
  created_at: string;
};

function Card({ label, value, sub, tone }: { label: string; value: string; sub?: string; tone?: "ok" | "warn" | "danger" }) {
  const t = tone === "ok" ? "text-[var(--color-ok)]" : tone === "warn" ? "text-[var(--color-warn)]" : tone === "danger" ? "text-[var(--color-danger)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${t}`}>{value}</div>
      {sub ? <div className="text-xs text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function statusTone(s: string): "ok" | "warn" | "danger" | undefined {
  if (s === "published" || s === "permission_granted") return "ok";
  if (s === "draft" || s === "permission_pending") return "warn";
  if (s === "permission_denied" || s === "retired") return "danger";
  return undefined;
}

function outcomeTone(o: string): "ok" | "warn" | "danger" | undefined {
  if (o === "positive") return "ok";
  if (o === "pending" || o === "neutral" || o === "no_show") return "warn";
  if (o === "negative" || o === "withdrawn") return "danger";
  return undefined;
}

function StatusPill({ s }: { s: string }) {
  const t = statusTone(s);
  const cls = t === "ok" ? "text-[var(--color-ok)] border-[var(--color-ok)]" : t === "warn" ? "text-[var(--color-warn)] border-[var(--color-warn)]" : t === "danger" ? "text-[var(--color-danger)] border-[var(--color-danger)]" : "text-[var(--color-muted)] border-[var(--color-border)]";
  return <span className={`inline-block rounded-full border px-2 py-0.5 text-xs ${cls}`}>{s}</span>;
}

function OutcomePill({ o }: { o: string }) {
  const t = outcomeTone(o);
  const cls = t === "ok" ? "text-[var(--color-ok)] border-[var(--color-ok)]" : t === "warn" ? "text-[var(--color-warn)] border-[var(--color-warn)]" : t === "danger" ? "text-[var(--color-danger)] border-[var(--color-danger)]" : "text-[var(--color-muted)] border-[var(--color-border)]";
  return <span className={`inline-block rounded-full border px-2 py-0.5 text-xs ${cls}`}>{o}</span>;
}

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try { return new Date(s).toISOString().slice(0, 10); } catch { return "—"; }
}

function fmtUris(arr: string[] | null): string {
  if (!arr || arr.length === 0) return "—";
  return `${arr.length} link${arr.length === 1 ? "" : "s"}`;
}

export default async function FounderCustomerCaseStudyTrackerPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const [sRes, cRes, rRes, pRes] = await Promise.all([
    sb.rpc("founder_case_study_tracker_summary"),
    sb.rpc("founder_case_studies_recent"),
    sb.rpc("founder_case_study_references_recent", { p_case_study_id: null }),
    sb.rpc("founder_case_studies_published"),
  ]);
  if (sRes.error) throw new Error(`cs_summary: ${sRes.error.message}`);
  if (cRes.error) throw new Error(`cs_recent: ${cRes.error.message}`);
  if (rRes.error) throw new Error(`cs_refs_recent: ${rRes.error.message}`);
  if (pRes.error) throw new Error(`cs_published: ${pRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const cases = (cRes.data ?? []) as CaseStudy[];
  const refs = (rRes.data ?? []) as Ref[];
  const published = (pRes.data ?? []) as CaseStudy[];

  return (
    <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
      <header className="mb-6">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">r1430 · founder console</div>
        <h1 className="mt-1 text-2xl font-semibold">Customer case study tracker</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Hospital reference + case study + permission tracker. Convert wins into reusable proof for pitch deck, website, and press.
        </p>
      </header>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Tracker KPIs</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          <Card label="Total case studies" value={formatNumber(s?.total_case_studies ?? 0)} />
          <Card label="Draft" value={formatNumber(s?.draft_count ?? 0)} tone="warn" />
          <Card label="Permission pending" value={formatNumber(s?.permission_pending_count ?? 0)} tone="warn" />
          <Card label="Permission granted" value={formatNumber(s?.permission_granted_count ?? 0)} tone="ok" />
          <Card label="Published" value={formatNumber(s?.published_count ?? 0)} tone="ok" />
          <Card label="Retired" value={formatNumber(s?.retired_count ?? 0)} tone="danger" />
          <Card label="Permission denied" value={formatNumber(s?.permission_denied_count ?? 0)} tone="danger" />
          <Card label="In pitch deck" value={formatNumber(s?.in_pitch_deck_count ?? 0)} />
          <Card label="In website" value={formatNumber(s?.in_website_count ?? 0)} />
          <Card label="In press" value={formatNumber(s?.in_press_count ?? 0)} />
          <Card label="Total references" value={formatNumber(s?.total_references ?? 0)} />
          <Card label="Positive outcomes" value={formatNumber(s?.positive_outcomes ?? 0)} tone="ok" />
          <Card label="Negative outcomes" value={formatNumber(s?.negative_outcomes ?? 0)} tone="danger" />
          <Card label="Pending references" value={formatNumber(s?.pending_references ?? 0)} tone="warn" />
          <Card label="Conversion rate" value={`${formatNumber(s?.conversion_rate_pct ?? 0)}%`} sub="positive vs all closed" />
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Case study ledger (30 most recent)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2">Label</th>
                <th className="px-3 py-2">Kind</th>
                <th className="px-3 py-2">Status</th>
                <th className="px-3 py-2">Headline</th>
                <th className="px-3 py-2">Pitch</th>
                <th className="px-3 py-2">Web</th>
                <th className="px-3 py-2">Press</th>
                <th className="px-3 py-2">Links</th>
                <th className="px-3 py-2">Granted</th>
                <th className="px-3 py-2">Published</th>
                <th className="px-3 py-2">Created</th>
              </tr>
            </thead>
            <tbody>
              {cases.length === 0 ? (
                <tr><td colSpan={11} className="px-3 py-6 text-center text-[var(--color-muted)]">No case studies registered yet.</td></tr>
              ) : cases.map((c) => (
                <tr key={c.id} className="border-b border-[var(--color-border)]/40 last:border-0">
                  <td className="px-3 py-2 font-medium">{c.case_study_label}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{c.case_study_kind}</td>
                  <td className="px-3 py-2"><StatusPill s={c.status} /></td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{c.headline ?? "—"}</td>
                  <td className="px-3 py-2 tabular-nums">{c.use_in_pitch_deck ? "yes" : "—"}</td>
                  <td className="px-3 py-2 tabular-nums">{c.use_in_website ? "yes" : "—"}</td>
                  <td className="px-3 py-2 tabular-nums">{c.use_in_press ? "yes" : "—"}</td>
                  <td className="px-3 py-2 tabular-nums">{fmtUris(c.publication_uris)}</td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(c.permission_granted_at)}</td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(c.published_at)}</td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(c.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Reference call feed (30 most recent)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2">Referrer</th>
                <th className="px-3 py-2">Prospect</th>
                <th className="px-3 py-2">Outcome</th>
                <th className="px-3 py-2">Call at</th>
                <th className="px-3 py-2">Notes</th>
                <th className="px-3 py-2">Created</th>
              </tr>
            </thead>
            <tbody>
              {refs.length === 0 ? (
                <tr><td colSpan={6} className="px-3 py-6 text-center text-[var(--color-muted)]">No reference calls logged yet.</td></tr>
              ) : refs.map((r) => (
                <tr key={r.id} className="border-b border-[var(--color-border)]/40 last:border-0">
                  <td className="px-3 py-2">{r.referrer_contact_name ?? "—"}<div className="text-xs text-[var(--color-muted)]">{r.referrer_contact_email ?? ""}</div></td>
                  <td className="px-3 py-2">{r.prospect_name ?? "—"}</td>
                  <td className="px-3 py-2"><OutcomePill o={r.outcome} /></td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(r.reference_call_at)}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{r.notes ?? "—"}</td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(r.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Published case studies</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2">Label</th>
                <th className="px-3 py-2">Kind</th>
                <th className="px-3 py-2">Headline</th>
                <th className="px-3 py-2">Signed by</th>
                <th className="px-3 py-2">Published</th>
              </tr>
            </thead>
            <tbody>
              {published.length === 0 ? (
                <tr><td colSpan={5} className="px-3 py-6 text-center text-[var(--color-muted)]">No published case studies yet.</td></tr>
              ) : published.map((c) => (
                <tr key={c.id} className="border-b border-[var(--color-border)]/40 last:border-0">
                  <td className="px-3 py-2 font-medium">{c.case_study_label}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{c.case_study_kind}</td>
                  <td className="px-3 py-2">{c.headline ?? "—"}</td>
                  <td className="px-3 py-2">{c.permission_signed_by ?? "—"}</td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(c.published_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="mt-10 border-t border-[var(--color-border)] pt-4 text-xs text-[var(--color-muted)]">
        r1430 · founder-only · is_founder() gate enforced on all 7 RPCs · register {"->"} permission_pending {"->"} permission_granted {"->"} published {"->"} retired
      </footer>
    </main>
  );
}
