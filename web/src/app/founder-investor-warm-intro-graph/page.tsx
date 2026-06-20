import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return new Intl.NumberFormat('en-IN').format(n);
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  if (n >= 10000000) return `₹${(n / 10000000).toFixed(2)} Cr`;
  if (n >= 100000) return `₹${(n / 100000).toFixed(2)} L`;
  return `₹${new Intl.NumberFormat('en-IN').format(n)}`;
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return `${Number(n).toFixed(1)}%`;
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [overviewR, ladderR, recentR, reciprocityR, debtsR, channelR, warmthR] = await Promise.all([
    sb.rpc('founder_iwi_overview'),
    sb.rpc('founder_iwi_introducer_ladder'),
    sb.rpc('founder_iwi_recent_intros'),
    sb.rpc('founder_iwi_reciprocity_score'),
    sb.rpc('founder_iwi_thank_you_debts'),
    sb.rpc('founder_iwi_channel_mix'),
    sb.rpc('founder_iwi_warmth_funnel'),
  ]);

  const overview = (overviewR.data?.[0] ?? {}) as any;
  const ladder = (ladderR.data ?? []) as any[];
  const recent = (recentR.data ?? []) as any[];
  const reciprocity = (reciprocityR.data ?? []) as any[];
  const debts = (debtsR.data ?? []) as any[];
  const channels = (channelR.data ?? []) as any[];
  const warmth = (warmthR.data ?? []) as any[];

  const totalIntros = Number(overview.total_intros ?? 0);
  const openIntros = Number(overview.open_intros ?? 0);
  const invested = Number(overview.invested_intros ?? 0);
  const passed = Number(overview.passed_intros ?? 0);
  const uniqueIntroducers = Number(overview.unique_introducers ?? 0);
  const totalCheque = Number(overview.total_cheque_rupees ?? 0);

  const investRate = totalIntros > 0 ? (invested * 100) / totalIntros : 0;
  const closeRate = totalIntros > 0 ? ((invested + passed) * 100) / totalIntros : 0;
  const avgPerIntroducer = uniqueIntroducers > 0 ? totalIntros / uniqueIntroducers : 0;
  const avgCheque = invested > 0 ? totalCheque / invested : 0;

  const openDebts = debts.length;
  const overdueDebts = debts.filter((d) => d.urgency === 'overdue').length;
  const topIntroducer = ladder[0]?.introducer_name ?? '—';
  const topIntroducerCount = Number(ladder[0]?.invested ?? 0);
  const bestChannel = channels.sort((a, b) => Number(b.invest_rate ?? 0) - Number(a.invest_rate ?? 0))[0]?.intro_channel ?? '—';
  const bestWarmth = warmth.sort((a, b) => Number(b.conv_rate ?? 0) - Number(a.conv_rate ?? 0))[0]?.intro_warmth ?? '—';
  const avgReciprocity =
    reciprocity.length > 0
      ? reciprocity.reduce((s, r) => s + Number(r.reciprocity_score ?? 0), 0) / reciprocity.length
      : 0;
  const replied = recent.filter((r) => r.outcome !== 'pending' && r.outcome !== 'no_reply' && r.outcome !== 'ghosted').length;

  const kpis: Kpi[] = [
    { label: 'Total intros', value: fmtNum(totalIntros) },
    { label: 'Open intros', value: fmtNum(openIntros) },
    { label: 'Invested', value: fmtNum(invested) },
    { label: 'Passed', value: fmtNum(passed) },
    { label: 'Unique introducers', value: fmtNum(uniqueIntroducers) },
    { label: 'Total cheque size', value: fmtRupees(totalCheque) },
    { label: 'Invest rate', value: fmtPct(investRate) },
    { label: 'Close rate', value: fmtPct(closeRate) },
    { label: 'Avg intros / introducer', value: avgPerIntroducer.toFixed(1) },
    { label: 'Avg cheque size', value: fmtRupees(avgCheque) },
    { label: 'Open thank-you debts', value: fmtNum(openDebts) },
    { label: 'Overdue debts', value: fmtNum(overdueDebts) },
    { label: 'Top introducer', value: topIntroducer },
    { label: 'Top introducer wins', value: fmtNum(topIntroducerCount) },
    { label: 'Best channel', value: bestChannel },
    { label: 'Best warmth tier', value: bestWarmth },
  ];

  const ladderCols: Column<any>[] = [
    { key: 'introducer_name', header: 'Introducer', render: (r: any) => r.introducer_name ?? '—' },
    { key: 'intros_made', header: 'Intros', render: (r: any) => fmtNum(Number(r.intros_made ?? 0)) },
    { key: 'replied', header: 'Replied', render: (r: any) => fmtNum(Number(r.replied ?? 0)) },
    { key: 'met', header: 'Met', render: (r: any) => fmtNum(Number(r.met ?? 0)) },
    { key: 'partner_met', header: 'Partner', render: (r: any) => fmtNum(Number(r.partner_met ?? 0)) },
    { key: 'term_sheets', header: 'TS', render: (r: any) => fmtNum(Number(r.term_sheets ?? 0)) },
    { key: 'invested', header: 'Invested', render: (r: any) => fmtNum(Number(r.invested ?? 0)) },
    { key: 'conv_rate', header: 'Conv', render: (r: any) => fmtPct(r.conv_rate) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'introducer_name', header: 'Introducer', render: (r: any) => r.introducer_name ?? '—' },
    { key: 'target_investor_name', header: 'Target', render: (r: any) => r.target_investor_name ?? '—' },
    { key: 'target_investor_fund', header: 'Fund', render: (r: any) => r.target_investor_fund ?? '—' },
    { key: 'intro_channel', header: 'Channel', render: (r: any) => r.intro_channel ?? '—' },
    { key: 'intro_warmth', header: 'Warmth', render: (r: any) => r.intro_warmth ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
    { key: 'days_since_intro', header: 'Days', render: (r: any) => fmtNum(Number(r.days_since_intro ?? 0)) },
  ];

  const reciprocityCols: Column<any>[] = [
    { key: 'introducer_name', header: 'Introducer', render: (r: any) => r.introducer_name ?? '—' },
    { key: 'intros_received', header: 'Received', render: (r: any) => fmtNum(Number(r.intros_received ?? 0)) },
    { key: 'thank_yous_open', header: 'Open debt', render: (r: any) => fmtNum(Number(r.thank_yous_open ?? 0)) },
    { key: 'thank_yous_done', header: 'Done', render: (r: any) => fmtNum(Number(r.thank_yous_done ?? 0)) },
    { key: 'reciprocity_score', header: 'Score', render: (r: any) => fmtPct(r.reciprocity_score) },
  ];

  const debtsCols: Column<any>[] = [
    { key: 'introducer_name', header: 'Introducer', render: (r: any) => r.introducer_name ?? '—' },
    { key: 'debt_type', header: 'Type', render: (r: any) => r.debt_type ?? '—' },
    { key: 'urgency', header: 'Urgency', render: (r: any) => r.urgency ?? '—' },
    { key: 'days_owed', header: 'Days owed', render: (r: any) => fmtNum(Number(r.days_owed ?? 0)) },
    { key: 'fulfillment_note', header: 'Note', render: (r: any) => r.fulfillment_note ?? '—' },
  ];

  const channelCols: Column<any>[] = [
    { key: 'intro_channel', header: 'Channel', render: (r: any) => r.intro_channel ?? '—' },
    { key: 'intros', header: 'Intros', render: (r: any) => fmtNum(Number(r.intros ?? 0)) },
    { key: 'reply_rate', header: 'Reply', render: (r: any) => fmtPct(r.reply_rate) },
    { key: 'invest_rate', header: 'Invest', render: (r: any) => fmtPct(r.invest_rate) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header className="space-y-1">
        <p className="text-xs uppercase tracking-wider text-zinc-500">Capital · r1486</p>
        <h1 className="text-2xl font-semibold tracking-tight">Investor warm-intro graph</h1>
        <p className="text-sm text-zinc-600">
          Who-introduced-whom across the investor network. Per-introducer conversion ladder, reciprocity scores, and open thank-you debts.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-lg border border-zinc-200 bg-white p-4">
            <div className="text-xs uppercase tracking-wider text-zinc-500">{k.label}</div>
            <div className="mt-1 text-lg font-semibold text-zinc-900 truncate">{k.value}</div>
          </div>
        ))}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Introducer conversion ladder</h2>
        <DataTable columns={ladderCols} rows={ladder} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent intros</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Reciprocity score</h2>
        <DataTable columns={reciprocityCols} rows={reciprocity} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Open thank-you debts</h2>
        <DataTable columns={debtsCols} rows={debts} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Channel mix</h2>
        <DataTable columns={channelCols} rows={channels} rowKey={(r: any) => r.id} />
      </section>

      <p className="text-xs text-zinc-500">Replied recently: {fmtNum(replied)} · Avg reciprocity: {fmtPct(avgReciprocity)}</p>
    </main>
  );
}
