import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [tests, qsbs, expiring, docs] = await Promise.all([
    sb.rpc('inv422_list_tests_r1857'),
    sb.rpc('inv422_qsbs_eligible_investors_r1857'),
    sb.rpc('inv422_expiring_holdings_r1857'),
    sb.rpc('inv422_list_documents_r1857', { p_test_id: null }),
  ]);

  const testRows: any[] = (tests.data as any[]) ?? [];
  const qsbsRows: any[] = (qsbs.data as any[]) ?? [];
  const expiringRows: any[] = (expiring.data as any[]) ?? [];
  const docRows: any[] = (docs.data as any[]) ?? [];

  const verifiedCount = testRows.filter((r) => r.status === 'verified').length;
  const underReviewCount = testRows.filter((r) => r.status === 'under_review').length;
  const nonQualCount = testRows.filter((r) => r.status === 'non_qualifying').length;

  const testCols: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'fiscal_year', header: 'FY', render: (r: any) => r.fiscal_year ?? '-' },
    { key: 'holding_period_years', header: 'Holding (yrs)', render: (r: any) => Number(r.holding_period_years ?? 0).toFixed(2) },
    { key: 'founded_at_invest', header: 'Founded', render: (r: any) => r.founded_at_invest ?? '-' },
    { key: 'holding_test_passed', header: 'Hold >= 5y', render: (r: any) => (r.holding_test_passed ? 'PASS' : 'FAIL') },
    { key: 'c_corp_test_passed', header: 'C-Corp', render: (r: any) => (r.c_corp_test_passed ? 'PASS' : 'FAIL') },
    { key: 'gross_assets_test_passed', header: 'Gross Assets <= 50M', render: (r: any) => (r.gross_assets_test_passed ? 'PASS' : 'FAIL') },
    { key: 'qsbs_eligible', header: 'QSBS', render: (r: any) => (r.qsbs_eligible ? 'YES' : 'NO') },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
  ];

  const qsbsCols: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'fiscal_year', header: 'FY', render: (r: any) => r.fiscal_year ?? '-' },
    { key: 'holding_period_years', header: 'Holding (yrs)', render: (r: any) => Number(r.holding_period_years ?? 0).toFixed(2) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'holding_period_years', header: 'Holding (yrs)', render: (r: any) => Number(r.holding_period_years ?? 0).toFixed(2) },
    { key: 'founded_at_invest', header: 'Founded', render: (r: any) => r.founded_at_invest ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
  ];

  const docCols: Column<any>[] = [
    { key: 'test_id', header: 'Test', render: (r: any) => String(r.test_id ?? '').slice(0, 8) },
    { key: 'doc_type', header: 'Doc Type', render: (r: any) => r.doc_type ?? '-' },
    { key: 'doc_url', header: 'URL', render: (r: any) => r.doc_url ?? '-' },
    { key: 'uploaded_at', header: 'Uploaded', render: (r: any) => (r.uploaded_at ? new Date(r.uploaded_at).toLocaleString() : '-') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, marginBottom: 8 }}>Investor 422 Substantial Test Tracker</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        US IRC §1202 QSBS substantial-purpose investment test. Tracks holding period (&gt;= 5y), C-corp status, and gross-assets cap (&lt;= $50M).
      </p>

      <section style={{ display: 'flex', gap: 16, marginBottom: 24, flexWrap: 'wrap' }}>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6, minWidth: 160 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Verified</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{verifiedCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6, minWidth: 160 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Under Review</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{underReviewCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6, minWidth: 160 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Non-Qualifying</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{nonQualCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6, minWidth: 160 }}>
          <div style={{ color: '#666', fontSize: 12 }}>QSBS Eligible</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{qsbsRows.length}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>All Substantial Tests</h2>
        <DataTable rows={testRows} columns={testCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>QSBS-Eligible Investors</h2>
        <DataTable rows={qsbsRows} columns={qsbsCols} rowKey={(r: any, i: number) => String(r.investor_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Expiring / Near-5y Holdings</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Holdings with period between 4 and 5 years and not yet QSBS-qualified — flag for follow-up.
        </p>
        <DataTable rows={expiringRows} columns={expiringCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Supporting Documents</h2>
        <DataTable rows={docRows} columns={docCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
