import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Snapshot = {
  total_chains_tracked: number;
  total_oems_tracked: number;
  active_partnerships: number;
  msa_signed_partnerships: number;
  chains_with_no_partnership: number;
  total_installed_base: number;
  total_annual_capex_lakhs: number;
};

type ChainPref = {
  id: string;
  chain_name: string;
  chain_tier: string;
  oem_vendor: string;
  preference_rank: number;
  installed_base_count: number;
  annual_capex_inr_lakhs: number;
  exclusive_contract: boolean;
  contract_expiry_date: string | null;
  partnership_stage: string;
  gap_flag: boolean;
};

type OemStatus = {
  id: string;
  oem_vendor: string;
  partnership_stage: string;
  authorized_service_partner: boolean;
  spare_parts_access: string;
  training_certified_engineers: number;
  msa_signed_date: string | null;
  msa_expiry_date: string | null;
  revenue_share_pct: number | null;
  next_action: string | null;
  next_action_due: string | null;
  chains_favoring_this_oem: number;
  total_installed_base: number;
};

type GapRow = {
  chain_name: string;
  chain_tier: string;
  favored_oem: string;
  installed_base_count: number;
  annual_capex_inr_lakhs: number;
  partnership_stage: string;
  blocker_summary: string | null;
  estimated_lost_arr_lakhs: number;
};

type ConcentrationRow = {
  oem_vendor: string;
  chain_count: number;
  total_installed_base: number;
  total_capex_lakhs: number;
  partnership_stage: string;
  pct_of_total_capex: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [snapRes, chainRes, oemRes, gapRes, concRes] = await Promise.all([
    supabase.rpc('fn_r2343_snapshot'),
    supabase.rpc('fn_r2343_chain_preferences'),
    supabase.rpc('fn_r2343_oem_status'),
    supabase.rpc('fn_r2343_gap_analysis'),
    supabase.rpc('fn_r2343_vendor_concentration'),
  ]);

  const snap: Snapshot | null = snapRes.data?.[0] ?? null;
  const chains: ChainPref[] = chainRes.data ?? [];
  const oems: OemStatus[] = oemRes.data ?? [];
  const gaps: GapRow[] = gapRes.data ?? [];
  const conc: ConcentrationRow[] = concRes.data ?? [];

  const chainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: ChainPref) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'chain_tier', header: 'Tier', render: (r: ChainPref) => r.chain_tier.replace('_', ' ') },
    { key: 'oem_vendor', header: 'OEM', render: (r: ChainPref) => r.oem_vendor },
    { key: 'preference_rank', header: 'Rank', render: (r: ChainPref) => <span className="font-mono">#{r.preference_rank}</span> },
    { key: 'installed_base_count', header: 'Installed', render: (r: ChainPref) => r.installed_base_count.toLocaleString() },
    { key: 'annual_capex_inr_lakhs', header: 'Capex (L)', render: (r: ChainPref) => `Rs ${Number(r.annual_capex_inr_lakhs).toLocaleString()}` },
    { key: 'exclusive_contract', header: 'Exclusive', render: (r: ChainPref) => r.exclusive_contract ? 'Yes' : 'No' },
    { key: 'partnership_stage', header: 'Our Status', render: (r: ChainPref) => (
      <span className={r.partnership_stage === 'active' ? 'text-emerald-700' : r.partnership_stage === 'none' ? 'text-red-700' : 'text-amber-700'}>
        {r.partnership_stage}
      </span>
    ) },
    { key: 'gap_flag', header: 'Gap', render: (r: ChainPref) => r.gap_flag ? <span className="text-red-700 font-semibold">GAP</span> : <span className="text-emerald-700">ok</span> },
  ];

  const oemCols: Column<any>[] = [
    { key: 'oem_vendor', header: 'OEM', render: (r: OemStatus) => <span className="font-medium">{r.oem_vendor}</span> },
    { key: 'partnership_stage', header: 'Stage', render: (r: OemStatus) => r.partnership_stage },
    { key: 'authorized_service_partner', header: 'ASP', render: (r: OemStatus) => r.authorized_service_partner ? 'Yes' : 'No' },
    { key: 'spare_parts_access', header: 'Parts', render: (r: OemStatus) => r.spare_parts_access },
    { key: 'training_certified_engineers', header: 'Certified Engs', render: (r: OemStatus) => r.training_certified_engineers },
    { key: 'msa_signed_date', header: 'MSA Signed', render: (r: OemStatus) => r.msa_signed_date ?? '-' },
    { key: 'msa_expiry_date', header: 'MSA Expiry', render: (r: OemStatus) => r.msa_expiry_date ?? '-' },
    { key: 'revenue_share_pct', header: 'Rev Share %', render: (r: OemStatus) => r.revenue_share_pct == null ? '-' : `${r.revenue_share_pct}%` },
    { key: 'chains_favoring_this_oem', header: 'Top-pick Chains', render: (r: OemStatus) => r.chains_favoring_this_oem },
    { key: 'total_installed_base', header: 'Total Installed', render: (r: OemStatus) => r.total_installed_base.toLocaleString() },
    { key: 'next_action', header: 'Next Action', render: (r: OemStatus) => r.next_action ?? '-' },
    { key: 'next_action_due', header: 'Due', render: (r: OemStatus) => r.next_action_due ?? '-' },
  ];

  const gapCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: GapRow) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'chain_tier', header: 'Tier', render: (r: GapRow) => r.chain_tier },
    { key: 'favored_oem', header: 'Favored OEM', render: (r: GapRow) => r.favored_oem },
    { key: 'installed_base_count', header: 'Installed', render: (r: GapRow) => r.installed_base_count.toLocaleString() },
    { key: 'annual_capex_inr_lakhs', header: 'Capex (L)', render: (r: GapRow) => `Rs ${Number(r.annual_capex_inr_lakhs).toLocaleString()}` },
    { key: 'partnership_stage', header: 'Our Stage', render: (r: GapRow) => <span className="text-red-700">{r.partnership_stage}</span> },
    { key: 'estimated_lost_arr_lakhs', header: 'Est. Lost ARR (L)', render: (r: GapRow) => <span className="font-semibold text-red-700">Rs {Number(r.estimated_lost_arr_lakhs).toLocaleString()}</span> },
    { key: 'blocker_summary', header: 'Blocker', render: (r: GapRow) => r.blocker_summary ?? '-' },
  ];

  const concCols: Column<any>[] = [
    { key: 'oem_vendor', header: 'OEM', render: (r: ConcentrationRow) => <span className="font-medium">{r.oem_vendor}</span> },
    { key: 'chain_count', header: 'Chains', render: (r: ConcentrationRow) => r.chain_count },
    { key: 'total_installed_base', header: 'Installed', render: (r: ConcentrationRow) => r.total_installed_base.toLocaleString() },
    { key: 'total_capex_lakhs', header: 'Capex (L)', render: (r: ConcentrationRow) => `Rs ${Number(r.total_capex_lakhs).toLocaleString()}` },
    { key: 'pct_of_total_capex', header: '% Share', render: (r: ConcentrationRow) => `${r.pct_of_total_capex}%` },
    { key: 'partnership_stage', header: 'Our Stage', render: (r: ConcentrationRow) => r.partnership_stage },
  ];

  const totalLostArr = gaps.reduce((s, g) => s + Number(g.estimated_lost_arr_lakhs || 0), 0);

  return (
    <main className="mx-auto max-w-7xl px-6 py-8 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Hospital Chain & OEM Partnership Tracker</h1>
        <p className="text-sm text-neutral-600 mt-1">
          Map of which OEM (GE / Philips / Siemens) each chain favors, our partnership posture with each OEM, and the gap between the two.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Stat label="Chains tracked" value={snap?.total_chains_tracked ?? 0} />
        <Stat label="OEMs tracked" value={snap?.total_oems_tracked ?? 0} />
        <Stat label="Active partnerships" value={snap?.active_partnerships ?? 0} accent="emerald" />
        <Stat label="MSA signed" value={snap?.msa_signed_partnerships ?? 0} />
        <Stat label="Chains in gap" value={snap?.chains_with_no_partnership ?? 0} accent="red" />
        <Stat label="Total installed" value={(snap?.total_installed_base ?? 0).toLocaleString()} />
        <Stat label="Total annual capex" value={`Rs ${Number(snap?.total_annual_capex_lakhs ?? 0).toLocaleString()} L`} />
        <Stat label="Est. lost ARR" value={`Rs ${totalLostArr.toLocaleString()} L`} accent="red" />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Gap analysis (chains where we are NOT the service partner of their #1 OEM)</h2>
        <DataTable
          rows={gaps}
          emptyMessage="No gaps — every #1 OEM has an active partnership."
          rowKey={(r: GapRow) => `${r.chain_name}-${r.favored_oem}`}
          columns={gapCols}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">OEM vendor concentration</h2>
        <DataTable
          rows={conc}
          emptyMessage="No OEM data yet."
          rowKey={(r: ConcentrationRow) => r.oem_vendor}
          columns={concCols}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">OEM partnership status</h2>
        <DataTable
          rows={oems}
          emptyMessage="No OEM partnerships recorded yet."
          rowKey={(r: OemStatus) => r.id}
          columns={oemCols}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Chain » OEM preferences</h2>
        <DataTable
          rows={chains}
          emptyMessage="No chain preferences captured yet."
          rowKey={(r: ChainPref) => r.id}
          columns={chainCols}
        />
      </section>
    </main>
  );
}

function Stat({ label, value, accent }: { label: string; value: number | string; accent?: 'red' | 'emerald' }) {
  const tone =
    accent === 'red' ? 'text-red-700' : accent === 'emerald' ? 'text-emerald-700' : 'text-neutral-900';
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-4">
      <div className="text-xs uppercase tracking-wide text-neutral-500">{label}</div>
      <div className={`mt-1 text-xl font-semibold ${tone}`}>{value}</div>
    </div>
  );
}
