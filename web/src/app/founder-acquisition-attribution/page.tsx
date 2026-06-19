import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder acquisition attribution — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_touchpoints: number;
  total_hospitals_touched: number;
  total_hospitals_converted: number;
  conversion_pct: number;
  avg_touches_per_conversion: number;
  first_touch_top_kind: string | null;
  last_touch_top_kind: string | null;
  referral_attributed_count: number;
  cold_outreach_attributed_count: number;
  event_attributed_count: number;
  website_form_attributed_count: number;
  partner_referral_attributed_count: number;
  other_kinds_attributed_count: number;
  first_touch_to_signed_median_days: number;
  touchpoints_last_30d: number;
  hospitals_with_zero_touchpoints: number;
};

type KindRow = {
  kind: string;
  touchpoint_count: number;
  hospitals_touched: number;
  hospitals_converted: number;
  conversion_pct: number;
  first_touch_attribution_count: number;
  last_touch_attribution_count: number;
};

const KIND_LABEL: Record<string, string> = {
  referral: "Referral",
  cold_outreach: "Cold outreach",
  event: "Event",
  website_form: "Website form",
  phone_inbound: "Phone inbound",
  referred_by_chain: "Referred by chain",
  partner_referral: "Partner referral",
  google_ads: "Google Ads",
  linkedin_ads: "LinkedIn Ads",
  content_marketing: "Content marketing",
  other: "Other",
};

function formatKind(k: string | null): string {
  if (!k) return "—";
  return KIND_LABEL[k] ?? k;
}

function convBand(pct: number): string {
  if (pct >= 25) return "text-[var(--color-ok)]";
  if (pct >= 10) return "text-[var(--color-info)]";
  if (pct > 0) return "text-[var(--color-warn)]";
  return "text-[var(--color-muted)]";
}

export default async function FounderAcquisitionAttributionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, byKindRes] = await Promise.all([
    supabase.rpc("founder_acquisition_attribution_summary"),
    supabase.rpc("founder_acquisition_attribution_by_kind"),
  ]);
  if (sumRes.error) throw new Error(`founder_acquisition_attribution_summary: ${sumRes.error.message}`);
  if (byKindRes.error) throw new Error(`founder_acquisition_attribution_by_kind: ${byKindRes.error.message}`);

  const s = (sumRes.data?.[0] ?? null) as Summary | null;
  const rows = (byKindRes.data ?? []) as KindRow[];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder acquisition attribution ★ r1361</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Multi-touch hospital acquisition ledger · 16 KPIs · first-touch + last-touch attribution model · per-kind breakdown · the forcing function against attribution amnesia
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-4">
          <div className="rounded-lg border-2 border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Total touchpoints</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-accent)]">{formatNumber(s.total_touchpoints)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Hospitals touched</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.total_hospitals_touched)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Hospitals converted</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{formatNumber(s.total_hospitals_converted)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Conversion %</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${convBand(Number(s.conversion_pct))}`}>{Number(s.conversion_pct).toFixed(2)}%</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Avg touches / conversion</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{Number(s.avg_touches_per_conversion).toFixed(2)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">First-touch top kind</div>
            <div className="mt-1 text-base font-semibold truncate" title={s.first_touch_top_kind ?? ""}>{formatKind(s.first_touch_top_kind)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Last-touch top kind</div>
            <div className="mt-1 text-base font-semibold truncate" title={s.last_touch_top_kind ?? ""}>{formatKind(s.last_touch_top_kind)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Median days first → signed</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{Number(s.first_touch_to_signed_median_days).toFixed(1)}<span className="text-xs text-[var(--color-muted)]">d</span></div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Referral attributed</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{formatNumber(s.referral_attributed_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Cold outreach attributed</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.cold_outreach_attributed_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Event attributed</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.event_attributed_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Website form attributed</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.website_form_attributed_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Partner referral attributed</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-info)]">{formatNumber(s.partner_referral_attributed_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Other kinds attributed</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-muted)]">{formatNumber(s.other_kinds_attributed_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Touchpoints last 30d</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.touchpoints_last_30d)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Hospitals w/ zero touchpoints</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${s.hospitals_with_zero_touchpoints > 0 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]"}`}>{formatNumber(s.hospitals_with_zero_touchpoints)}</div>
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Per-kind breakdown · first-touch vs last-touch</h2>
        {rows.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No touchpoints logged yet. Call <code className="font-mono text-xs">log_founder_acquisition_record_touch(p_hospital_org_id, p_kind, p_source_label, p_notes)</code> to start the ledger.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-left text-[var(--color-muted)] border-b border-[var(--color-border)]">
                <tr>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3 text-right">Touches</th>
                  <th className="py-2 pr-3 text-right">Hospitals touched</th>
                  <th className="py-2 pr-3 text-right">Converted</th>
                  <th className="py-2 pr-3 text-right">Conv %</th>
                  <th className="py-2 pr-3 text-right">First-touch attrib</th>
                  <th className="py-2 pr-3 text-right">Last-touch attrib</th>
                  <th className="py-2 pr-3">Gap</th>
                </tr>
              </thead>
              <tbody>
                {rows.map(r => {
                  const gap = (r.last_touch_attribution_count ?? 0) - (r.first_touch_attribution_count ?? 0);
                  return (
                    <tr key={r.kind} className="border-b border-[var(--color-border)]">
                      <td className="py-2 pr-3 font-semibold">{formatKind(r.kind)}</td>
                      <td className="py-2 pr-3 text-right tabular-nums">{formatNumber(r.touchpoint_count)}</td>
                      <td className="py-2 pr-3 text-right tabular-nums">{formatNumber(r.hospitals_touched)}</td>
                      <td className="py-2 pr-3 text-right tabular-nums text-[var(--color-ok)]">{formatNumber(r.hospitals_converted)}</td>
                      <td className={`py-2 pr-3 text-right tabular-nums ${convBand(Number(r.conversion_pct))}`}>{Number(r.conversion_pct).toFixed(2)}%</td>
                      <td className="py-2 pr-3 text-right tabular-nums text-[var(--color-info)]">{formatNumber(r.first_touch_attribution_count)}</td>
                      <td className="py-2 pr-3 text-right tabular-nums text-[var(--color-accent)]">{formatNumber(r.last_touch_attribution_count)}</td>
                      <td className={`py-2 pr-3 tabular-nums ${gap > 0 ? "text-[var(--color-ok)]" : gap < 0 ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]"}`}>{gap > 0 ? "+" : ""}{gap}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
          <h3 className="text-sm font-semibold text-[var(--color-fg)]">First-touch vs last-touch — why we show both</h3>
          <ul className="list-disc list-inside space-y-1">
            <li><b>First-touch</b> = which channel <i>sourced</i> the lead. Credits the awareness-building work — content, events, cold outreach — that often gets defunded because last-touch dashboards hide it.</li>
            <li><b>Last-touch</b> = which channel <i>closed</i> the lead. Credits the conversion-closing work — partner referrals, demos, direct calls — that the sales narrative tends to over-claim.</li>
            <li>If a kind shows high last-touch but low first-touch attribution it's a <i>closer</i>, not a sourcer. Don't budget it as if it generates leads.</li>
            <li>If a kind shows high first-touch but low last-touch it's a <i>sourcer</i> dependent on closers downstream. Cut it and you starve the rest of the funnel.</li>
            <li>Both numbers should be visible side-by-side every time you make a channel-budget decision. Picking one model is how founders convince themselves to defund the thing that's actually working.</li>
          </ul>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
          <h3 className="text-sm font-semibold text-[var(--color-fg)]">Recording discipline</h3>
          <ul className="list-disc list-inside space-y-1">
            <li>Record a touch <i>at the moment it happens</i>, not retroactively. Memory rewrites attribution to fit the current narrative.</li>
            <li>One row per real interaction — call, meeting, form fill, event scan. Not one row per <i>day</i> of activity.</li>
            <li>Fill the <code className="font-mono">source_label</code> with the concrete source (event name, referrer org, ad campaign id). Aggregate kind without label is useless 90 days later.</li>
            <li>Conversion = hospital has an <i>active</i> AMC contract. Paused / expired hospitals do not count as converted — they count as churned, which is a separate problem.</li>
            <li>Hospitals-with-zero-touchpoints {">"} 0 means we have hospitals in <code className="font-mono">organizations</code> with no recorded acquisition story. Backfill or accept the data is permanently incomplete.</li>
          </ul>
        </div>
      </section>
    </div>
  );
}
