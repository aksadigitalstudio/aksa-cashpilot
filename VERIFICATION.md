# Validation record — AKSA CashPilot

Verified 28 October 2026 against the production build on http://127.0.0.1:4600.

**61 test groups passed:** 18 shared domain groups, 10 PostgreSQL/PGlite groups, 22 primary browser groups, 11 extended browser groups.

The complete clean-state workflow passed through real UI forms:
Cash 5,000,000 + Bank 20,000,000 → Invoice 10,000,000 → Payment 4,000,000 → Payment 6,000,000 → Supplier Bill 3,000,000 → Bill Payment → Transfer 2,000,000 → Expense → Recurring Flow → Forecast 30/60/90 Days → Projected Shortage → Reports.

Additional checks: multi-line invoice tax/discount, logo and private attachment uploads, receipt/invoice sharing in a separate browser context, actual print invocation plus generated A4 PDF, CSV export bytes and reviewed CSV import, account reconciliation, immutable reversal, budgets, alerts, global search, every workspace route, viewer/staff controls, refresh persistence, two simultaneous browser-tab saves, desktop/tablet/mobile layouts, malformed public-link handling, no critical browser runtime or console errors.

PostgreSQL compiled the actual schema and exercised invoice/payment/bill/transfer commits, revision conflicts, historical ledger edits/deletions, overpayment rejection, balance view, private bucket configuration, and blocked anonymous/authenticated direct access.

The Edge Function TypeScript syntax and production Vite build passed. Shared browser/server domain rules were synchronized.

**Live deployment verification, 29 October 2026:** authenticated OWNER login, zero-balance cloud workspace reads, settings writes, private Storage upload, signed-image preview and persistence after refresh passed. Six additional actual Edge-handler regression groups passed. Five deployed HTTP security checks passed. The 22 primary browser groups also passed against the public Vercel demo. Live business records were kept at zero ledger entries; destructive financial integration tests remain isolated. The included browser demo uses IndexedDB and demo identities, not secure shared-user authentication. Shared demo documents are unsigned snapshots; cloud tokens resolve live server records.

Machine-readable results and screenshots are available in test-artifacts/ in the local working folder. Tests use isolated Chrome contexts and do not modify the user's browser preview data.
