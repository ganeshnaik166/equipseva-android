import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_jobs: number;
  total_quoted: number;
  total_invoiced: number;
  total_variance: number;
  avg_variance_pct: number;
  disputes_open: number;
};

type VarianceRow = {
  id: string;
  job_ref: string;
  customer_org: string;
  engineer_name: string;
  quoted_rupees: number;
  invoiced_rupees: number;
  variance_rupees: number;
  variance_pct: number;
  cause: string;
  approved_by_customer: boolean;
  observed_at: string;
};

type CauseRow = {
  cause: string;
  jobs: number;
  total_variance: number;
  avg_variance_pct: number;
};

type DisputeRow = {
  id: string;
  job_ref: string;
  customer_org: string;
  variance_rupees: number;
  dispute_state: string;
  resolution: string;
  refund_rupees: number;
  resolved_at: string | null;
  notes: string;
};

type EngineerRow = {
  engineer_name: string;
  jobs: number;
  total_quoted: number;
  total_invoiced: number;
  total_variance: number;
  avg_variance_pct: number;
};

type CustomerRow = {
  customer_org: string;
  jobs: number;
  total_variance: number;
  approved_jobs: number;
  disputed_jobs: number;
};

type ResolutionRow = {
  resolution: string;
  jobs: number;
  total_refund: number;
};

type OutlierRow = {
  job_ref: string;
  customer_org: string;
  engineer_name: string;
  variance_rupees: number;
  variance_pct: number;
  cause: string;
};

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN', { maximumFractionDigits: 2 });
}

function pct(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return v.toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, varRes, causeRes, dispRes, engRes, custRes, resRes, outRes] = await Promise.all([
    supabase.rpc('founder_r2836_kpis'),
    supabase.rpc('founder_r2836_variances'),
    supabase.rpc('founder_r2836_cause_breakdown'),
    supabase.rpc('founder_r2836_disputes'),
    supabase.rpc('founder_r2836_engineer_leaderboard'),
    supabase.rpc('founder_r2836_customer_breakdown'),
    supabase.rpc('founder_r2836_resolution_mix'),
    supabase.rpc('founder_r2836_top_outliers'),
  ]);

  const kpi: Kpi = (kpisRes.data?.[0] as Kpi) ?? {
    total_jobs: 0,
    total_quoted: 0,
    total_invoiced: 0,
    total_variance: 0,
    avg_variance_pct: 0,
    disputes_open: 0,
  };
  const variances: VarianceRow[] = (varRes.data as VarianceRow[]) ?? [];
  const causes: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const disputes: DisputeRow[] = (dispRes.data as DisputeRow[]) ?? [];
  const engineers: EngineerRow[] = (engRes.data as EngineerRow[]) ?? [];
  const customers: CustomerRow[] = (custRes.data as CustomerRow[]) ?? [];
  const resolutions: ResolutionRow[] = (resRes.data as ResolutionRow[]) ?? [];
  const outliers: OutlierRow[] = (outRes.data as OutlierRow[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Monthly Engineer Quote vs Invoice Variance</h1>
        <p className="text-sm text-gray-600">
          Per-job comparison: quoted → invoiced → variance → cause → dispute → outcome.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total jobs</div>
          <div className="text-xl font-semibold">{kpi.total_jobs}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Quoted</div>
          <div className="text-xl font-semibold">{rupees(kpi.total_quoted)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Invoiced</div>
          <div className="text-xl font-semibold">{rupees(kpi.total_invoiced)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Variance</div>
          <div className="text-xl font-semibold">{rupees(kpi.total_variance)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Avg variance %</div>
          <div className="text-xl font-semibold">{pct(kpi.avg_variance_pct)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Open disputes</div>
          <div className="text-xl font-semibold">{kpi.disputes_open}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Variance rows (largest delta first)</h2>
        <DataTable
          rows={variances}
          columns={[
            { key: 'job_ref', header: 'Job', render: (r: VarianceRow) => r.job_ref },
            { key: 'customer_org', header: 'Customer', render: (r: VarianceRow) => r.customer_org },
            { key: 'engineer_name', header: 'Engineer', render: (r: VarianceRow) => r.engineer_name },
            { key: 'quoted_rupees', header: 'Quoted', render: (r: VarianceRow) => rupees(r.quoted_rupees) },
            { key: 'invoiced_rupees', header: 'Invoiced', render: (r: VarianceRow) => rupees(r.invoiced_rupees) },
            { key: 'variance_rupees', header: 'Variance', render: (r: VarianceRow) => rupees(r.variance_rupees) },
            { key: 'variance_pct', header: 'Variance %', render: (r: VarianceRow) => pct(r.variance_pct) },
            { key: 'cause', header: 'Cause', render: (r: VarianceRow) => r.cause },
            { key: 'approved_by_customer', header: 'Approved', render: (r: VarianceRow) => (r.approved_by_customer ? 'yes' : 'no') },
            { key: 'observed_at', header: 'Observed', render: (r: VarianceRow) => r.observed_at },
          ]}
          emptyMessage="No data"
          rowKey={(r: VarianceRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cause breakdown</h2>
        <DataTable
          rows={causes}
          columns={[
            { key: 'cause', header: 'Cause', render: (r: CauseRow) => r.cause },
            { key: 'jobs', header: 'Jobs', render: (r: CauseRow) => r.jobs },
            { key: 'total_variance', header: 'Total variance', render: (r: CauseRow) => rupees(r.total_variance) },
            { key: 'avg_variance_pct', header: 'Avg %', render: (r: CauseRow) => pct(r.avg_variance_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CauseRow, i: number) => String(r.cause ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Dispute outcomes</h2>
        <DataTable
          rows={disputes}
          columns={[
            { key: 'job_ref', header: 'Job', render: (r: DisputeRow) => r.job_ref },
            { key: 'customer_org', header: 'Customer', render: (r: DisputeRow) => r.customer_org },
            { key: 'variance_rupees', header: 'Variance', render: (r: DisputeRow) => rupees(r.variance_rupees) },
            { key: 'dispute_state', header: 'State', render: (r: DisputeRow) => r.dispute_state },
            { key: 'resolution', header: 'Resolution', render: (r: DisputeRow) => r.resolution },
            { key: 'refund_rupees', header: 'Refund', render: (r: DisputeRow) => rupees(r.refund_rupees) },
            { key: 'resolved_at', header: 'Resolved', render: (r: DisputeRow) => r.resolved_at ?? '-' },
            { key: 'notes', header: 'Notes', render: (r: DisputeRow) => r.notes },
          ]}
          emptyMessage="No data"
          rowKey={(r: DisputeRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer leaderboard (worst variance first)</h2>
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => r.engineer_name },
            { key: 'jobs', header: 'Jobs', render: (r: EngineerRow) => r.jobs },
            { key: 'total_quoted', header: 'Quoted', render: (r: EngineerRow) => rupees(r.total_quoted) },
            { key: 'total_invoiced', header: 'Invoiced', render: (r: EngineerRow) => rupees(r.total_invoiced) },
            { key: 'total_variance', header: 'Variance', render: (r: EngineerRow) => rupees(r.total_variance) },
            { key: 'avg_variance_pct', header: 'Avg %', render: (r: EngineerRow) => pct(r.avg_variance_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Customer breakdown</h2>
        <DataTable
          rows={customers}
          columns={[
            { key: 'customer_org', header: 'Customer', render: (r: CustomerRow) => r.customer_org },
            { key: 'jobs', header: 'Jobs', render: (r: CustomerRow) => r.jobs },
            { key: 'total_variance', header: 'Variance', render: (r: CustomerRow) => rupees(r.total_variance) },
            { key: 'approved_jobs', header: 'Approved', render: (r: CustomerRow) => r.approved_jobs },
            { key: 'disputed_jobs', header: 'Disputed', render: (r: CustomerRow) => r.disputed_jobs },
          ]}
          emptyMessage="No data"
          rowKey={(r: CustomerRow, i: number) => String(r.customer_org ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Resolution mix</h2>
        <DataTable
          rows={resolutions}
          columns={[
            { key: 'resolution', header: 'Resolution', render: (r: ResolutionRow) => r.resolution },
            { key: 'jobs', header: 'Jobs', render: (r: ResolutionRow) => r.jobs },
            { key: 'total_refund', header: 'Total refund', render: (r: ResolutionRow) => rupees(r.total_refund) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ResolutionRow, i: number) => String(r.resolution ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top outliers (by variance %)</h2>
        <DataTable
          rows={outliers}
          columns={[
            { key: 'job_ref', header: 'Job', render: (r: OutlierRow) => r.job_ref },
            { key: 'customer_org', header: 'Customer', render: (r: OutlierRow) => r.customer_org },
            { key: 'engineer_name', header: 'Engineer', render: (r: OutlierRow) => r.engineer_name },
            { key: 'variance_rupees', header: 'Variance', render: (r: OutlierRow) => rupees(r.variance_rupees) },
            { key: 'variance_pct', header: 'Variance %', render: (r: OutlierRow) => pct(r.variance_pct) },
            { key: 'cause', header: 'Cause', render: (r: OutlierRow) => r.cause },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutlierRow, i: number) => String(r.job_ref ?? i)}
        />
      </section>
    </div>
  );
}
