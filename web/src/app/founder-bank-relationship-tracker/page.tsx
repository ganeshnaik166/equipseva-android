import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type RelRow = {
  id: string;
  bank_name: string;
  branch_name: string | null;
  account_number_last4: string | null;
  relationship_status: string;
  rm_name: string | null;
  rm_email: string | null;
  rm_phone: string | null;
  onboarded_on: string;
  next_review_on: string | null;
  facility_count: number;
  total_sanctioned_rupees: number;
  total_drawn_rupees: number;
};

type FacRow = {
  id: string;
  relationship_id: string;
  bank_name: string;
  facility_kind: string;
  facility_label: string;
  sanctioned_limit_rupees: number;
  drawn_amount_rupees: number;
  utilisation_pct: number;
  interest_rate_bps: number | null;
  sanctioned_on: string | null;
  matures_on: string | null;
  renewal_due_on: string | null;
  facility_status: string;
};

type RenewalRow = {
  id: string;
  bank_name: string;
  facility_kind: string;
  facility_label: string;
  sanctioned_limit_rupees: number;
  renewal_due_on: string;
  days_until_renewal: number;
  rm_name: string | null;
  rm_email: string | null;
};

type KindRow = {
  facility_kind: string;
  live_count: number;
  total_sanctioned_rupees: number;
  total_drawn_rupees: number;
  avg_utilisation_pct: number;
};

type ReviewRow = {
  id: string;
  bank_name: string;
  rm_name: string | null;
  rm_email: string | null;
  rm_phone: string | null;
  next_review_on: string;
  days_until_review: number;
  relationship_status: string;
};

function rupees(n: number | null | undefined): string {
  if (n == null) return '0';
  return '₹' + (Number(n) / 100000).toFixed(2) + 'L';
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [relRes, facRes, renewalRes, kindRes, reviewRes] = await Promise.all([
    sb.rpc('list_bank_relationships_r2297'),
    sb.rpc('list_bank_facilities_r2297'),
    sb.rpc('renewals_due_soon_r2297', { p_window_days: 60 }),
    sb.rpc('summary_by_facility_kind_r2297'),
    sb.rpc('relationship_review_calendar_r2297'),
  ]);

  const rels: RelRow[] = (relRes.data as RelRow[] | null) ?? [];
  const facs: FacRow[] = (facRes.data as FacRow[] | null) ?? [];
  const renewals: RenewalRow[] = (renewalRes.data as RenewalRow[] | null) ?? [];
  const kinds: KindRow[] = (kindRes.data as KindRow[] | null) ?? [];
  const reviews: ReviewRow[] = (reviewRes.data as ReviewRow[] | null) ?? [];

  const relCols: Column<RelRow>[] = [
    { key: 'bank_name', header: 'Bank', render: (r: any) => r.bank_name },
    { key: 'branch_name', header: 'Branch', render: (r: any) => r.branch_name ?? '—' },
    { key: 'account_number_last4', header: 'A/c ****', render: (r: any) => r.account_number_last4 ?? '—' },
    { key: 'relationship_status', header: 'Status', render: (r: any) => r.relationship_status },
    { key: 'rm_name', header: 'RM', render: (r: any) => r.rm_name ?? '—' },
    { key: 'rm_email', header: 'RM email', render: (r: any) => r.rm_email ?? '—' },
    { key: 'rm_phone', header: 'RM phone', render: (r: any) => r.rm_phone ?? '—' },
    { key: 'onboarded_on', header: 'Onboarded', render: (r: any) => r.onboarded_on },
    { key: 'next_review_on', header: 'Next review', render: (r: any) => r.next_review_on ?? '—' },
    { key: 'facility_count', header: 'Facilities', render: (r: any) => r.facility_count },
    { key: 'total_sanctioned_rupees', header: 'Sanctioned', render: (r: any) => rupees(r.total_sanctioned_rupees) },
    { key: 'total_drawn_rupees', header: 'Drawn', render: (r: any) => rupees(r.total_drawn_rupees) },
  ];

  const facCols: Column<FacRow>[] = [
    { key: 'bank_name', header: 'Bank', render: (r: any) => r.bank_name },
    { key: 'facility_kind', header: 'Kind', render: (r: any) => r.facility_kind },
    { key: 'facility_label', header: 'Label', render: (r: any) => r.facility_label },
    { key: 'sanctioned_limit_rupees', header: 'Sanctioned', render: (r: any) => rupees(r.sanctioned_limit_rupees) },
    { key: 'drawn_amount_rupees', header: 'Drawn', render: (r: any) => rupees(r.drawn_amount_rupees) },
    { key: 'utilisation_pct', header: 'Util %', render: (r: any) => Number(r.utilisation_pct).toFixed(1) },
    { key: 'interest_rate_bps', header: 'Rate (bps)', render: (r: any) => r.interest_rate_bps ?? '—' },
    { key: 'sanctioned_on', header: 'Sanctioned on', render: (r: any) => r.sanctioned_on ?? '—' },
    { key: 'matures_on', header: 'Matures', render: (r: any) => r.matures_on ?? '—' },
    { key: 'renewal_due_on', header: 'Renewal due', render: (r: any) => r.renewal_due_on ?? '—' },
    { key: 'facility_status', header: 'Status', render: (r: any) => r.facility_status },
  ];

  const renewalCols: Column<RenewalRow>[] = [
    { key: 'bank_name', header: 'Bank', render: (r: any) => r.bank_name },
    { key: 'facility_kind', header: 'Kind', render: (r: any) => r.facility_kind },
    { key: 'facility_label', header: 'Label', render: (r: any) => r.facility_label },
    { key: 'sanctioned_limit_rupees', header: 'Limit', render: (r: any) => rupees(r.sanctioned_limit_rupees) },
    { key: 'renewal_due_on', header: 'Renewal due', render: (r: any) => r.renewal_due_on },
    { key: 'days_until_renewal', header: 'Days left', render: (r: any) => r.days_until_renewal },
    { key: 'rm_name', header: 'RM', render: (r: any) => r.rm_name ?? '—' },
    { key: 'rm_email', header: 'RM email', render: (r: any) => r.rm_email ?? '—' },
  ];

  const kindCols: Column<KindRow>[] = [
    { key: 'facility_kind', header: 'Kind', render: (r: any) => r.facility_kind },
    { key: 'live_count', header: 'Live', render: (r: any) => r.live_count },
    { key: 'total_sanctioned_rupees', header: 'Sanctioned', render: (r: any) => rupees(r.total_sanctioned_rupees) },
    { key: 'total_drawn_rupees', header: 'Drawn', render: (r: any) => rupees(r.total_drawn_rupees) },
    { key: 'avg_utilisation_pct', header: 'Avg util %', render: (r: any) => Number(r.avg_utilisation_pct).toFixed(1) },
  ];

  const reviewCols: Column<ReviewRow>[] = [
    { key: 'bank_name', header: 'Bank', render: (r: any) => r.bank_name },
    { key: 'rm_name', header: 'RM', render: (r: any) => r.rm_name ?? '—' },
    { key: 'rm_email', header: 'RM email', render: (r: any) => r.rm_email ?? '—' },
    { key: 'rm_phone', header: 'RM phone', render: (r: any) => r.rm_phone ?? '—' },
    { key: 'next_review_on', header: 'Review on', render: (r: any) => r.next_review_on },
    { key: 'days_until_review', header: 'Days left', render: (r: any) => r.days_until_review },
    { key: 'relationship_status', header: 'Status', render: (r: any) => r.relationship_status },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Bank Relationship Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Current banks, sanctioned limits, lines of credit & term loans, RM contacts, and renewal calendar.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Bank relationships ({rels.length})</h2>
        <DataTable
          rows={rels}
          columns={relCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All facilities ({facs.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Utilisation = drawn / sanctioned. Status &lt;&gt; live rows are kept for history.
        </p>
        <DataTable
          rows={facs}
          columns={facCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Renewals due within 60 days ({renewals.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Live facilities with renewal_due_on &lt;= today + 60 days. Sort ascending by renewal date.
        </p>
        <DataTable
          rows={renewals}
          columns={renewalCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary by facility kind ({kinds.length})</h2>
        <DataTable
          rows={kinds}
          columns={kindCols}
          rowKey={(r: any, i: number) => String(r.facility_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>RM review calendar ({reviews.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Active & watch relationships with a next_review_on date set.
        </p>
        <DataTable
          rows={reviews}
          columns={reviewCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
