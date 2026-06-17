import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export const metadata = { title: "Audit trail export — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  id: string;
  actor_user_id: string | null;
  op_name: string;
  target_table: string | null;
  target_row_id: string | null;
  outcome: string | null;
  reason: string | null;
  created_at: string;
};

function csvEscape(v: unknown): string {
  if (v === null || v === undefined) return "";
  const s = String(v);
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

export default async function AuditTrailExportPage({
  searchParams,
}: {
  searchParams?: Promise<{ days?: string }>;
}) {
  await requireFounder();
  const params = (await searchParams) ?? {};
  const days = Math.max(1, Math.min(365, Number.parseInt(params.days ?? "90", 10) || 90));

  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase
    .from("founder_action_log")
    .select("id, actor_user_id, op_name, target_table, target_row_id, outcome, reason, created_at")
    .gte("created_at", new Date(Date.now() - days * 86400000).toISOString())
    .order("created_at", { ascending: false })
    .limit(1000);
  if (error) throw new Error(`founder_action_log: ${error.message}`);
  const rows = (data ?? []) as Row[];

  const csv = [
    ["id", "actor_user_id", "op_name", "target_table", "target_row_id", "outcome", "reason", "created_at"].join(","),
    ...rows.map((r) =>
      [r.id, r.actor_user_id, r.op_name, r.target_table, r.target_row_id, r.outcome, r.reason, r.created_at]
        .map(csvEscape)
        .join(","),
    ),
  ].join("\n");

  const dataUrl = `data:text/csv;charset=utf-8,${encodeURIComponent(csv)}`;
  const filename = `equipseva-audit-trail-${days}d-${new Date().toISOString().slice(0, 10)}.csv`;

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Audit trail export ★</h1>
        <span className="text-xs text-[var(--color-muted)]">r900 milestone · CSV download for compliance archive</span>
      </header>

      <section className="rounded border border-[var(--color-border)] bg-white p-4">
        <div className="text-sm">Last {days} days · {rows.length} rows (max 1000).</div>
        <div className="mt-3 flex gap-3 text-xs">
          <a href={`?days=30`} className="underline">30d</a>
          <a href={`?days=90`} className="underline">90d</a>
          <a href={`?days=180`} className="underline">180d</a>
          <a href={`?days=365`} className="underline">365d</a>
        </div>
        <a
          href={dataUrl}
          download={filename}
          className="mt-4 inline-block rounded border border-[var(--color-fg)] bg-[var(--color-fg)] px-4 py-2 text-sm font-semibold text-white hover:opacity-90"
        >
          Download {filename}
        </a>
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>Why this page.</strong> Compliance / audit requirements often need a flat-file export of founder ops history (who did what, when, why). RLS-gated to founder; CSV is generated server-side and inlined as a data URL so no server upload is needed. Adjust the window via the link buttons. Hard cap of 1000 rows keeps the data URL under the browser limit; for larger exports, run the SQL directly.
      </section>
    </div>
  );
}
