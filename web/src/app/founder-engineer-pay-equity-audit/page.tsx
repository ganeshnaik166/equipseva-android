import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [kpisRes, underpaidRes, regionRes, genderRes, matrixRes, actionsRes] = await Promise.all([
    sb.rpc('founder_pay_equity_kpis_r2282'),
    sb.rpc('founder_pay_equity_top_underpaid_r2282', { p_limit: 20 }),
    sb.rpc('founder_pay_equity_by_region_r2282'),
    sb.rpc('founder_pay_equity_by_gender_r2282'),
    sb.rpc('founder_pay_equity_tier_role_matrix_r2282'),
    sb.rpc('founder_pay_equity_recent_actions_r2282', { p_limit: 25 }),
  ]);

  const kpis = (kpisRes.data?.[0] ?? {}) as Record<string, unknown>;
  const underpaid = (underpaidRes.data ?? []) as Record<string, unknown>[];
  const regions = (regionRes.data ?? []) as Record<string, unknown>[];
  const genders = (genderRes.data ?? []) as Record<string, unknown>[];
  const matrix = (matrixRes.data ?? []) as Record<string, unknown>[];
  const actions = (actionsRes.data ?? []) as Record<string, unknown>[];

  const fmtRupees = (v: unknown) => {
    const n = Number(v ?? 0);
    return '₹' + n.toLocaleString('en-IN', { maximumFractionDigits: 2 });
  };
  const fmtPct = (v: unknown) => {
    const n = Number(v ?? 0);
    return (n > 0 ? '+' : '') + n.toFixed(2) + '%';
  };

  const errors = [kpisRes, underpaidRes, regionRes, genderRes, matrixRes, actionsRes]
    .map((r) => r.error?.message)
    .filter(Boolean);

  const underpaidCols: Column<Record<string, unknown>>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => String(r.engineer_email ?? '') },
    { key: 'tier_band', header: 'Tier', render: (r) => String(r.tier_band ?? '') },
    { key: 'role_label', header: 'Role', render: (r) => String(r.role_label ?? '') },
    { key: 'region', header: 'Region', render: (r) => String(r.region ?? '') },
    { key: 'city', header: 'City', render: (r) => String(r.city ?? '') },
    { key: 'avg_payout_rupees_90d', header: 'Avg 90d', render: (r) => fmtRupees(r.avg_payout_rupees_90d) },
    { key: 'cohort_median_rupees', header: 'Cohort Median', render: (r) => fmtRupees(r.cohort_median_rupees) },
    { key: 'delta_vs_cohort_pct', header: 'Delta', render: (r) => fmtPct(r.delta_vs_cohort_pct) },
    { key: 'equity_score', header: 'Score', render: (r) => Number(r.equity_score ?? 0).toFixed(2) },
  ];

  const regionCols: Column<Record<string, unknown>>[] = [
    { key: 'region', header: 'Region', render: (r) => String(r.region ?? '') },
    { key: 'engineer_count', header: 'Engineers', render: (r) => String(r.engineer_count ?? 0) },
    { key: 'avg_payout', header: 'Avg Payout', render: (r) => fmtRupees(r.avg_payout) },
    { key: 'avg_delta_pct', header: 'Avg Delta', render: (r) => fmtPct(r.avg_delta_pct) },
    { key: 'underpaid_count', header: 'Underpaid', render: (r) => String(r.underpaid_count ?? 0) },
    { key: 'avg_equity_score', header: 'Avg Score', render: (r) => Number(r.avg_equity_score ?? 0).toFixed(2) },
  ];

  const genderCols: Column<Record<string, unknown>>[] = [
    { key: 'gender', header: 'Gender', render: (r) => String(r.gender ?? '') },
    { key: 'engineer_count', header: 'Engineers', render: (r) => String(r.engineer_count ?? 0) },
    { key: 'avg_payout', header: 'Avg Payout', render: (r) => fmtRupees(r.avg_payout) },
    { key: 'avg_delta_pct', header: 'Avg Delta', render: (r) => fmtPct(r.avg_delta_pct) },
    { key: 'avg_equity_score', header: 'Avg Score', render: (r) => Number(r.avg_equity_score ?? 0).toFixed(2) },
  ];

  const matrixCols: Column<Record<string, unknown>>[] = [
    { key: 'tier_band', header: 'Tier', render: (r) => String(r.tier_band ?? '') },
    { key: 'role_label', header: 'Role', render: (r) => String(r.role_label ?? '') },
    { key: 'engineer_count', header: 'Engineers', render: (r) => String(r.engineer_count ?? 0) },
    { key: 'avg_payout', header: 'Avg', render: (r) => fmtRupees(r.avg_payout) },
    { key: 'min_payout', header: 'Min', render: (r) => fmtRupees(r.min_payout) },
    { key: 'max_payout', header: 'Max', render: (r) => fmtRupees(r.max_payout) },
    { key: 'spread_pct', header: 'Spread', render: (r) => Number(r.spread_pct ?? 0).toFixed(2) + '%' },
  ];

  const actionCols: Column<Record<string, unknown>>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => String(r.engineer_email ?? '') },
    { key: 'action_type', header: 'Action', render: (r) => String(r.action_type ?? '') },
    { key: 'rationale', header: 'Rationale', render: (r) => String(r.rationale ?? '') },
    { key: 'amount_rupees', header: 'Amount', render: (r) => (r.amount_rupees == null ? '—' : fmtRupees(r.amount_rupees)) },
    { key: 'taken_by_email', header: 'By', render: (r) => String(r.taken_by_email ?? '') },
    { key: 'taken_at', header: 'When', render: (r) => new Date(String(r.taken_at)).toLocaleString('en-IN') },
    { key: 'status', header: 'Status', render: (r) => String(r.status ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
        Engineer Pay-Equity Audit
      </h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Same-tier same-role pay deltas, gender & region disparity, equity scores, action log.
      </p>

      {errors.length > 0 && (
        <div style={{ background: '#fee', border: '1px solid #c33', padding: 12, marginBottom: 16, borderRadius: 6 }}>
          <strong>Errors:</strong>
          <ul>{errors.map((e, i) => <li key={i}>{e}</li>)}</ul>
        </div>
      )}

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <KpiCard label="Engineers" value={String(kpis.total_engineers ?? 0)} />
        <KpiCard label="Underpaid" value={String(kpis.underpaid_count ?? 0)} tone="warn" />
        <KpiCard label="Overpaid" value={String(kpis.overpaid_count ?? 0)} />
        <KpiCard label="Avg Equity Score" value={Number(kpis.avg_equity_score ?? 0).toFixed(2)} />
        <KpiCard label="Avg Delta" value={fmtPct(kpis.avg_delta_pct)} />
        <KpiCard label="Pending Actions" value={String(kpis.actions_pending ?? 0)} />
        <KpiCard label="Applied Actions" value={String(kpis.actions_applied ?? 0)} />
        <KpiCard label="Rupees Adjusted" value={fmtRupees(kpis.total_rupees_adjusted)} />
      </section>

      <Section title="Top Underpaid Engineers">
        <DataTable columns={underpaidCols} rows={underpaid} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Region Disparity">
        <DataTable columns={regionCols} rows={regions} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Gender Disparity">
        <DataTable columns={genderCols} rows={genders} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Tier x Role Pay Matrix">
        <DataTable columns={matrixCols} rows={matrix} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Recent Equity Actions">
        <DataTable columns={actionCols} rows={actions} rowKey={(_, i) => String(i)} />
      </Section>
    </main>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: string; tone?: 'warn' }) {
  return (
    <div style={{
      border: '1px solid #e0e0e0',
      borderRadius: 8,
      padding: 14,
      background: tone === 'warn' ? '#fff7ed' : '#fff',
    }}>
      <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
