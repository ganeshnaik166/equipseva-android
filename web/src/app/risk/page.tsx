import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRelativeTime, formatRupees, shortId } from "@/lib/format";
import { RiskActions } from "./RiskActions";

export const metadata = { title: "Risk — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type CollusionFlag = {
  id: string;
  engineer_email: string | null;
  hospital_email: string | null;
  signal_kind: string;
  job_count_30d: number | null;
  total_value_rupees_30d: number | null;
  evidence: unknown;
  created_at: string;
};

type DuplicateFlag = {
  id: string;
  user_id_a: string;
  email_a: string | null;
  user_id_b: string;
  email_b: string | null;
  signal_kind: string;
  severity: string;
  evidence: unknown;
  created_at: string;
};

export default async function RiskPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [collusionRes, duplicateRes] = await Promise.all([
    supabase.rpc("founder_open_collusion_flags", { p_limit: 50 }),
    supabase.rpc("founder_open_duplicate_flags", { p_limit: 100 }),
  ]);
  if (collusionRes.error) {
    throw new Error(`founder_open_collusion_flags failed: ${collusionRes.error.message}`);
  }
  if (duplicateRes.error) {
    throw new Error(`founder_open_duplicate_flags failed: ${duplicateRes.error.message}`);
  }
  const collusionRows = (collusionRes.data ?? []) as CollusionFlag[];
  const duplicateRows = (duplicateRes.data ?? []) as DuplicateFlag[];

  const collusionCols: Column<CollusionFlag>[] = [
    {
      key: "created",
      header: "Detected",
      render: (r) => <span title={r.created_at}>{formatRelativeTime(r.created_at)}</span>,
    },
    { key: "engineer", header: "Engineer", render: (r) => r.engineer_email ?? "—" },
    { key: "hospital", header: "Hospital", render: (r) => r.hospital_email ?? "—" },
    { key: "signal", header: "Signal", render: (r) => r.signal_kind },
    { key: "jobs", header: "Jobs 30d", render: (r) => formatNumber(r.job_count_30d) },
    { key: "value", header: "Value 30d", render: (r) => formatRupees(r.total_value_rupees_30d) },
    {
      key: "evidence",
      header: "Evidence",
      render: (r) => (
        <details>
          <summary className="cursor-pointer text-xs text-[var(--color-muted)]">view</summary>
          <pre className="mt-1 max-w-xs overflow-auto text-xs">
            {JSON.stringify(r.evidence, null, 2)}
          </pre>
        </details>
      ),
    },
    {
      key: "actions",
      header: "Action",
      render: (r) => <RiskActions kind="collusion" flagId={r.id} />,
    },
  ];

  const duplicateCols: Column<DuplicateFlag>[] = [
    {
      key: "created",
      header: "Detected",
      render: (r) => <span title={r.created_at}>{formatRelativeTime(r.created_at)}</span>,
    },
    {
      key: "severity",
      header: "Severity",
      render: (r) => (
        <span
          className={`rounded px-1.5 py-0.5 text-xs ${
            r.severity === "high"
              ? "bg-red-100 text-[var(--color-danger)]"
              : r.severity === "medium"
                ? "bg-yellow-100 text-[var(--color-warn)]"
                : "bg-gray-100"
          }`}
        >
          {r.severity}
        </span>
      ),
    },
    { key: "a", header: "Account A", render: (r) => r.email_a ?? shortId(r.user_id_a) },
    { key: "b", header: "Account B", render: (r) => r.email_b ?? shortId(r.user_id_b) },
    { key: "signal", header: "Signal", render: (r) => r.signal_kind },
    {
      key: "evidence",
      header: "Evidence",
      render: (r) => (
        <details>
          <summary className="cursor-pointer text-xs text-[var(--color-muted)]">view</summary>
          <pre className="mt-1 max-w-xs overflow-auto text-xs">
            {JSON.stringify(r.evidence, null, 2)}
          </pre>
        </details>
      ),
    },
    {
      key: "actions",
      header: "Action",
      render: (r) => <RiskActions kind="duplicate" flagId={r.id} />,
    },
  ];

  return (
    <div className="space-y-8">
      <header>
        <h1 className="text-xl font-semibold">Risk flags</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Open alerts from the collusion + duplicate-account detectors (r498 + r501).
          Acting here writes to <code>founder_action_log</code> via SECDEF RPCs.
        </p>
      </header>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Collusion pairs <span className="text-[var(--color-muted)]">({collusionRows.length})</span>
        </h2>
        <DataTable
          columns={collusionCols}
          rows={collusionRows}
          rowKey={(r) => r.id}
          emptyMessage="No open collusion flags."
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Duplicate accounts <span className="text-[var(--color-muted)]">({duplicateRows.length})</span>
        </h2>
        <DataTable
          columns={duplicateCols}
          rows={duplicateRows}
          rowKey={(r) => r.id}
          emptyMessage="No open duplicate flags."
        />
      </section>
    </div>
  );
}
