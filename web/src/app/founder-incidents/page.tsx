import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";
import { resolveIncidentAction } from "./actions";

export const metadata = { title: "Founder incidents — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  open_now: number; investigating_now: number; resolved_30d: number;
  opened_today: number; resolved_today: number;
  p0_open: number; p1_open: number; p2_open: number; p3_open: number;
  median_resolve_hrs: number; oldest_open_age_days: number; resolution_rate_30d_pct: number;
};

type Incident = {
  id: string; source_domain: string; source_item_id: string | null;
  title: string; severity: "p0"|"p1"|"p2"|"p3";
  status: "open"|"investigating"|"resolved"|"wont_fix"|"dupe";
  opened_at: string; resolved_at: string | null;
  age_hours: number; auto_created: boolean;
  root_cause_note: string | null;
};

const SEV_TONE: Record<Incident["severity"], string> = {
  p0: "text-[var(--color-danger)] border-[var(--color-danger)]",
  p1: "text-[var(--color-warn)] border-[var(--color-warn)]",
  p2: "text-[var(--color-info)] border-[var(--color-info)]",
  p3: "text-[var(--color-muted)] border-[var(--color-border)]",
};

const STATUS_TONE: Record<Incident["status"], string> = {
  open:          "text-[var(--color-danger)]",
  investigating: "text-[var(--color-warn)]",
  resolved:      "text-[var(--color-ok)]",
  wont_fix:      "text-[var(--color-muted)]",
  dupe:          "text-[var(--color-muted)]",
};

export default async function FounderIncidentsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, recRes] = await Promise.all([
    supabase.rpc("founder_incidents_summary"),
    supabase.rpc("founder_incidents_recent", { p_limit: 100 }),
  ]);
  if (sumRes.error) throw new Error(`founder_incidents_summary: ${sumRes.error.message}`);
  if (recRes.error) throw new Error(`founder_incidents_recent: ${recRes.error.message}`);
  const s = (sumRes.data?.[0] ?? null) as Summary | null;
  const incidents = (recRes.data ?? []) as Incident[];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder incidents ★ r1311</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">Historical record of every fire · auto-creates from /founder-action-center critical items &gt;24h old · resolve with root-cause note</p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <div className="rounded-lg border-2 border-[var(--color-danger)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">P0 open</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-danger)]">{formatNumber(s.p0_open)}</div>
          </div>
          <div className="rounded-lg border-2 border-[var(--color-warn)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">P1 open</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-warn)]">{formatNumber(s.p1_open)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-info)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">P2 open</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.p2_open)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Resolved 30d</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{formatNumber(s.resolved_30d)}</div>
            <div className="text-xs text-[var(--color-muted)]">{Number(s.resolution_rate_30d_pct).toFixed(1)}% resolution rate</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Median resolve hrs</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{Number(s.median_resolve_hrs).toFixed(1)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Oldest open (days)</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.oldest_open_age_days)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Opened today</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.opened_today)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Resolved today</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{formatNumber(s.resolved_today)}</div>
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Incidents (open first, then resolved)</h2>
        {incidents.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No incidents yet. Auto-creation runs every hour from /founder-action-center critical items &gt;24h.</p>
        ) : (
          <div className="space-y-3">
            {incidents.map(i => (
              <article key={i.id} className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
                <div className="flex items-baseline justify-between flex-wrap gap-2">
                  <h3 className="text-sm font-semibold">{i.title}</h3>
                  <div className="flex items-baseline gap-2 text-[10px] uppercase tracking-wider font-semibold">
                    <span className={`px-2 py-0.5 rounded border ${SEV_TONE[i.severity]}`}>{i.severity}</span>
                    <span className={STATUS_TONE[i.status]}>{i.status}</span>
                    {i.auto_created ? <span className="text-[var(--color-muted)]">AUTO</span> : null}
                  </div>
                </div>
                <div className="mt-2 text-xs text-[var(--color-muted)]">
                  <span className="font-mono">{i.source_domain}</span>
                  {" · opened "}{new Date(i.opened_at).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" })}
                  {" · "}{i.age_hours < 24 ? `${i.age_hours}h` : `${Math.floor(i.age_hours / 24)}d`}
                  {i.resolved_at ? ` · resolved ${new Date(i.resolved_at).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" })}` : null}
                </div>
                {i.root_cause_note ? (
                  <p className="mt-2 text-xs italic text-[var(--color-muted)]">Root cause: {i.root_cause_note}</p>
                ) : null}
                {i.status === "open" || i.status === "investigating" ? (
                  <form action={resolveIncidentAction} className="mt-3 flex flex-wrap items-end gap-2">
                    <input type="hidden" name="incident_id" value={i.id} />
                    <input name="root_cause" required placeholder="Root cause (required)" className="flex-1 min-w-[200px] text-xs px-2 py-1 rounded border border-[var(--color-border)] bg-[var(--color-surface)]" />
                    <input name="postmortem" placeholder="Postmortem URL (optional)" className="flex-1 min-w-[200px] text-xs px-2 py-1 rounded border border-[var(--color-border)] bg-[var(--color-surface)]" />
                    <button type="submit" className="px-3 py-1 text-[10px] uppercase tracking-wider font-semibold border border-[var(--color-ok)] text-[var(--color-ok)] rounded hover:opacity-80">Mark resolved</button>
                  </form>
                ) : null}
              </article>
            ))}
          </div>
        )}
      </section>
      <p className="text-xs text-[var(--color-muted)]">Cron: <code>founder_auto_create_incidents()</code> runs hourly. Pulls severity=1 items from /founder-action-center with age_hours&gt;24 and inserts a founder_incidents row (UNIQUE constraint on (source_domain, source_item_id) prevents dupes).</p>
    </div>
  );
}
