import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [directory, tierRollup, relMix, recent, stale, followups, summary] = await Promise.all([
    sb.rpc('f_r2283_cxo_priority_directory'),
    sb.rpc('f_r2283_cxo_tier_rollup'),
    sb.rpc('f_r2283_cxo_relationship_mix'),
    sb.rpc('f_r2283_cxo_recent_touchpoints'),
    sb.rpc('f_r2283_cxo_stale_contacts'),
    sb.rpc('f_r2283_cxo_upcoming_followups'),
    sb.rpc('f_r2283_cxo_directory_summary'),
  ]);

  const directoryRows = directory.data ?? [];
  const tierRows = tierRollup.data ?? [];
  const relRows = relMix.data ?? [];
  const recentRows = recent.data ?? [];
  const staleRows = stale.data ?? [];
  const followupRows = followups.data ?? [];
  const s = summary.data?.[0] ?? null;

  const inr = (n: number | null | undefined) =>
    n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');

  const directoryCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'chain_tier', header: 'Tier', render: (r) => r.chain_tier },
    { key: 'contact_name', header: 'Contact', render: (r) => r.contact_name },
    { key: 'contact_role', header: 'Role', render: (r) => r.contact_role },
    { key: 'contact_email', header: 'Email', render: (r) => r.contact_email },
    { key: 'hq_city', header: 'HQ', render: (r) => r.hq_city },
    { key: 'active_amc_count', header: 'AMCs', render: (r) => r.active_amc_count },
    { key: 'annual_contract_value_rupees', header: 'ACV', render: (r) => inr(r.annual_contract_value_rupees) },
    { key: 'relationship_status', header: 'Status', render: (r) => r.relationship_status },
    { key: 'founder_priority', header: 'Priority', render: (r) => (r.founder_priority ? 'Yes' : 'No') },
    { key: 'days_since_last_touch', header: 'Days Silent', render: (r) => r.days_since_last_touch ?? '-' },
  ];

  const tierCols: Column<any>[] = [
    { key: 'chain_tier', header: 'Tier', render: (r) => r.chain_tier },
    { key: 'contact_count', header: 'Contacts', render: (r) => r.contact_count },
    { key: 'decision_makers', header: 'DMs', render: (r) => r.decision_makers },
    { key: 'champions', header: 'Champions', render: (r) => r.champions },
    { key: 'at_risk', header: 'At Risk', render: (r) => r.at_risk },
    { key: 'total_facilities', header: 'Facilities', render: (r) => r.total_facilities },
    { key: 'total_acv_rupees', header: 'Total ACV', render: (r) => inr(r.total_acv_rupees) },
  ];

  const relCols: Column<any>[] = [
    { key: 'relationship_status', header: 'Status', render: (r) => r.relationship_status },
    { key: 'cxo_count', header: 'CXOs', render: (r) => r.cxo_count },
    { key: 'acv_rupees', header: 'ACV', render: (r) => inr(r.acv_rupees) },
    { key: 'pct_of_acv', header: '% of ACV', render: (r) => `${r.pct_of_acv}%` },
  ];

  const recentCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'contact_name', header: 'Contact', render: (r) => r.contact_name },
    { key: 'touchpoint_type', header: 'Type', render: (r) => r.touchpoint_type },
    { key: 'occurred_at', header: 'When', render: (r) => new Date(r.occurred_at).toLocaleDateString('en-IN') },
    { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
    { key: 'summary', header: 'Summary', render: (r) => r.summary },
    { key: 'next_action', header: 'Next Action', render: (r) => r.next_action ?? '-' },
  ];

  const staleCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'contact_name', header: 'Contact', render: (r) => r.contact_name },
    { key: 'contact_role', header: 'Role', render: (r) => r.contact_role },
    { key: 'acv_rupees', header: 'ACV', render: (r) => inr(r.acv_rupees) },
    { key: 'days_silent', header: 'Days Silent', render: (r) => r.days_silent ?? '-' },
    { key: 'last_touch_at', header: 'Last Touch', render: (r) => (r.last_touch_at ? new Date(r.last_touch_at).toLocaleDateString('en-IN') : '-') },
  ];

  const followupCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'contact_name', header: 'Contact', render: (r) => r.contact_name },
    { key: 'next_action', header: 'Next Action', render: (r) => r.next_action },
    { key: 'next_action_due', header: 'Due', render: (r) => new Date(r.next_action_due).toLocaleDateString('en-IN') },
    { key: 'days_until_due', header: 'Days Until', render: (r) => r.days_until_due ?? '-' },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain CXO Contact Directory</h1>
        <p className="mt-1 text-sm text-gray-600">
          Primary chain CXO/COO/CFO contacts, last touchpoint, founder-priority engagement tracking.
        </p>
      </header>

      {s && (
        <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
          <div className="rounded border p-4">
            <div className="text-xs text-gray-500">Total Contacts</div>
            <div className="text-2xl font-bold">{s.total_contacts}</div>
          </div>
          <div className="rounded border p-4">
            <div className="text-xs text-gray-500">Decision Makers</div>
            <div className="text-2xl font-bold">{s.decision_makers}</div>
          </div>
          <div className="rounded border p-4">
            <div className="text-xs text-gray-500">Founder Priority</div>
            <div className="text-2xl font-bold">{s.founder_priority}</div>
          </div>
          <div className="rounded border p-4">
            <div className="text-xs text-gray-500">Champions</div>
            <div className="text-2xl font-bold">{s.champions}</div>
          </div>
          <div className="rounded border p-4">
            <div className="text-xs text-gray-500">At Risk</div>
            <div className="text-2xl font-bold">{s.at_risk}</div>
          </div>
          <div className="rounded border p-4">
            <div className="text-xs text-gray-500">Total Facilities</div>
            <div className="text-2xl font-bold">{s.total_facilities}</div>
          </div>
          <div className="rounded border p-4">
            <div className="text-xs text-gray-500">Total ACV</div>
            <div className="text-2xl font-bold">{inr(s.total_acv_rupees)}</div>
          </div>
          <div className="rounded border p-4">
            <div className="text-xs text-gray-500">Champion %</div>
            <div className="text-2xl font-bold">{s.champion_pct}%</div>
          </div>
        </section>
      )}

      <section>
        <h2 className="mb-3 text-lg font-semibold">Priority Directory</h2>
        <DataTable columns={directoryCols} rows={directoryRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Tier Rollup</h2>
        <DataTable columns={tierCols} rows={tierRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Relationship Status Mix</h2>
        <DataTable columns={relCols} rows={relRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Recent Touchpoints</h2>
        <DataTable columns={recentCols} rows={recentRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Priority Contacts (Stale Risk)</h2>
        <DataTable columns={staleCols} rows={staleRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Upcoming Followups</h2>
        <DataTable columns={followupCols} rows={followupRows} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
