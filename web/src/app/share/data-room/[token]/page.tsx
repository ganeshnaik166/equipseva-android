import { createClient } from "@supabase/supabase-js";

export const metadata = { title: "EquipSeva — investor data room" };
export const dynamic = "force-dynamic";

type Row = {
  outcome: "ok" | "expired" | "exhausted" | "revoked" | "not_found" | "sensitivity_blocked";
  investor_firm_name: string | null;
  remaining_views_total: number;
  expires_at: string | null;
  document_label: string | null;
  document_kind: string | null;
  storage_uri: string | null;
};

function publicClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { auth: { persistSession: false } },
  );
}

export default async function InvestorDataRoomPage({
  params,
  searchParams,
}: {
  params: Promise<{ token: string }>;
  searchParams: Promise<{ doc?: string }>;
}) {
  const { token } = await params;
  const { doc } = await searchParams;
  const supabase = publicClient();
  const { data, error } = await supabase.rpc("investor_data_room_view", {
    p_token_hash: token,
    p_document_id: doc ?? null,
  });
  if (error) {
    return (
      <main className="mx-auto max-w-2xl p-8 font-sans">
        <h1 className="text-2xl font-bold">EquipSeva data room</h1>
        <p className="mt-4 text-red-600">Failed to load: {error.message}</p>
      </main>
    );
  }
  const r = (data?.[0] ?? null) as Row | null;
  if (!r) {
    return (
      <main className="mx-auto max-w-2xl p-8 font-sans">
        <h1 className="text-2xl font-bold">EquipSeva data room</h1>
        <p className="mt-4 text-red-600">Invalid token. Contact your EquipSeva point-of-contact.</p>
      </main>
    );
  }

  if (r.outcome === "not_found") {
    return (
      <main className="mx-auto max-w-2xl p-8 font-sans">
        <h1 className="text-2xl font-bold">EquipSeva data room</h1>
        <p className="mt-4 text-red-600">Token not found. Contact your EquipSeva point-of-contact.</p>
      </main>
    );
  }
  if (r.outcome === "expired") {
    return (
      <main className="mx-auto max-w-2xl p-8 font-sans">
        <h1 className="text-2xl font-bold">EquipSeva data room</h1>
        <p className="mt-4 text-amber-700">Access expired. Contact your EquipSeva point-of-contact for an extension.</p>
      </main>
    );
  }
  if (r.outcome === "exhausted") {
    return (
      <main className="mx-auto max-w-2xl p-8 font-sans">
        <h1 className="text-2xl font-bold">EquipSeva data room</h1>
        <p className="mt-4 text-amber-700">View limit reached. Contact your EquipSeva point-of-contact for additional views.</p>
      </main>
    );
  }
  if (r.outcome === "revoked") {
    return (
      <main className="mx-auto max-w-2xl p-8 font-sans">
        <h1 className="text-2xl font-bold">EquipSeva data room</h1>
        <p className="mt-4 text-red-600">Access has been revoked.</p>
      </main>
    );
  }
  if (r.outcome === "sensitivity_blocked") {
    return (
      <main className="mx-auto max-w-2xl p-8 font-sans">
        <h1 className="text-2xl font-bold">EquipSeva data room</h1>
        <p className="mt-4 text-amber-700">This document is outside your access tier. Contact EquipSeva to upgrade.</p>
      </main>
    );
  }

  // ok
  return (
    <main className="mx-auto max-w-3xl p-8 font-sans space-y-6">
      <header>
        <h1 className="text-2xl font-bold">EquipSeva data room</h1>
        {r.investor_firm_name ? (
          <p className="mt-1 text-sm text-gray-600">For: <strong>{r.investor_firm_name}</strong></p>
        ) : null}
        <p className="mt-1 text-xs text-gray-500">
          Remaining views: <strong>{r.remaining_views_total}</strong>
          {r.expires_at ? ` · Expires ${new Date(r.expires_at).toLocaleDateString("en-IN")}` : null}
        </p>
      </header>

      {doc && r.document_label ? (
        <section className="rounded border border-gray-200 bg-white p-6">
          <h2 className="text-lg font-semibold">{r.document_label}</h2>
          <p className="mt-1 text-xs text-gray-500">{r.document_kind}</p>
          {r.storage_uri ? (
            <a
              href={r.storage_uri}
              target="_blank"
              rel="noreferrer noopener"
              className="mt-4 inline-block rounded bg-emerald-700 px-4 py-2 text-sm text-white"
            >
              Open document →
            </a>
          ) : (
            <p className="mt-4 text-sm text-gray-500">Document available but no storage URI configured.</p>
          )}
        </section>
      ) : (
        <section className="rounded border border-gray-200 bg-white p-6">
          <p className="text-sm text-gray-700">
            Token validated. Use a direct document link from your EquipSeva contact (format <code>/share/data-room/{"{token}"}?doc={"{uuid}"}</code>) to view a specific document.
          </p>
        </section>
      )}

      <footer className="border-t border-gray-200 pt-4 text-xs text-gray-500">
        EquipSeva · investor data room v1 · every view is audit-logged.
      </footer>
    </main>
  );
}
