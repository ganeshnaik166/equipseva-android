import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    introsRes,
    outcomesRes,
    topValueRes,
    sourceRes,
    roleRes,
    influenceRes,
    recentRes,
  ] = await Promise.all([
    supabase.rpc('list_intros_r2475'),
    supabase.rpc('list_outcomes_r2475'),
    supabase.rpc('top_value_intros_r2475'),
    supabase.rpc('source_breakdown_r2475'),
    supabase.rpc('role_breakdown_r2475'),
    supabase.rpc('deal_influence_summary_r2475'),
    supabase.rpc('recent_outcomes_focus_r2475'),
  ]);

  const intros: any[] = (introsRes.data as any[]) ?? [];
  const outcomes: any[] = (outcomesRes.data as any[]) ?? [];
  const topValue: any[] = (topValueRes.data as any[]) ?? [];
  const sources: any[] = (sourceRes.data as any[]) ?? [];
  const roles: any[] = (roleRes.data as any[]) ?? [];
  const influence: any[] = (influenceRes.data as any[]) ?? [];
  const recent: any[] = (recentRes.data as any[]) ?? [];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleString() : '-');
  const fmtINR = (v: any) =>
    v == null ? '-' : '₹' + Number(v).toLocaleString('en-IN');

  const introCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'c_suite_name', header: 'Name', render: (r: any) => r.c_suite_name },
    { key: 'c_suite_role', header: 'Role', render: (r: any) => r.c_suite_role },
    { key: 'intro_source_kind', header: 'Source', render: (r: any) => r.intro_source_kind },
    { key: 'intro_source_name', header: 'Source Name', render: (r: any) => r.intro_source_name ?? '-' },
    { key: 'intro_at', header: 'Intro At', render: (r: any) => fmtDate(r.intro_at) },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => fmtDate(r.follow_up_at) },
    { key: 'follow_up_owner_email', header: 'Owner', render: (r: any) => r.follow_up_owner_email ?? '-' },
    { key: 'deal_influence', header: 'Influence', render: (r: any) => r.deal_influence },
    { key: 'deck_shared_at', header: 'Deck Shared', render: (r: any) => fmtDate(r.deck_shared_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'c_suite_name', header: 'Name', render: (r: any) => r.c_suite_name ?? '-' },
    { key: 'c_suite_role', header: 'Role', render: (r: any) => r.c_suite_role ?? '-' },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'outcome_summary', header: 'Summary', render: (r: any) => r.outcome_summary ?? '-' },
    { key: 'value_rupees', header: 'Value', render: (r: any) => fmtINR(r.value_rupees) },
    { key: 'next_step', header: 'Next Step', render: (r: any) => r.next_step ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'outcome_at', header: 'Outcome At', render: (r: any) => fmtDate(r.outcome_at) },
  ];

  const topValueCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'c_suite_name', header: 'Name', render: (r: any) => r.c_suite_name },
    { key: 'c_suite_role', header: 'Role', render: (r: any) => r.c_suite_role },
    { key: 'intro_source_kind', header: 'Source', render: (r: any) => r.intro_source_kind },
    { key: 'deal_influence', header: 'Influence', render: (r: any) => r.deal_influence },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtINR(r.total_value_rupees) },
    { key: 'outcome_count', header: 'Outcomes', render: (r: any) => r.outcome_count },
  ];

  const sourceCols: Column<any>[] = [
    { key: 'intro_source_kind', header: 'Source', render: (r: any) => r.intro_source_kind },
    { key: 'intro_count', header: 'Intros', render: (r: any) => r.intro_count },
    { key: 'pct', header: 'Pct', render: (r: any) => r.pct + '%' },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'in_progress_count', header: 'In Progress', render: (r: any) => r.in_progress_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtINR(r.total_value_rupees) },
  ];

  const roleCols: Column<any>[] = [
    { key: 'c_suite_role', header: 'Role', render: (r: any) => r.c_suite_role },
    { key: 'intro_count', header: 'Intros', render: (r: any) => r.intro_count },
    { key: 'pct', header: 'Pct', render: (r: any) => r.pct + '%' },
    { key: 'high_critical_count', header: 'High/Critical', render: (r: any) => r.high_critical_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtINR(r.total_value_rupees) },
  ];

  const influenceCols: Column<any>[] = [
    { key: 'deal_influence', header: 'Influence', render: (r: any) => r.deal_influence },
    { key: 'intro_count', header: 'Intros', render: (r: any) => r.intro_count },
    { key: 'pct', header: 'Pct', render: (r: any) => r.pct + '%' },
    { key: 'deck_shared_count', header: 'Deck Shared', render: (r: any) => r.deck_shared_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtINR(r.total_value_rupees) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'c_suite_name', header: 'Name', render: (r: any) => r.c_suite_name ?? '-' },
    { key: 'c_suite_role', header: 'Role', render: (r: any) => r.c_suite_role ?? '-' },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'outcome_summary', header: 'Summary', render: (r: any) => r.outcome_summary ?? '-' },
    { key: 'value_rupees', header: 'Value', render: (r: any) => fmtINR(r.value_rupees) },
    { key: 'next_step', header: 'Next Step', render: (r: any) => r.next_step ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'outcome_at', header: 'Outcome At', render: (r: any) => fmtDate(r.outcome_at) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Hospital Chain C-Suite Introductions Log
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Chain > C-suite name > intro source > intro at > follow-up > deal influence > deck shared.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Intros</h2>
        <DataTable
          rows={intros}
          columns={introCols}
          emptyMessage="No intros yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeCols}
          emptyMessage="No outcomes yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Value Intros</h2>
        <DataTable
          rows={topValue}
          columns={topValueCols}
          emptyMessage="No value data yet."
          rowKey={(r: any, i: number) => String(r.intro_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Source Breakdown</h2>
        <DataTable
          rows={sources}
          columns={sourceCols}
          emptyMessage="No source data."
          rowKey={(r: any, i: number) => String(r.intro_source_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Role Breakdown</h2>
        <DataTable
          rows={roles}
          columns={roleCols}
          emptyMessage="No role data."
          rowKey={(r: any, i: number) => String(r.c_suite_role ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Deal Influence Summary</h2>
        <DataTable
          rows={influence}
          columns={influenceCols}
          emptyMessage="No influence data."
          rowKey={(r: any, i: number) => String(r.deal_influence ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Outcomes Focus (90d)</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          emptyMessage="No recent outcomes."
          rowKey={(r: any, i: number) => String(r.outcome_id ?? i)}
        />
      </section>
    </main>
  );
}
