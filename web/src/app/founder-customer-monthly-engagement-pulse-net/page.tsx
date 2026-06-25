import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder customer monthly engagement pulse net — r2648" };
export const dynamic = "force-dynamic";

type PulseRow = {
  id: string;
  month_label: string;
  touches_made: number;
  touches_responded: number;
  engagement_score: number;
  sentiment_kind: string;
  retention_risk_kind: string;
  owner_email: string | null;
  status: string;
  notes: string | null;
  created_at: string;
};

type ActionRow = {
  id: string;
  pulse_id: string;
  action_at: string;
  action_kind: string;
  outcome: string;
  owner_email: string | null;
  status: string;
  notes: string | null;
  created_at: string;
};

type AtRiskRow = {
  id: string;
  month_label: string;
  engagement_score: number;
  sentiment_kind: string;
  retention_risk_kind: string;
  owner_email: string | null;
  status: string;
};

type SentimentRow = {
  sentiment_kind: string;
  pulse_count: number;
  avg_engagement_score: number;
};

type StatusRow = {
  status: string;
  pulse_count: number;
};

type TrendRow = {
  month_bucket: string;
  pulse_count: number;
  avg_engagement_score: number;
};

type OwnerRow = {
  owner_email: string;
  pulse_count: number;
  at_risk_count: number;
  champion_count: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function statusBadge(status: string): string {
  if (status === "champion") return "text-emerald-700";
  if (status === "monitoring") return "text-sky-700";
  if (status === "at_risk") return "text-amber-700";
  if (status === "lost") return "text-rose-700";
  return "";
}

function riskBadge(risk: string): string {
  if (risk === "low") return "text-emerald-700";
  if (risk === "medium") return "text-amber-700";
  if (risk === "high") return "text-orange-700";
  if (risk === "critical") return "text-rose-700";
  return "";
}

function sentimentBadge(s: string): string {
  if (s === "positive") return "text-emerald-700";
  if (s === "neutral") return "text-gray-700";
  if (s === "negative") return "text-rose-700";
  return "";
}

export default async function FounderCustomerMonthlyEngagementPulseNetPage() {
  const sb = await getSupabaseServerClient();
  const [pulsesRes, actionsRes, atRiskRes, sentimentRes, statusRes, trendRes, ownerRes] = await Promise.all([
    sb.rpc("list_engagement_r2648"),
    sb.rpc("list_action_outcomes_r2648"),
    sb.rpc("top_at_risk_focus_r2648"),
    sb.rpc("sentiment_distribution_r2648"),
    sb.rpc("status_funnel_r2648"),
    sb.rpc("monthly_engagement_trend_r2648"),
    sb.rpc("owner_load_r2648"),
  ]);

  if (pulsesRes.error) throw new Error(`list_engagement_r2648: ${pulsesRes.error.message}`);
  if (actionsRes.error) throw new Error(`list_action_outcomes_r2648: ${actionsRes.error.message}`);
  if (atRiskRes.error) throw new Error(`top_at_risk_focus_r2648: ${atRiskRes.error.message}`);
  if (sentimentRes.error) throw new Error(`sentiment_distribution_r2648: ${sentimentRes.error.message}`);
  if (statusRes.error) throw new Error(`status_funnel_r2648: ${statusRes.error.message}`);
  if (trendRes.error) throw new Error(`monthly_engagement_trend_r2648: ${trendRes.error.message}`);
  if (ownerRes.error) throw new Error(`owner_load_r2648: ${ownerRes.error.message}`);

  const pulses = (pulsesRes.data ?? []) as PulseRow[];
  const actions = (actionsRes.data ?? []) as ActionRow[];
  const atRisk = (atRiskRes.data ?? []) as AtRiskRow[];
  const sentiment = (sentimentRes.data ?? []) as SentimentRow[];
  const statusFunnel = (statusRes.data ?? []) as StatusRow[];
  const trend = (trendRes.data ?? []) as TrendRow[];
  const owners = (ownerRes.data ?? []) as OwnerRow[];

  const totalPulses = pulses.length;
  const championCount = pulses.filter((p) => p.status === "champion").length;
  const atRiskCount = pulses.filter((p) => p.status === "at_risk").length;
  const lostCount = pulses.filter((p) => p.status === "lost").length;
  const avgScore = totalPulses > 0
    ? Math.round(pulses.reduce((acc, p) => acc + (p.engagement_score ?? 0), 0) / totalPulses)
    : 0;

  const pulseColumns: Column<PulseRow>[] = [
    { key: "month_label", header: "Month", render: (r: any) => <span className="font-medium">{r.month_label}</span> },
    { key: "engagement_score", header: "Score", render: (r: any) => r.engagement_score },
    { key: "touches_made", header: "Touches", render: (r: any) => `${r.touches_responded}/${r.touches_made}` },
    { key: "sentiment_kind", header: "Sentiment", render: (r: any) => <span className={sentimentBadge(r.sentiment_kind)}>{r.sentiment_kind}</span> },
    { key: "retention_risk_kind", header: "Risk", render: (r: any) => <span className={riskBadge(r.retention_risk_kind)}>{r.retention_risk_kind}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
    { key: "created_at", header: "Created", render: (r: any) => fmtDate(r.created_at) },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: "action_at", header: "When", render: (r: any) => fmtDate(r.action_at) },
    { key: "action_kind", header: "Kind", render: (r: any) => <span className="font-medium">{r.action_kind}</span> },
    { key: "outcome", header: "Outcome", render: (r: any) => r.outcome },
    { key: "status", header: "Status", render: (r: any) => r.status },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const atRiskColumns: Column<AtRiskRow>[] = [
    { key: "month_label", header: "Month", render: (r: any) => r.month_label },
    { key: "engagement_score", header: "Score", render: (r: any) => r.engagement_score },
    { key: "sentiment_kind", header: "Sentiment", render: (r: any) => <span className={sentimentBadge(r.sentiment_kind)}>{r.sentiment_kind}</span> },
    { key: "retention_risk_kind", header: "Risk", render: (r: any) => <span className={riskBadge(r.retention_risk_kind)}>{r.retention_risk_kind}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
  ];

  const sentimentColumns: Column<SentimentRow>[] = [
    { key: "sentiment_kind", header: "Sentiment", render: (r: any) => <span className={sentimentBadge(r.sentiment_kind)}>{r.sentiment_kind}</span> },
    { key: "pulse_count", header: "Pulses", render: (r: any) => r.pulse_count },
    { key: "avg_engagement_score", header: "Avg score", render: (r: any) => Number(r.avg_engagement_score).toFixed(1) },
  ];

  const statusColumns: Column<StatusRow>[] = [
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "pulse_count", header: "Count", render: (r: any) => r.pulse_count },
  ];

  const trendColumns: Column<TrendRow>[] = [
    { key: "month_bucket", header: "Month", render: (r: any) => r.month_bucket },
    { key: "pulse_count", header: "Pulses", render: (r: any) => r.pulse_count },
    { key: "avg_engagement_score", header: "Avg score", render: (r: any) => Number(r.avg_engagement_score).toFixed(1) },
  ];

  const ownerColumns: Column<OwnerRow>[] = [
    { key: "owner_email", header: "Owner", render: (r: any) => <span className="font-medium">{r.owner_email}</span> },
    { key: "pulse_count", header: "Pulses", render: (r: any) => r.pulse_count },
    { key: "at_risk_count", header: "At risk", render: (r: any) => r.at_risk_count },
    { key: "champion_count", header: "Champions", render: (r: any) => r.champion_count },
  ];

  return (
    <main className="p-6 space-y-6 max-w-7xl mx-auto">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Customer monthly engagement pulse net</h1>
        <p className="text-sm text-gray-600">Round 2648 — founder view of monthly customer engagement health, sentiment, retention risk & action outcomes.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total pulses</div>
          <div className="text-xl font-semibold">{totalPulses}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Avg score</div>
          <div className="text-xl font-semibold">{avgScore}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Champions</div>
          <div className="text-xl font-semibold text-emerald-700">{championCount}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">At risk</div>
          <div className="text-xl font-semibold text-amber-700">{atRiskCount}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Lost</div>
          <div className="text-xl font-semibold text-rose-700">{lostCount}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Engagement pulses</h2>
        <DataTable
          rows={pulses}
          columns={pulseColumns}
          emptyMessage="No engagement pulses yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Top at-risk focus</h2>
        <DataTable
          rows={atRisk}
          columns={atRiskColumns}
          emptyMessage="No at-risk customers right now"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Action outcomes</h2>
        <DataTable
          rows={actions}
          columns={actionColumns}
          emptyMessage="No action outcomes logged yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Sentiment distribution</h2>
          <DataTable
            rows={sentiment}
            columns={sentimentColumns}
            emptyMessage="No sentiment data yet"
            rowKey={(r: any, i: number) => String(r.sentiment_kind ?? i)}
          />
        </div>
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Status funnel</h2>
          <DataTable
            rows={statusFunnel}
            columns={statusColumns}
            emptyMessage="No status data yet"
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </div>
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Monthly engagement trend</h2>
          <DataTable
            rows={trend}
            columns={trendColumns}
            emptyMessage="No trend data yet"
            rowKey={(r: any, i: number) => String(r.month_bucket ?? i)}
          />
        </div>
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Owner load</h2>
          <DataTable
            rows={owners}
            columns={ownerColumns}
            emptyMessage="No owners assigned yet"
            rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
          />
        </div>
      </section>
    </main>
  );
}
