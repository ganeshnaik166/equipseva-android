import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  engineers_tracked: number;
  units_assigned_total: number;
  units_completed_total: number;
  completion_pct: number | null;
  open_blockers: number;
  critical_blockers: number;
  avg_verification_pct: number | null;
};

type Readiness = {
  engineer_code: string;
  engineer_name: string;
  region: string;
  oem_partner: string;
  recall_campaign: string;
  units_assigned: number;
  units_completed: number;
  kit_ready_pct: number;
  training_pct: number;
  avg_turnaround_h: number;
  verification_pass_pct: number;
  readiness_grade: string;
  blocker_note: string | null;
};

type Grade = {
  readiness_grade: string;
  engineers: number;
  units_assigned: number;
  units_completed: number;
  completion_pct: number | null;
};

type Blocker = {
  engineer_code: string;
  blocker_type: string;
  severity: string;
  units_blocked: number;
  reported_at: string;
  due_by: string;
  owner_team: string;
  status: string;
  resolution_note: string | null;
};

type Oem = {
  oem_partner: string;
  engineers: number;
  units_assigned: number;
  units_completed: number;
  completion_pct: number | null;
  avg_kit_ready: number | null;
  avg_verification: number | null;
};

type Region = {
  region: string;
  engineers: number;
  units_assigned: number;
  units_completed: number;
  completion_pct: number | null;
  avg_turnaround_h: number | null;
  open_blockers: number;
};

type AtRisk = {
  engineer_code: string;
  engineer_name: string;
  region: string;
  oem_partner: string;
  units_remaining: number;
  verification_pass_pct: number;
  readiness_grade: string;
  blocker_note: string | null;
};

type Bucket = {
  bucket: string;
  engineers: number;
  avg_verification: number | null;
};

function fmtPct(v: number | null | undefined) {
  if (v === null || v === undefined) return '—';
  return `${Number(v).toFixed(1)}%`;
}

function fmtNum(v: number | null | undefined) {
  if (v === null || v === undefined) return '—';
  return Number(v).toLocaleString('en-IN');
}

function fmtDateTime(v: string | null | undefined) {
  if (!v) return '—';
  try {
    return new Date(v).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
  } catch {
    return v;
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, readinessRes, gradeRes, blockersRes, oemRes, regionRes, atRiskRes, bucketRes] =
    await Promise.all([
      supabase.rpc('founder_r2750_kpis'),
      supabase.rpc('founder_r2750_readiness_list'),
      supabase.rpc('founder_r2750_grade_distribution'),
      supabase.rpc('founder_r2750_blockers_list'),
      supabase.rpc('founder_r2750_oem_rollup'),
      supabase.rpc('founder_r2750_region_rollup'),
      supabase.rpc('founder_r2750_at_risk'),
      supabase.rpc('founder_r2750_turnaround_buckets'),
    ]);

  const kpis: Kpis | null = (kpisRes.data as Kpis[] | null)?.[0] ?? null;
  const readiness: Readiness[] = (readinessRes.data as Readiness[] | null) ?? [];
  const grades: Grade[] = (gradeRes.data as Grade[] | null) ?? [];
  const blockers: Blocker[] = (blockersRes.data as Blocker[] | null) ?? [];
  const oems: Oem[] = (oemRes.data as Oem[] | null) ?? [];
  const regions: Region[] = (regionRes.data as Region[] | null) ?? [];
  const atRisk: AtRisk[] = (atRiskRes.data as AtRisk[] | null) ?? [];
  const buckets: Bucket[] = (bucketRes.data as Bucket[] | null) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Engineer Monthly Recall Action Readiness</h1>
        <p className="text-sm text-gray-600">
          Engineer × OEM recall × kit ready × training × turnaround × verification.
          Grades A/B are on-track, C/D/F need founder action.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Engineers tracked</div>
          <div className="text-2xl font-semibold">{fmtNum(kpis?.engineers_tracked)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Units assigned</div>
          <div className="text-2xl font-semibold">{fmtNum(kpis?.units_assigned_total)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Units completed</div>
          <div className="text-2xl font-semibold">{fmtNum(kpis?.units_completed_total)}</div>
          <div className="text-xs text-gray-500 mt-1">{fmtPct(kpis?.completion_pct)} of plan</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Avg verification pass</div>
          <div className="text-2xl font-semibold">{fmtPct(kpis?.avg_verification_pct)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Open blockers</div>
          <div className="text-2xl font-semibold">{fmtNum(kpis?.open_blockers)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Critical blockers</div>
          <div className="text-2xl font-semibold">{fmtNum(kpis?.critical_blockers)}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Readiness grade distribution</h2>
        <p className="text-sm text-gray-600">A is best, F is field-stop. Completion percentage rolled up per grade.</p>
        <DataTable
          rows={grades}
          rowKey={(r, i) => String(r.readiness_grade ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'readiness_grade', header: 'Grade', render: (r: Grade) => r.readiness_grade },
            { key: 'engineers', header: 'Engineers', render: (r: Grade) => fmtNum(r.engineers) },
            { key: 'units_assigned', header: 'Assigned', render: (r: Grade) => fmtNum(r.units_assigned) },
            { key: 'units_completed', header: 'Completed', render: (r: Grade) => fmtNum(r.units_completed) },
            { key: 'completion_pct', header: 'Completion', render: (r: Grade) => fmtPct(r.completion_pct) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Engineer readiness scorecard</h2>
        <p className="text-sm text-gray-600">Per-engineer recall view. Sorted by grade then verification pass rate.</p>
        <DataTable
          rows={readiness}
          rowKey={(r, i) => String(r.engineer_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: Readiness) => `${r.engineer_code} — ${r.engineer_name}` },
            { key: 'region', header: 'Region', render: (r: Readiness) => r.region },
            { key: 'oem_partner', header: 'OEM', render: (r: Readiness) => r.oem_partner },
            { key: 'recall_campaign', header: 'Campaign', render: (r: Readiness) => r.recall_campaign },
            { key: 'units', header: 'Units', render: (r: Readiness) => `${r.units_completed} / ${r.units_assigned}` },
            { key: 'kit_ready_pct', header: 'Kit ready', render: (r: Readiness) => fmtPct(r.kit_ready_pct) },
            { key: 'training_pct', header: 'Training', render: (r: Readiness) => fmtPct(r.training_pct) },
            { key: 'avg_turnaround_h', header: 'Turnaround (h)', render: (r: Readiness) => Number(r.avg_turnaround_h).toFixed(1) },
            { key: 'verification_pass_pct', header: 'Verification', render: (r: Readiness) => fmtPct(r.verification_pass_pct) },
            { key: 'readiness_grade', header: 'Grade', render: (r: Readiness) => r.readiness_grade },
            { key: 'blocker_note', header: 'Note', render: (r: Readiness) => r.blocker_note ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Open blocker actions</h2>
        <p className="text-sm text-gray-600">Critical and high severity blockers shown first. Ordered by due-by ascending.</p>
        <DataTable
          rows={blockers}
          rowKey={(r, i) => `${r.engineer_code}-${r.blocker_type}-${i}`}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: Blocker) => r.engineer_code },
            { key: 'blocker_type', header: 'Type', render: (r: Blocker) => r.blocker_type },
            { key: 'severity', header: 'Severity', render: (r: Blocker) => r.severity },
            { key: 'units_blocked', header: 'Units blocked', render: (r: Blocker) => fmtNum(r.units_blocked) },
            { key: 'reported_at', header: 'Reported', render: (r: Blocker) => fmtDateTime(r.reported_at) },
            { key: 'due_by', header: 'Due by', render: (r: Blocker) => fmtDateTime(r.due_by) },
            { key: 'owner_team', header: 'Owner', render: (r: Blocker) => r.owner_team },
            { key: 'status', header: 'Status', render: (r: Blocker) => r.status },
            { key: 'resolution_note', header: 'Note', render: (r: Blocker) => r.resolution_note ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">OEM partner rollup</h2>
        <p className="text-sm text-gray-600">Worst completion percentage at the top — that's where founder pressure goes.</p>
        <DataTable
          rows={oems}
          rowKey={(r, i) => String(r.oem_partner ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'oem_partner', header: 'OEM', render: (r: Oem) => r.oem_partner },
            { key: 'engineers', header: 'Engineers', render: (r: Oem) => fmtNum(r.engineers) },
            { key: 'units_assigned', header: 'Assigned', render: (r: Oem) => fmtNum(r.units_assigned) },
            { key: 'units_completed', header: 'Completed', render: (r: Oem) => fmtNum(r.units_completed) },
            { key: 'completion_pct', header: 'Completion', render: (r: Oem) => fmtPct(r.completion_pct) },
            { key: 'avg_kit_ready', header: 'Avg kit ready', render: (r: Oem) => fmtPct(r.avg_kit_ready) },
            { key: 'avg_verification', header: 'Avg verification', render: (r: Oem) => fmtPct(r.avg_verification) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Region rollup</h2>
        <p className="text-sm text-gray-600">Region-level view with open-blocker count joined in.</p>
        <DataTable
          rows={regions}
          rowKey={(r, i) => String(r.region ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'region', header: 'Region', render: (r: Region) => r.region },
            { key: 'engineers', header: 'Engineers', render: (r: Region) => fmtNum(r.engineers) },
            { key: 'units_assigned', header: 'Assigned', render: (r: Region) => fmtNum(r.units_assigned) },
            { key: 'units_completed', header: 'Completed', render: (r: Region) => fmtNum(r.units_completed) },
            { key: 'completion_pct', header: 'Completion', render: (r: Region) => fmtPct(r.completion_pct) },
            { key: 'avg_turnaround_h', header: 'Avg turnaround (h)', render: (r: Region) => r.avg_turnaround_h !== null && r.avg_turnaround_h !== undefined ? Number(r.avg_turnaround_h).toFixed(1) : '—' },
            { key: 'open_blockers', header: 'Open blockers', render: (r: Region) => fmtNum(r.open_blockers) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">At-risk engineers (grade C / D / F)</h2>
        <p className="text-sm text-gray-600">Sorted by units remaining descending. Verification ascending tie-break.</p>
        <DataTable
          rows={atRisk}
          rowKey={(r, i) => String(r.engineer_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: AtRisk) => `${r.engineer_code} — ${r.engineer_name}` },
            { key: 'region', header: 'Region', render: (r: AtRisk) => r.region },
            { key: 'oem_partner', header: 'OEM', render: (r: AtRisk) => r.oem_partner },
            { key: 'units_remaining', header: 'Units remaining', render: (r: AtRisk) => fmtNum(r.units_remaining) },
            { key: 'verification_pass_pct', header: 'Verification', render: (r: AtRisk) => fmtPct(r.verification_pass_pct) },
            { key: 'readiness_grade', header: 'Grade', render: (r: AtRisk) => r.readiness_grade },
            { key: 'blocker_note', header: 'Note', render: (r: AtRisk) => r.blocker_note ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Turnaround time buckets</h2>
        <p className="text-sm text-gray-600">Faster turnaround usually correlates with higher verification pass rate.</p>
        <DataTable
          rows={buckets}
          rowKey={(r, i) => String(r.bucket ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'bucket', header: 'Bucket', render: (r: Bucket) => r.bucket },
            { key: 'engineers', header: 'Engineers', render: (r: Bucket) => fmtNum(r.engineers) },
            { key: 'avg_verification', header: 'Avg verification', render: (r: Bucket) => fmtPct(r.avg_verification) },
          ]}
        />
      </section>
    </div>
  );
}
