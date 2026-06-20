import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type KpiRow = {
  total_safes: number;
  active_safes: number;
  converted_safes: number;
  repaid_safes: number;
  defaulted_safes: number;
  total_principal_rupees: number;
  active_principal_rupees: number;
  converted_principal_rupees: number;
  weighted_avg_cap_rupees: number;
  weighted_avg_discount_pct: number;
  mfn_count: number;
  pro_rata_count: number;
  maturing_next_30d: number;
  maturing_next_90d: number;
  matured_overdue: number;
  signed_last_90d: number;
};

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpisRes, listRes, calRes, dilRes, topRes, evtRes, mixRes] = await Promise.all([
    supabase.rpc('founder_safe_kpis'),
    supabase.rpc('founder_safe_list'),
    supabase.rpc('founder_safe_maturity_calendar'),
    supabase.rpc('founder_safe_dilution_scenarios'),
    supabase.rpc('founder_safe_top_investors'),
    supabase.rpc('founder_safe_event_timeline'),
    supabase.rpc('founder_safe_instrument_mix'),
  ]);

  const k: KpiRow = (kpisRes.data?.[0] as KpiRow) ?? {
    total_safes: 0, active_safes: 0, converted_safes: 0, repaid_safes: 0, defaulted_safes: 0,
    total_principal_rupees: 0, active_principal_rupees: 0, converted_principal_rupees: 0,
    weighted_avg_cap_rupees: 0, weighted_avg_discount_pct: 0,
    mfn_count: 0, pro_rata_count: 0,
    maturing_next_30d: 0, maturing_next_90d: 0, matured_overdue: 0, signed_last_90d: 0,
  };

  const list = (listRes.data ?? []) as Array<{
    id: string; investor_name: string; instrument_kind: string;
    principal_rupees: number; valuation_cap_rupees: number | null;
    discount_pct: number | null; signed_at: string; maturity_at: string | null;
    status: string; days_to_maturity: number | null;
  }>;
  const cal = (calRes.data ?? []) as Array<{
    id: string; investor_name: string; principal_rupees: number;
    maturity_at: string; days_to_maturity: number; bucket: string; trigger_event: string;
  }>;
  const dil = (dilRes.data ?? []) as Array<{
    scenario_label: string; next_round_valuation_rupees: number;
    total_safe_principal_rupees: number; weighted_conversion_price_rupees: number;
    est_safe_dilution_pct: number;
  }>;
  const top = (topRes.data ?? []) as Array<{
    investor_name: string; safe_count: number; total_principal_rupees: number;
    active_principal_rupees: number; share_of_active_pct: number;
    has_mfn: boolean; has_pro_rata: boolean;
  }>;
  const evt = (evtRes.data ?? []) as Array<{
    id: string; safe_id: string; investor_name: string;
    event_kind: string; payload: Record<string, unknown>; created_at: string;
  }>;
  const mix = (mixRes.data ?? []) as Array<{
    instrument_kind: string; cnt: number; total_principal_rupees: number;
    avg_cap_rupees: number; avg_discount_pct: number;
  }>;

  const Kpi = ({ label, value, hint }: { label: string; value: string; hint?: string }) => (
    <div className="rounded-2xl border border-neutral-200 bg-white p-4 shadow-sm">
      <div className="text-[11px] uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold tabular-nums">{value}</div>
      {hint ? <div className="mt-0.5 text-[11px] text-neutral-400">{hint}</div> : null}
    </div>
  );

  return (
    <div className="mx-auto max-w-7xl px-4 py-6">
      <header className="mb-6">
        <div className="text-[11px] uppercase tracking-wider text-neutral-500">Capital · r1455</div>
        <h1 className="text-2xl font-semibold">Investor SAFE Conversion Tracker</h1>
        <p className="mt-1 text-sm text-neutral-600">
          SAFEs and convertibles with caps, discounts, maturity dates, and dilution scenarios.
          Surfaces upcoming maturities (next 30 / 90 / 180 days), overdue notes, and conversion preview at 5cr {"→"} 100cr priced rounds.
        </p>
      </header>

      {/* 16 KPI CARDS */}
      <section className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-8">
        <Kpi label="Total SAFEs" value={String(k.total_safes)} />
        <Kpi label="Active" value={String(k.active_safes)} />
        <Kpi label="Converted" value={String(k.converted_safes)} />
        <Kpi label="Repaid" value={String(k.repaid_safes)} />
        <Kpi label="Defaulted" value={String(k.defaulted_safes)} />
        <Kpi label="Total Principal" value={formatRupees(k.total_principal_rupees)} />
        <Kpi label="Active Principal" value={formatRupees(k.active_principal_rupees)} />
        <Kpi label="Converted Principal" value={formatRupees(k.converted_principal_rupees)} />
        <Kpi label="Wtd Avg Cap" value={formatRupees(k.weighted_avg_cap_rupees)} />
        <Kpi label="Wtd Avg Discount" value={`${Number(k.weighted_avg_discount_pct ?? 0).toFixed(1)}%`} />
        <Kpi label="MFN Clauses" value={String(k.mfn_count)} hint="active" />
        <Kpi label="Pro-Rata Rights" value={String(k.pro_rata_count)} hint="active" />
        <Kpi label="Maturing 30d" value={String(k.maturing_next_30d)} />
        <Kpi label="Maturing 90d" value={String(k.maturing_next_90d)} />
        <Kpi label="Overdue" value={String(k.matured_overdue)} hint="past maturity" />
        <Kpi label="Signed 90d" value={String(k.signed_last_90d)} />
      </section>

      {/* SECTION 1: SAFE LIST */}
      <section className="mb-8">
        <h2 className="text-base font-semibold mb-2">All SAFEs · ranked by principal</h2>
        <DataTable
          rowKey={(r) => r.id}
          rows={list}
          columns={[
            { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
            { key: 'instrument_kind', header: 'Kind', render: (r: any) => r.instrument_kind ?? '—' },
            { key: 'principal_rupees', header: 'Principal', render: (r) => formatRupees(r.principal_rupees) },
            { key: 'valuation_cap_rupees', header: 'Cap', render: (r) => r.valuation_cap_rupees ? formatRupees(r.valuation_cap_rupees) : '—' },
            { key: 'discount_pct', header: 'Discount', render: (r) => r.discount_pct != null ? `${Number(r.discount_pct).toFixed(1)}%` : '—' },
            { key: 'signed_at', header: 'Signed', render: (r: any) => r.signed_at ?? '—' },
            { key: 'maturity_at', header: 'Maturity', render: (r) => r.maturity_at ?? '—' },
            { key: 'days_to_maturity', header: 'Days', render: (r) => r.days_to_maturity == null ? '—' : String(r.days_to_maturity) },
            { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
          ]}
        />
      </section>

      {/* SECTION 2: MATURITY CALENDAR */}
      <section className="mb-8">
        <h2 className="text-base font-semibold mb-2">Upcoming maturities · next 180 days {"+"} overdue</h2>
        <DataTable
          rowKey={(r) => r.id}
          rows={cal}
          columns={[
            { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
            { key: 'principal_rupees', header: 'Principal', render: (r) => formatRupees(r.principal_rupees) },
            { key: 'maturity_at', header: 'Maturity', render: (r: any) => r.maturity_at ?? '—' },
            { key: 'days_to_maturity', header: 'Days', render: (r: any) => r.days_to_maturity ?? '—' },
            { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket ?? '—' },
            { key: 'trigger_event', header: 'Trigger', render: (r: any) => r.trigger_event ?? '—' },
          ]}
        />
      </section>

      {/* SECTION 3: DILUTION SCENARIOS */}
      <section className="mb-8">
        <h2 className="text-base font-semibold mb-2">Dilution scenarios · if priced round closes at...</h2>
        <p className="text-xs text-neutral-500 mb-2">
          Naive estimate: total active SAFE principal {"÷"} valuation. Real conversion uses min(cap-price, discount-price)
          per SAFE and depends on MFN cascades — treat as upper-bound floor.
        </p>
        <DataTable
          rowKey={(r) => r.scenario_label}
          rows={dil}
          columns={[
            { key: 'scenario_label', header: 'Scenario', render: (r: any) => r.scenario_label ?? '—' },
            { key: 'next_round_valuation_rupees', header: 'Valuation', render: (r) => formatRupees(r.next_round_valuation_rupees) },
            { key: 'total_safe_principal_rupees', header: 'SAFE Total', render: (r) => formatRupees(r.total_safe_principal_rupees) },
            { key: 'est_safe_dilution_pct', header: 'Est Dilution %', render: (r) => `${Number(r.est_safe_dilution_pct ?? 0).toFixed(2)}%` },
          ]}
        />
      </section>

      {/* SECTION 4: TOP INVESTORS */}
      <section className="mb-8">
        <h2 className="text-base font-semibold mb-2">Cap-stack concentration · top investors</h2>
        <DataTable
          rowKey={(r) => r.investor_name}
          rows={top}
          columns={[
            { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
            { key: 'safe_count', header: 'SAFEs', render: (r: any) => r.safe_count ?? '—' },
            { key: 'total_principal_rupees', header: 'Total', render: (r) => formatRupees(r.total_principal_rupees) },
            { key: 'active_principal_rupees', header: 'Active', render: (r) => formatRupees(r.active_principal_rupees) },
            { key: 'share_of_active_pct', header: 'Share %', render: (r) => `${Number(r.share_of_active_pct ?? 0).toFixed(1)}%` },
            { key: 'has_mfn', header: 'MFN', render: (r) => r.has_mfn ? 'yes' : '—' },
            { key: 'has_pro_rata', header: 'Pro-Rata', render: (r) => r.has_pro_rata ? 'yes' : '—' },
          ]}
        />
      </section>

      {/* SECTION 5: INSTRUMENT MIX + EVENT TIMELINE */}
      <section className="mb-8 grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div>
          <h2 className="text-base font-semibold mb-2">Instrument mix</h2>
          <DataTable
            rowKey={(r) => r.instrument_kind}
            rows={mix}
            columns={[
              { key: 'instrument_kind', header: 'Kind', render: (r: any) => r.instrument_kind ?? '—' },
              { key: 'cnt', header: 'Count', render: (r: any) => r.cnt ?? '—' },
              { key: 'total_principal_rupees', header: 'Principal', render: (r) => formatRupees(r.total_principal_rupees) },
              { key: 'avg_cap_rupees', header: 'Avg Cap', render: (r) => formatRupees(r.avg_cap_rupees) },
              { key: 'avg_discount_pct', header: 'Avg Disc', render: (r) => `${Number(r.avg_discount_pct ?? 0).toFixed(1)}%` },
            ]}
          />
        </div>
        <div>
          <h2 className="text-base font-semibold mb-2">Recent SAFE events</h2>
          <DataTable
            rowKey={(r) => r.id}
            rows={evt}
            columns={[
              { key: 'created_at', header: 'When', render: (r) => new Date(r.created_at).toLocaleString('en-IN') },
              { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
              { key: 'event_kind', header: 'Event', render: (r: any) => r.event_kind ?? '—' },
            ]}
          />
        </div>
      </section>

      <footer className="mt-10 border-t border-neutral-200 pt-4 text-[11px] text-neutral-400">
        r1455 · capital · founder-only · 7 SECDEF RPCs + 4 log_founder_* helpers · investor_safes + investor_safe_events
      </footer>
    </div>
  );
}
