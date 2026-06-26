import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_archives: number;
  clean_count: number;
  rejected_count: number;
  pending_count: number;
  avg_score_pct: number;
  signoff_rate_pct: number;
  total_storage_mb: number;
};

type ArchiveRow = {
  id: string;
  customer_org_name: string;
  engineer_name: string;
  job_code: string;
  job_kind: string;
  equipment_label: string;
  photos_uploaded: number;
  photos_required: number;
  archive_verdict: string;
  archive_score_pct: number;
  customer_signoff_received: boolean;
};

type VerdictRow = {
  verdict: string;
  bundle_count: number;
  avg_score: number;
  total_photos: number;
};

type LeaderRow = {
  engineer_name: string;
  archives: number;
  clean_archives: number;
  avg_score: number;
  signoff_rate: number;
};

type GapRow = {
  job_code: string;
  customer_org_name: string;
  engineer_name: string;
  photos_uploaded: number;
  photos_required: number;
  gap: number;
  archive_verdict: string;
};

type TimelineRow = {
  event_at: string;
  event_kind: string;
  actor_role: string;
  detail: string;
  prior_verdict: string | null;
  new_verdict: string | null;
};

type StorageRow = {
  job_kind: string;
  bundle_count: number;
  total_photos: number;
  storage_mb: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, listRes, verdictRes, leaderRes, gapsRes, timelineRes, storageRes] = await Promise.all([
    supabase.rpc('kpis_photo_archive_r2816'),
    supabase.rpc('list_photo_archives_r2816'),
    supabase.rpc('verdict_breakdown_r2816'),
    supabase.rpc('engineer_archive_leaderboard_r2816'),
    supabase.rpc('archive_gaps_r2816'),
    supabase.rpc('audit_log_timeline_r2816'),
    supabase.rpc('storage_rollup_r2816'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? {
    total_archives: 0,
    clean_count: 0,
    rejected_count: 0,
    pending_count: 0,
    avg_score_pct: 0,
    signoff_rate_pct: 0,
    total_storage_mb: 0,
  }) as Kpi;

  const archives: ArchiveRow[] = (listRes.data ?? []) as ArchiveRow[];
  const verdicts: VerdictRow[] = (verdictRes.data ?? []) as VerdictRow[];
  const leaders: LeaderRow[] = (leaderRes.data ?? []) as LeaderRow[];
  const gaps: GapRow[] = (gapsRes.data ?? []) as GapRow[];
  const timeline: TimelineRow[] = (timelineRes.data ?? []) as TimelineRow[];
  const storage: StorageRow[] = (storageRes.data ?? []) as StorageRow[];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
        Customer Monthly Engineer Job Completion Photo Archive
      </h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Round r2816 — job × photos × resolution proof × customer signoff × archive verdict.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total Archives" value={kpi.total_archives} />
        <KpiCard label="Clean" value={kpi.clean_count} />
        <KpiCard label="Rejected" value={kpi.rejected_count} />
        <KpiCard label="Pending Review" value={kpi.pending_count} />
        <KpiCard label="Avg Score %" value={kpi.avg_score_pct} />
        <KpiCard label="Signoff Rate %" value={kpi.signoff_rate_pct} />
        <KpiCard label="Storage (MB)" value={kpi.total_storage_mb} />
      </section>

      <Section title="Archive Bundles">
        <DataTable
          rows={archives}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: ArchiveRow) => r.job_code },
            { key: 'customer_org_name', header: 'Customer', render: (r: ArchiveRow) => r.customer_org_name },
            { key: 'engineer_name', header: 'Engineer', render: (r: ArchiveRow) => r.engineer_name },
            { key: 'job_kind', header: 'Kind', render: (r: ArchiveRow) => r.job_kind },
            { key: 'equipment_label', header: 'Equipment', render: (r: ArchiveRow) => r.equipment_label },
            { key: 'photos', header: 'Photos', render: (r: ArchiveRow) => `${r.photos_uploaded} / ${r.photos_required}` },
            { key: 'archive_verdict', header: 'Verdict', render: (r: ArchiveRow) => <VerdictBadge value={r.archive_verdict} /> },
            { key: 'archive_score_pct', header: 'Score %', render: (r: ArchiveRow) => Number(r.archive_score_pct).toFixed(1) },
            { key: 'customer_signoff_received', header: 'Signoff', render: (r: ArchiveRow) => (r.customer_signoff_received ? 'yes' : 'no') },
          ]}
          emptyMessage="No data"
          rowKey={(r: ArchiveRow, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Verdict Breakdown">
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => <VerdictBadge value={r.verdict} /> },
            { key: 'bundle_count', header: 'Bundles', render: (r: VerdictRow) => r.bundle_count },
            { key: 'avg_score', header: 'Avg Score', render: (r: VerdictRow) => Number(r.avg_score).toFixed(1) },
            { key: 'total_photos', header: 'Total Photos', render: (r: VerdictRow) => r.total_photos },
          ]}
          emptyMessage="No data"
          rowKey={(r: VerdictRow, i: number) => String(r.verdict ?? i)}
        />
      </Section>

      <Section title="Engineer Leaderboard">
        <DataTable
          rows={leaders}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: LeaderRow) => r.engineer_name },
            { key: 'archives', header: 'Archives', render: (r: LeaderRow) => r.archives },
            { key: 'clean_archives', header: 'Clean', render: (r: LeaderRow) => r.clean_archives },
            { key: 'avg_score', header: 'Avg Score', render: (r: LeaderRow) => Number(r.avg_score).toFixed(1) },
            { key: 'signoff_rate', header: 'Signoff %', render: (r: LeaderRow) => Number(r.signoff_rate).toFixed(1) },
          ]}
          emptyMessage="No data"
          rowKey={(r: LeaderRow, i: number) => String(r.engineer_name ?? i)}
        />
      </Section>

      <Section title="Gap Watchlist (uploaded < required OR resolution/signoff missing)">
        <DataTable
          rows={gaps}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: GapRow) => r.job_code },
            { key: 'customer_org_name', header: 'Customer', render: (r: GapRow) => r.customer_org_name },
            { key: 'engineer_name', header: 'Engineer', render: (r: GapRow) => r.engineer_name },
            { key: 'photos', header: 'Photos', render: (r: GapRow) => `${r.photos_uploaded} / ${r.photos_required}` },
            { key: 'gap', header: 'Gap', render: (r: GapRow) => r.gap },
            { key: 'archive_verdict', header: 'Verdict', render: (r: GapRow) => <VerdictBadge value={r.archive_verdict} /> },
          ]}
          emptyMessage="No data"
          rowKey={(r: GapRow, i: number) => String(r.job_code ?? i)}
        />
      </Section>

      <Section title="Storage Rollup by Job Kind">
        <DataTable
          rows={storage}
          columns={[
            { key: 'job_kind', header: 'Kind', render: (r: StorageRow) => r.job_kind },
            { key: 'bundle_count', header: 'Bundles', render: (r: StorageRow) => r.bundle_count },
            { key: 'total_photos', header: 'Photos', render: (r: StorageRow) => r.total_photos },
            { key: 'storage_mb', header: 'Storage (MB)', render: (r: StorageRow) => Number(r.storage_mb).toFixed(2) },
          ]}
          emptyMessage="No data"
          rowKey={(r: StorageRow, i: number) => String(r.job_kind ?? i)}
        />
      </Section>

      <Section title="Audit Timeline (latest 50)">
        <DataTable
          rows={timeline}
          columns={[
            { key: 'event_at', header: 'When', render: (r: TimelineRow) => new Date(r.event_at).toLocaleString() },
            { key: 'event_kind', header: 'Event', render: (r: TimelineRow) => r.event_kind },
            { key: 'actor_role', header: 'Actor', render: (r: TimelineRow) => r.actor_role },
            { key: 'detail', header: 'Detail', render: (r: TimelineRow) => r.detail },
            { key: 'verdict_shift', header: 'Verdict Shift', render: (r: TimelineRow) => `${r.prior_verdict ?? '-'} => ${r.new_verdict ?? '-'}` },
          ]}
          emptyMessage="No data"
          rowKey={(_r: TimelineRow, i: number) => String(i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: number | string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 10, padding: 14, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}

function VerdictBadge({ value }: { value: string }) {
  const color =
    value === 'clean' ? '#0a7a2f' :
    value === 'minor_gaps' ? '#9a7600' :
    value === 'rejected' ? '#a11212' :
    '#555';
  const bg =
    value === 'clean' ? '#e3f7e8' :
    value === 'minor_gaps' ? '#fff4d1' :
    value === 'rejected' ? '#fde2e2' :
    '#eee';
  return (
    <span style={{ color, background: bg, padding: '2px 8px', borderRadius: 999, fontSize: 12, fontWeight: 600 }}>
      {value}
    </span>
  );
}
