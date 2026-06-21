import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

export default async function FounderDigestAnalyticsPage() {
  const sb = await getSupabaseServerClient();

  const trendRes = await sb.rpc("founder_digest_weekly_trend");
  const summaryRes = await sb.rpc("founder_digest_latest_digest_summary");
  const replyCatRes = await sb.rpc("founder_digest_reply_categorization");
  const recipRes = await sb.rpc("founder_digest_recipient_engagement");
  const linksRes = await sb.rpc("founder_digest_top_clicked_links");
  const dormantRes = await sb.rpc("founder_digest_dormant_recipients");
  const repliesRes = await sb.rpc("founder_digest_recent_replies");

  const trend: any[] = Array.isArray(trendRes.data) ? trendRes.data : [];
  const summary: any[] = Array.isArray(summaryRes.data) ? summaryRes.data : [];
  const replyCat: any[] = Array.isArray(replyCatRes.data) ? replyCatRes.data : [];
  const recipients: any[] = Array.isArray(recipRes.data) ? recipRes.data : [];
  const links: any[] = Array.isArray(linksRes.data) ? linksRes.data : [];
  const dormant: any[] = Array.isArray(dormantRes.data) ? dormantRes.data : [];
  const replies: any[] = Array.isArray(repliesRes.data) ? repliesRes.data : [];

  const latest = summary[0] ?? null;

  const trendCols: Column<any>[] = [
    { key: "week_start", header: "Week", render: (r: any) => String(r.week_start ?? "—") },
    { key: "sent", header: "Sent", render: (r: any) => String(r.sent ?? 0) },
    { key: "opened", header: "Opened", render: (r: any) => String(r.opened ?? 0) },
    { key: "clicked", header: "Clicked", render: (r: any) => String(r.clicked ?? 0) },
    { key: "replied", header: "Replied", render: (r: any) => String(r.replied ?? 0) },
    { key: "open_rate_pct", header: "Open %", render: (r: any) => `${r.open_rate_pct ?? 0}%` },
    { key: "click_rate_pct", header: "Click %", render: (r: any) => `${r.click_rate_pct ?? 0}%` },
    { key: "reply_rate_pct", header: "Reply %", render: (r: any) => `${r.reply_rate_pct ?? 0}%` },
  ];

  const replyCatCols: Column<any>[] = [
    { key: "reply_category", header: "Category", render: (r: any) => String(r.reply_category ?? "—") },
    { key: "reply_count", header: "Replies", render: (r: any) => String(r.reply_count ?? 0) },
    { key: "pct_of_replies", header: "% of replies", render: (r: any) => `${r.pct_of_replies ?? 0}%` },
  ];

  const recipCols: Column<any>[] = [
    { key: "recipient_email", header: "Recipient", render: (r: any) => String(r.recipient_email ?? "—") },
    { key: "recipient_role", header: "Role", render: (r: any) => String(r.recipient_role ?? "—") },
    { key: "digests_received", header: "Sent", render: (r: any) => String(r.digests_received ?? 0) },
    { key: "digests_opened", header: "Opened", render: (r: any) => String(r.digests_opened ?? 0) },
    { key: "digests_clicked", header: "Clicked", render: (r: any) => String(r.digests_clicked ?? 0) },
    { key: "digests_replied", header: "Replied", render: (r: any) => String(r.digests_replied ?? 0) },
    { key: "engagement_score", header: "Score", render: (r: any) => String(r.engagement_score ?? 0) },
    { key: "last_opened_at", header: "Last Open", render: (r: any) => r.last_opened_at ? new Date(r.last_opened_at).toLocaleDateString() : "—" },
  ];

  const linksCols: Column<any>[] = [
    { key: "link_url", header: "Link", render: (r: any) => String(r.link_url ?? "—") },
    { key: "click_count", header: "Clicks", render: (r: any) => String(r.click_count ?? 0) },
    { key: "unique_clickers", header: "Unique", render: (r: any) => String(r.unique_clickers ?? 0) },
  ];

  const dormantCols: Column<any>[] = [
    { key: "recipient_email", header: "Recipient", render: (r: any) => String(r.recipient_email ?? "—") },
    { key: "recipient_role", header: "Role", render: (r: any) => String(r.recipient_role ?? "—") },
    { key: "digests_received", header: "Sent", render: (r: any) => String(r.digests_received ?? 0) },
    { key: "last_opened_at", header: "Last Open", render: (r: any) => r.last_opened_at ? new Date(r.last_opened_at).toLocaleDateString() : "never" },
    { key: "weeks_since_open", header: "Weeks Idle", render: (r: any) => String(r.weeks_since_open ?? 0) },
  ];

  const repliesCols: Column<any>[] = [
    { key: "event_at", header: "When", render: (r: any) => r.event_at ? new Date(r.event_at).toLocaleString() : "—" },
    { key: "recipient_email", header: "From", render: (r: any) => String(r.recipient_email ?? "—") },
    { key: "reply_category", header: "Category", render: (r: any) => String(r.reply_category ?? "—") },
    { key: "reply_excerpt", header: "Excerpt", render: (r: any) => String(r.reply_excerpt ?? "—") },
    { key: "digest_id", header: "Digest", render: (r: any) => String(r.digest_id ?? "—") },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: "0 auto" }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Weekly Digest Analytics</h1>
      <p style={{ color: "#666", marginBottom: 20 }}>
        Open rate, click-through, reply categorization, and per-recipient engagement.
      </p>

      {latest ? (
        <section style={{ marginBottom: 24, padding: 16, background: "#f8fafc", borderRadius: 8 }}>
          <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>
            Latest Digest · week of {String(latest.week_start ?? "—")}
          </h2>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 12 }}>
            <Stat label="Sent" value={String(latest.sent ?? 0)} />
            <Stat label="Open rate" value={`${latest.open_rate_pct ?? 0}%`} />
            <Stat label="Click-through (of opens)" value={`${latest.click_through_pct ?? 0}%`} />
            <Stat label="Replies" value={String(latest.replied ?? 0)} />
          </div>
        </section>
      ) : (
        <p style={{ color: "#999", marginBottom: 24 }}>No digest sent yet.</p>
      )}

      <Section title="12-Week Trend">
        <DataTable
          columns={trendCols}
          rows={trend}
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </Section>

      <Section title="Reply Categorization (12 wks)">
        <DataTable
          columns={replyCatCols}
          rows={replyCat}
          rowKey={(r: any, i: number) => String(r.reply_category ?? i)}
        />
      </Section>

      <Section title="Per-Recipient Engagement Score">
        <DataTable
          columns={recipCols}
          rows={recipients}
          rowKey={(r: any, i: number) => String(r.recipient_email ?? i)}
        />
      </Section>

      <Section title="Top Clicked Links">
        <DataTable
          columns={linksCols}
          rows={links}
          rowKey={(r: any, i: number) => String(r.link_url ?? i)}
        />
      </Section>

      <Section title="Dormant Recipients (no open in 4 wks)">
        <DataTable
          columns={dormantCols}
          rows={dormant}
          rowKey={(r: any, i: number) => String(r.recipient_email ?? i)}
        />
      </Section>

      <Section title="Recent Replies">
        <DataTable
          columns={repliesCols}
          rows={replies}
          rowKey={(r: any, i: number) => String(r.event_at ?? i)}
        />
      </Section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ background: "#fff", padding: 12, borderRadius: 6, border: "1px solid #e5e7eb" }}>
      <div style={{ fontSize: 12, color: "#666" }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
