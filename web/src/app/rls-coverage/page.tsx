import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "RLS coverage — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  table_name: string;
  rls_enabled: boolean;
  policy_count: number;
  anon_select: boolean;
  anon_insert: boolean;
  authenticated_select: boolean;
  authenticated_insert: boolean;
  risk_score: number;
};

export default async function RlsCoveragePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_rls_coverage");
  if (error) throw new Error(`founder_rls_coverage: ${error.message}`);

  const rows = (data ?? []) as Row[];
  const noRlsCount = rows.filter((r) => !r.rls_enabled).length;
  const anonReadable = rows.filter((r) => r.anon_select).length;
  const anonWritable = rows.filter((r) => r.anon_insert).length;
  const noPolicies = rows.filter((r) => r.policy_count === 0 && r.rls_enabled).length;

  const cols: Column<Row>[] = [
    {
      key: "name",
      header: "Table",
      render: (r) => <code className="text-xs">{r.table_name}</code>,
    },
    {
      key: "rls",
      header: "RLS",
      render: (r) =>
        r.rls_enabled ? (
          <span className="rounded bg-green-50 px-1.5 py-0.5 text-xs text-[var(--color-ok)]">
            on
          </span>
        ) : (
          <span className="rounded bg-red-100 px-1.5 py-0.5 text-xs text-[var(--color-danger)]">
            OFF
          </span>
        ),
    },
    {
      key: "policies",
      header: "Policies",
      render: (r) => (
        <span
          className={`text-xs tabular-nums ${
            r.policy_count === 0 ? "text-[var(--color-warn)]" : ""
          }`}
        >
          {r.policy_count}
        </span>
      ),
    },
    {
      key: "anon",
      header: "anon",
      render: (r) => (
        <span className="text-xs">
          {r.anon_select && "S "}
          {r.anon_insert && (
            <span className="text-[var(--color-danger)]">I</span>
          )}
          {!r.anon_select && !r.anon_insert && (
            <span className="text-[var(--color-muted)]">—</span>
          )}
        </span>
      ),
    },
    {
      key: "auth",
      header: "auth",
      render: (r) => (
        <span className="text-xs">
          {r.authenticated_select && "S "}
          {r.authenticated_insert && "I"}
          {!r.authenticated_select && !r.authenticated_insert && (
            <span className="text-[var(--color-muted)]">—</span>
          )}
        </span>
      ),
    },
    {
      key: "risk",
      header: "Risk",
      render: (r) => {
        const tone =
          r.risk_score >= 100
            ? "bg-red-100 text-[var(--color-danger)]"
            : r.risk_score >= 50
              ? "bg-yellow-100 text-[var(--color-warn)]"
              : r.risk_score > 0
                ? "bg-orange-50"
                : "bg-gray-50 text-[var(--color-muted)]";
        return (
          <span className={`rounded px-1.5 py-0.5 text-xs tabular-nums font-semibold ${tone}`}>
            {r.risk_score}
          </span>
        );
      },
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">RLS coverage</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {rows.length} public tables · sorted by risk
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="Tables without RLS"
            value={formatNumber(noRlsCount)}
            tone={noRlsCount > 0 ? "danger" : "ok"}
          />
          <StatCard
            label="RLS-on but no policies"
            value={formatNumber(noPolicies)}
            tone={noPolicies > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="anon-readable"
            value={formatNumber(anonReadable)}
            tone={anonReadable > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="anon-writable"
            value={formatNumber(anonWritable)}
            tone={anonWritable > 0 ? "danger" : "ok"}
          />
        </div>
      </section>

      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.table_name}
        emptyMessage="No public tables."
      />

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>r603 RLS coverage check.</strong> Risk score breakdown: <code>100</code> = RLS
        OFF + no policies + readable by anon or authenticated (worst-case). <code>+50</code> = RLS
        OFF + writable by anon or authenticated. <code>+20</code> = anon-readable but no
        policy. <code>+10</code> = RLS on but no policy (RLS-on without policies =
        deny-all, which is intentional for SECDEF-only tables, but flag it so we
        can confirm the design is intentional). Columns &quot;S&quot; / &quot;I&quot; in anon/auth
        columns = SELECT / INSERT grants. Each ship that adds a public table
        should leave this table&apos;s top row at risk_score = 0.
      </section>
    </div>
  );
}
