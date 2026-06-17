import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Grants audit — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  function_name: string;
  authenticated: boolean;
  service_role: boolean;
  anon: boolean;
  arg_signature: string;
};

export default async function GrantsAuditPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_grants_audit");
  if (error) throw new Error(`founder_grants_audit: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const broken = rows.filter((r) => !r.authenticated && r.service_role);
  const total = rows.length;

  const cols: Column<Row>[] = [
    { key: "n", header: "Function", render: (r) => <span className="text-xs font-mono">{r.function_name}<span className="text-[var(--color-muted)]">({r.arg_signature})</span></span> },
    { key: "a", header: "authenticated",
      render: (r) => r.authenticated
        ? <span className="text-xs text-[var(--color-ok)]">✓</span>
        : <span className="text-xs text-[var(--color-danger)]">✗</span>
    },
    { key: "s", header: "service_role",
      render: (r) => r.service_role
        ? <span className="text-xs text-[var(--color-ok)]">✓</span>
        : <span className="text-xs text-[var(--color-muted)]">—</span>
    },
    { key: "o", header: "anon",
      render: (r) => r.anon
        ? <span className="text-xs text-[var(--color-danger)]">✓</span>
        : <span className="text-xs text-[var(--color-muted)]">—</span>
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Grants audit</h1>
        <span className="text-xs text-[var(--color-muted)]">EXECUTE privilege snapshot · founder_* functions</span>
      </header>

      <section className="grid grid-cols-1 gap-3 md:grid-cols-3">
        <div className="rounded border border-[var(--color-border)] bg-white p-3">
          <div className="text-xs text-[var(--color-muted)]">Total founder_* fns</div>
          <div className="text-xl font-semibold tabular-nums">{total}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-3">
          <div className="text-xs text-[var(--color-muted)]">Has authenticated grant</div>
          <div className="text-xl font-semibold tabular-nums text-[var(--color-ok)]">{rows.length - broken.length}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-3">
          <div className="text-xs text-[var(--color-muted)]">service_role-only (suspicious)</div>
          <div className="text-xl font-semibold tabular-nums text-[var(--color-warn)]">{broken.length}</div>
        </div>
      </section>

      {broken.length > 0 && (
        <section className="rounded border border-[var(--color-warn)] bg-[#fff8e1] p-3 text-xs">
          <strong>Suspicious:</strong> these {broken.length} founder_* functions are granted to service_role only. If any of these are called from a web page or server action via the founder&apos;s authenticated session, every call will throw permission_denied. Audit pass needed.
          <ul className="mt-2 list-disc pl-5 font-mono">
            {broken.map((r) => (
              <li key={r.function_name + r.arg_signature}>{r.function_name}({r.arg_signature})</li>
            ))}
          </ul>
        </section>
      )}

      <DataTable columns={cols} rows={rows} rowKey={(r) => r.function_name + r.arg_signature} emptyMessage="No founder_* functions found." />

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>Why this page exists.</strong> r847-r849 audit found 13 founder RPCs that were granted to service_role only, but called from the web ops console via the founder&apos;s SSR session — every call threw permission_denied for 3 months until caught. This page surfaces the same pattern proactively. When you ship a new founder_* RPC, glance here to confirm it ended up in the &quot;authenticated&quot; column.
      </section>
    </div>
  );
}
