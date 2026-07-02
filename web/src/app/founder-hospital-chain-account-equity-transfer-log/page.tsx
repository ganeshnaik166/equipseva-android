import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";
export const metadata = { title: "Account Equity Transfer Log — Founder Console" };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [transfersRes, summaryRes, reasonRes, atRiskRes, ownerLoadRes, categoryRes] = await Promise.all([
    supabase.rpc("list_equity_transfers_r2379"),
    supabase.rpc("equity_transfer_summary_r2379"),
    supabase.rpc("equity_transfer_by_reason_r2379"),
    supabase.rpc("equity_transfer_at_risk_r2379"),
    supabase.rpc("equity_transfer_owner_load_r2379"),
    supabase.rpc("equity_kt_category_completion_r2379"),
  ]);

  const transfers = (transfersRes.data ?? []) as any[];
  const summary = ((summaryRes.data ?? [])[0] ?? {}) as any;
  const reasons = (reasonRes.data ?? []) as any[];
  const atRisk = (atRiskRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];
  const categories = (categoryRes.data ?? []) as any[];

  const fmtINR = (v: number | null | undefined) =>
    v == null ? "—" : `₹${(Number(v) / 100000).toFixed(1)}L`;

  const transferCols: Column<any>[] = [
    { key: "chain_name", header: "Chain", render: (r) => r.chain_name ?? "—" },
    { key: "from", header: "From", render: (r) => r.from_owner_email ?? "—" },
    { key: "to", header: "To", render: (r) => r.to_owner_email ?? "—" },
    { key: "reason", header: "Reason", render: (r) => r.transfer_reason ?? "—" },
    { key: "tier", header: "Tier", render: (r) => r.account_tier ?? "—" },
    { key: "arr", header: "ARR", render: (r) => fmtINR(r.account_arr_rupees) },
    { key: "hosp", header: "Hospitals", render: (r) => r.hospitals_in_chain ?? 0 },
    { key: "amc", header: "AMCs", render: (r) => r.amc_contracts_count ?? 0 },
    { key: "pct", header: "Completion", render: (r) => `${r.completion_pct ?? 0}% (${r.completed_items}/${r.total_items})` },
    { key: "crit", header: "Critical Open", render: (r) => r.critical_open ?? 0 },
    { key: "status", header: "Status", render: (r) => r.status ?? "—" },
    { key: "init", header: "Initiated", render: (r) => r.transfer_initiated_at?.slice(0, 10) ?? "—" },
  ];

  const reasonCols: Column<any>[] = [
    { key: "reason", header: "Reason", render: (r) => r.transfer_reason ?? "—" },
    { key: "count", header: "Count", render: (r) => r.transfer_count ?? 0 },
    { key: "arr", header: "Total ARR", render: (r) => fmtINR(r.total_arr_rupees) },
    { key: "avg", header: "Avg Completion", render: (r) => `${r.avg_completion_pct ?? 0}%` },
  ];

  const atRiskCols: Column<any>[] = [
    { key: "chain", header: "Chain", render: (r) => r.chain_name ?? "—" },
    { key: "from", header: "From", render: (r) => r.from_owner_email ?? "—" },
    { key: "to", header: "To", render: (r) => r.to_owner_email ?? "—" },
    { key: "days", header: "Days Open", render: (r) => r.days_open ?? 0 },
    { key: "pct", header: "Completion", render: (r) => `${r.completion_pct ?? 0}%` },
    { key: "crit", header: "Critical Open", render: (r) => r.critical_open ?? 0 },
    { key: "arr", header: "ARR", render: (r) => fmtINR(r.account_arr_rupees) },
  ];

  const ownerCols: Column<any>[] = [
    { key: "owner", header: "Owner", render: (r) => r.owner_email ?? "—" },
    { key: "in", header: "Incoming", render: (r) => r.incoming_count ?? 0 },
    { key: "out", header: "Outgoing", render: (r) => r.outgoing_count ?? 0 },
    { key: "arr", header: "Incoming ARR", render: (r) => fmtINR(r.incoming_arr_rupees) },
  ];

  const categoryCols: Column<any>[] = [
    { key: "cat", header: "Category", render: (r) => r.item_category ?? "—" },
    { key: "total", header: "Total Items", render: (r) => r.total_items ?? 0 },
    { key: "done", header: "Completed", render: (r) => r.completed_items ?? 0 },
    { key: "pct", header: "Completion", render: (r) => `${r.completion_pct ?? 0}%` },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Chain Account-Equity Transfer Log</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Ownership transfers between team members — KT checklist tracking & completion %.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">In Progress</div>
          <div className="text-2xl font-semibold">{summary.in_progress_count ?? 0}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Completed</div>
          <div className="text-2xl font-semibold">{summary.completed_count ?? 0}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">At Risk</div>
          <div className="text-2xl font-semibold">{summary.at_risk_count ?? 0}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">ARR Under Transfer</div>
          <div className="text-2xl font-semibold">{fmtINR(summary.total_arr_under_transfer_rupees)}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Avg Completion</div>
          <div className="text-2xl font-semibold">{summary.avg_completion_pct ?? 0}%</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Avg Days to Complete</div>
          <div className="text-2xl font-semibold">{summary.avg_days_to_complete ?? 0}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Aborted</div>
          <div className="text-2xl font-semibold">{summary.aborted_count ?? 0}</div>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-lg font-medium">All Transfers</h2>
        <DataTable
          columns={transferCols}
          rows={transfers}
          rowKey={(r) => r.id}
          emptyMessage="No transfers logged."
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-medium">At-Risk Transfers (low completion &gt;= 14d open OR critical-open &gt; 0)</h2>
        <DataTable
          columns={atRiskCols}
          rows={atRisk}
          rowKey={(r) => r.id}
          emptyMessage="No at-risk transfers."
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div>
          <h2 className="mb-2 text-lg font-medium">By Transfer Reason</h2>
          <DataTable
            columns={reasonCols}
            rows={reasons}
            rowKey={(r) => r.transfer_reason}
            emptyMessage="No reasons."
          />
        </div>
        <div>
          <h2 className="mb-2 text-lg font-medium">KT Category Completion</h2>
          <DataTable
            columns={categoryCols}
            rows={categories}
            rowKey={(r) => r.item_category}
            emptyMessage="No category data."
          />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-lg font-medium">Owner Load (Incoming & Outgoing)</h2>
        <DataTable
          columns={ownerCols}
          rows={ownerLoad}
          rowKey={(r, i) => `${r.owner_email}-${i}`}
          emptyMessage="No owner load data."
        />
      </section>
    </div>
  );
}
