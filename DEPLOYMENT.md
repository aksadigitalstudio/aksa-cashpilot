# AKSA CashPilot — deployment

Verified 29 October 2026.

- Public browser-storage demo: https://aksa-cashpilot.vercel.app/
- Authenticated business workspace: https://aksa-cashpilot-b87x.vercel.app/
- Source: https://github.com/aksadigitalstudio/aksa-cashpilot

The business deployment uses Supabase Auth, an active server-side OWNER profile, private relational tables with RLS, the cashpilot Edge Function and private document storage. Frontend environment variables contain only the project URL and client-safe publishable key. Privileged keys remain server-side.

Live verification: authenticated workspace reads, settings commits, private image upload, signed-image rendering and refresh persistence. No sample cash transactions were posted to the business workspace. The public demo remains independent and stores its data in the visitor’s browser.

Validation: 61 original groups plus 6 Edge-handler regression groups and 5 deployed HTTP security checks. The primary 22 browser groups passed on the public demo. Detailed artifacts remain in the local test-artifacts folder.

Business financial end-to-end tests run in isolated fixtures; no real payments or bank transfers were executed. Maintain database backups and provision additional staff through trusted Supabase administration.
