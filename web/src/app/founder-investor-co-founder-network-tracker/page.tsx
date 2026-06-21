import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [introsRes, outcomesRes, topRes, conversionsRes, unthankedRes] = await Promise.all([
    sb.rpc('list_intros_r1729'),
    sb.rpc('list_outcomes_r1729'),
    sb.rpc('top_intro_investors_r1729'),
    sb.rpc('recent_conversions_r1729'),
    sb.rpc('unthanked_intros_r1729'),
  ]);

  const intros = (introsRes.data ?? []) as any[];
  const outcomes = (outcomesRes.data ?? []) as any[];
  const top = (topRes.data ?? []) as any[];
  const conversions = (conversionsRes.data ?? []) as any[];
  const unthanked = (unthankedRes.data ?? []) as any[];

  const introCols: Column<any>[] = [
    { key: 'intro_date', header: 'Date', render: (r: any) => String(r.intro_date ?? '') },
    { key: 'investor_email', header: 'Investor', render: (r: any) => String(r.investor_email ?? '-') },
    { key: 'intro_to_name', header: 'Intro To', render: (r: any) => String(r.intro_to_name ?? '') },
    { key: 'intro_to_org', header: 'Org', render: (r: any) => String(r.intro_to_org ?? '-') },
    { key: 'intro_to_role', header: 'Role', render: (r: any) => String(r.intro_to_role ?? '-') },
    { key: 'intro_purpose', header: 'Purpose', render: (r: any) => String(r.intro_purpose ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'value_realized_md', header: 'Value MD', render: (r: any) => String(r.value_realized_md ?? '-') },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'outcome_at', header: 'When', render: (r: any) => r.outcome_at ? new Date(r.outcome_at).toLocaleDateString() : '' },
    { key: 'intro_to_name', header: 'Intro To', render: (r: any) => String(r.intro_to_name ?? '-') },
    { key: 'outcome_type', header: 'Type', render: (r: any) => String(r.outcome_type ?? '') },
    { key: 'outcome_value_rupees', header: 'Value', render: (r: any) => r.outcome_value_rupees != null ? `Rs ${Number(r.outcome_value_rupees).toLocaleString('en-IN')}` : '-' },
    { key: 'founder_thanks_sent_at', header: 'Thanked', render: (r: any) => r.founder_thanks_sent_at ? 'Yes' : 'No' },
  ];

  const topCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => String(r.investor_email ?? '-') },
    { key: 'intros_count', header: 'Intros', render: (r: any) => String(r.intros_count ?? 0) },
    { key: 'conversions', header: 'Conversions', render: (r: any) => String(r.conversions ?? 0) },
    { key: 'total_value_rupees', header: 'Value Realized', render: (r: any) => `Rs ${Number(r.total_value_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const conversionCols: Column<any>[] = [
    { key: 'outcome_at', header: 'When', render: (r: any) => r.outcome_at ? new Date(r.outcome_at).toLocaleDateString() : '' },
    { key: 'intro_to_name', header: 'Intro To', render: (r: any) => String(r.intro_to_name ?? '-') },
    { key: 'intro_to_org', header: 'Org', render: (r: any) => String(r.intro_to_org ?? '-') },
    { key: 'outcome_type', header: 'Type', render: (r: any) => String(r.outcome_type ?? '') },
    { key: 'outcome_value_rupees', header: 'Value', render: (r: any) => r.outcome_value_rupees != null ? `Rs ${Number(r.outcome_value_rupees).toLocaleString('en-IN')}` : '-' },
  ];

  const unthankedCols: Column<any>[] = [
    { key: 'outcome_at', header: 'When', render: (r: any) => r.outcome_at ? new Date(r.outcome_at).toLocaleDateString() : '' },
    { key: 'intro_to_name', header: 'Intro To', render: (r: any) => String(r.intro_to_name ?? '-') },
    { key: 'investor_email', header: 'Investor', render: (r: any) => String(r.investor_email ?? '-') },
    { key: 'outcome_type', header: 'Outcome', render: (r: any) => String(r.outcome_type ?? '') },
    { key: 'days_since', header: 'Days Since', render: (r: any) => String(r.days_since ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Investor Co-Founder Network Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track intros from investors to founders, operators, customers & partners. Measure conversions & thank promptly.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Intro Investors</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.investor_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Conversions (last 90d)</h2>
        <DataTable rows={conversions} columns={conversionCols} rowKey={(r: any, i: number) => String(r.intro_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Unthanked Wins</h2>
        <p style={{ color: '#a00', marginBottom: 8, fontSize: 14 }}>
          Send a thank-you note ASAP — ideally within 7 days of outcome.
        </p>
        <DataTable rows={unthanked} columns={unthankedCols} rowKey={(r: any, i: number) => String(r.outcome_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Intros</h2>
        <DataTable rows={intros} columns={introCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Outcome Log</h2>
        <DataTable rows={outcomes} columns={outcomeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
