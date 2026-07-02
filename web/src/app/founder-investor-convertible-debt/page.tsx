import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_notes: number;
  outstanding_notes: number;
  converted_notes: number;
  repaid_notes: number;
  defaulted_notes: number;
  watch_listed: number;
  total_principal_rupees: number;
  outstanding_principal_rupees: number;
  accrued_interest_rupees: number;
  maturing_within_90d: number;
};

function inr(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + Math.round(Number(n)).toLocaleString('en-IN');
}

export default async function FounderInvestorConvertibleDebtPage() {
  const sb = await getSupabaseServerClient();

  const summaryResp = await sb.rpc('founder_convertible_debt_summary');
  const listResp = await sb.rpc('founder_convertible_debt_list');
  const watchResp = await sb.rpc('founder_convertible_debt_watch_list');
  const eventsResp = await sb.rpc('founder_convertible_debt_events', { p_limit: 50 });

  const summary: SummaryRow | null = (summaryResp.data?.[0] as SummaryRow) ?? null;
  const notes: any[] = (listResp.data as any[]) ?? [];
  const watch: any[] = (watchResp.data as any[]) ?? [];
  const events: any[] = (eventsResp.data as any[]) ?? [];

  const noteCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'principal_rupees', header: 'Principal', render: (r) => inr(r.principal_rupees) },
    { key: 'interest_rate_pct', header: 'Rate', render: (r) => (r.interest_rate_pct ?? '—') + '%' },
    { key: 'issue_date', header: 'Issued', render: (r) => r.issue_date ?? '—' },
    { key: 'maturity_date', header: 'Maturity', render: (r) => r.maturity_date ?? '—' },
    { key: 'days_to_maturity', header: 'Days left', render: (r) => String(r.days_to_maturity ?? '—') },
    { key: 'accrued_interest_rupees', header: 'Accrued', render: (r) => inr(r.accrued_interest_rupees) },
    { key: 'total_owed_rupees', header: 'Owed', render: (r) => inr(r.total_owed_rupees) },
    { key: 'conversion_trigger', header: 'Trigger', render: (r) => r.conversion_trigger ?? '—' },
    { key: 'conversion_discount_pct', header: 'Disc', render: (r) => (r.conversion_discount_pct ?? '—') + '%' },
    { key: 'valuation_cap_rupees', header: 'Cap', render: (r) => inr(r.valuation_cap_rupees) },
    { key: 'status', header: 'Status', render: (r) => r.status ?? '—' },
    { key: 'watch_flag', header: 'Watch', render: (r) => (r.watch_flag ? 'yes' : '—') },
  ];

  const watchCols: Column<any>[] = [
    { key: 'urgency', header: 'Urgency', render: (r) => r.urgency ?? '—' },
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'principal_rupees', header: 'Principal', render: (r) => inr(r.principal_rupees) },
    { key: 'maturity_date', header: 'Maturity', render: (r) => r.maturity_date ?? '—' },
    { key: 'days_to_maturity', header: 'Days', render: (r) => String(r.days_to_maturity ?? '—') },
    { key: 'status', header: 'Status', render: (r) => r.status ?? '—' },
    { key: 'watch_reason', header: 'Reason', render: (r) => r.watch_reason ?? '—' },
  ];

  const eventCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r) => (r.created_at ? new Date(r.created_at).toLocaleString('en-IN') : '—') },
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'event_type', header: 'Event', render: (r) => r.event_type ?? '—' },
    { key: 'event_amount_rupees', header: 'Amount', render: (r) => inr(r.event_amount_rupees) },
    { key: 'event_note', header: 'Note', render: (r) => r.event_note ?? '—' },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Investor convertible debt log</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Convertible notes (debt, not SAFE) — principal, interest accrual, maturity, conversion triggers, founder watch list. r1649.
      </p>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Portfolio summary</h2>
        {summary ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 8 }}>
            <Stat label="Total notes" value={String(summary.total_notes ?? '—')} />
            <Stat label="Outstanding" value={String(summary.outstanding_notes ?? '—')} />
            <Stat label="Converted" value={String(summary.converted_notes ?? '—')} />
            <Stat label="Repaid" value={String(summary.repaid_notes ?? '—')} />
            <Stat label="Defaulted" value={String(summary.defaulted_notes ?? '—')} />
            <Stat label="Watch listed" value={String(summary.watch_listed ?? '—')} />
            <Stat label="Total principal" value={inr(summary.total_principal_rupees)} />
            <Stat label="Outstanding principal" value={inr(summary.outstanding_principal_rupees)} />
            <Stat label="Accrued interest" value={inr(summary.accrued_interest_rupees)} />
            <Stat label="Maturing in 90d" value={String(summary.maturing_within_90d ?? '—')} />
          </div>
        ) : (
          <p style={{ color: '#888' }}>No summary data.</p>
        )}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Watch list (urgent)</h2>
        <DataTable rows={watch} columns={watchCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All convertible notes</h2>
        <DataTable rows={notes} columns={noteCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent events</h2>
        <DataTable rows={events} columns={eventCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{value}</div>
    </div>
  );
}
