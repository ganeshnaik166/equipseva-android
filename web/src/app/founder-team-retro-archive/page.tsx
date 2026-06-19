import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder team retro archive — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_retros: number;
  retros_30d: number;
  retros_90d: number;
  retros_ytd: number;
  weekly_engineering_count: number;
  biweekly_product_count: number;
  monthly_ops_count: number;
  quarterly_founder_count: number;
  incident_retro_count: number;
  latest_retro_at: string | null;
  days_since_last_retro: number;
  top_format: string | null;
  top_format_count: number;
  avg_attendees: number;
};

type RetroRow = {
  id: string;
  retro_label: string;
  retro_kind: string;
  held_at: string;
  attendees_count: number;
  format: string | null;
  what_went_well: string | null;
  what_went_poorly: string | null;
  action_items_text: string | null;
  surfacing_themes: string | null;
  blockers_raised: string | null;
  decisions_committed: string | null;
  facilitator_user_id: string | null;
  notes_url: string | null;
  created_at: string;
};

const KIND_LABEL: Record<string, string> = {
  weekly_engineering: "Weekly Eng",
  biweekly_product: "Biweekly Product",
  monthly_ops: "Monthly Ops",
  quarterly_founder: "Quarterly Founder",
  incident_retro: "Incident",
  launch_retro: "Launch",
  ad_hoc: "Ad-hoc",
};

const KIND_TONE: Record<string, string> = {
  weekly_engineering: "text-[var(--color-info)] border-[var(--color-info)]",
  biweekly_product: "text-[var(--color-info)] border-[var(--color-info)]",
  monthly_ops: "text-[var(--color-ok)] border-[var(--color-ok)]",
  quarterly_founder: "text-[var(--color-ok)] border-[var(--color-ok)]",
  incident_retro: "text-[var(--color-err)] border-[var(--color-err)]",
  launch_retro: "text-[var(--color-warn)] border-[var(--color-warn)]",
  ad_hoc: "text-[var(--color-muted)] border-[var(--color-muted)]",
};

const FORMAT_LABEL: Record<string, string> = {
  start_stop_continue: "Start/Stop/Continue",
  plus_delta: "Plus/Delta",
  "5_whys": "5 Whys",
  what_went_well_what_didnt: "Well/Didn't",
  postmortem: "Postmortem",
  open_format: "Open",
};

function truncate(s: string | null, n: number): string {
  if (!s) return "—";
  if (s.length <= n) return s;
  return s.slice(0, n - 1) + "...";
}

export default async function FounderTeamRetroArchivePage({
  searchParams,
}: { searchParams: Promise<{ kind?: string }> }) {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const sp = await searchParams;
  const kindParam = sp?.kind && sp.kind in KIND_LABEL ? sp.kind : null;
  const [sumRes, recRes] = await Promise.all([
    supabase.rpc("founder_team_retro_archive_summary"),
    supabase.rpc("founder_team_retros_recent", { p_kind: kindParam, p_limit: 50 }),
  ]);
  if (sumRes.error) throw new Error(`founder_team_retro_archive_summary: ${sumRes.error.message}`);
  if (recRes.error) throw new Error(`founder_team_retros_recent: ${recRes.error.message}`);

  const s = (sumRes.data?.[0] ?? null) as Summary | null;
  const rows = (recRes.data ?? []) as RetroRow[];

  const kinds: Array<{ value: string | null; label: string }> = [
    { value: null, label: "All" },
    { value: "weekly_engineering", label: "Weekly Eng" },
    { value: "biweekly_product", label: "Biweekly Product" },
    { value: "monthly_ops", label: "Monthly Ops" },
    { value: "quarterly_founder", label: "Quarterly Founder" },
    { value: "incident_retro", label: "Incident" },
    { value: "launch_retro", label: "Launch" },
    { value: "ad_hoc", label: "Ad-hoc" },
  ];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder team retro archive ★ r1368</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Retro ledger across weekly eng · biweekly product · monthly ops · quarterly founder · incidents · launches · ends the loop of re-learning the same lessons every quarter · 14 KPIs
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-3">
        <Card label="Total retros" value={formatNumber(s?.total_retros ?? 0)} />
        <Card label="Last 30d" value={formatNumber(s?.retros_30d ?? 0)} />
        <Card label="Last 90d" value={formatNumber(s?.retros_90d ?? 0)} />
        <Card label="YTD" value={formatNumber(s?.retros_ytd ?? 0)} />
        <Card label="Weekly Eng" value={formatNumber(s?.weekly_engineering_count ?? 0)} />
        <Card label="Biweekly Product" value={formatNumber(s?.biweekly_product_count ?? 0)} />
        <Card label="Monthly Ops" value={formatNumber(s?.monthly_ops_count ?? 0)} />
        <Card label="Quarterly Founder" value={formatNumber(s?.quarterly_founder_count ?? 0)} />
        <Card label="Incident retros" value={formatNumber(s?.incident_retro_count ?? 0)} />
        <Card label="Latest retro" value={s?.latest_retro_at ? new Date(s.latest_retro_at).toLocaleDateString() : "—"} />
        <Card label="Days since last" value={formatNumber(s?.days_since_last_retro ?? 0)} hint="days" />
        <Card label="Top format" value={s?.top_format ? (FORMAT_LABEL[s.top_format] ?? s.top_format) : "—"} />
        <Card label="Top format count" value={formatNumber(s?.top_format_count ?? 0)} />
        <Card label="Avg attendees" value={s?.avg_attendees ? Number(s.avg_attendees).toFixed(1) : "—"} hint="per retro" />
      </section>

      <section className="space-y-2">
        <h2 className="text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Filter by kind</h2>
        <div className="flex flex-wrap gap-2">
          {kinds.map((k) => {
            const href = k.value ? `/founder-team-retro-archive?kind=${k.value}` : "/founder-team-retro-archive";
            const active = (k.value ?? null) === kindParam;
            return (
              <a
                key={k.label}
                href={href}
                className={`px-3 py-1 rounded border text-xs ${active ? "bg-[var(--color-info)] text-white border-[var(--color-info)]" : "border-[var(--color-border)] text-[var(--color-muted)] hover:text-[var(--color-fg)]"}`}
              >
                {k.label}
              </a>
            );
          })}
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)] mb-2">
          Retro ledger · last 50 {kindParam ? `· filtered by ${KIND_LABEL[kindParam] ?? kindParam}` : ""}
        </h2>
        <div className="overflow-x-auto border border-[var(--color-border)] rounded">
          <table className="w-full text-xs">
            <thead className="bg-[var(--color-surface)]">
              <tr className="text-left text-[var(--color-muted)]">
                <th className="px-3 py-2">Held</th>
                <th className="px-3 py-2">Kind</th>
                <th className="px-3 py-2">Label</th>
                <th className="px-3 py-2">Format</th>
                <th className="px-3 py-2 text-right">Attendees</th>
                <th className="px-3 py-2">Decisions</th>
                <th className="px-3 py-2">Action items</th>
                <th className="px-3 py-2">Notes</th>
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 ? (
                <tr><td className="px-3 py-3 text-[var(--color-muted)]" colSpan={8}>No retros logged yet.</td></tr>
              ) : (
                rows.map((r) => (
                  <tr key={r.id} className="border-t border-[var(--color-border)] align-top">
                    <td className="px-3 py-2 whitespace-nowrap">{new Date(r.held_at).toLocaleDateString()}</td>
                    <td className="px-3 py-2 whitespace-nowrap">
                      <span className={`px-2 py-0.5 rounded border text-[10px] ${KIND_TONE[r.retro_kind] ?? "border-[var(--color-border)] text-[var(--color-muted)]"}`}>
                        {KIND_LABEL[r.retro_kind] ?? r.retro_kind}
                      </span>
                    </td>
                    <td className="px-3 py-2">{r.retro_label}</td>
                    <td className="px-3 py-2 whitespace-nowrap">
                      {r.format ? (
                        <span className="px-2 py-0.5 rounded border border-[var(--color-border)] text-[10px] text-[var(--color-muted)]">
                          {FORMAT_LABEL[r.format] ?? r.format}
                        </span>
                      ) : "—"}
                    </td>
                    <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.attendees_count)}</td>
                    <td className="px-3 py-2 max-w-[18rem]">{truncate(r.decisions_committed, 80)}</td>
                    <td className="px-3 py-2 max-w-[18rem]">{truncate(r.action_items_text, 80)}</td>
                    <td className="px-3 py-2">{r.notes_url ? <a href={r.notes_url} target="_blank" rel="noreferrer" className="underline text-[var(--color-info)]">link</a> : "—"}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

function Card({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="border border-[var(--color-border)] rounded p-3 bg-[var(--color-surface)]">
      <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className="text-lg font-semibold mt-1 tabular-nums">{value}</div>
      {hint ? <div className="text-[10px] text-[var(--color-muted)] mt-0.5">{hint}</div> : null}
    </div>
  );
}
