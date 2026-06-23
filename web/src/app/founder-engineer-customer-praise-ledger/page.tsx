import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function inr(n: number | null | undefined): string {
  if (n == null) return '-';
  return 'Rs ' + Math.round(Number(n)).toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined): string {
  if (n == null) return '-';
  return Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  try { return new Date(s).toLocaleDateString('en-IN'); } catch { return String(s); }
}

function fmtDateTime(s: string | null | undefined): string {
  if (!s) return '-';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return String(s); }
}

function shortId(s: string | null | undefined): string {
  if (!s) return '-';
  return String(s).slice(0, 8);
}

export default async function EngineerCustomerPraiseLedgerPage() {
  const sb = await getSupabaseServerClient();

  const [praiseR, ledgerR, topR, kindR, sourceR, trendR, focusR] = await Promise.all([
    sb.rpc('list_praise_r2438'),
    sb.rpc('list_ledger_r2438'),
    sb.rpc('top_praise_engineers_r2438'),
    sb.rpc('kind_breakdown_r2438'),
    sb.rpc('source_breakdown_r2438'),
    sb.rpc('monthly_praise_trend_r2438'),
    sb.rpc('eligible_awards_focus_r2438'),
  ]);

  const praise: any[] = praiseR.data ?? [];
  const ledger: any[] = ledgerR.data ?? [];
  const top: any[] = topR.data ?? [];
  const kinds: any[] = kindR.data ?? [];
  const sources: any[] = sourceR.data ?? [];
  const trend: any[] = trendR.data ?? [];
  const focus: any[] = focusR.data ?? [];

  const totalPraise = praise.length;
  const totalBonus = praise.reduce((s: number, r: any) => s + Number(r.bonus_rupees ?? 0), 0);
  const unpaidBonus = praise
    .filter((r: any) => !r.bonus_paid_at)
    .reduce((s: number, r: any) => s + Number(r.bonus_rupees ?? 0), 0);
  const avgCsat = (() => {
    const arr = praise.map((r: any) => Number(r.csat_score)).filter((n) => Number.isFinite(n));
    if (!arr.length) return null;
    return (arr.reduce((s, n) => s + n, 0) / arr.length).toFixed(2);
  })();
  const eligibleCount = praise.filter((r: any) => r.award_eligibility && r.award_eligibility !== 'none').length;

  const praiseCols: Column<any>[] = [
    { key: 'praise_at', header: 'When', render: (r: any) => fmtDateTime(r.praise_at) },
    { key: 'engineer', header: 'Engineer', render: (r: any) => (
      <div>
        <div style={{ fontFamily: 'monospace', fontSize: 12 }}>{shortId(r.engineer_user_id)}</div>
        <div style={{ fontSize: 11, color: '#666' }}>{r.engineer_tier ?? '-'}</div>
      </div>
    ) },
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'praise_kind', header: 'Kind', render: (r: any) => r.praise_kind },
    { key: 'praise_source', header: 'Source', render: (r: any) => r.praise_source },
    { key: 'csat_score', header: 'CSAT', render: (r: any) => r.csat_score == null ? '-' : Number(r.csat_score).toFixed(1) },
    { key: 'praise_text', header: 'Praise', render: (r: any) => (
      <div style={{ maxWidth: 360, whiteSpace: 'normal', fontSize: 12 }}>{r.praise_text ?? '-'}</div>
    ) },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label ?? '-' },
    { key: 'repeated_praise_streak', header: 'Streak', render: (r: any) => fmtNum(r.repeated_praise_streak) },
    { key: 'award_eligibility', header: 'Eligibility', render: (r: any) => r.award_eligibility },
    { key: 'bonus_rupees', header: 'Bonus', render: (r: any) => inr(r.bonus_rupees) },
    { key: 'paid', header: 'Paid', render: (r: any) => r.bonus_paid_at ? fmtDate(r.bonus_paid_at) : 'unpaid' },
  ];

  const ledgerCols: Column<any>[] = [
    { key: 'period', header: 'Period', render: (r: any) => fmtDate(r.award_period_start) + ' to ' + fmtDate(r.award_period_end) },
    { key: 'engineer', header: 'Engineer', render: (r: any) => (
      <div>
        <div style={{ fontFamily: 'monospace', fontSize: 12 }}>{shortId(r.engineer_user_id)}</div>
        <div style={{ fontSize: 11, color: '#666' }}>{r.engineer_tier ?? '-'}</div>
      </div>
    ) },
    { key: 'total_praise_count', header: 'Praise #', render: (r: any) => fmtNum(r.total_praise_count) },
    { key: 'top_kind', header: 'Top kind', render: (r: any) => r.top_kind ?? '-' },
    { key: 'total_bonus_rupees', header: 'Bonus paid', render: (r: any) => inr(r.total_bonus_rupees) },
    { key: 'hospitals_count', header: 'Hospitals', render: (r: any) => fmtNum(r.hospitals_count) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'awarded_at', header: 'Awarded', render: (r: any) => fmtDate(r.awarded_at) },
    { key: 'ceremony_at', header: 'Ceremony', render: (r: any) => fmtDate(r.ceremony_at) },
    { key: 'awarded_by_email', header: 'By', render: (r: any) => r.awarded_by_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => (
      <div style={{ maxWidth: 240, whiteSpace: 'normal', fontSize: 12 }}>{r.notes ?? '-'}</div>
    ) },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => (
      <div>
        <div style={{ fontFamily: 'monospace', fontSize: 12 }}>{shortId(r.engineer_user_id)}</div>
        <div style={{ fontSize: 11, color: '#666' }}>{r.engineer_tier ?? '-'}</div>
      </div>
    ) },
    { key: 'praise_events', header: 'Praise #', render: (r: any) => fmtNum(r.praise_events) },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => r.avg_csat == null ? '-' : Number(r.avg_csat).toFixed(2) },
    { key: 'total_bonus_rupees', header: 'Bonus', render: (r: any) => inr(r.total_bonus_rupees) },
    { key: 'distinct_hospitals', header: 'Hospitals', render: (r: any) => fmtNum(r.distinct_hospitals) },
    { key: 'last_praise_at', header: 'Last praise', render: (r: any) => fmtDateTime(r.last_praise_at) },
  ];

  const kindCols: Column<any>[] = [
    { key: 'praise_kind', header: 'Kind', render: (r: any) => r.praise_kind },
    { key: 'praise_events', header: 'Events', render: (r: any) => fmtNum(r.praise_events) },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => r.avg_csat == null ? '-' : Number(r.avg_csat).toFixed(2) },
    { key: 'total_bonus_rupees', header: 'Bonus', render: (r: any) => inr(r.total_bonus_rupees) },
    { key: 'pct', header: 'Share', render: (r: any) => r.pct == null ? '-' : Number(r.pct).toFixed(1) + '%' },
  ];

  const sourceCols: Column<any>[] = [
    { key: 'praise_source', header: 'Source', render: (r: any) => r.praise_source },
    { key: 'praise_events', header: 'Events', render: (r: any) => fmtNum(r.praise_events) },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => r.avg_csat == null ? '-' : Number(r.avg_csat).toFixed(2) },
    { key: 'total_bonus_rupees', header: 'Bonus', render: (r: any) => inr(r.total_bonus_rupees) },
    { key: 'pct', header: 'Share', render: (r: any) => r.pct == null ? '-' : Number(r.pct).toFixed(1) + '%' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtDate(r.month_start) },
    { key: 'praise_events', header: 'Events', render: (r: any) => fmtNum(r.praise_events) },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => r.avg_csat == null ? '-' : Number(r.avg_csat).toFixed(2) },
    { key: 'total_bonus_rupees', header: 'Bonus', render: (r: any) => inr(r.total_bonus_rupees) },
    { key: 'distinct_engineers', header: 'Engineers', render: (r: any) => fmtNum(r.distinct_engineers) },
  ];

  const focusCols: Column<any>[] = [
    { key: 'award_eligibility', header: 'Award track', render: (r: any) => r.award_eligibility },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => (
      <div>
        <div style={{ fontFamily: 'monospace', fontSize: 12 }}>{shortId(r.engineer_user_id)}</div>
        <div style={{ fontSize: 11, color: '#666' }}>{r.engineer_tier ?? '-'}</div>
      </div>
    ) },
    { key: 'praise_events', header: 'Praise #', render: (r: any) => fmtNum(r.praise_events) },
    { key: 'unpaid_bonus_rupees', header: 'Unpaid bonus', render: (r: any) => inr(r.unpaid_bonus_rupees) },
    { key: 'last_praise_at', header: 'Last praise', render: (r: any) => fmtDateTime(r.last_praise_at) },
    { key: 'example_text', header: 'Sample', render: (r: any) => (
      <div style={{ maxWidth: 360, whiteSpace: 'normal', fontSize: 12 }}>{r.example_text ?? '-'}</div>
    ) },
  ];

  return (
    <div style={{ padding: '24px 32px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Engineer Customer Praise Ledger</h1>
      <p style={{ color: '#666', fontSize: 13, marginBottom: 24 }}>
        Captures unsolicited praise per engineer across call, email, in-app, WhatsApp, SMS, in-person, and survey
        sources & drives spot bonus + monthly/quarterly/annual awards.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 11, color: '#666' }}>Praise events</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtNum(totalPraise)}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 11, color: '#666' }}>Avg CSAT</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{avgCsat ?? '-'}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 11, color: '#666' }}>Bonus paid total</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{inr(totalBonus)}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 11, color: '#666' }}>Unpaid bonus owed</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{inr(unpaidBonus)}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 11, color: '#666' }}>Award-eligible events</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtNum(eligibleCount)}</div>
        </div>
      </div>

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Award eligibility focus</h2>
      <DataTable
        rows={focus}
        columns={focusCols}
        emptyMessage="No award-eligible praise yet."
        rowKey={(r: any, i: number) => String(r.id ?? `${r.engineer_user_id}-${r.award_eligibility}-${i}`)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Top praised engineers</h2>
      <DataTable
        rows={top}
        columns={topCols}
        emptyMessage="No praise recorded yet."
        rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Award ledger</h2>
      <DataTable
        rows={ledger}
        columns={ledgerCols}
        emptyMessage="Ledger empty."
        rowKey={(r: any, i: number) => String(r.id ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Praise kind breakdown</h2>
      <DataTable
        rows={kinds}
        columns={kindCols}
        emptyMessage="No praise yet."
        rowKey={(r: any, i: number) => String(r.praise_kind ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Praise source breakdown</h2>
      <DataTable
        rows={sources}
        columns={sourceCols}
        emptyMessage="No praise yet."
        rowKey={(r: any, i: number) => String(r.praise_source ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Monthly praise trend</h2>
      <DataTable
        rows={trend}
        columns={trendCols}
        emptyMessage="No trend yet."
        rowKey={(r: any, i: number) => String(r.month_start ?? i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Praise event ledger</h2>
      <DataTable
        rows={praise}
        columns={praiseCols}
        emptyMessage="No praise events."
        rowKey={(r: any, i: number) => String(r.id ?? i)}
      />
    </div>
  );
}
