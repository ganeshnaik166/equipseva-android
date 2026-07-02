import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  total_deals: number;
  discovery_count: number;
  demo_scheduled_count: number;
  demo_completed_count: number;
  proposal_sent_count: number;
  negotiation_count: number;
  contracted_count: number;
  closed_won_count: number;
  closed_lost_count: number;
  on_hold_count: number;
  pipeline_value_rupees: number;
  weighted_pipeline_rupees: number;
  closed_won_value_rupees: number;
  avg_deal_size_rupees: number;
  total_contacts: number;
  champion_contact_count: number;
  total_activities: number;
  activities_last_7d: number;
};

type Deal = {
  id: string;
  deal_label: string;
  hospital_org_id: string | null;
  target_amc_tier: string | null;
  deal_stage: string;
  deal_size_rupees: number | null;
  expected_close_date: string | null;
  probability_pct: number | null;
  salesperson_user_id: string | null;
  created_at: string;
  updated_at: string;
};

type Contact = {
  id: string;
  deal_id: string;
  contact_name: string;
  contact_role: string;
  contact_email: string | null;
  contact_phone: string | null;
  sentiment: string;
  created_at: string;
};

type Activity = {
  id: string;
  deal_id: string;
  activity_kind: string;
  description: string | null;
  happened_at: string;
  performed_by: string | null;
  created_at: string;
};

const STAGE_LABEL: Record<string, string> = {
  discovery: "Discovery",
  demo_scheduled: "Demo scheduled",
  demo_completed: "Demo completed",
  proposal_sent: "Proposal sent",
  negotiation: "Negotiation",
  contracted: "Contracted",
  closed_won: "Closed won",
  closed_lost: "Closed lost",
  on_hold: "On hold",
};

const SENTIMENT_LABEL: Record<string, string> = {
  champion: "Champion",
  supportive: "Supportive",
  neutral: "Neutral",
  skeptical: "Skeptical",
  opposed: "Opposed",
};

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [{ data: sumRows }, { data: deals }, { data: contacts }, { data: activities }] = await Promise.all([
    sb.rpc("founder_sales_pipeline_v2_summary"),
    sb.rpc("founder_sales_pipeline_v2_deals_recent"),
    sb.rpc("founder_sales_pipeline_v2_contacts_recent", { p_deal_id: null }),
    sb.rpc("founder_sales_pipeline_v2_activities_recent", { p_deal_id: null }),
  ]);

  const s: Summary = (Array.isArray(sumRows) ? sumRows[0] : sumRows) ?? {
    total_deals: 0,
    discovery_count: 0,
    demo_scheduled_count: 0,
    demo_completed_count: 0,
    proposal_sent_count: 0,
    negotiation_count: 0,
    contracted_count: 0,
    closed_won_count: 0,
    closed_lost_count: 0,
    on_hold_count: 0,
    pipeline_value_rupees: 0,
    weighted_pipeline_rupees: 0,
    closed_won_value_rupees: 0,
    avg_deal_size_rupees: 0,
    total_contacts: 0,
    champion_contact_count: 0,
    total_activities: 0,
    activities_last_7d: 0,
  };
  const ds: Deal[] = (deals as Deal[]) ?? [];
  const cs: Contact[] = (contacts as Contact[]) ?? [];
  const as: Activity[] = (activities as Activity[]) ?? [];

  const contactsByDeal = new Map<string, Contact[]>();
  for (const c of cs) {
    const arr = contactsByDeal.get(c.deal_id) ?? [];
    arr.push(c);
    contactsByDeal.set(c.deal_id, arr);
  }

  const winRate =
    s.closed_won_count + s.closed_lost_count > 0
      ? ((100 * s.closed_won_count) / (s.closed_won_count + s.closed_lost_count)).toFixed(1)
      : "0.0";

  return (
    <div style={{ padding: 24, fontFamily: "ui-sans-serif, system-ui", maxWidth: 1240, margin: "0 auto" }}>
      <header style={{ marginBottom: 20 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>Sales pipeline v2</h1>
        <p style={{ color: "#666", margin: "6px 0 0 0", fontSize: 13 }}>
          r1420 ★★★★ · multi-stage multi-decision-maker pipeline · deals + contacts + activities
        </p>
      </header>

      <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(180px, 1fr))", gap: 10, marginBottom: 24 }}>
        <Card label="Total deals" value={formatNumber(s.total_deals)} />
        <Card label="Discovery" value={formatNumber(s.discovery_count)} />
        <Card label="Demo scheduled" value={formatNumber(s.demo_scheduled_count)} />
        <Card label="Demo completed" value={formatNumber(s.demo_completed_count)} />
        <Card label="Proposal sent" value={formatNumber(s.proposal_sent_count)} />
        <Card label="Negotiation" value={formatNumber(s.negotiation_count)} />
        <Card label="Contracted" value={formatNumber(s.contracted_count)} />
        <Card label="Closed won" value={formatNumber(s.closed_won_count)} />
        <Card label="Closed lost" value={formatNumber(s.closed_lost_count)} />
        <Card label="On hold" value={formatNumber(s.on_hold_count)} />
        <Card label="Pipeline value (open)" value={`₹${formatNumber(s.pipeline_value_rupees)}`} />
        <Card label="Weighted pipeline" value={`₹${formatNumber(s.weighted_pipeline_rupees)}`} />
        <Card label="Closed won value" value={`₹${formatNumber(s.closed_won_value_rupees)}`} />
        <Card label="Avg deal size" value={`₹${formatNumber(s.avg_deal_size_rupees)}`} />
        <Card label="Win rate" value={`${winRate}%`} />
        <Card label="Total contacts" value={formatNumber(s.total_contacts)} />
        <Card label="Champion contacts" value={formatNumber(s.champion_contact_count)} />
        <Card label="Activities last 7d" value={formatNumber(s.activities_last_7d)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, margin: "0 0 10px 0" }}>
          Deals ledger ({ds.length})
        </h2>
        <div style={{ overflowX: "auto", border: "1px solid #eee", borderRadius: 8 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#fafafa" }}>
              <tr>
                <Th>Deal label</Th>
                <Th>Stage</Th>
                <Th>Tier</Th>
                <Th>Size</Th>
                <Th>Prob.</Th>
                <Th>Weighted</Th>
                <Th>Close date</Th>
                <Th>Contacts</Th>
                <Th>Updated</Th>
              </tr>
            </thead>
            <tbody>
              {ds.length === 0 ? (
                <tr>
                  <td colSpan={9} style={{ padding: 16, textAlign: "center", color: "#999" }}>No deals yet.</td>
                </tr>
              ) : (
                ds.map((d) => {
                  const size = d.deal_size_rupees ?? 0;
                  const prob = d.probability_pct ?? 0;
                  const weighted = (size * prob) / 100;
                  const dealContacts = contactsByDeal.get(d.id) ?? [];
                  return (
                    <tr key={d.id} style={{ borderTop: "1px solid #f0f0f0" }}>
                      <Td><strong>{d.deal_label}</strong></Td>
                      <Td><StageBadge stage={d.deal_stage} /></Td>
                      <Td>{d.target_amc_tier ?? "—"}</Td>
                      <Td>{d.deal_size_rupees != null ? `₹${formatNumber(d.deal_size_rupees)}` : "—"}</Td>
                      <Td>{d.probability_pct != null ? `${d.probability_pct}%` : "—"}</Td>
                      <Td>{d.deal_size_rupees != null && d.probability_pct != null ? `₹${formatNumber(weighted)}` : "—"}</Td>
                      <Td>{d.expected_close_date ?? "—"}</Td>
                      <Td>{dealContacts.length}</Td>
                      <Td style={{ color: "#777" }}>{new Date(d.updated_at).toLocaleDateString()}</Td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, margin: "0 0 10px 0" }}>
          Contacts by deal ({cs.length})
        </h2>
        <div style={{ display: "grid", gap: 12 }}>
          {ds.length === 0 ? (
            <div style={{ padding: 16, color: "#999", fontSize: 13, border: "1px dashed #eee", borderRadius: 8 }}>
              No deals — add deals to register contacts.
            </div>
          ) : (
            ds
              .filter((d) => (contactsByDeal.get(d.id) ?? []).length > 0)
              .slice(0, 10)
              .map((d) => {
                const list = contactsByDeal.get(d.id) ?? [];
                return (
                  <div key={d.id} style={{ border: "1px solid #eee", borderRadius: 8, padding: 12 }}>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
                      <strong style={{ fontSize: 13 }}>{d.deal_label}</strong>
                      <span style={{ fontSize: 11, color: "#666" }}>
                        {STAGE_LABEL[d.deal_stage] ?? d.deal_stage} · {list.length} contact{list.length === 1 ? "" : "s"}
                      </span>
                    </div>
                    <div style={{ overflowX: "auto" }}>
                      <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 12 }}>
                        <thead style={{ background: "#fafafa" }}>
                          <tr>
                            <Th>Name</Th>
                            <Th>Role</Th>
                            <Th>Sentiment</Th>
                            <Th>Email</Th>
                            <Th>Phone</Th>
                          </tr>
                        </thead>
                        <tbody>
                          {list.map((c) => (
                            <tr key={c.id} style={{ borderTop: "1px solid #f5f5f5" }}>
                              <Td>{c.contact_name}</Td>
                              <Td><RoleBadge role={c.contact_role} /></Td>
                              <Td><SentimentBadge sentiment={c.sentiment} /></Td>
                              <Td style={{ color: "#666" }}>{c.contact_email ?? "—"}</Td>
                              <Td style={{ color: "#666" }}>{c.contact_phone ?? "—"}</Td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                );
              })
          )}
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, margin: "0 0 10px 0" }}>
          Activity feed ({as.length})
        </h2>
        <div style={{ overflowX: "auto", border: "1px solid #eee", borderRadius: 8 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#fafafa" }}>
              <tr>
                <Th>When</Th>
                <Th>Kind</Th>
                <Th>Deal</Th>
                <Th>Description</Th>
              </tr>
            </thead>
            <tbody>
              {as.length === 0 ? (
                <tr>
                  <td colSpan={4} style={{ padding: 16, textAlign: "center", color: "#999" }}>No activities yet.</td>
                </tr>
              ) : (
                as.map((a) => {
                  const dealLabel = ds.find((d) => d.id === a.deal_id)?.deal_label ?? a.deal_id.slice(0, 8);
                  return (
                    <tr key={a.id} style={{ borderTop: "1px solid #f0f0f0" }}>
                      <Td style={{ color: "#777", whiteSpace: "nowrap" }}>{new Date(a.happened_at).toLocaleString()}</Td>
                      <Td><KindBadge kind={a.activity_kind} /></Td>
                      <Td>{dealLabel}</Td>
                      <Td style={{ color: "#444" }}>{a.description ?? "—"}</Td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: "1px solid #eee", borderRadius: 8, padding: "10px 12px", background: "#fff" }}>
      <div style={{ fontSize: 11, color: "#888", textTransform: "uppercase", letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Th({ children }: { children: React.ReactNode }) {
  return <th style={{ textAlign: "left", padding: "8px 10px", fontWeight: 600, color: "#444", fontSize: 12 }}>{children}</th>;
}

function Td({ children, style }: { children: React.ReactNode; style?: React.CSSProperties }) {
  return <td style={{ padding: "8px 10px", verticalAlign: "top", ...(style ?? {}) }}>{children}</td>;
}

function StageBadge({ stage }: { stage: string }) {
  const color =
    stage === "closed_won" ? "#0a7d2b" :
    stage === "closed_lost" ? "#a40000" :
    stage === "on_hold" ? "#777" :
    stage === "negotiation" ? "#b25c00" :
    stage === "proposal_sent" ? "#7a4dbd" :
    stage === "contracted" ? "#005b9f" :
    "#444";
  return (
    <span style={{ fontSize: 11, padding: "2px 8px", borderRadius: 999, background: "#f5f5f7", color, border: `1px solid ${color}22` }}>
      {STAGE_LABEL[stage] ?? stage}
    </span>
  );
}

function RoleBadge({ role }: { role: string }) {
  const labels: Record<string, string> = {
    decision_maker: "Decision maker",
    influencer: "Influencer",
    user: "User",
    sponsor: "Sponsor",
    blocker: "Blocker",
    gatekeeper: "Gatekeeper",
  };
  const color = role === "blocker" ? "#a40000" : role === "decision_maker" ? "#005b9f" : "#444";
  return (
    <span style={{ fontSize: 11, padding: "2px 8px", borderRadius: 999, background: "#f5f5f7", color }}>
      {labels[role] ?? role}
    </span>
  );
}

function SentimentBadge({ sentiment }: { sentiment: string }) {
  const color =
    sentiment === "champion" ? "#0a7d2b" :
    sentiment === "supportive" ? "#3d8b3d" :
    sentiment === "neutral" ? "#777" :
    sentiment === "skeptical" ? "#b25c00" :
    sentiment === "opposed" ? "#a40000" :
    "#444";
  return (
    <span style={{ fontSize: 11, padding: "2px 8px", borderRadius: 999, background: "#f5f5f7", color }}>
      {SENTIMENT_LABEL[sentiment] ?? sentiment}
    </span>
  );
}

function KindBadge({ kind }: { kind: string }) {
  const labels: Record<string, string> = {
    email: "Email",
    call: "Call",
    meeting: "Meeting",
    demo: "Demo",
    proposal_sent: "Proposal sent",
    contract_sent: "Contract sent",
    site_visit: "Site visit",
    stakeholder_intro: "Stakeholder intro",
  };
  return (
    <span style={{ fontSize: 11, padding: "2px 8px", borderRadius: 999, background: "#eef3fb", color: "#234" }}>
      {labels[kind] ?? kind}
    </span>
  );
}
