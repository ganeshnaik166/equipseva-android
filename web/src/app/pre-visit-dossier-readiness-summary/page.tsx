import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Pre-visit dossier readiness — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  metric_key: string;
  metric_label: string;
  value_num: number;
  value_display: string;
  bucket: string;
};

function bucketColor(bucket: string): string {
  switch (bucket) {
    case "risk":
      return "text-[var(--color-danger)]";
    case "rate":
      return "text-[var(--color-ok)]";
    case "latency":
      return "text-[var(--color-warn)]";
    case "size":
      return "text-[var(--color-muted)]";
    default:
      return "";
  }
}

export default async function PreVisitDossierReadinessSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc(
    "founder_pre_visit_dossier_readiness_summary"
  );
  if (error)
    throw new Error(
      `founder_pre_visit_dossier_readiness_summary: ${error.message}`
    );
  const rows = (data ?? []) as Row[];

  const cols: Column<Row>[] = [
    {
      key: "b",
      header: "Bucket",
      render: (r) => (
        <span className="text-[10px] font-medium uppercase tracking-wider text-[var(--color-muted)]">
          {r.bucket}
        </span>
      ),
    },
    {
      key: "l",
      header: "Metric",
      render: (r) => <span className="text-xs">{r.metric_label}</span>,
    },
    {
      key: "v",
      header: "Value",
      render: (r) => (
        <span className={`text-xs tabular-nums font-medium ${bucketColor(r.bucket)}`}>
          {r.value_display}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Pre-visit dossier readiness</h1>
        <span className="text-xs text-[var(--color-muted)]">
          PVED quality-prep signal (90d) · gen % · consume % · accept→open p50 · FTFR proxy
        </span>
      </header>
      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.metric_key}
        emptyMessage="No dossier activity in last 90 days."
      />
    </div>
  );
}
