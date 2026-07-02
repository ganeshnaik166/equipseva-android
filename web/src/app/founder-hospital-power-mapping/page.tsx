import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatRelativeTime, shortId } from "@/lib/format";

export const metadata = { title: "Hospital power mapping — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_stakeholders: number;
  total_hospitals_mapped: number;
  total_relationships: number;
  champions_count: number;
  supportive_count: number;
  neutral_count: number;
  skeptical_count: number;
  opposed_count: number;
  signs_contract_count: number;
  holds_budget_count: number;
  blockers_count: number;
  high_influence_count: number;
  stale_engagement_60d_count: number;
  avg_stakeholders_per_hospital: number;
  generated_at: string;
};

type StakeholderRow = {
  id: string;
  hospital_user_id: string;
  contact_name: string;
  contact_role: string | null;
  contact_email: string | null;
  contact_phone: string | null;
  decision_authority: string;
  influence_band: string;
  sentiment: string;
  last_engaged_at: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

type RelationshipRow = {
  id: string;
  source_stakeholder_id: string;
  source_name: string | null;
  source_role: string | null;
  target_stakeholder_id: string;
  target_name: string | null;
  target_role: string | null;
  relationship_kind: string;
  strength_band: string;
  notes: string | null;
  created_at: string;
};

type ChampionRow = {
  id: string;
  hospital_user_id: string;
  contact_name: string;
  contact_role: string | null;
  decision_authority: string;
  influence_band: string;
  last_engaged_at: string | null;
  updated_at: string;
};

function Card({ title, val, sub, danger, ok, warn }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean; warn?: boolean }) {
  const color = danger ? "text-[var(--color-danger)]" : warn ? "text-[var(--color-warn)]" : ok ? "text-[var(--color-ok)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${color}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function AuthorityBadge({ k }: { k: string }) {
  const v = (k ?? "").toLowerCase();
  const cls =
    v === "signs_contract" || v === "holds_budget"
      ? "bg-green-100 text-[var(--color-ok)]"
      : v === "blocker"
        ? "bg-red-100 text-[var(--color-danger)]"
        : v === "technical_decision" || v === "sponsor"
          ? "bg-blue-100 text-blue-700"
          : v === "referrer"
            ? "bg-yellow-100 text-[var(--color-warn)]"
            : "bg-[var(--color-bg)] text-[var(--color-muted)]";
  return <span className={`inline-block rounded px-1.5 py-0.5 text-xs ${cls}`}>{v}</span>;
}

function SentimentBadge({ s }: { s: string }) {
  const v = (s ?? "").toLowerCase();
  const cls =
    v === "champion"
      ? "bg-green-100 text-[var(--color-ok)]"
      : v === "supportive"
        ? "bg-blue-100 text-blue-700"
        : v === "skeptical"
          ? "bg-yellow-100 text-[var(--color-warn)]"
          : v === "opposed"
            ? "bg-red-100 text-[var(--color-danger)]"
            : "bg-[var(--color-bg)] text-[var(--color-muted)]";
  return <span className={`inline-block rounded px-1.5 py-0.5 text-xs ${cls}`}>{v}</span>;
}

function InfluenceBadge({ b }: { b: string }) {
  const v = (b ?? "").toLowerCase();
  const cls =
    v === "high"
      ? "bg-red-100 text-[var(--color-danger)]"
      : v === "medium"
        ? "bg-yellow-100 text-[var(--color-warn)]"
        : "bg-[var(--color-bg)] text-[var(--color-muted)]";
  return <span className={`inline-block rounded px-1.5 py-0.5 text-xs ${cls}`}>{v}</span>;
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, stakeholdersRes, relsRes, championsRes] = await Promise.all([
    supabase.rpc("founder_hospital_power_mapping_summary"),
    supabase.rpc("founder_hospital_power_map_stakeholders_recent"),
    supabase.rpc("founder_hospital_power_map_relationships_recent"),
    supabase.rpc("founder_hospital_power_map_champions"),
  ]);

  const summary: SummaryRow | null = (summaryRes.data?.[0] as SummaryRow | undefined) ?? null;
  const stakeholders: StakeholderRow[] = (stakeholdersRes.data as StakeholderRow[] | null) ?? [];
  const rels: RelationshipRow[] = (relsRes.data as RelationshipRow[] | null) ?? [];
  const champions: ChampionRow[] = (championsRes.data as ChampionRow[] | null) ?? [];

  return (
    <main className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Hospital power mapping</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Who-decides-what at each hospital — stakeholders + relationships + sentiment band. r1442
        </p>
      </header>

      {summary ? (
        <section className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-7">
          <Card title="Stakeholders" val={formatNumber(summary.total_stakeholders)} />
          <Card title="Hospitals mapped" val={formatNumber(summary.total_hospitals_mapped)} />
          <Card title="Relationships" val={formatNumber(summary.total_relationships)} />
          <Card title="Champions" val={formatNumber(summary.champions_count)} ok />
          <Card title="Supportive" val={formatNumber(summary.supportive_count)} />
          <Card title="Neutral" val={formatNumber(summary.neutral_count)} />
          <Card title="Skeptical" val={formatNumber(summary.skeptical_count)} warn />
          <Card title="Opposed" val={formatNumber(summary.opposed_count)} danger />
          <Card title="Signs contract" val={formatNumber(summary.signs_contract_count)} ok />
          <Card title="Holds budget" val={formatNumber(summary.holds_budget_count)} ok />
          <Card title="Blockers" val={formatNumber(summary.blockers_count)} danger />
          <Card title="High influence" val={formatNumber(summary.high_influence_count)} />
          <Card title="Stale > 60d" val={formatNumber(summary.stale_engagement_60d_count)} warn />
          <Card title="Avg per hospital" val={formatNumber(summary.avg_stakeholders_per_hospital)} />
        </section>
      ) : (
        <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-sm text-[var(--color-muted)]">
          No summary yet.
        </section>
      )}

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
        <h2 className="text-lg font-semibold">Champions banner</h2>
        <p className="text-xs text-[var(--color-muted)]">Sentiment = champion · ranked by influence band.</p>
        <div className="mt-3 overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="text-left text-xs text-[var(--color-muted)]">
              <tr>
                <th className="py-1 pr-3">Name</th>
                <th className="py-1 pr-3">Role</th>
                <th className="py-1 pr-3">Hospital</th>
                <th className="py-1 pr-3">Authority</th>
                <th className="py-1 pr-3">Influence</th>
                <th className="py-1 pr-3">Last engaged</th>
              </tr>
            </thead>
            <tbody>
              {champions.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-2 text-[var(--color-muted)]">No champions yet.</td>
                </tr>
              ) : champions.map((c) => (
                <tr key={c.id} className="border-t border-[var(--color-border)]">
                  <td className="py-1 pr-3">{c.contact_name}</td>
                  <td className="py-1 pr-3 text-[var(--color-muted)]">{c.contact_role ?? "—"}</td>
                  <td className="py-1 pr-3 font-mono text-xs">{shortId(c.hospital_user_id)}</td>
                  <td className="py-1 pr-3"><AuthorityBadge k={c.decision_authority} /></td>
                  <td className="py-1 pr-3"><InfluenceBadge b={c.influence_band} /></td>
                  <td className="py-1 pr-3 text-[var(--color-muted)]">{c.last_engaged_at ? formatRelativeTime(c.last_engaged_at) : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
        <h2 className="text-lg font-semibold">Stakeholders (recent 40)</h2>
        <div className="mt-3 overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="text-left text-xs text-[var(--color-muted)]">
              <tr>
                <th className="py-1 pr-3">Name</th>
                <th className="py-1 pr-3">Role</th>
                <th className="py-1 pr-3">Hospital</th>
                <th className="py-1 pr-3">Authority</th>
                <th className="py-1 pr-3">Influence</th>
                <th className="py-1 pr-3">Sentiment</th>
                <th className="py-1 pr-3">Contact</th>
                <th className="py-1 pr-3">Engaged</th>
                <th className="py-1 pr-3">Updated</th>
              </tr>
            </thead>
            <tbody>
              {stakeholders.length === 0 ? (
                <tr>
                  <td colSpan={9} className="py-2 text-[var(--color-muted)]">No stakeholders yet.</td>
                </tr>
              ) : stakeholders.map((s) => (
                <tr key={s.id} className="border-t border-[var(--color-border)]">
                  <td className="py-1 pr-3">{s.contact_name}</td>
                  <td className="py-1 pr-3 text-[var(--color-muted)]">{s.contact_role ?? "—"}</td>
                  <td className="py-1 pr-3 font-mono text-xs">{shortId(s.hospital_user_id)}</td>
                  <td className="py-1 pr-3"><AuthorityBadge k={s.decision_authority} /></td>
                  <td className="py-1 pr-3"><InfluenceBadge b={s.influence_band} /></td>
                  <td className="py-1 pr-3"><SentimentBadge s={s.sentiment} /></td>
                  <td className="py-1 pr-3 text-xs text-[var(--color-muted)]">{s.contact_email ?? s.contact_phone ?? "—"}</td>
                  <td className="py-1 pr-3 text-[var(--color-muted)]">{s.last_engaged_at ? formatRelativeTime(s.last_engaged_at) : "—"}</td>
                  <td className="py-1 pr-3 text-[var(--color-muted)]">{formatRelativeTime(s.updated_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
        <h2 className="text-lg font-semibold">Relationships (recent 40)</h2>
        <p className="text-xs text-[var(--color-muted)]">Edges between stakeholders · reports_to · peer_of · influenced_by · blocks · reports_above.</p>
        <div className="mt-3 overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="text-left text-xs text-[var(--color-muted)]">
              <tr>
                <th className="py-1 pr-3">Source</th>
                <th className="py-1 pr-3">Source role</th>
                <th className="py-1 pr-3">Kind</th>
                <th className="py-1 pr-3">Target</th>
                <th className="py-1 pr-3">Target role</th>
                <th className="py-1 pr-3">Strength</th>
                <th className="py-1 pr-3">When</th>
              </tr>
            </thead>
            <tbody>
              {rels.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-2 text-[var(--color-muted)]">No relationships yet.</td>
                </tr>
              ) : rels.map((r) => (
                <tr key={r.id} className="border-t border-[var(--color-border)]">
                  <td className="py-1 pr-3">{r.source_name ?? shortId(r.source_stakeholder_id)}</td>
                  <td className="py-1 pr-3 text-[var(--color-muted)]">{r.source_role ?? "—"}</td>
                  <td className="py-1 pr-3"><span className="inline-block rounded bg-[var(--color-bg)] px-1.5 py-0.5 text-xs">{r.relationship_kind}</span></td>
                  <td className="py-1 pr-3">{r.target_name ?? shortId(r.target_stakeholder_id)}</td>
                  <td className="py-1 pr-3 text-[var(--color-muted)]">{r.target_role ?? "—"}</td>
                  <td className="py-1 pr-3">{r.strength_band}</td>
                  <td className="py-1 pr-3 text-[var(--color-muted)]">{formatRelativeTime(r.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
