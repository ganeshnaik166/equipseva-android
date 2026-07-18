import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Customer loyalty points redemption — r2524" };
export const dynamic = "force-dynamic";

type RedemptionRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  redemption_at: string;
  points_redeemed: number;
  redemption_kind: string;
  satisfaction_score: number;
  owner_email: string | null;
  status: string;
  notes: string | null;
};

type RepeatMetricRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  period_start: string;
  period_end: string;
  total_redemptions: number;
  total_points_redeemed: number;
  avg_satisfaction: number;
  repeat_redeem_rate_pct: number;
  status: string;
  notes: string | null;
};

type TopHospitalRow = {
  hospital_user_id: string;
  hospital_email: string | null;
  redemption_count: number;
  total_points: number;
  avg_satisfaction: number;
  last_redemption_at: string | null;
};

type KindBreakdownRow = {
  redemption_kind: string;
  redemption_count: number;
  total_points: number;
  avg_satisfaction: number;
  fulfilled_count: number;
};

type SatisfactionBucketRow = {
  bucket: string;
  redemption_count: number;
  total_points: number;
};

type MonthlyTrendRow = {
  month_start: string;
  redemption_count: number;
  total_points: number;
  avg_satisfaction: number;
};

type ChampionFocusRow = {
  hospital_user_id: string;
  hospital_email: string | null;
  status: string;
  total_redemptions: number;
  total_points_redeemed: number;
  avg_satisfaction: number;
  repeat_redeem_rate_pct: number;
  notes: string | null;
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
  if (status === "fulfilled" || status === "champion") return "text-emerald-700";
  if (status === "pending" || status === "monitoring") return "text-amber-700";
  if (status === "at_risk") return "text-rose-700";
  if (status === "cancelled" || status === "expired") return "text-gray-500";
  return "";
}

export default async function FounderCustomerLoyaltyPointsRedemptionPage() {
  const sb = await getSupabaseServerClient();
  const [
    redemptionsRes,
    metricsRes,
    topHospitalsRes,
    kindRes,
    satisfactionRes,
    trendRes,
    championRes,
  ] = await Promise.all([
    sb.rpc("list_redemptions_r2524"),
    sb.rpc("list_repeat_metrics_r2524"),
    sb.rpc("top_redeeming_hospitals_r2524"),
    sb.rpc("kind_breakdown_r2524"),
    sb.rpc("satisfaction_distribution_r2524"),
    sb.rpc("monthly_redemption_trend_r2524"),
    sb.rpc("champion_focus_r2524"),
  ]);

  if (redemptionsRes.error) throw new Error(`list_redemptions_r2524: ${redemptionsRes.error.message}`);
  if (metricsRes.error) throw new Error(`list_repeat_metrics_r2524: ${metricsRes.error.message}`);
  if (topHospitalsRes.error) throw new Error(`top_redeeming_hospitals_r2524: ${topHospitalsRes.error.message}`);
  if (kindRes.error) throw new Error(`kind_breakdown_r2524: ${kindRes.error.message}`);
  if (satisfactionRes.error) throw new Error(`satisfaction_distribution_r2524: ${satisfactionRes.error.message}`);
  if (trendRes.error) throw new Error(`monthly_redemption_trend_r2524: ${trendRes.error.message}`);
  if (championRes.error) throw new Error(`champion_focus_r2524: ${championRes.error.message}`);

  const redemptions = (redemptionsRes.data ?? []) as RedemptionRow[];
  const metrics = (metricsRes.data ?? []) as RepeatMetricRow[];
  const topHospitals = (topHospitalsRes.data ?? []) as TopHospitalRow[];
  const kindRows = (kindRes.data ?? []) as KindBreakdownRow[];
  const satisfactionRows = (satisfactionRes.data ?? []) as SatisfactionBucketRow[];
  const trendRows = (trendRes.data ?? []) as MonthlyTrendRow[];
  const champions = (championRes.data ?? []) as ChampionFocusRow[];

  const totalRedemptions = redemptions.length;
  const fulfilledCount = redemptions.filter((r) => r.status === "fulfilled").length;
  const pendingCount = redemptions.filter((r) => r.status === "pending").length;
  const cancelledCount = redemptions.filter((r) => r.status === "cancelled").length;
  const totalPoints = redemptions.reduce((a, r) => a + (r.points_redeemed || 0), 0);
  const avgSat =
    redemptions.length === 0
      ? 0
      : redemptions.reduce((a, r) => a + (r.satisfaction_score || 0), 0) / redemptions.length;

  const championCount = metrics.filter((m) => m.status === "champion").length;
  const atRiskCount = metrics.filter((m) => m.status === "at_risk").length;
  const monitoringCount = metrics.filter((m) => m.status === "monitoring").length;

  const redemptionColumns: Column<RedemptionRow>[] = [
    { key: "hospital_email", header: "Hospital", render: (r: any) => <span className="font-medium">{r.hospital_email ?? "—"}</span> },
    { key: "redemption_at", header: "When", render: (r: any) => fmtDate(r.redemption_at) },
    { key: "redemption_kind", header: "Kind", render: (r: any) => r.redemption_kind },
    { key: "points_redeemed", header: "Points", render: (r: any) => String(r.points_redeemed) },
    { key: "satisfaction_score", header: "CSAT", render: (r: any) => `${r.satisfaction_score}/10` },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const metricColumns: Column<RepeatMetricRow>[] = [
    { key: "hospital_email", header: "Hospital", render: (r: any) => <span className="font-medium">{r.hospital_email ?? "—"}</span> },
    { key: "period", header: "Period", render: (r: any) => `${fmtDate(r.period_start)} → ${fmtDate(r.period_end)}` },
    { key: "total_redemptions", header: "Redemptions", render: (r: any) => String(r.total_redemptions) },
    { key: "total_points_redeemed", header: "Points", render: (r: any) => String(r.total_points_redeemed) },
    { key: "avg_satisfaction", header: "Avg CSAT", render: (r: any) => Number(r.avg_satisfaction).toFixed(2) },
    { key: "repeat_redeem_rate_pct", header: "Repeat %", render: (r: any) => `${Number(r.repeat_redeem_rate_pct).toFixed(2)}%` },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const topHospitalColumns: Column<TopHospitalRow>[] = [
    { key: "hospital_email", header: "Hospital", render: (r: any) => <span className="font-medium">{r.hospital_email ?? "—"}</span> },
    { key: "redemption_count", header: "Count", render: (r: any) => String(r.redemption_count) },
    { key: "total_points", header: "Points", render: (r: any) => String(r.total_points) },
    { key: "avg_satisfaction", header: "Avg CSAT", render: (r: any) => Number(r.avg_satisfaction).toFixed(2) },
    { key: "last_redemption_at", header: "Last", render: (r: any) => fmtDate(r.last_redemption_at) },
  ];

  const kindColumns: Column<KindBreakdownRow>[] = [
    { key: "redemption_kind", header: "Kind", render: (r: any) => <span className="font-medium">{r.redemption_kind}</span> },
    { key: "redemption_count", header: "Count", render: (r: any) => String(r.redemption_count) },
    { key: "total_points", header: "Points", render: (r: any) => String(r.total_points) },
    { key: "avg_satisfaction", header: "Avg CSAT", render: (r: any) => Number(r.avg_satisfaction).toFixed(2) },
    { key: "fulfilled_count", header: "Fulfilled", render: (r: any) => String(r.fulfilled_count) },
  ];

  const satisfactionColumns: Column<SatisfactionBucketRow>[] = [
    { key: "bucket", header: "Bucket", render: (r: any) => <span className="font-medium">{r.bucket}</span> },
    { key: "redemption_count", header: "Count", render: (r: any) => String(r.redemption_count) },
    { key: "total_points", header: "Points", render: (r: any) => String(r.total_points) },
  ];

  const trendColumns: Column<MonthlyTrendRow>[] = [
    { key: "month_start", header: "Month", render: (r: any) => fmtDate(r.month_start) },
    { key: "redemption_count", header: "Count", render: (r: any) => String(r.redemption_count) },
    { key: "total_points", header: "Points", render: (r: any) => String(r.total_points) },
    { key: "avg_satisfaction", header: "Avg CSAT", render: (r: any) => Number(r.avg_satisfaction).toFixed(2) },
  ];

  const championColumns: Column<ChampionFocusRow>[] = [
    { key: "hospital_email", header: "Hospital", render: (r: any) => <span className="font-medium">{r.hospital_email ?? "—"}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "total_redemptions", header: "Redemptions", render: (r: any) => String(r.total_redemptions) },
    { key: "total_points_redeemed", header: "Points", render: (r: any) => String(r.total_points_redeemed) },
    { key: "avg_satisfaction", header: "Avg CSAT", render: (r: any) => Number(r.avg_satisfaction).toFixed(2) },
    { key: "repeat_redeem_rate_pct", header: "Repeat %", render: (r: any) => `${Number(r.repeat_redeem_rate_pct).toFixed(2)}%` },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Customer loyalty points redemption — r2524</h1>
        <p className="mt-1 text-xs text-gray-500">
          Hospital & loyalty point redemptions: kind &gt; satisfaction &gt; repeat-redeem rate. Identify champions
          to spotlight & at-risk hospitals to re-engage.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-[11px] uppercase tracking-wide text-gray-500">Redemptions</div>
          <div className="mt-1 text-lg font-semibold">{totalRedemptions}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-[11px] uppercase tracking-wide text-gray-500">Fulfilled</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{fulfilledCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-[11px] uppercase tracking-wide text-gray-500">Pending</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{pendingCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-[11px] uppercase tracking-wide text-gray-500">Cancelled</div>
          <div className="mt-1 text-lg font-semibold text-gray-500">{cancelledCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-[11px] uppercase tracking-wide text-gray-500">Total points</div>
          <div className="mt-1 text-lg font-semibold">{totalPoints}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-[11px] uppercase tracking-wide text-gray-500">Avg CSAT</div>
          <div className="mt-1 text-lg font-semibold">{avgSat.toFixed(2)}</div>
        </div>
      </section>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-3">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-[11px] uppercase tracking-wide text-gray-500">Champions</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{championCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-[11px] uppercase tracking-wide text-gray-500">At risk</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{atRiskCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-[11px] uppercase tracking-wide text-gray-500">Monitoring</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{monitoringCount}</div>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Champion & at-risk focus</h2>
        <DataTable
          rows={champions}
          columns={championColumns}
          emptyMessage="No champion or at-risk hospitals yet."
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Repeat-redeem metrics</h2>
        <DataTable
          rows={metrics}
          columns={metricColumns}
          emptyMessage="No repeat-redeem metrics yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Top redeeming hospitals</h2>
        <DataTable
          rows={topHospitals}
          columns={topHospitalColumns}
          emptyMessage="No redeeming hospitals yet."
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <div>
          <h2 className="mb-2 text-sm font-semibold">Redemption kind breakdown</h2>
          <DataTable
            rows={kindRows}
            columns={kindColumns}
            emptyMessage="No redemptions yet."
            rowKey={(r: any, i: number) => String(r.redemption_kind ?? i)}
          />
        </div>
        <div>
          <h2 className="mb-2 text-sm font-semibold">Satisfaction distribution</h2>
          <DataTable
            rows={satisfactionRows}
            columns={satisfactionColumns}
            emptyMessage="No satisfaction data yet."
            rowKey={(r: any, i: number) => String(r.bucket ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Monthly redemption trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendColumns}
          emptyMessage="No monthly trend data yet."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">All redemptions</h2>
        <DataTable
          rows={redemptions}
          columns={redemptionColumns}
          emptyMessage="No redemptions yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
