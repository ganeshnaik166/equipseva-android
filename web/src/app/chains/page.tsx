import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime, shortId } from "@/lib/format";
import { ChainForm } from "./ChainForm";

export const metadata = { title: "Hospital chains — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type ChainRow = {
  id: string;
  name: string;
  billing_gstin: string | null;
  primary_admin_user_id: string;
  primary_admin_email: string | null;
  status: string;
  member_count: number | null;
  pending_invite_count: number | null;
  contracted_at: string | null;
  created_at: string;
};

export default async function ChainsPage({
  searchParams,
}: {
  searchParams?: Promise<{ status?: string }>;
}) {
  await requireFounder();
  const params = (await searchParams) ?? {};
  const statusFilter = params.status ?? "all";

  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_list_hospital_chains", {
    p_status: statusFilter === "all" ? null : statusFilter,
    p_limit: 200,
  });
  if (error) throw new Error(`founder_list_hospital_chains: ${error.message}`);
  const rows = (data ?? []) as ChainRow[];

  const activeCount = rows.filter((r) => r.status === "active").length;
  const totalMembers = rows.reduce((s, r) => s + (r.member_count ?? 0), 0);
  const totalPendingInvites = rows.reduce((s, r) => s + (r.pending_invite_count ?? 0), 0);

  const STATUSES = ["all", "active", "paused", "offboarded"];

  const cols: Column<ChainRow>[] = [
    {
      key: "name",
      header: "Chain",
      render: (r) => (
        <Link href={`/chains/${r.id}`} className="block hover:underline">
          <div className="font-medium text-[var(--color-accent)]">{r.name}</div>
          <div className="text-xs text-[var(--color-muted)]">{shortId(r.id)}</div>
        </Link>
      ),
    },
    {
      key: "admin",
      header: "Primary admin",
      render: (r) => (
        <Link
          href={`/hospitals/${r.primary_admin_user_id}`}
          className="text-[var(--color-accent)] hover:underline"
        >
          {r.primary_admin_email ?? shortId(r.primary_admin_user_id)}
        </Link>
      ),
    },
    {
      key: "gstin",
      header: "GSTIN",
      render: (r) => (
        <code className="text-xs">{r.billing_gstin ?? "—"}</code>
      ),
    },
    {
      key: "status",
      header: "Status",
      render: (r) => {
        const cls =
          r.status === "active"
            ? "bg-green-100 text-[var(--color-ok)]"
            : r.status === "paused"
              ? "bg-yellow-100 text-[var(--color-warn)]"
              : "bg-gray-100";
        return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{r.status}</span>;
      },
    },
    {
      key: "members",
      header: "Members",
      render: (r) => formatNumber(r.member_count),
    },
    {
      key: "pending",
      header: "Pending invites",
      render: (r) => (
        <span
          className={(r.pending_invite_count ?? 0) > 0 ? "font-medium text-[var(--color-warn)]" : ""}
        >
          {formatNumber(r.pending_invite_count)}
        </span>
      ),
    },
    {
      key: "contracted",
      header: "Contracted",
      render: (r) => formatRelativeTime(r.contracted_at),
    },
    {
      key: "created",
      header: "Created",
      render: (r) => formatRelativeTime(r.created_at),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospital chains</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {rows.length} match{rows.length === 1 ? "" : "es"}
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Active chains" value={formatNumber(activeCount)} tone="ok" />
          <StatCard label="Total chains" value={formatNumber(rows.length)} />
          <StatCard label="Total members" value={formatNumber(totalMembers)} />
          <StatCard
            label="Pending invites"
            value={formatNumber(totalPendingInvites)}
            tone={totalPendingInvites > 0 ? "warn" : "ok"}
          />
        </div>
      </section>

      <ChainForm />

      <nav className="flex flex-wrap gap-2 text-sm">
        {STATUSES.map((s) => (
          <a
            key={s}
            href={`/chains?status=${s}`}
            className={`rounded border px-2 py-1 ${
              s === statusFilter
                ? "border-[var(--color-fg)] bg-[var(--color-fg)] text-white"
                : "border-[var(--color-border)] hover:bg-gray-50"
            }`}
          >
            {s}
          </a>
        ))}
      </nav>

      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.id}
        emptyMessage={
          statusFilter === "all"
            ? "No chains yet — register one above."
            : `No chains with status="${statusFilter}".`
        }
      />

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Chain admin invitations + member management land in v0.5 Phase 1 #2 once the first
        chain is registered. Backend RPCs <code>chain_admin_invite_site</code> +{" "}
        <code>accept_hospital_chain_invite</code> are already live (r544).
      </section>
    </div>
  );
}
