import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Evidence ledger §65B — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_evidence_rows: number;
  rows_today: number;
  rows_7d: number;
  rows_30d: number;
  distinct_evidence_kinds: number;
  distinct_source_jobs: number;
  top_kind: string;
  top_kind_count: number;
  pved_pdf_count: number;
  dsr_pdf_count: number;
  photo_before_count: number;
  photo_after_count: number;
  photo_during_count: number;
  signature_engineer_count: number;
  signature_hospital_count: number;
  chat_archive_count: number;
  amc_affidavit_count: number;
  gst_invoice_pdf_count: number;
  tds_certificate_count: number;
  voice_note_count: number;
  job_completion_otp_count: number;
  parts_receipt_count: number;
  producer_engineer_count: number;
  producer_hospital_count: number;
  producer_system_count: number;
  producer_founder_count: number;
  total_bytes_stored: number;
  avg_bytes_per_row: number;
  duplicate_hash_collisions: number;
  unknown_platform_count: number;
  jobs_missing_photo_before: number;
  jobs_missing_photo_after: number;
  jobs_with_full_photo_set: number;
  newest_row_at: string | null;
  oldest_row_at: string | null;
};

function fmtBytes(n: number): string {
  if (!n) return "0 B";
  const u = ["B", "KB", "MB", "GB", "TB"];
  let i = 0;
  let v = n;
  while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
  return `${v.toFixed(1)} ${u[i]}`;
}

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try { return new Date(s).toISOString().slice(0, 16).replace("T", " "); } catch { return "—"; }
}

export default async function EvidenceLedger65bSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_evidence_ledger_65b_summary");
  if (error) throw new Error(`founder_evidence_ledger_65b_summary: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const r = rows[0];

  const kpi = (label: string, value: string | number, tone: "ok" | "warn" | "danger" | "muted" = "muted") => {
    const color =
      tone === "ok" ? "text-[var(--color-ok)]" :
      tone === "warn" ? "text-[var(--color-warn)]" :
      tone === "danger" ? "text-[var(--color-danger)]" :
      "text-[var(--color-fg)]";
    return (
      <div className="rounded-md border border-[var(--color-border)] p-3">
        <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{label}</div>
        <div className={`mt-1 text-base font-semibold tabular-nums ${color}`}>{value}</div>
      </div>
    );
  };

  if (!r) {
    return (
      <div className="space-y-6">
        <header className="flex items-baseline justify-between">
          <h1 className="text-xl font-semibold">Evidence ledger §65B</h1>
          <span className="text-xs text-[var(--color-muted)]">no evidence rows yet</span>
        </header>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Evidence ledger §65B</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Indian Evidence Act §65B chain-of-custody · {formatNumber(r.total_evidence_rows)} ledger rows · top kind <span className="font-mono">{r.top_kind}</span>
        </span>
      </header>

      <section>
        <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">Volume</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          {kpi("Total rows", formatNumber(r.total_evidence_rows))}
          {kpi("Today", formatNumber(r.rows_today), "ok")}
          {kpi("Last 7d", formatNumber(r.rows_7d))}
          {kpi("Last 30d", formatNumber(r.rows_30d))}
          {kpi("Distinct kinds", formatNumber(r.distinct_evidence_kinds))}
          {kpi("Distinct jobs", formatNumber(r.distinct_source_jobs))}
          {kpi("Top kind count", formatNumber(r.top_kind_count))}
          {kpi("Total bytes", fmtBytes(Number(r.total_bytes_stored)))}
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">By evidence kind</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          {kpi("pved_pdf", formatNumber(r.pved_pdf_count))}
          {kpi("dsr_pdf", formatNumber(r.dsr_pdf_count))}
          {kpi("photo_before", formatNumber(r.photo_before_count))}
          {kpi("photo_after", formatNumber(r.photo_after_count))}
          {kpi("photo_during", formatNumber(r.photo_during_count))}
          {kpi("sig engineer", formatNumber(r.signature_engineer_count))}
          {kpi("sig hospital", formatNumber(r.signature_hospital_count))}
          {kpi("chat archive", formatNumber(r.chat_archive_count))}
          {kpi("amc affidavit", formatNumber(r.amc_affidavit_count))}
          {kpi("gst invoice", formatNumber(r.gst_invoice_pdf_count))}
          {kpi("tds cert", formatNumber(r.tds_certificate_count))}
          {kpi("voice note", formatNumber(r.voice_note_count))}
          {kpi("job otp", formatNumber(r.job_completion_otp_count))}
          {kpi("parts receipt", formatNumber(r.parts_receipt_count))}
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">Producers & storage</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          {kpi("Producer engineer", formatNumber(r.producer_engineer_count))}
          {kpi("Producer hospital", formatNumber(r.producer_hospital_count))}
          {kpi("Producer system", formatNumber(r.producer_system_count))}
          {kpi("Producer founder", formatNumber(r.producer_founder_count))}
          {kpi("Avg bytes/row", fmtBytes(Number(r.avg_bytes_per_row)))}
          {kpi("Hash collisions", formatNumber(r.duplicate_hash_collisions), Number(r.duplicate_hash_collisions) > 0 ? "warn" : "ok")}
          {kpi("Unknown platform", formatNumber(r.unknown_platform_count), Number(r.unknown_platform_count) > 0 ? "warn" : "ok")}
          {kpi("Newest row", fmtDate(r.newest_row_at))}
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">Gaps (closed jobs)</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          {kpi("Missing photo_before", formatNumber(r.jobs_missing_photo_before), Number(r.jobs_missing_photo_before) > 0 ? "danger" : "ok")}
          {kpi("Missing photo_after", formatNumber(r.jobs_missing_photo_after), Number(r.jobs_missing_photo_after) > 0 ? "danger" : "ok")}
          {kpi("Full photo set", formatNumber(r.jobs_with_full_photo_set), "ok")}
          {kpi("Oldest row", fmtDate(r.oldest_row_at))}
        </div>
      </section>

      <p className="text-[11px] text-[var(--color-muted)]">
        §65B Indian Evidence Act admissibility depends on the ledger being immutable &amp; complete. Missing photo_before/after on closed jobs &rarr; dispute defense gap. Hash collisions &gt; 0 &rarr; investigate (likely benign re-upload of identical content, but verify).
      </p>
    </div>
  );
}
