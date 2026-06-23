import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerAmcRenewalRunwayBoardPage() {
  const supabase = await getSupabaseServerClient();

  const [
    runwayRes,
    followupsRes,
    expiring30Res,
    redFocusRes,
    topArrRes,
    weekFollowupsRes,
    funnelRes,
  ] = await Promise.all([
    supabase.rpc('list_runway_r2428'),
    supabase.rpc('list_followups_r2428'),
    supabase.rpc('expiring_30d_r2428'),
    supabase.rpc('red_status_focus_r2428'),
    supabase.rpc('top_arr_at_risk_r2428'),
    supabase.rpc('this_week_followups_r2428'),
    supabase.rpc('renewal_funnel_r2428'),
  ]);

  const runway = (runwayRes.data ?? []) as any[];
  const followups = (followupsRes.data ?? []) as any[];
  const expiring30 = (expiring30Res.data ?? []) as any[];
  const redFocus = (redFocusRes.data ?? []) as any[];
  const topArr = (topArrRes.data ?? []) as any[];
  const weekFollowups = (weekFollowupsRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];

  const fmtRupees = (n: any) =>
    n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');
  const fmtDate = (v: any) =>
    v ? new Date(v).toLocaleDateString('en-IN') : '-';
  const fmtDateTime = (v: any) =>
    v ? new Date(v).toLocaleString('en-IN') : '-';

  const runwayColumns: Column<any>[] = [
    { key: 'amc_tier', header: 'Tier', render: (r: any) => r.amc_tier },
    {
      key: 'current_term_end',
      header: 'Term End',
      render: (r: any) => fmtDate(r.current_term_end),
    },
    {
      key: 'days_to_expiry',
      header: 'Days to Expiry',
      render: (r: any) => String(r.days_to_expiry),
    },
    {
      key: 'renewal_probability_pct',
      header: 'Renew %',
      render: (r: any) => `${r.renewal_probability_pct}%`,
    },
    {
      key: 'discount_asked_pct',
      header: 'Asked %',
      render: (r: any) => `${r.discount_asked_pct}%`,
    },
    {
      key: 'our_offer_pct',
      header: 'Our Offer %',
      render: (r: any) => `${r.our_offer_pct}%`,
    },
    {
      key: 'negotiation_owner_email',
      header: 'Owner',
      render: (r: any) => r.negotiation_owner_email,
    },
    {
      key: 'last_touch_at',
      header: 'Last Touch',
      render: (r: any) => fmtDateTime(r.last_touch_at),
    },
    {
      key: 'next_followup_at',
      header: 'Next Follow-up',
      render: (r: any) => fmtDateTime(r.next_followup_at),
    },
    {
      key: 'escalation_required',
      header: 'Escalate',
      render: (r: any) => (r.escalation_required ? 'yes' : 'no'),
    },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    {
      key: 'arr_at_risk_rupees',
      header: 'ARR at Risk',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: fmtRupees(r.arr_at_risk_rupees) }} />
      ),
    },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const followupsColumns: Column<any>[] = [
    {
      key: 'followup_at',
      header: 'When',
      render: (r: any) => fmtDateTime(r.followup_at),
    },
    {
      key: 'followup_kind',
      header: 'Kind',
      render: (r: any) => r.followup_kind,
    },
    { key: 'agenda', header: 'Agenda', render: (r: any) => r.agenda },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '-' },
    {
      key: 'outcome_notes',
      header: 'Outcome Notes',
      render: (r: any) => r.outcome_notes ?? '-',
    },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const expiring30Columns: Column<any>[] = [
    { key: 'amc_tier', header: 'Tier', render: (r: any) => r.amc_tier },
    {
      key: 'current_term_end',
      header: 'Term End',
      render: (r: any) => fmtDate(r.current_term_end),
    },
    {
      key: 'days_to_expiry',
      header: 'Days Left',
      render: (r: any) => String(r.days_to_expiry),
    },
    {
      key: 'renewal_probability_pct',
      header: 'Renew %',
      render: (r: any) => `${r.renewal_probability_pct}%`,
    },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    {
      key: 'arr_at_risk_rupees',
      header: 'ARR at Risk',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: fmtRupees(r.arr_at_risk_rupees) }} />
      ),
    },
    {
      key: 'negotiation_owner_email',
      header: 'Owner',
      render: (r: any) => r.negotiation_owner_email,
    },
  ];

  const redFocusColumns: Column<any>[] = [
    { key: 'amc_tier', header: 'Tier', render: (r: any) => r.amc_tier },
    {
      key: 'days_to_expiry',
      header: 'Days Left',
      render: (r: any) => String(r.days_to_expiry),
    },
    {
      key: 'renewal_probability_pct',
      header: 'Renew %',
      render: (r: any) => `${r.renewal_probability_pct}%`,
    },
    {
      key: 'arr_at_risk_rupees',
      header: 'ARR at Risk',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: fmtRupees(r.arr_at_risk_rupees) }} />
      ),
    },
    {
      key: 'escalation_required',
      header: 'Escalate',
      render: (r: any) => (r.escalation_required ? 'yes' : 'no'),
    },
    {
      key: 'negotiation_owner_email',
      header: 'Owner',
      render: (r: any) => r.negotiation_owner_email,
    },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topArrColumns: Column<any>[] = [
    { key: 'amc_tier', header: 'Tier', render: (r: any) => r.amc_tier },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    {
      key: 'days_to_expiry',
      header: 'Days Left',
      render: (r: any) => String(r.days_to_expiry),
    },
    {
      key: 'arr_at_risk_rupees',
      header: 'ARR at Risk',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: fmtRupees(r.arr_at_risk_rupees) }} />
      ),
    },
    {
      key: 'renewal_probability_pct',
      header: 'Renew %',
      render: (r: any) => `${r.renewal_probability_pct}%`,
    },
  ];

  const weekFollowupsColumns: Column<any>[] = [
    {
      key: 'followup_at',
      header: 'When',
      render: (r: any) => fmtDateTime(r.followup_at),
    },
    {
      key: 'followup_kind',
      header: 'Kind',
      render: (r: any) => r.followup_kind,
    },
    { key: 'agenda', header: 'Agenda', render: (r: any) => r.agenda },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const funnelColumns: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    {
      key: 'renewal_count',
      header: 'Count',
      render: (r: any) => String(r.renewal_count),
    },
    {
      key: 'total_arr_at_risk_rupees',
      header: 'Total ARR at Risk',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: fmtRupees(r.total_arr_at_risk_rupees) }} />
      ),
    },
    {
      key: 'avg_probability_pct',
      header: 'Avg Renew %',
      render: (r: any) => `${r.avg_probability_pct}%`,
    },
    {
      key: 'avg_discount_asked_pct',
      header: 'Avg Asked %',
      render: (r: any) => `${r.avg_discount_asked_pct}%`,
    },
    {
      key: 'avg_our_offer_pct',
      header: 'Avg Our Offer %',
      render: (r: any) => `${r.avg_our_offer_pct}%`,
    },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Customer AMC Renewal Runway Board
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        AMC renewal & days-to-expiry & renewal probability & discount asked
        & negotiation owner & follow-up calendar. Status: green > yellow > red > lost > renewed.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Renewal funnel (by status)
        </h2>
        <DataTable
          rows={funnel}
          columns={funnelColumns}
          emptyMessage="No funnel data yet."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Red status — needs immediate founder attention
        </h2>
        <DataTable
          rows={redFocus}
          columns={redFocusColumns}
          emptyMessage="No red-status renewals. Nice."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Expiring within 30 days
        </h2>
        <DataTable
          rows={expiring30}
          columns={expiring30Columns}
          emptyMessage="No renewals expiring in next 30 days."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Top ARR at risk
        </h2>
        <DataTable
          rows={topArr}
          columns={topArrColumns}
          emptyMessage="No ARR at risk."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          This week's follow-ups
        </h2>
        <DataTable
          rows={weekFollowups}
          columns={weekFollowupsColumns}
          emptyMessage="No follow-ups scheduled this week."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          All renewals — runway board
        </h2>
        <DataTable
          rows={runway}
          columns={runwayColumns}
          emptyMessage="No renewals in pipeline."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          All follow-ups — calendar
        </h2>
        <DataTable
          rows={followups}
          columns={followupsColumns}
          emptyMessage="No follow-ups logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
