import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Integrity events — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type EventRow = {
  id: string;
  user_id: string;
  display_name: string;
  action: string;
  pass: boolean;
  device_verdict: string | null;
  app_verdict: string | null;
  client_header: string | null;
  created_at: string;
};

type SummaryRow = {
  window_label: string;
  total_checks: number;
  pass_count: number;
  fail_count: number;
  dirty_header: number;
  pass_pct: number;
};

export default async function IntegrityEventsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [eventsRes, summaryRes] = await Promise.all([
    supabase.rpc("founder_integrity_events"),
    supabase.rpc("founder_integrity_summary"),
  ]);
  if (eventsRes.error) throw new Error(`founder_integrity_events: ${eventsRes.error.message}`);
  if (summaryRes.error) throw new Error(`founder_integrity_summary: ${summaryRes.error.message}`);
  const events = (eventsRes.data ?? []) as EventRow[];
  const summary = (summaryRes.data ?? []) as SummaryRow[];

  const cols: Column<EventRow>[] = [
    { key: "t", header: "When", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.created_at).toLocaleString()}</span> },
    { key: "n", header: "User", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "a", header: "Action", render: (r) => <span className="text-xs font-semibold">{r.action}</span> },
    { key: "p", header: "Pass",
      render: (r) => r.pass
        ? <span className="text-xs text-[var(--color-ok)]">✓</span>
        : <span className="text-xs text-[var(--color-danger)]">✗</span>
    },
    { key: "d", header: "Google verdict", render: (r) => <span className="text-xs text-[var(--color-muted)]">{r.device_verdict ?? "—"}</span> },
    { key: "h", header: "Client header",
      render: (r) => {
        if (!r.client_header) return <span className="text-xs text-[var(--color-muted)]">—</span>;
        const dirty = r.client_header.includes("tampered") || r.client_header.includes("root=1") || r.client_header.includes("frida=1");
        const tone = dirty ? "text-[var(--color-danger)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs font-mono ${tone}`}>{r.client_header}</span>;
      }
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Integrity events</h1>
        <span className="text-xs text-[var(--color-muted)]">Play Integrity verification audit · last 200 + windowed summary</span>
      </header>

      <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
        {summary.map((s) => (
          <div key={s.window_label} className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs font-semibold uppercase tracking-wider text-[var(--color-muted)]">{s.window_label}</div>
            <div className="mt-2 grid grid-cols-2 gap-2">
              <StatCard label="Total" value={formatNumber(s.total_checks)} />
              <StatCard label="Pass %" value={`${s.pass_pct}%`} />
              <StatCard label="Fail" value={formatNumber(s.fail_count)} />
              <StatCard label="Dirty header" value={formatNumber(s.dirty_header)} />
            </div>
          </div>
        ))}
      </div>

      <DataTable columns={cols} rows={events} rowKey={(r) => r.id} emptyMessage="No integrity events yet." />

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>What this shows.</strong> Every call to <code>verify-play-integrity</code> writes one row here. The <em>Client header</em> column is the boot-time self-report from the Android client (r844: <code>X-Equipseva-Integrity</code>). A tampered client CAN lie about this header, but lazy mods often strip only the boot if-block — so this header still flags a lot of real-world tampering. Final source of truth is Google's verdict in the <em>Pass</em> column.
      </section>
    </div>
  );
}
