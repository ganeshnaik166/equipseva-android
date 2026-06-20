import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';
import { createCampaign, updateSpend, setStatus, logTouch } from './actions';

export const dynamic = 'force-dynamic';

export default async function MarketingUtmCampaignTrackerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpisRes, campaignsRes, byChannelRes, topRoiRes, weeklyRes, touchesRes, underRes] = await Promise.all([
    supabase.rpc('founder_utm_kpis'),
    supabase.rpc('founder_utm_campaigns_overview'),
    supabase.rpc('founder_utm_by_channel'),
    supabase.rpc('founder_utm_top_roi', { p_limit: 10 }),
    supabase.rpc('founder_utm_spend_by_week'),
    supabase.rpc('founder_utm_recent_touches', { p_limit: 50 }),
    supabase.rpc('founder_utm_underperformers'),
  ]);

  const k = (kpisRes.data && kpisRes.data[0]) || {};
  const campaigns = campaignsRes.data || [];
  const byChannel = byChannelRes.data || [];
  const topRoi = topRoiRes.data || [];
  const weekly = weeklyRes.data || [];
  const touches = touchesRes.data || [];
  const under = underRes.data || [];

  const fmtPct = (v: number | null | undefined) => (v === null || v === undefined ? '—' : `${v}%`);
  const fmtNum = (v: number | null | undefined) => (v === null || v === undefined ? '—' : v.toLocaleString('en-IN'));
  const fmtDate = (v: string | null | undefined) => (v ? new Date(v).toLocaleDateString('en-IN') : '—');

  return (
    <div className="mx-auto max-w-7xl px-4 py-6 space-y-6">
      <header className="space-y-1">
        <div className="text-xs uppercase tracking-wide text-slate-500">Founder · Growth · r1451</div>
        <h1 className="text-2xl font-semibold">Marketing UTM Campaign Tracker</h1>
        <p className="text-sm text-slate-600">
          Log marketing campaigns with UTM tags, spend, and attributed outcomes. ROI computed per campaign,
          per channel, and per week (last 12wk window).
        </p>
      </header>

      {/* 16 KPI cards */}
      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Total campaigns" value={fmtNum(k.total_campaigns)} />
        <Kpi label="Active" value={fmtNum(k.active_campaigns)} />
        <Kpi label="Paused" value={fmtNum(k.paused_campaigns)} />
        <Kpi label="Ended" value={fmtNum(k.ended_campaigns)} />
        <Kpi label="Total spend" value={formatRupees(k.total_spend_rupees || 0)} />
        <Kpi label="Spend (30d)" value={formatRupees(k.spend_30d_rupees || 0)} />
        <Kpi label="Total revenue" value={formatRupees(k.total_revenue_rupees || 0)} />
        <Kpi label="Revenue (30d)" value={formatRupees(k.revenue_30d_rupees || 0)} />
        <Kpi label="Total leads" value={fmtNum(k.total_leads)} />
        <Kpi label="Leads (30d)" value={fmtNum(k.leads_30d)} />
        <Kpi label="Signups" value={fmtNum(k.total_signups)} />
        <Kpi label="Jobs attributed" value={fmtNum(k.total_jobs_attributed)} />
        <Kpi label="AMC attributed" value={fmtNum(k.total_amc_attributed)} />
        <Kpi label="Overall ROI" value={fmtPct(k.overall_roi_pct)} />
        <Kpi label="Avg CPL" value={k.avg_cpl_rupees ? formatRupees(Math.round(k.avg_cpl_rupees)) : '—'} />
        <Kpi label="Top channel" value={k.best_channel || '—'} />
      </section>

      {/* Write surface */}
      <section className="rounded-lg border border-slate-200 bg-white p-4 space-y-4">
        <h2 className="text-base font-semibold">Log new campaign</h2>
        <form action={createCampaign} className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <input name="name" required placeholder="Campaign name" className="rounded border border-slate-300 px-2 py-1 text-sm" />
          <select name="channel" required className="rounded border border-slate-300 px-2 py-1 text-sm">
            <option value="google_ads">google_ads</option>
            <option value="meta_ads">meta_ads</option>
            <option value="linkedin">linkedin</option>
            <option value="email">email</option>
            <option value="whatsapp">whatsapp</option>
            <option value="seo">seo</option>
            <option value="event">event</option>
            <option value="partner">partner</option>
            <option value="referral">referral</option>
            <option value="other">other</option>
          </select>
          <input name="spend_rupees" type="number" min={0} placeholder="Spend (rupees)" className="rounded border border-slate-300 px-2 py-1 text-sm" />
          <input name="utm_source" required placeholder="utm_source" className="rounded border border-slate-300 px-2 py-1 text-sm" />
          <input name="utm_medium" required placeholder="utm_medium" className="rounded border border-slate-300 px-2 py-1 text-sm" />
          <input name="utm_campaign" required placeholder="utm_campaign" className="rounded border border-slate-300 px-2 py-1 text-sm" />
          <input name="utm_term" placeholder="utm_term (optional)" className="rounded border border-slate-300 px-2 py-1 text-sm" />
          <input name="utm_content" placeholder="utm_content (optional)" className="rounded border border-slate-300 px-2 py-1 text-sm" />
          <input name="notes" placeholder="Notes" className="rounded border border-slate-300 px-2 py-1 text-sm" />
          <div className="md:col-span-3">
            <button type="submit" className="rounded bg-slate-900 px-3 py-1.5 text-sm font-medium text-white">
              Create campaign
            </button>
          </div>
        </form>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2 border-t border-slate-100">
          <form action={logTouch} className="space-y-2">
            <h3 className="text-sm font-semibold">Log touch / attribution</h3>
            <input name="campaign_id" required placeholder="campaign_id (uuid)" className="w-full rounded border border-slate-300 px-2 py-1 text-sm" />
            <select name="touch_kind" required className="w-full rounded border border-slate-300 px-2 py-1 text-sm">
              <option value="lead">lead</option>
              <option value="signup">signup</option>
              <option value="job_attributed">job_attributed</option>
              <option value="amc_attributed">amc_attributed</option>
            </select>
            <input name="lead_email" placeholder="lead email (optional)" className="w-full rounded border border-slate-300 px-2 py-1 text-sm" />
            <input name="lead_phone" placeholder="lead phone (optional)" className="w-full rounded border border-slate-300 px-2 py-1 text-sm" />
            <input name="revenue_rupees" type="number" min={0} placeholder="revenue (rupees)" className="w-full rounded border border-slate-300 px-2 py-1 text-sm" />
            <button type="submit" className="rounded bg-slate-900 px-3 py-1.5 text-sm font-medium text-white">Log touch</button>
          </form>

          <div className="grid grid-cols-1 gap-3">
            <form action={updateSpend} className="space-y-2">
              <h3 className="text-sm font-semibold">Update spend</h3>
              <input name="id" required placeholder="campaign_id (uuid)" className="w-full rounded border border-slate-300 px-2 py-1 text-sm" />
              <input name="spend_rupees" type="number" min={0} required placeholder="new spend (rupees)" className="w-full rounded border border-slate-300 px-2 py-1 text-sm" />
              <button type="submit" className="rounded bg-slate-900 px-3 py-1.5 text-sm font-medium text-white">Update</button>
            </form>
            <form action={setStatus} className="space-y-2">
              <h3 className="text-sm font-semibold">Set status</h3>
              <input name="id" required placeholder="campaign_id (uuid)" className="w-full rounded border border-slate-300 px-2 py-1 text-sm" />
              <select name="status" required className="w-full rounded border border-slate-300 px-2 py-1 text-sm">
                <option value="active">active</option>
                <option value="paused">paused</option>
                <option value="ended">ended</option>
              </select>
              <button type="submit" className="rounded bg-slate-900 px-3 py-1.5 text-sm font-medium text-white">Save</button>
            </form>
          </div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">All campaigns ({campaigns.length})</h2>
        <p className="text-xs text-slate-500">ROI {">"} 0 means revenue exceeds spend. CPL = spend ÷ leads.</p>
        <DataTable
          rows={campaigns as any[]}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'name', header: 'Name', render: (r: any) => r.name ?? '—' },
            { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '—' },
            { key: 'utm_campaign', header: 'utm_campaign', render: (r: any) => r.utm_campaign ?? '—' },
            { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
            { key: 'spend_rupees', header: 'Spend', render: (r: any) => formatRupees(r.spend_rupees) },
            { key: 'leads', header: 'Leads', render: (r: any) => fmtNum(r.leads) },
            { key: 'jobs_attributed', header: 'Jobs', render: (r: any) => fmtNum(r.jobs_attributed) },
            { key: 'revenue_rupees', header: 'Revenue', render: (r: any) => formatRupees(r.revenue_rupees) },
            { key: 'roi_pct', header: 'ROI', render: (r: any) => fmtPct(r.roi_pct) },
            { key: 'cpl_rupees', header: 'CPL', render: (r: any) => (r.cpl_rupees ? formatRupees(Math.round(r.cpl_rupees)) : '—') },
            { key: 'started_at', header: 'Started', render: (r: any) => fmtDate(r.started_at) },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">By channel</h2>
        <DataTable
          rows={byChannel as any[]}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '—' },
            { key: 'campaigns', header: 'Campaigns', render: (r: any) => fmtNum(r.campaigns) },
            { key: 'spend_rupees', header: 'Spend', render: (r: any) => formatRupees(r.spend_rupees) },
            { key: 'leads', header: 'Leads', render: (r: any) => fmtNum(r.leads) },
            { key: 'jobs_attrib', header: 'Jobs', render: (r: any) => fmtNum(r.jobs_attrib) },
            { key: 'revenue_rupees', header: 'Revenue', render: (r: any) => formatRupees(r.revenue_rupees) },
            { key: 'roi_pct', header: 'ROI', render: (r: any) => fmtPct(r.roi_pct) },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">Top ROI (top 10)</h2>
        <DataTable
          rows={topRoi as any[]}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'name', header: 'Name', render: (r: any) => r.name ?? '—' },
            { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '—' },
            { key: 'utm_campaign', header: 'utm_campaign', render: (r: any) => r.utm_campaign ?? '—' },
            { key: 'spend_rupees', header: 'Spend', render: (r: any) => formatRupees(r.spend_rupees) },
            { key: 'revenue_rupees', header: 'Revenue', render: (r: any) => formatRupees(r.revenue_rupees) },
            { key: 'roi_pct', header: 'ROI', render: (r: any) => fmtPct(r.roi_pct) },
            { key: 'leads', header: 'Leads', render: (r: any) => fmtNum(r.leads) },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">Underperformers (ROI {"<"} 0 or zero leads)</h2>
        <DataTable
          rows={under as any[]}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'name', header: 'Name', render: (r: any) => r.name ?? '—' },
            { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '—' },
            { key: 'utm_campaign', header: 'utm_campaign', render: (r: any) => r.utm_campaign ?? '—' },
            { key: 'spend_rupees', header: 'Spend', render: (r: any) => formatRupees(r.spend_rupees) },
            { key: 'revenue_rupees', header: 'Revenue', render: (r: any) => formatRupees(r.revenue_rupees) },
            { key: 'roi_pct', header: 'ROI', render: (r: any) => fmtPct(r.roi_pct) },
            { key: 'leads', header: 'Leads', render: (r: any) => fmtNum(r.leads) },
            { key: 'flag', header: 'Flag', render: (r: any) => r.flag ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">Spend vs revenue by week (last 12wk)</h2>
        <DataTable
          rows={weekly as any[]}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
            { key: 'spend_rupees', header: 'Spend', render: (r: any) => formatRupees(r.spend_rupees) },
            { key: 'revenue_rupees', header: 'Revenue', render: (r: any) => formatRupees(r.revenue_rupees) },
            { key: 'leads', header: 'Leads', render: (r: any) => fmtNum(r.leads) },
            { key: 'jobs_attributed', header: 'Jobs', render: (r: any) => fmtNum(r.jobs_attributed) },
            { key: 'roi_pct', header: 'ROI', render: (r: any) => fmtPct(r.roi_pct) },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">Recent touches (latest 50)</h2>
        <DataTable
          rows={touches as any[]}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'touched_at', header: 'When', render: (r: any) => new Date(r.touched_at).toLocaleString('en-IN') },
            { key: 'touch_kind', header: 'Kind', render: (r: any) => r.touch_kind ?? '—' },
            { key: 'campaign_name', header: 'Campaign', render: (r: any) => r.campaign_name ?? '—' },
            { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '—' },
            { key: 'utm_campaign', header: 'utm_campaign', render: (r: any) => r.utm_campaign ?? '—' },
            { key: 'lead_email', header: 'Email', render: (r: any) => r.lead_email ?? '—' },
            { key: 'lead_phone', header: 'Phone', render: (r: any) => r.lead_phone ?? '—' },
            { key: 'revenue_rupees', header: 'Revenue', render: (r: any) => formatRupees(r.revenue_rupees) },
          ]}
        />
      </section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-slate-200 bg-white p-3">
      <div className="text-xs text-slate-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-slate-900">{value}</div>
    </div>
  );
}