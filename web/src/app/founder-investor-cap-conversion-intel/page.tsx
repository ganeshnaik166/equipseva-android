import { getSupabaseServerClient } from '@/lib/supabase/server'
import { DataTable, type Column } from '@/components/DataTable'

export const dynamic = 'force-dynamic'

type SafeRow = {
  id: string
  investor_name: string | null
  investor_email: string | null
  principal_rupees: number | null
  signed_at: string | null
  valuation_cap_rupees: number | null
  discount_pct: number | null
  mfn_flag: boolean | null
  status: string | null
  age_days: number | null
}

type RoundRow = {
  id: string
  round_name: string | null
  premoney_valuation_rupees: number | null
  new_money_rupees: number | null
  new_share_price_rupees: number | null
  pre_round_shares: number | null
  status: string | null
  founder_verified_at: string | null
  created_at: string | null
}

type PreviewRow = {
  safe_id: string
  investor_name: string | null
  principal_rupees: number | null
  cap_price: number | null
  discount_price: number | null
  new_share_price: number | null
  conversion_price: number | null
  price_source: string | null
  shares_issued: number | null
  ownership_pct: number | null
}

type DilutionRow = {
  bucket: string
  shares: number | null
  pct: number | null
}

type MfnRow = {
  safe_id: string
  investor_name: string | null
  principal_rupees: number | null
  current_discount_pct: number | null
  best_other_discount_pct: number | null
  mfn_upgrade: boolean | null
}

type Overview = {
  outstanding_count: number | null
  outstanding_principal_rupees: number | null
  capped_count: number | null
  uncapped_count: number | null
  mfn_count: number | null
  oldest_signed_at: string | null
  newest_signed_at: string | null
}

function fmtRupees(v: number | null | undefined): string {
  if (v === null || v === undefined) return '—'
  return '₹' + Number(v).toLocaleString('en-IN')
}

function fmtPct(v: number | null | undefined): string {
  if (v === null || v === undefined) return '—'
  return Number(v).toFixed(2) + '%'
}

function fmtDate(v: string | null | undefined): string {
  if (!v) return '—'
  return new Date(v).toLocaleDateString('en-IN')
}

function fmtNum(v: number | null | undefined): string {
  if (v === null || v === undefined) return '—'
  return Number(v).toLocaleString('en-IN')
}

export default async function FounderInvestorCapConversionIntelPage({
  searchParams,
}: {
  searchParams: Promise<{ round?: string }>
}) {
  const sb = await getSupabaseServerClient()
  const sp = await searchParams

  const safesRes = await sb.rpc('founder_cap_list_safes')
  const roundsRes = await sb.rpc('founder_cap_list_rounds')
  const overviewRes = await sb.rpc('founder_cap_capital_overview')
  const mfnRes = await sb.rpc('founder_cap_mfn_risk')

  const safes: SafeRow[] = (safesRes.data ?? []) as SafeRow[]
  const rounds: RoundRow[] = (roundsRes.data ?? []) as RoundRow[]
  const overview: Overview = ((overviewRes.data ?? [])[0] ?? {}) as Overview
  const mfn: MfnRow[] = (mfnRes.data ?? []) as MfnRow[]

  const selectedRoundId = sp?.round ?? rounds[0]?.id ?? null

  let preview: PreviewRow[] = []
  let dilution: DilutionRow[] = []
  if (selectedRoundId) {
    const previewRes = await sb.rpc('founder_cap_conversion_preview', { p_round_id: selectedRoundId })
    const dilutionRes = await sb.rpc('founder_cap_dilution_summary', { p_round_id: selectedRoundId })
    preview = (previewRes.data ?? []) as PreviewRow[]
    dilution = (dilutionRes.data ?? []) as DilutionRow[]
  }

  const safeCols: Column<SafeRow>[] = [
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'principal_rupees', header: 'Principal', render: (r) => fmtRupees(r.principal_rupees) },
    { key: 'valuation_cap_rupees', header: 'Cap', render: (r) => r.valuation_cap_rupees ? fmtRupees(r.valuation_cap_rupees) : 'uncapped' },
    { key: 'discount_pct', header: 'Discount', render: (r) => r.discount_pct !== null ? fmtPct(r.discount_pct) : '—' },
    { key: 'mfn_flag', header: 'MFN', render: (r) => r.mfn_flag ? 'yes' : 'no' },
    { key: 'signed_at', header: 'Signed', render: (r) => fmtDate(r.signed_at) },
    { key: 'age_days', header: 'Age (d)', render: (r) => fmtNum(r.age_days) },
    { key: 'status', header: 'Status', render: (r) => r.status ?? '—' },
  ]

  const roundCols: Column<RoundRow>[] = [
    { key: 'round_name', header: 'Round', render: (r) => r.round_name ?? '—' },
    { key: 'premoney_valuation_rupees', header: 'Pre-money', render: (r) => fmtRupees(r.premoney_valuation_rupees) },
    { key: 'new_money_rupees', header: 'New money', render: (r) => fmtRupees(r.new_money_rupees) },
    { key: 'new_share_price_rupees', header: 'Share ₹', render: (r) => fmtNum(r.new_share_price_rupees) },
    { key: 'pre_round_shares', header: 'Pre shares', render: (r) => fmtNum(r.pre_round_shares) },
    { key: 'status', header: 'Status', render: (r) => r.status ?? '—' },
    { key: 'founder_verified_at', header: 'Verified', render: (r) => fmtDate(r.founder_verified_at) },
  ]

  const previewCols: Column<PreviewRow>[] = [
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'principal_rupees', header: 'Principal', render: (r) => fmtRupees(r.principal_rupees) },
    { key: 'cap_price', header: 'Cap price', render: (r) => r.cap_price !== null ? fmtNum(r.cap_price) : '—' },
    { key: 'discount_price', header: 'Disc price', render: (r) => r.discount_price !== null ? fmtNum(r.discount_price) : '—' },
    { key: 'new_share_price', header: 'New price', render: (r) => fmtNum(r.new_share_price) },
    { key: 'conversion_price', header: 'Conv price', render: (r) => fmtNum(r.conversion_price) },
    { key: 'price_source', header: 'Source', render: (r) => r.price_source ?? '—' },
    { key: 'shares_issued', header: 'Shares', render: (r) => fmtNum(r.shares_issued) },
    { key: 'ownership_pct', header: 'Own %', render: (r) => fmtPct(r.ownership_pct) },
  ]

  const dilutionCols: Column<DilutionRow>[] = [
    { key: 'bucket', header: 'Bucket', render: (r) => r.bucket ?? '—' },
    { key: 'shares', header: 'Shares', render: (r) => fmtNum(r.shares) },
    { key: 'pct', header: 'Ownership %', render: (r) => fmtPct(r.pct) },
  ]

  const mfnCols: Column<MfnRow>[] = [
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'principal_rupees', header: 'Principal', render: (r) => fmtRupees(r.principal_rupees) },
    { key: 'current_discount_pct', header: 'Current %', render: (r) => fmtPct(r.current_discount_pct) },
    { key: 'best_other_discount_pct', header: 'Best other %', render: (r) => fmtPct(r.best_other_discount_pct) },
    { key: 'mfn_upgrade', header: 'Upgrade?', render: (r) => r.mfn_upgrade ? 'YES' : 'no' },
  ]

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <div>
        <h1 className="text-2xl font-bold">Investor cap & conversion intel</h1>
        <p className="text-sm text-gray-600 mt-1">
          SAFEs converting to equity at the next priced round. Per-SAFE math runs cap, discount, and MFN clauses; founder verifies the numbers before the round closes.
        </p>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-3">Capital overview</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Outstanding SAFEs</div>
            <div className="text-xl font-semibold">{fmtNum(overview?.outstanding_count)}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Outstanding principal</div>
            <div className="text-xl font-semibold">{fmtRupees(overview?.outstanding_principal_rupees)}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Capped / Uncapped</div>
            <div className="text-xl font-semibold">
              {fmtNum(overview?.capped_count)} / {fmtNum(overview?.uncapped_count)}
            </div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">MFN clauses</div>
            <div className="text-xl font-semibold">{fmtNum(overview?.mfn_count)}</div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Priced rounds</h2>
        <DataTable rowKey={(r: any) => String((r as any).id ?? "")} columns={roundCols} rows={rounds} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">
          Per-SAFE conversion preview {selectedRoundId ? '' : '(no round selected)'}
        </h2>
        <DataTable rowKey={(r: any) => String((r as any).safe_id ?? "")} columns={previewCols} rows={preview} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Post-round dilution</h2>
        <DataTable rowKey={(r: any) => String((r as any).bucket ?? "")} columns={dilutionCols} rows={dilution} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">MFN risk</h2>
        <DataTable rowKey={(r: any) => String((r as any).safe_id ?? "")} columns={mfnCols} rows={mfn} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Outstanding SAFEs</h2>
        <DataTable rowKey={(r: any) => String((r as any).id ?? "")} columns={safeCols} rows={safes} />
      </section>
    </div>
  )
}
