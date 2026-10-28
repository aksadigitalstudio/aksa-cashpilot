# AKSA CashPilot

A functional small-business cash-flow workspace for **AKSA Studio**. React, Vite, locally bundled fonts, IndexedDB demo storage, optional authenticated Supabase backend. Default currency: **IDR**.

## Run

Node.js 20.19+ or 22.12+.

    npm ci
    npm run dev

Development: http://127.0.0.1:4600

For the production build:

    npm run build
    npm run preview

The included production server also supports direct /invoice/{token} and /receipt/{token} URLs. Deploy dist/ to static hosting. For Vercel, use Vite, build command npm run build, output directory dist. vercel.json supplies SPA rewrites.

## Start exploring

The first browser visit creates a persistent, clearly labeled demo with three accounts, customers, suppliers, income, expenses, invoices, partial payments, overdue documents, recurring flows, budgets and a 90-day scenario that dips below zero before recovering.

- **Accounts**: opening balances, linked transfers, history, reconciliation and explicit corrections.
- **Invoices**: save a draft, issue it, record partial/final payment, print or share the invoice and each payment receipt.
- **Bills & payables**: record an obligation, then record actual payments separately.
- **Income / Expenses**: actual money movements; expense receipts support images/PDFs up to 2 MB.
- **Recurring flows**: schedules stay outside actual cash until an occurrence is explicitly posted.
- **Cash forecast / Cash-flow calendar**: choose 30, 60 or 90 days; compare confirmed-only schedules and the scenario including expected flows. Include/exclude unpaid documents and manual events.
- **Budgets / Reports**: cash-basis operating results, invoice value, receivables and liabilities are labeled separately.
- **Transactions**: filter, inspect, reverse eligible direct entries, export CSV or import through column mapping and validation.
- **Settings**: identity, logo, categories, invoice rules, minimum buffer and demo data backup.

The demo role selector demonstrates OWNER, FINANCE ADMIN, STAFF and VIEWER controls. It is **not authentication**. Demo records live in this browser, not in a cloud account. Use a dedicated browser profile for testing. Download a JSON backup from Settings before clearing site data. Browser storage is not a substitute for business backups.

Demo shared links carry an unsigned, read-only snapshot of **one invoice or receipt** in their URL fragment. They work in another browser without exposing the workspace. They do not update automatically after later payments. Logos are omitted to keep these links compact. Verify payment information with the sender. Cloud links instead resolve live records using opaque, revocable sharing tokens.

## Financial model

- Integer whole-currency amounts, default Rupiah. No foreign-exchange conversion. Changing display currency relabels values; it does not convert balances. Issued documents retain their recorded currency.
- Actual balances = signed posted ledger entries, including opening balances and explained corrections.
- Issuing an invoice or creating an unpaid bill changes receivables/payables, **not actual cash**.
- Payments post exactly one corresponding ledger movement and reduce the document's remaining balance.
- Transfers create two equal/opposite linked movements and are excluded from operating income/expenses.
- No normal overpayments, invalid/zero amounts, same-account transfers or unauthorized negative daily balances.
- Direct-entry corrections append reversals; original ledger rows remain. Reconciled entries require a separate explained adjustment.
- Reconciliation compares selected period transactions with external starting/ending balances. The difference must be zero; transaction amounts are not rewritten.
- Forecasts start from current actual cash. Confirmed schedules and expected scenarios are distinct. Paid amounts, drafts, cancellations, excluded events and posted occurrences are not counted again.
- Overdue included invoices/bills carry to tomorrow for planning, with original dates preserved. This is a scenario assumption, not a guaranteed collection date.
- Recurring schedules forecast **future** occurrences. Unposted past occurrences are not automatically turned into debt or cash. Record a bill/event when needed.
- Monthly/quarterly/yearly schedules preserve their original day across short months.
- Runway uses the average of the last three complete months of cash outflows and is hidden without at least two active months.
- Reports show a management cash-basis operating estimate, not certified accounts, audited profit, tax filing or financial advice.

## Supabase backend

The backend adapter is included and its SQL has been exercised with PostgreSQL/PGlite. No Supabase credentials or live project are included; live Auth, Edge Function and Storage integration still require deployment and an environment-specific acceptance test.

Use a **dedicated Supabase project**:

1. Run supabase/schema.sql in the SQL editor. It creates the private cashpilot schema, configured zero-balance accounts and categories, relational financial tables, generated keys/constraints, an account balance view, and server-only functions.
2. Create users through Supabase Auth using trusted administrator controls. Disable open self-sign-up for a private business workspace.
3. Provision each authorized user's profile through trusted SQL:

       insert into cashpilot.profiles(id,name,role)
       values ('AUTH-USER-UUID', 'Business Owner', 'OWNER');

   Allowed roles: OWNER, FINANCE ADMIN, STAFF, VIEWER. Do not put a service role credential in browser code.
4. Synchronize shared command rules:

       npm run prepare:backend

5. Deploy the function with its provided config. Public document retrieval uses the same function; management actions explicitly verify the user's JWT and active database profile:

       supabase functions deploy cashpilot --no-verify-jwt

6. Set the server-side secret CASHPILOT_ALLOWED_ORIGINS to a comma-separated allowlist, for example your deployed HTTPS origin and http://127.0.0.1:4600. SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided to the Edge runtime by Supabase. Never copy the privileged key into Vite variables.
7. Copy .env.example to .env.local and set only:

       VITE_SUPABASE_URL=https://YOUR-PROJECT.supabase.co
       VITE_SUPABASE_ANON_KEY=YOUR-CLIENT-SAFE-KEY

8. Rebuild/redeploy the frontend. Configure Supabase Auth site/redirect URLs for the deployed origin.
9. Sign in and verify the full workflow in your actual cloud environment before entering business records. Cloud mode starts without sample financial transactions.

### Access and integrity

Private tables have RLS enabled and no anonymous/authenticated browser policies. The Edge Function obtains identity and role from Auth plus the active database profile; it never trusts a client-supplied actor. Privileged RPCs are service-only. A compare-and-swap workspace revision lock serializes financial commits; SQL constraints enforce document uniqueness, payment/ledger correspondence, immutable historical records, transfer integrity and overpayment protection.

The app is intentionally a **single-business workspace**, not a multi-tenant service. Private documents use the cashpilot-documents bucket. Supported uploads are checked by MIME type, payload and size and replaced with private storage references. Authorized responses receive short-lived signed links after role filtering. Public invoice/receipt responses project only the requested customer document and optional business logo. Private receipt/bill attachments are never included in public documents.

Set up database/storage backups, retention and staff provisioning through your Supabase administrator. Uploaded files and financial records are retained for history; no silent destructive cleanup is performed.

## Validation

    npm test
    npm run test:database
    npm run build
    npm run preview
    npm run test:browser
    node tests/extended-browser.mjs

Browser tests use installed Google Chrome through Playwright. They use isolated browser profiles and a clean financial fixture, so they do not change the user's preview data. Artifacts and per-group results are written to test-artifacts/.

The core test creates Cash 5,000,000 and Bank 20,000,000, issues an invoice without moving cash, receives 4,000,000 then 6,000,000, records/pay a bill, transfers funds, records an expense, creates schedules, detects a 90-day shortage, reconciles a statement, imports/exports CSV, opens public documents in another browser and verifies persistence/roles/mobile layout.

## Source

src/config.js is the initial configuration source; Settings is the persisted runtime source. src/domain.js contains shared finance rules; src/repository.js provides atomic IndexedDB or Supabase access without changing the interface. The PostgreSQL schema is the initial installation snapshot; deploy migrations when changing an existing cloud database.
