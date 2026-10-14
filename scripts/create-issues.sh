#!/usr/bin/env bash
# Creates 125 GitHub issues for dupdap-backend
# Run from dupdap-backend directory

set -e

REPO="dupdab/dupdap-backend"

create_issue() {
  local title="$1"
  local body="$2"
  local labels="$3"
  gh issue create --repo "$REPO" --title "$title" --body "$body" --label "$labels" 2>/dev/null || \
  gh issue create --repo "$REPO" --title "$title" --body "$body" 2>/dev/null
  sleep 0.4
}

echo "Creating 125 GitHub issues for dupdap-backend..."

# ─── P0: CRITICAL (15 issues) ────────────────────────────────────────────────

create_issue \
  "[P0] Implement SorobanService contract methods (deposit, release, refund)" \
  "## Problem
\`src/blockchain-wallet/soroban.service.ts\` has 6 critical contract invocation stubs that are unimplemented:
- \`deposit(stellarAddress, amountUsdc)\` — logs only, never invokes contract
- \`release(paymentId, merchantAddress)\` — logs only
- \`refund(paymentId, customerAddress)\` — logs only
- \`registerUser(username, publicKey)\` — logs only
- \`getBalance(stellarAddress)\` — hardcoded to return \`'0'\`
- \`getStakeBalance(stellarAddress)\` — hardcoded to return \`'0'\`

These are the core escrow operations powering the entire payment flow.

## Expected Behaviour
Each method should invoke the corresponding DupDub Soroban contract function using \`StellarSdk.rpc.Server\` and handle contract errors gracefully.

## Acceptance Criteria
- [ ] All 6 stubs replaced with actual Soroban RPC calls
- [ ] Contract errors wrapped in \`SorobanRpcException\`
- [ ] Unit tests for each method with mock RPC responses
- [ ] Integration test verifying testnet contract invocation" \
  "bug,P0,blockchain"

create_issue \
  "[P0] Resolve duplicate payments/ and payment/ modules" \
  "## Problem
Both \`src/payments/\` and \`src/payment/\` exist as separate module directories. It is unclear which is canonical, which is imported by \`app.module.ts\`, and whether they share or duplicate entity/service logic.

## Risk
- Double registration of the same entity could silently shadow one module
- Developers adding features may edit the wrong module

## Acceptance Criteria
- [ ] Determine which module is the canonical one
- [ ] Migrate any unique logic from the deprecated module
- [ ] Remove the deprecated module
- [ ] Confirm \`app.module.ts\` imports only the canonical module
- [ ] All tests pass after consolidation" \
  "bug,P0,architecture"

create_issue \
  "[P0] Resolve duplicate queues/ and queue/ modules" \
  "## Problem
Queue constants and processors are split across \`src/queues/\` and \`src/queue/\`. This creates import ambiguity and makes it hard to trace which processor handles which job.

## Acceptance Criteria
- [ ] Consolidate all queue-related code into a single directory (\`src/queues/\`)
- [ ] Remove the unused directory
- [ ] Update all imports across the codebase
- [ ] Confirm Bull jobs still enqueue and process correctly" \
  "bug,P0,architecture"

create_issue \
  "[P0] Add transaction boundaries to settlement creation" \
  "## Problem
\`SettlementsService.initiateSettlement()\` performs multiple \`paymentsRepo.save()\` and \`settlementsRepo.save()\` calls without wrapping them in a database transaction. If the process crashes mid-way, the payment and settlement records can be left in an inconsistent state.

## Affected File
\`src/settlements/settlements.service.ts\` lines 52–102

## Acceptance Criteria
- [ ] Wrap all repo operations in \`dataSource.transaction()\`
- [ ] Ensure webhook dispatch only fires on commit
- [ ] Add a test simulating a mid-operation failure and asserting rollback" \
  "bug,P0,database"

create_issue \
  "[P0] Implement dead letter queue for failed settlement/webhook jobs" \
  "## Problem
Failed Bull jobs (settlements, webhook deliveries) are retried and then silently discarded. There is no dead letter queue (DLQ) to capture permanently failed jobs for inspection and manual replay.

## Risk
- Lost revenue if settlement jobs fail permanently
- Merchant webhooks fail silently with no admin visibility

## Acceptance Criteria
- [ ] Configure a DLQ queue for \`settlement\` and \`webhook\` queues
- [ ] Failed jobs after max retries are moved to DLQ
- [ ] Admin endpoint to list and replay DLQ jobs
- [ ] Alert raised when a job enters DLQ" \
  "bug,P0,queues"

create_issue \
  "[P0] Implement idempotency keys for payment creation" \
  "## Problem
\`POST /api/v1/payments\` has no idempotency key support. If a merchant's client retries on network timeout, a duplicate payment record is created. The reference field uses \`PAY-\${Date.now()}-\${Math.random()}\` which provides no duplicate prevention.

## Acceptance Criteria
- [ ] Accept \`Idempotency-Key\` header on payment creation
- [ ] Cache key→paymentId in Redis with 24h TTL
- [ ] Return existing payment on duplicate key submission
- [ ] Document header in Swagger
- [ ] Unit tests for duplicate detection" \
  "bug,P0,payments"

create_issue \
  "[P0] Implement Redis health check in health module" \
  "## Problem
\`src/health/health.controller.ts\` contains a TODO comment and returns \`{ status: 'ok' }\` unconditionally for the Redis health check without performing an actual \`PING\`.

## Acceptance Criteria
- [ ] Implement actual Redis \`PING\` in the health check
- [ ] Return \`degraded\` status with latency if Redis is slow (>100ms)
- [ ] Return \`down\` if Redis is unreachable
- [ ] Liveness probe does NOT include Redis; readiness probe does" \
  "bug,P0,health"

create_issue \
  "[P0] Implement queue health check in health module" \
  "## Problem
Queue health check in \`src/health/health.controller.ts\` is stubbed and always returns \`ok\` regardless of Bull/Redis queue state.

## Acceptance Criteria
- [ ] Check Bull queue connectivity via Redis ping
- [ ] Report queue depth if above configurable threshold
- [ ] Return \`degraded\` on high queue depth, \`down\` on connectivity failure" \
  "bug,P0,health"

create_issue \
  "[P0] Move hardcoded settlement thresholds to RuntimeConfig" \
  "## Problem
\`src/settlements/settlements.service.ts\` hard-codes business-critical constants:
\`\`\`typescript
const SMALL_BATCH_THRESHOLD_USD = 10;
const BATCH_FEE_RATE = 0.015;
const BATCH_WINDOW_MINUTES = 15;
const LARGE_SETTLEMENT_THRESHOLD = 10000;
\`\`\`
Changing any of these requires a code deploy.

## Acceptance Criteria
- [ ] Add all four values to \`RuntimeConfig\` entity with sensible defaults
- [ ] \`SettlementsService\` reads from runtime config at execution time
- [ ] Admin API to update these values without redeploy
- [ ] Audit log entry on every change" \
  "enhancement,P0,settlements"

create_issue \
  "[P0] Standardize exception handling — replace raw Error with NestJS exceptions" \
  "## Problem
15+ instances of \`throw new Error()\` appear in services where NestJS HTTP exceptions (\`NotFoundException\`, \`BadRequestException\`, etc.) should be used. This results in 500 responses for what should be 400/404 errors.

## Acceptance Criteria
- [ ] Audit all \`throw new Error()\` in \`src/\`
- [ ] Replace each with the appropriate NestJS exception
- [ ] Add a custom exception hierarchy for business logic errors (e.g., \`PaymentExpiredException\`, \`InsufficientFundsException\`)
- [ ] Global exception filter logs all unhandled errors to Sentry" \
  "bug,P0,architecture"

create_issue \
  "[P0] Replace console.log/warn with Logger throughout the codebase" \
  "## Problem
\`app.module.ts\` and other files use \`console.log\` and \`console.warn\` instead of the NestJS \`Logger\`. This bypasses structured logging and log-level filtering.

## Affected File
\`app.module.ts\` lines 58, 65 and elsewhere

## Acceptance Criteria
- [ ] Replace all \`console.log/warn/error\` with \`new Logger(context).log/warn/error\`
- [ ] Add ESLint rule \`no-console\` to prevent regression" \
  "bug,P0,observability"

create_issue \
  "[P0] Implement encryption key rotation strategy for Stellar wallet keys" \
  "## Problem
\`STELLAR_WALLET_ENCRYPTION_KEY\` is used to AES-256-GCM encrypt Stellar secret keys per user. There is no documented or implemented key rotation strategy. If the key is compromised, all stored wallet secrets are at risk.

## Acceptance Criteria
- [ ] Document key rotation procedure in RECOVERY_DRILL.md
- [ ] Implement a re-encryption job that reads with old key and writes with new key
- [ ] Add \`keyVersion\` field to encrypted wallet records
- [ ] Admin endpoint to trigger rotation with audit log" \
  "security,P0,blockchain"

create_issue \
  "[P0] Implement settlement approval workflow for large settlements" \
  "## Problem
\`SettlementsService\` sets \`requiresApproval = true\` for settlements above \$10,000 and raises an admin alert, but there is no admin endpoint to approve or reject the settlement. It remains stuck in \`PENDING_APPROVAL\` indefinitely.

## Acceptance Criteria
- [ ] \`POST /admin/settlements/:id/approve\` — approves and enqueues
- [ ] \`POST /admin/settlements/:id/reject\` — marks rejected and notifies merchant
- [ ] Approval requires SUPERADMIN role
- [ ] Audit log entry on every decision
- [ ] Email notification to merchant on approval/rejection" \
  "enhancement,P0,settlements"

create_issue \
  "[P0] Complete admin cron job management endpoints" \
  "## Problem
\`src/admin/cron-admin.controller.ts\` has two endpoints returning empty arrays with TODO comments:
- \`GET /admin/cron\` → \`[]\` (TODO: implement)
- \`GET /admin/cron/:jobName/history\` → \`[]\` (TODO: paginated logs)

## Acceptance Criteria
- [ ] \`listJobs()\` returns all registered cron jobs with name, schedule, last run, and next run
- [ ] \`getHistory(jobName)\` returns paginated cron run log with status and duration
- [ ] Cron run history persisted in database
- [ ] Swagger docs for both endpoints" \
  "bug,P0,admin"

create_issue \
  "[P0] Fix ADMIN_IP_BYPASS_IN_DEV — must be gated on NODE_ENV check" \
  "## Problem
The admin IP bypass flag can be set to \`true\` in any environment without a hard \`NODE_ENV === 'development'\` guard in code. If misconfigured in staging or production, the admin IP allowlist is disabled.

## Acceptance Criteria
- [ ] Bypass only activates if \`NODE_ENV === 'development'\` AND \`ADMIN_IP_BYPASS_IN_DEV=true\`
- [ ] Startup warning log if bypass is enabled
- [ ] Config validation test asserting bypass is never active in production" \
  "security,P0,auth"

# ─── P1: HIGH (30 issues) ────────────────────────────────────────────────────

create_issue \
  "[P1] Apply API key rate limiting to all merchant-facing endpoints" \
  "## Problem
\`ApiKeyRateLimitGuard\` exists but is not applied consistently to all merchant endpoints. Some routes are unprotected against API key abuse.

## Acceptance Criteria
- [ ] Audit all merchant-facing controllers for missing guard
- [ ] Apply \`ApiKeyRateLimitGuard\` globally via \`APP_GUARD\` or per controller
- [ ] Rate limit state persisted in Redis (not in-memory)
- [ ] Return \`Retry-After\` header on 429 responses" \
  "security,P1,auth"

create_issue \
  "[P1] Add startup validation for email provider configuration" \
  "## Problem
\`.env.example\` lists both \`SMTP_*\` (old) and \`EMAIL_SMTP_*\` (new) variables, and the \`EMAIL_PROVIDER\` env var is not validated at startup. The app boots silently even with invalid email config.

## Acceptance Criteria
- [ ] \`ConfigModule\` Joi schema enforces \`EMAIL_PROVIDER\` is one of \`smtp\` or \`sendgrid\`
- [ ] Provider-specific vars validated based on \`EMAIL_PROVIDER\` value
- [ ] App fails fast with clear error message on invalid email config
- [ ] Remove duplicate \`SMTP_*\` vars from \`.env.example\`" \
  "bug,P1,email"

create_issue \
  "[P1] Add input bounds validation to CreatePaymentDto" \
  "## Problem
\`CreatePaymentDto\` does not enforce min/max bounds on \`amountUsd\`. An extremely large value could cause arithmetic overflow or unexpected behaviour in downstream fee calculation.

## Acceptance Criteria
- [ ] \`@Min(0.01)\` and \`@Max(1000000)\` on \`amountUsd\`
- [ ] \`@IsEmail()\` on \`customerEmail\`
- [ ] \`@MaxLength(500)\` on \`description\`
- [ ] Metadata object size limit enforced
- [ ] Unit tests for boundary values" \
  "security,P1,payments"

create_issue \
  "[P1] Implement soft deletes for audit-sensitive entities" \
  "## Problem
Merchants, payments, and webhooks are hard-deleted, making post-incident audits impossible. TypeORM's \`@DeleteDateColumn\` + \`softDelete()\` should be used.

## Acceptance Criteria
- [ ] Add \`deletedAt\` column to Merchant, Payment, Webhook, Settlement entities
- [ ] All queries scoped to non-deleted records by default
- [ ] Admin endpoint to list and restore soft-deleted records
- [ ] Existing migration written for schema change" \
  "enhancement,P1,database"

create_issue \
  "[P1] Implement webhook event versioning" \
  "## Problem
Webhook event payloads have no version field. A schema change would silently break all merchant integrations with no migration path.

## Acceptance Criteria
- [ ] Add \`version: string\` field to all webhook payloads (e.g., \`\"v1\"\`)
- [ ] Merchants can filter subscriptions by event version
- [ ] Version changelog documented in README
- [ ] Breaking changes increment major version and maintain deprecated version for 90 days" \
  "enhancement,P1,webhooks"

create_issue \
  "[P1] Add materialized view refresh error handling and alerting" \
  "## Problem
\`analytics-refresh.service.ts\` runs \`REFRESH MATERIALIZED VIEW CONCURRENTLY\` with no error handling. If the refresh hangs or fails, stale analytics data is served silently.

## Acceptance Criteria
- [ ] Wrap refresh in try/catch with detailed logging
- [ ] Raise admin alert if refresh fails or takes longer than 60s
- [ ] Admin endpoint to manually trigger refresh
- [ ] Prometheus metric for refresh duration and last success time" \
  "bug,P1,analytics"

create_issue \
  "[P1] Add Soroban RPC fallback and retry strategy" \
  "## Problem
\`StellarService\` and \`SorobanService\` make RPC calls with no retry or fallback. A transient Soroban RPC outage hard-fails all payment operations.

## Acceptance Criteria
- [ ] Retry with exponential backoff (3 attempts) for transient RPC errors
- [ ] Configurable fallback RPC endpoint via \`SOROBAN_RPC_FALLBACK_URL\`
- [ ] Circuit breaker opens after 5 consecutive failures
- [ ] Alert raised when circuit breaker opens" \
  "enhancement,P1,blockchain"

create_issue \
  "[P1] Add circuit breaker to Stellar Horizon API calls" \
  "## Problem
\`StellarService\` polls Horizon every 30 seconds with no circuit breaker. A Horizon outage causes repeated failed requests and log flooding.

## Acceptance Criteria
- [ ] Implement circuit breaker (e.g., opossum) around Horizon calls
- [ ] Monitor polling circuit state via Prometheus metric
- [ ] Alert admin when circuit opens
- [ ] Graceful degradation — pause polling, not crash, when circuit is open" \
  "enhancement,P1,blockchain"

create_issue \
  "[P1] Remove unsafe \`any\` type casts from cache and auth services" \
  "## Problem
\`auth/rate-limit.service.ts\` and other services use \`(this.cache as any).redis\` to access internal Redis client, bypassing TypeScript type safety. This will break silently on \`@nestjs/cache-manager\` version upgrades.

## Acceptance Criteria
- [ ] Replace \`(this.cache as any)\` casts with properly typed Redis client injection
- [ ] Inject \`ioredis\` Redis client directly where needed
- [ ] No \`as any\` in production service code
- [ ] TypeScript strict mode enabled (\`strict: true\` in tsconfig)" \
  "bug,P1,architecture"

create_issue \
  "[P1] Implement webhook circuit breaker to prevent spamming failing endpoints" \
  "## Problem
Webhook retry schedule is hardcoded to \`[60s, 5m, 30m, 2h, 12h]\` with no circuit breaker. If a merchant endpoint consistently returns 500, the system keeps retrying indefinitely.

## Acceptance Criteria
- [ ] After 5 consecutive failures, open circuit per merchant endpoint for 24h
- [ ] Admin can manually reset circuit
- [ ] Admin alert when circuit opens for a merchant webhook
- [ ] Merchant notified via email on circuit open" \
  "enhancement,P1,webhooks"

create_issue \
  "[P1] Implement admin user role management endpoints" \
  "## Problem
The admin module has role guards (\`ADMIN\`, \`SUPERADMIN\`) but no endpoints to create, update, or revoke admin users and their roles.

## Acceptance Criteria
- [ ] \`POST /admin/users\` — create admin user (SUPERADMIN only)
- [ ] \`PATCH /admin/users/:id/role\` — update role
- [ ] \`DELETE /admin/users/:id\` — deactivate (soft delete)
- [ ] Audit log entry on every change
- [ ] Tests for role escalation prevention" \
  "enhancement,P1,admin"

create_issue \
  "[P1] Implement two-factor authentication for admin accounts" \
  "## Problem
Admin accounts are protected only by JWT. There is no 2FA, making a compromised admin credential a single point of failure.

## Acceptance Criteria
- [ ] TOTP-based 2FA using \`otplib\`
- [ ] \`POST /auth/admin/2fa/enable\` — generates QR code
- [ ] \`POST /auth/admin/2fa/verify\` — verifies TOTP code, returns session token
- [ ] 2FA required for all \`/admin/*\` endpoints
- [ ] Backup recovery codes generated on setup" \
  "security,P1,auth"

create_issue \
  "[P1] Implement merchant analytics export endpoint" \
  "## Problem
Merchants can view analytics but cannot export their payment data as CSV or JSON for their own reporting needs.

## Acceptance Criteria
- [ ] \`GET /merchant/analytics/export?format=csv&from=&to=\`
- [ ] Exports: payment volume, settlement amounts, fees, dates
- [ ] Background job for large date ranges
- [ ] Download link emailed when job completes
- [ ] Rate limited to 5 exports per day" \
  "enhancement,P1,analytics"

create_issue \
  "[P1] Implement merchant settlement history export" \
  "## Problem
No export endpoint exists for settlement records. Merchants need this for reconciliation and accounting.

## Acceptance Criteria
- [ ] \`GET /merchant/settlements/export?format=csv\`
- [ ] Includes: settlement ID, date, gross amount, fee, net amount, bank reference
- [ ] PDF receipts per settlement
- [ ] Rate limited, background job for large ranges" \
  "enhancement,P1,settlements"

create_issue \
  "[P1] Add KYC/KYB verification workflow for merchant onboarding" \
  "## Problem
Merchant registration has no KYC/KYB step. Any account can immediately create payments. This is a regulatory compliance gap.

## Acceptance Criteria
- [ ] KYC status field on Merchant entity (\`UNVERIFIED\`, \`PENDING\`, \`VERIFIED\`, \`REJECTED\`)
- [ ] Document upload endpoint for business verification
- [ ] Admin review queue for pending KYC applications
- [ ] Unverified merchants limited to test mode (low amounts)
- [ ] Email notification on status change" \
  "enhancement,P1,compliance"

create_issue \
  "[P1] Implement AML flag SLA tracking and auto-escalation" \
  "## Problem
AML flags are raised but there is no SLA tracking. Flags can sit unreviewed indefinitely with no escalation to senior reviewers.

## Acceptance Criteria
- [ ] SLA deadline on each AML flag (default 24h, configurable)
- [ ] Cron job escalates overdue flags to \`ESCALATED\` status
- [ ] Alert raised to SUPERADMIN on escalation
- [ ] Prometheus metric for open flag count and avg resolution time" \
  "enhancement,P1,compliance"

create_issue \
  "[P1] Add support for multiple bank accounts per merchant" \
  "## Problem
Merchants can only have one bank account for settlement. Multi-currency merchants need to route settlements to different bank accounts.

## Acceptance Criteria
- [ ] \`MerchantBankAccount\` entity with currency, account number, routing number, is_default
- [ ] \`POST /merchant/bank-accounts\` — add account
- [ ] \`PATCH /merchant/bank-accounts/:id/default\` — set default
- [ ] Settlement uses the merchant's default bank account for the target currency" \
  "enhancement,P1,merchants"

create_issue \
  "[P1] Implement payment dispute resolution system" \
  "## Problem
There is no mechanism for customers or merchants to raise a dispute on a payment. Disputed funds sit in escrow with no workflow to resolve them.

## Acceptance Criteria
- [ ] \`Dispute\` entity with status (\`OPEN\`, \`UNDER_REVIEW\`, \`RESOLVED\`, \`ESCALATED\`)
- [ ] \`POST /payments/:id/dispute\` — customer/merchant raises dispute
- [ ] Admin dispute review queue
- [ ] Dispute blocks settlement release until resolved
- [ ] SLA tracking and auto-escalation after 48h" \
  "enhancement,P1,payments"

create_issue \
  "[P1] Implement payment cancellation workflow with automatic refund" \
  "## Problem
There is no way for a merchant to cancel a pending payment and trigger an automatic refund to the customer's Stellar wallet.

## Acceptance Criteria
- [ ] \`POST /payments/:id/cancel\` — merchant cancels PENDING payment
- [ ] Soroban contract refund invoked if funds are in escrow
- [ ] Payment status set to \`CANCELLED\`
- [ ] \`payment.cancelled\` webhook dispatched
- [ ] Customer email notification" \
  "enhancement,P1,payments"

create_issue \
  "[P1] Implement real-time payment status updates via WebSocket" \
  "## Problem
Merchant dashboards must poll \`GET /payments/:id\` to see status updates. This creates unnecessary load and poor UX for the checkout flow.

## Acceptance Criteria
- [ ] \`@nestjs/websockets\` gateway for payment status events
- [ ] Merchant subscribes to their payment room by payment ID
- [ ] Event emitted on status change (\`PENDING\` → \`CONFIRMED\` → \`SETTLED\`)
- [ ] Authentication via JWT on WebSocket handshake
- [ ] Swagger/AsyncAPI documentation for events" \
  "enhancement,P1,payments"

create_issue \
  "[P1] Implement settlement reversal workflow" \
  "## Problem
There is no way to reverse a completed settlement (e.g., for fraud or chargebacks). Manual database intervention is required.

## Acceptance Criteria
- [ ] \`POST /admin/settlements/:id/reverse\` — SUPERADMIN only
- [ ] Creates a reversal record linked to original settlement
- [ ] Triggers refund via Soroban contract
- [ ] Audit log entry with reason
- [ ] Merchant and customer notified" \
  "enhancement,P1,settlements"

create_issue \
  "[P1] Add payment velocity checks for fraud prevention" \
  "## Problem
There are no velocity checks to detect suspicious patterns (e.g., 50 payments in 1 minute from the same IP or to the same merchant).

## Acceptance Criteria
- [ ] Configurable thresholds: max payments per IP/hour, per merchant/hour
- [ ] Redis-backed sliding window counter
- [ ] Threshold breach raises AML flag automatically
- [ ] Alert to admin on breach
- [ ] \`X-Velocity-Check: blocked\` header on rejected requests" \
  "security,P1,payments"

create_issue \
  "[P1] Add merchant API key audit trail" \
  "## Problem
API key creation, rotation, and revocation are not logged in the audit trail. If a key is compromised, there is no forensic record.

## Acceptance Criteria
- [ ] Audit log entries on key create, rotate, revoke
- [ ] Log includes: actor, timestamp, key prefix (last 4 chars), IP address
- [ ] \`GET /merchant/api-keys/audit\` endpoint
- [ ] Alert on key usage from new IP" \
  "security,P1,merchants"

create_issue \
  "[P1] Implement request deduplication middleware" \
  "## Problem
No deduplication is in place for POST endpoints. Network retries can create duplicate resources.

## Acceptance Criteria
- [ ] Accept \`X-Request-ID\` header on all POST endpoints
- [ ] Store request hash → response in Redis for 5 minutes
- [ ] Return cached response on duplicate request ID
- [ ] Middleware applies to all resource-creating endpoints" \
  "enhancement,P1,architecture"

create_issue \
  "[P1] Fix SQL injection risk in raw analytics queries" \
  "## Problem
\`analytics.service.ts\` and \`merchant-analytics.service.ts\` use raw \`.query()\` calls with string interpolation for merchant IDs and date ranges. These must be parameterized.

## Acceptance Criteria
- [ ] Replace all string-interpolated raw queries with parameterized queries
- [ ] Add integration test asserting SQL injection attempt returns 400
- [ ] Enable TypeORM query logging in development to verify parameterization" \
  "security,P1,analytics"

create_issue \
  "[P1] Implement dynamic settlement fee tiers based on volume" \
  "## Problem
Fee rate is hardcoded at 1.5% for all merchants. High-volume merchants should benefit from lower fees, and this should be configurable per merchant.

## Acceptance Criteria
- [ ] \`MerchantFeeTier\` entity with volume thresholds and rates
- [ ] \`SettlementsService\` looks up merchant fee tier at settlement time
- [ ] Admin endpoint to create/update fee tiers
- [ ] Default tier at 1.5% if no custom tier configured" \
  "enhancement,P1,settlements"

create_issue \
  "[P1] Add Swagger documentation for all admin endpoints" \
  "## Problem
Admin endpoints at \`/api/v1/admin/*\` have minimal or no Swagger decorators, making the API undiscoverable for internal tooling.

## Acceptance Criteria
- [ ] \`@ApiOperation\`, \`@ApiResponse\`, \`@ApiBearerAuth\` on all admin controllers
- [ ] Error response schemas documented (400, 401, 403, 404, 500)
- [ ] Swagger UI served at \`/docs\` with all admin endpoints visible
- [ ] OpenAPI spec exported to \`openapi.json\` in repo" \
  "documentation,P1,admin"

create_issue \
  "[P1] Standardize error response schemas across all controllers" \
  "## Problem
Error responses vary in shape across controllers — some return \`{ message }\`, others \`{ error, message, statusCode }\`, others raw strings. This breaks client error handling.

## Acceptance Criteria
- [ ] Define a canonical error response DTO: \`{ statusCode, error, message, requestId }\`
- [ ] Global exception filter applies this shape to all errors
- [ ] Swagger documents the error DTO
- [ ] Breaking change documented in changelog" \
  "enhancement,P1,architecture"

create_issue \
  "[P1] Implement merchant team member management with roles" \
  "## Problem
Merchants can only have one login. Teams need to assign roles (owner, developer, viewer) to multiple team members.

## Acceptance Criteria
- [ ] \`MerchantMember\` entity with roles (\`OWNER\`, \`DEVELOPER\`, \`VIEWER\`)
- [ ] \`POST /merchant/team\` — invite member by email
- [ ] \`PATCH /merchant/team/:id\` — update role
- [ ] \`DELETE /merchant/team/:id\` — remove member
- [ ] API keys scoped to creating member's permissions" \
  "enhancement,P1,merchants"

# ─── P2: MEDIUM (45 issues) ──────────────────────────────────────────────────

create_issue \
  "[P2] Add integration tests for complete payment lifecycle" \
  "## Problem
There are 42 unit test files but no integration tests covering the full flow: payment creation → Stellar confirmation → settlement → webhook.

## Acceptance Criteria
- [ ] Integration test suite in \`test/integration/\`
- [ ] Tests use in-memory Postgres (pg-mem) or test database
- [ ] Mock Stellar Horizon and Soroban RPC
- [ ] Coverage includes happy path and each failure mode
- [ ] CI runs integration tests in separate step" \
  "testing,P2,architecture"

create_issue \
  "[P2] Add E2E tests for merchant onboarding and settlement flow" \
  "## Problem
No E2E test suite covers the merchant-facing API from registration to first settlement.

## Acceptance Criteria
- [ ] \`test/e2e/\` directory with supertest-based tests
- [ ] Covers: register → login → create payment → confirm → settle → webhook received
- [ ] Seeds test database before each test suite
- [ ] Runs in CI with real PostgreSQL + Redis via Docker Compose" \
  "testing,P2,architecture"

create_issue \
  "[P2] Improve test coverage to 70% minimum" \
  "## Problem
Current test coverage is approximately 15.3% (42 test files for 274 source files). Many critical services have zero test coverage.

## Acceptance Criteria
- [ ] Set Jest coverage threshold to 70% in \`jest.config.js\`
- [ ] Prioritize: \`SettlementsService\`, \`StellarService\`, \`WebhooksService\`, \`AuthService\`
- [ ] CI fails build if coverage drops below threshold
- [ ] Coverage badge in README" \
  "testing,P2,architecture"

create_issue \
  "[P2] Add performance benchmarks for payment confirmation latency" \
  "## Problem
There is no defined SLA for payment confirmation latency. Without benchmarks, regressions are undetectable.

## Acceptance Criteria
- [ ] Benchmark: p50/p95/p99 for payment creation, confirmation, and settlement dispatch
- [ ] Benchmark script using k6 (see existing \`load-tests/payments.k6.ts\`)
- [ ] Target: p95 < 200ms for payment creation, p95 < 5s for confirmation
- [ ] Results documented in README" \
  "performance,P2,observability"

create_issue \
  "[P2] Implement structured logging with trace/correlation IDs" \
  "## Problem
Log messages lack trace IDs, making it impossible to correlate logs for a single request or payment across services.

## Acceptance Criteria
- [ ] \`X-Request-ID\` header set on every request (or generated if absent)
- [ ] Request ID included in every log line for that request
- [ ] Winston configured for JSON output in production
- [ ] OpenTelemetry trace ID injected into log context" \
  "observability,P2,architecture"

create_issue \
  "[P2] Add Prometheus histograms for payment confirmation latency" \
  "## Problem
Current Prometheus metrics (if any) do not include payment confirmation latency histograms. SRE teams cannot set latency-based SLOs.

## Acceptance Criteria
- [ ] \`payment_confirmation_duration_seconds\` histogram with buckets [0.1, 0.5, 1, 5, 30]
- [ ] \`settlement_duration_seconds\` histogram
- [ ] \`webhook_delivery_duration_seconds\` histogram
- [ ] All metrics exposed at \`/metrics\`" \
  "observability,P2,observability"

create_issue \
  "[P2] Write operational runbook for common failure scenarios" \
  "## Problem
No runbook exists for common production failures: Stellar monitor stuck, settlement queue backed up, Redis down, Soroban RPC unreachable.

## Acceptance Criteria
- [ ] \`docs/runbooks/\` directory with one file per scenario
- [ ] Each runbook: symptoms, root cause, remediation steps, escalation path
- [ ] Minimum: Stellar monitor stuck, settlement queue backup, Redis down, partner API down" \
  "documentation,P2,observability"

create_issue \
  "[P2] Implement cache key versioning to handle deployment cache staleness" \
  "## Problem
Cache keys are not versioned by deployment. A code deploy that changes serialization format can serve stale/incorrect data from Redis.

## Acceptance Criteria
- [ ] \`CACHE_VERSION\` env var (e.g., git commit hash) prefixed to all cache keys
- [ ] Cache automatically invalidated on version change
- [ ] Document cache invalidation policy in README" \
  "bug,P2,cache"

create_issue \
  "[P2] Implement webhook retry configuration per merchant" \
  "## Problem
Retry schedule is global. Some merchants may want faster retries; others have different SLAs.

## Acceptance Criteria
- [ ] \`WebhookRetryConfig\` on merchant: max attempts, retry delays array
- [ ] Default config preserved if merchant has none set
- [ ] Admin/merchant endpoint to update retry config
- [ ] Validation: max 10 attempts, max delay 24h" \
  "enhancement,P2,webhooks"

create_issue \
  "[P2] Add merchant account suspension and unsuspension" \
  "## Problem
There is no way to suspend a merchant account (e.g., for AML review) without deleting it. Suspended accounts should be blocked from creating new payments while retaining data.

## Acceptance Criteria
- [ ] \`suspended\` boolean and \`suspendedReason\` string on Merchant entity
- [ ] \`POST /admin/merchants/:id/suspend\` — requires reason
- [ ] \`POST /admin/merchants/:id/unsuspend\`
- [ ] Suspended merchants receive 403 on all API calls
- [ ] Audit log and merchant email on suspension/unsuspension" \
  "enhancement,P2,merchants"

create_issue \
  "[P2] Add payment search by reference number and Stellar memo" \
  "## Problem
\`GET /payments\` supports basic filters but not search by payment reference (\`PAY-...\`) or Stellar memo. Support teams need this for customer queries.

## Acceptance Criteria
- [ ] \`GET /payments?reference=PAY-xxx\` — exact match
- [ ] \`GET /payments?memo=ABC123\` — exact match on stellar memo
- [ ] Database index on \`reference\` and \`stellarMemo\` columns
- [ ] Full-text search on description (optional)" \
  "enhancement,P2,payments"

create_issue \
  "[P2] Implement bulk payment import from CSV" \
  "## Problem
Merchants creating many payments (e.g., payroll, batch invoicing) must call the API individually. Bulk import would reduce integration effort.

## Acceptance Criteria
- [ ] \`POST /payments/import\` — accepts multipart CSV file
- [ ] CSV columns: amount, description, customerEmail, expiryMinutes, metadata
- [ ] Background job for processing, results emailed to merchant
- [ ] Max 500 rows per file; validation errors returned per row
- [ ] Idempotency: duplicate reference in CSV skipped" \
  "enhancement,P2,payments"

create_issue \
  "[P2] Add payment metadata tagging and search" \
  "## Problem
Payments support arbitrary \`metadata\` JSON but there is no way to query or tag payments by metadata values. Merchants use metadata for order IDs, customer IDs, etc.

## Acceptance Criteria
- [ ] \`GET /payments?metadata[orderId]=123\` — filter by metadata key-value
- [ ] GIN index on \`metadata\` column in PostgreSQL
- [ ] Document metadata schema best practices" \
  "enhancement,P2,payments"

create_issue \
  "[P2] Add recurring payment support" \
  "## Problem
No support for recurring/subscription payments. Merchants with subscription models must implement their own scheduling.

## Acceptance Criteria
- [ ] \`RecurringPayment\` entity with schedule (cron expression or interval), amount, merchant
- [ ] Cron job creates payment on schedule
- [ ] \`POST /merchant/recurring-payments\` — create subscription
- [ ] \`DELETE /merchant/recurring-payments/:id\` — cancel
- [ ] Merchant notified before each charge" \
  "enhancement,P2,payments"

create_issue \
  "[P2] Implement payment partial refund support" \
  "## Problem
\`RefundPaymentDto\` exists but only supports full refunds. Merchants need partial refunds for returns/adjustments.

## Acceptance Criteria
- [ ] \`amount\` field on \`RefundPaymentDto\` (optional; defaults to full amount)
- [ ] Validate \`amount <= originalAmount\`
- [ ] Track cumulative refunded amount; prevent over-refund
- [ ] Partial refund dispatches \`payment.refunded\` webhook with partial amount" \
  "enhancement,P2,payments"

create_issue \
  "[P2] Implement payment hold and release workflow" \
  "## Problem
Funds in escrow can only be released to the merchant or refunded. There is no \`HOLD\` state for fraud review that pauses both paths.

## Acceptance Criteria
- [ ] \`HELD\` payment status
- [ ] \`POST /admin/payments/:id/hold\` — requires reason
- [ ] \`POST /admin/payments/:id/release\` — admin releases hold, continues to settlement
- [ ] Hold and release logged in audit trail
- [ ] Merchant notified on hold" \
  "enhancement,P2,payments"

create_issue \
  "[P2] Implement notification template management" \
  "## Problem
Email notification templates are hardcoded in \`EmailService\`. Changes require code deploys.

## Acceptance Criteria
- [ ] \`NotificationTemplate\` entity with \`name\`, \`subject\`, \`htmlBody\`, \`version\`
- [ ] Template variables rendered with Handlebars
- [ ] Admin CRUD for templates
- [ ] Template preview endpoint with test data
- [ ] Version history with rollback support" \
  "enhancement,P2,notifications"

create_issue \
  "[P2] Implement in-app notification read/unread tracking" \
  "## Problem
Notifications sent to merchants have no read state. Once sent, there's no way to know if the merchant has seen them.

## Acceptance Criteria
- [ ] \`Notification\` entity with \`readAt\` timestamp
- [ ] \`GET /merchant/notifications\` — paginated list with unread count
- [ ] \`PATCH /merchant/notifications/:id/read\`
- [ ] \`PATCH /merchant/notifications/read-all\`
- [ ] Unread count included in auth response" \
  "enhancement,P2,notifications"

create_issue \
  "[P2] Add support for SMS notifications via Twilio" \
  "## Problem
Only email notifications are supported. Merchants in markets with low email engagement need SMS for critical alerts (payment received, settlement sent).

## Acceptance Criteria
- [ ] Twilio integration in \`NotificationsService\`
- [ ] Merchant can configure phone number and SMS opt-in per event type
- [ ] \`SMS\` added to \`NotificationChannel\` enum
- [ ] Rate limited to avoid Twilio cost overruns" \
  "enhancement,P2,notifications"

create_issue \
  "[P2] Implement merchant IP allowlist feature" \
  "## Problem
API keys can be used from any IP. High-security merchants want to restrict their keys to known IP ranges.

## Acceptance Criteria
- [ ] CIDR-based IP allowlist on API key
- [ ] \`POST /merchant/api-keys/:id/ip-allowlist\`
- [ ] Requests from unlisted IPs return 403 with \`IP_NOT_ALLOWED\` error code
- [ ] Admin can bypass allowlist for support purposes with audit log" \
  "security,P2,merchants"

create_issue \
  "[P2] Add account recovery flow for merchants" \
  "## Problem
If a merchant loses their password and 2FA device, there is no recovery flow. They must contact support for manual database intervention.

## Acceptance Criteria
- [ ] \`POST /auth/forgot-password\` — sends recovery email
- [ ] \`POST /auth/reset-password\` — validates token and resets
- [ ] Recovery tokens expire in 1 hour
- [ ] Recovery codes generated at registration for backup
- [ ] Audit log on successful recovery" \
  "enhancement,P2,auth"

create_issue \
  "[P2] Add webhook signature verification documentation and test suite" \
  "## Problem
Webhook payloads are signed but the verification guide for merchant developers is missing from the README.

## Acceptance Criteria
- [ ] Documentation: how to verify HMAC-SHA256 signature from \`X-Webhook-Signature\` header
- [ ] Code examples in Node.js, Python, PHP
- [ ] Test endpoint \`POST /webhooks/test\` for merchants to verify their setup
- [ ] Replay protection documentation (timestamp validation)" \
  "documentation,P2,webhooks"

create_issue \
  "[P2] Document complete Stellar network configuration options" \
  "## Problem
\`.env.example\` mentions Stellar config vars but doesn't explain testnet vs mainnet setup or Soroban contract deployment.

## Acceptance Criteria
- [ ] README section: Stellar Configuration
- [ ] Table of all \`STELLAR_*\` and \`SOROBAN_*\` env vars with descriptions and defaults
- [ ] Testnet setup guide with faucet instructions
- [ ] Link to \`dupdapp_stellar\` repo for contract deployment" \
  "documentation,P2,architecture"

create_issue \
  "[P2] Implement transaction amount limits per merchant" \
  "## Problem
There are no per-merchant transaction limits. A misconfigured integration or compromised key can initiate unlimited-value payments.

## Acceptance Criteria
- [ ] \`singleTransactionLimitUsd\` and \`dailyLimitUsd\` on Merchant entity
- [ ] Payment creation validates against limits
- [ ] Limit breach returns 422 with \`LIMIT_EXCEEDED\` error
- [ ] Admin endpoint to update limits
- [ ] Default limits: $10,000 per transaction, $100,000 per day" \
  "security,P2,payments"

create_issue \
  "[P2] Implement IP geolocation for payment fraud detection" \
  "## Problem
No geographic context is captured for payments. Geolocation could flag payments from sanctioned countries or unexpected locations.

## Acceptance Criteria
- [ ] Store customer IP on payment creation
- [ ] Lookup country from IP using MaxMind GeoIP2
- [ ] Flag payments from sanctioned country list
- [ ] Admin dashboard: payments by country heatmap
- [ ] \`BLOCKED_COUNTRIES\` config list" \
  "security,P2,compliance"

create_issue \
  "[P2] Add database query plan analysis for analytics service" \
  "## Problem
Analytics queries are complex but there is no evidence of query plan review. Slow queries could degrade platform performance.

## Acceptance Criteria
- [ ] Run \`EXPLAIN ANALYZE\` on all analytics queries in \`scripts/explain-list-queries.ts\`
- [ ] Add results to \`docs/query-plans.md\`
- [ ] Add indexes where sequential scans are found on large tables
- [ ] \`pg_stat_statements\` monitoring enabled" \
  "performance,P2,analytics"

create_issue \
  "[P2] Fix N+1 query issue in merchant analytics service" \
  "## Problem
\`merchant-analytics.service.ts\` builds queries that may trigger N+1 patterns when fetching related merchant data without JOIN or eager loading.

## Acceptance Criteria
- [ ] Identify all N+1 query instances via query logging
- [ ] Replace with JOIN queries or DataLoader pattern
- [ ] Verify fix with \`EXPLAIN\` output showing no sequential scans on large tables
- [ ] Add test asserting query count for analytics endpoint" \
  "performance,P2,analytics"

create_issue \
  "[P2] Add database indexes for high-traffic query patterns" \
  "## Problem
Missing indexes on \`payment.merchantId\`, \`payment.status\`, \`payment.createdAt\`, and \`settlement.merchantId\` result in slow queries under load.

## Acceptance Criteria
- [ ] Audit all \`WHERE\` clauses in repositories
- [ ] Add composite indexes for common filter combinations
- [ ] Migration for each new index
- [ ] Document index strategy in \`docs/database.md\`" \
  "performance,P2,database"

create_issue \
  "[P2] Add dynamic database connection pool sizing" \
  "## Problem
\`DB_POOL_MAX=20\` is hardcoded in comments. Under high concurrency, pool exhaustion causes cascading failures with no telemetry.

## Acceptance Criteria
- [ ] \`DB_POOL_MIN\` and \`DB_POOL_MAX\` configurable via env
- [ ] Prometheus metric for pool size, active connections, waiting queries
- [ ] Alert when pool is >80% utilized for >60s
- [ ] Document recommended pool size formula in README" \
  "performance,P2,database"

create_issue \
  "[P2] Improve payment reference generation to prevent collisions" \
  "## Problem
\`PAY-\${Date.now()}-\${Math.random()}\` is not collision-safe under high concurrency and generates non-URL-safe characters from \`toString(36)\`.

## Acceptance Criteria
- [ ] Use \`nanoid\` or \`uuid\` v4 for reference generation
- [ ] Format: \`PAY-[timestamp-base36]-[8-char-unique-suffix]\`
- [ ] Unique constraint on \`reference\` column enforced at DB level
- [ ] Migration to add unique index" \
  "bug,P2,payments"

create_issue \
  "[P2] Add merchant dashboard analytics date range filtering" \
  "## Problem
Analytics endpoints do not support flexible date range filtering beyond preset periods.

## Acceptance Criteria
- [ ] \`?from=ISO8601&to=ISO8601\` on all analytics endpoints
- [ ] Preset options: today, 7d, 30d, 90d, ytd, custom
- [ ] Validate max range of 1 year
- [ ] Cache per merchant+range combination" \
  "enhancement,P2,analytics"

create_issue \
  "[P2] Implement Grafana dashboard for merchant and platform metrics" \
  "## Problem
Prometheus metrics are exported but there is no pre-built Grafana dashboard for operational monitoring.

## Acceptance Criteria
- [ ] \`infra/grafana/\` directory with dashboard JSON exports
- [ ] Platform dashboard: payment volume, settlement queue depth, Stellar monitor lag
- [ ] Merchant dashboard: payments by status, webhook delivery rate, settlement time
- [ ] Alert rules: payment confirmation p95 > 30s, queue depth > 1000" \
  "observability,P2,observability"

create_issue \
  "[P2] Add alerting rules for payment confirmation failures" \
  "## Problem
No automated alerting exists for elevated payment failure rates. On-call engineers discover issues reactively from merchant complaints.

## Acceptance Criteria
- [ ] Alert: payment failure rate > 5% over 5 minutes
- [ ] Alert: settlement queue depth > 500 for > 10 minutes
- [ ] Alert: Stellar monitor not running for > 2 minutes
- [ ] Alerts sent to Slack and/or PagerDuty
- [ ] Runbook link in each alert" \
  "observability,P2,observability"

create_issue \
  "[P2] Implement notification delivery webhook for merchants" \
  "## Problem
Merchants receive email notifications but cannot programmatically receive them for integration into their own systems.

## Acceptance Criteria
- [ ] Merchant can register a notification webhook URL
- [ ] All notification events (payment confirmed, settled, failed) sent to webhook
- [ ] Webhook payload signed with merchant's webhook secret
- [ ] Retry policy identical to existing webhook delivery" \
  "enhancement,P2,notifications"

create_issue \
  "[P2] Add payment funnel metrics — conversion rate tracking" \
  "## Problem
\`PaymentFunnelQueryDto\` exists but there's no visibility into conversion rates (payments created vs confirmed vs settled) by merchant.

## Acceptance Criteria
- [ ] \`GET /analytics/funnel?merchantId=&from=&to=\`
- [ ] Returns: created, confirmed, settling, settled, failed, expired counts and percentages
- [ ] Admin endpoint for platform-wide funnel
- [ ] Grafana panel for funnel visualization" \
  "enhancement,P2,analytics"

create_issue \
  "[P2] Add merchant notification preference defaults for new merchants" \
  "## Problem
New merchants have no notification preferences set. They receive no notifications until they configure preferences manually.

## Acceptance Criteria
- [ ] Default preferences created on merchant registration
- [ ] Defaults: email enabled for payment.confirmed, payment.settled, payment.failed
- [ ] Defaults configurable via admin RuntimeConfig
- [ ] Migration to backfill existing merchants with defaults" \
  "enhancement,P2,notifications"

create_issue \
  "[P2] Implement migration uncommitted check in CI pipeline" \
  "## Problem
\`scripts/migration-uncommitted-check.ts\` exists to catch uncommitted migrations, but is not integrated into the CI pipeline. Drift can reach production undetected.

## Acceptance Criteria
- [ ] CI step runs \`npm run migration:uncommitted:check\` on every PR
- [ ] Build fails if uncommitted migrations detected
- [ ] Clear error message guiding developer to generate migration" \
  "enhancement,P2,database"

create_issue \
  "[P2] Add TypeScript strict mode" \
  "## Problem
\`tsconfig.json\` does not enable TypeScript strict mode (\`strict: true\`). This allows implicit \`any\`, no null checks, and other type-safety gaps.

## Acceptance Criteria
- [ ] Enable \`\"strict\": true\` in \`tsconfig.json\`
- [ ] Fix all resulting type errors
- [ ] CI fails on TypeScript errors
- [ ] No use of \`@ts-ignore\` without a code comment explaining why" \
  "quality,P2,architecture"

create_issue \
  "[P2] Fix ESLint warnings and enforce zero-warning policy" \
  "## Problem
\`eslint-full-out.txt\` in the repo root suggests a large number of ESLint warnings that are not blocking CI.

## Acceptance Criteria
- [ ] Address all warnings in \`eslint-full-out.txt\`
- [ ] \`--max-warnings 0\` flag in lint script
- [ ] CI fails on any ESLint warning
- [ ] Delete \`eslint-full-out.txt\` from repo" \
  "quality,P2,architecture"

create_issue \
  "[P2] Add pre-commit hooks with husky and lint-staged" \
  "## Problem
Linting and formatting only run in CI. Developers can commit unformatted or linting-errored code, cluttering PR diffs.

## Acceptance Criteria
- [ ] \`husky\` + \`lint-staged\` added as devDependencies
- [ ] Pre-commit hook: \`eslint --fix\` and \`prettier --write\` on staged files
- [ ] Pre-push hook: \`tsc --noEmit\` type check
- [ ] Setup instructions in README" \
  "quality,P2,architecture"

create_issue \
  "[P2] Add GitHub Actions workflow for automated testing" \
  "## Problem
No \`.github/workflows/\` CI configuration found in the repository. Tests may only be run locally.

## Acceptance Criteria
- [ ] \`.github/workflows/ci.yml\` — runs on PR and push to main
- [ ] Steps: install deps, lint, type-check, unit tests, integration tests
- [ ] PostgreSQL and Redis services in workflow
- [ ] Coverage report uploaded to Codecov
- [ ] Status badge in README" \
  "devops,P2,architecture"

# ─── P3: LOW (35 issues) ─────────────────────────────────────────────────────

create_issue \
  "[P3] Document Soroban contract integration architecture" \
  "## Problem
The relationship between this backend and the \`dupdapp_stellar\` Soroban contracts is mentioned in README but not detailed enough for new contributors to understand the contract ABI and call patterns.

## Acceptance Criteria
- [ ] \`docs/soroban-integration.md\` explaining contract IDs, methods, and expected XDR responses
- [ ] Sequence diagram of payment flow through contracts
- [ ] Test contract addresses documented for testnet" \
  "documentation,P3,blockchain"

create_issue \
  "[P3] Add code examples for common Merchant API patterns" \
  "## Problem
The README has architecture docs but no practical code examples for merchant integrations.

## Acceptance Criteria
- [ ] \`docs/examples/\` directory
- [ ] Node.js example: create payment, poll status, verify webhook
- [ ] Python example: same flow
- [ ] Postman collection exported to \`docs/\`" \
  "documentation,P3,architecture"

create_issue \
  "[P3] Improve error message clarity and actionability" \
  "## Problem
Some error messages are internal (e.g., \`Cannot read property of undefined\`) rather than actionable for API consumers.

## Acceptance Criteria
- [ ] Audit error messages across all services
- [ ] Replace technical messages with user-friendly ones
- [ ] Each error includes an \`errorCode\` string (e.g., \`PAYMENT_EXPIRED\`)
- [ ] Error codes documented in API reference" \
  "quality,P3,architecture"

create_issue \
  "[P3] Add domain glossary to documentation" \
  "## Problem
Terms like \`escrow\`, \`settlement\`, \`USDC\`, \`Soroban\`, \`ledger\`, \`memo\` are used throughout but not defined for developers new to Stellar payments.

## Acceptance Criteria
- [ ] \`docs/glossary.md\` with definitions for all domain terms
- [ ] Linked from README
- [ ] Terms defined in context of DupDub specifically" \
  "documentation,P3,architecture"

create_issue \
  "[P3] Document webhook event payloads with full schema" \
  "## Problem
Webhook event types are referenced in code (\`payment.confirmed\`, \`payment.settling\`, etc.) but their payload schemas are not documented.

## Acceptance Criteria
- [ ] \`docs/webhooks.md\` listing all event types
- [ ] JSON Schema or TypeScript interface for each payload
- [ ] Example payload for each event
- [ ] Changelog for payload changes" \
  "documentation,P3,webhooks"

create_issue \
  "[P3] Implement better logging for Stellar monitor service" \
  "## Problem
Stellar monitor polling logs are minimal. It's hard to tell from logs whether monitoring is healthy, catching up, or stuck.

## Acceptance Criteria
- [ ] Log: each poll cycle start/end with ledger cursor
- [ ] Log: each payment detection with memo and amount
- [ ] Log: polling lag (current ledger vs last processed ledger)
- [ ] Metric: \`stellar_monitor_lag_ledgers\` gauge" \
  "observability,P3,blockchain"

create_issue \
  "[P3] Add Prometheus metrics for settlement batch sizes" \
  "## Problem
No metrics exist for settlement batch composition. Cannot tell from Prometheus whether batches are optimal or if small-payment batching is working correctly.

## Acceptance Criteria
- [ ] \`settlement_batch_size\` histogram
- [ ] \`settlement_batch_amount_usd\` histogram
- [ ] \`settlement_small_payment_queued_total\` counter
- [ ] Grafana panel for batch analytics" \
  "observability,P3,settlements"

create_issue \
  "[P3] Document backup and restore procedures" \
  "## Problem
\`src/backup/RECOVERY_DRILL.md\` exists but backup restore procedures for disaster recovery are incomplete.

## Acceptance Criteria
- [ ] Step-by-step restore procedure from S3 backup
- [ ] RTO and RPO targets defined
- [ ] Tested restore documented with timings
- [ ] Quarterly drill schedule added to RECOVERY_DRILL.md" \
  "documentation,P3,backup"

create_issue \
  "[P3] Refactor cache service to remove all any types" \
  "## Problem
\`CacheService\` uses untyped patterns in several places. A full refactor to use generics and typed Redis client injection would improve reliability.

## Acceptance Criteria
- [ ] All \`any\` types in \`cache/\` replaced with proper generics
- [ ] \`CacheService\` methods typed: \`get<T>(key: string): Promise<T | null>\`
- [ ] Existing tests pass after refactor" \
  "quality,P3,cache"

create_issue \
  "[P3] Extract settlement fee calculation to a dedicated service" \
  "## Problem
Fee calculation is embedded in \`SettlementsService\`. As fee tiers become more complex, this logic should be isolated and independently testable.

## Acceptance Criteria
- [ ] \`FeeCalculationService\` with \`calculateFee(merchantId, amountUsd): Promise<FeeResult>\`
- [ ] \`FeeResult\` includes: \`feeUsd\`, \`feeRate\`, \`tierName\`, \`netUsd\`
- [ ] Unit tests covering all tier boundaries
- [ ] \`SettlementsService\` delegates to \`FeeCalculationService\`" \
  "quality,P3,settlements"

create_issue \
  "[P3] Refactor payment status transitions into an explicit state machine" \
  "## Problem
Payment status transitions (\`PENDING\` → \`CONFIRMED\` → \`SETTLING\` → \`SETTLED\`) are scattered across multiple services. An invalid transition (e.g., SETTLED → PENDING) is not guarded.

## Acceptance Criteria
- [ ] \`PaymentStateMachine\` class with explicit allowed transitions map
- [ ] All status changes go through the state machine
- [ ] Invalid transitions throw \`InvalidStateTransitionException\`
- [ ] Unit tests for all valid and invalid transitions" \
  "quality,P3,payments"

create_issue \
  "[P3] Extract webhook retry logic into a reusable module" \
  "## Problem
Webhook retry logic is tightly coupled to the webhook delivery service. The same exponential backoff pattern is reimplemented in settlement retry.

## Acceptance Criteria
- [ ] \`RetryPolicyService\` or utility function for exponential backoff scheduling
- [ ] Configurable: base delay, multiplier, max attempts, jitter
- [ ] Used by both webhook and settlement retry jobs" \
  "quality,P3,architecture"

create_issue \
  "[P3] Implement event store for complete payment history" \
  "## Problem
Only the current payment state is stored. There is no event log showing each status transition, actor, and timestamp for audit and debugging purposes.

## Acceptance Criteria
- [ ] \`PaymentEvent\` entity: \`paymentId\`, \`eventType\`, \`previousStatus\`, \`newStatus\`, \`actorId\`, \`timestamp\`, \`metadata\`
- [ ] Every status transition creates a \`PaymentEvent\`
- [ ] \`GET /payments/:id/history\` returns the event log
- [ ] Events stored immutably (no updates/deletes)" \
  "enhancement,P3,payments"

create_issue \
  "[P3] Implement merchant settlement payment preferences (schedule/frequency)" \
  "## Problem
All merchants are settled as soon as the threshold is met. Some merchants may prefer end-of-day or weekly settlement batches.

## Acceptance Criteria
- [ ] \`settlementFrequency\` on Merchant: \`INSTANT\`, \`DAILY\`, \`WEEKLY\`
- [ ] Cron job respects merchant preference
- [ ] \`PATCH /merchant/settings\` to update preference
- [ ] Existing instant settlement behavior preserved as default" \
  "enhancement,P3,settlements"

create_issue \
  "[P3] Add lazy loading for merchant relationships in payment queries" \
  "## Problem
Payment list queries load the full merchant entity eagerly, even when only the merchant name is needed. This adds unnecessary data transfer.

## Acceptance Criteria
- [ ] Use TypeORM \`relations: []\` selectively per query
- [ ] Payment list endpoint uses projection to fetch only needed merchant fields
- [ ] Measure query time improvement with and without optimization" \
  "performance,P3,database"

create_issue \
  "[P3] Add database query profiling in development" \
  "## Problem
TypeORM logging is enabled in development but query durations are not profiled or surfaced. Slow queries go unnoticed locally.

## Acceptance Criteria
- [ ] \`DB_SLOW_QUERY_THRESHOLD_MS\` env var (default: 500ms)
- [ ] Queries exceeding threshold logged as WARN with full query text and parameters
- [ ] Prometheus metric \`db_slow_query_total\` counter by table" \
  "performance,P3,database"

create_issue \
  "[P3] Add Docker Compose configuration for local development" \
  "## Problem
README mentions PostgreSQL 16+, Redis 6+, but no Docker Compose file is provided. Developers must install and configure services manually.

## Acceptance Criteria
- [ ] \`docker-compose.yml\` with: PostgreSQL 16, Redis 6, (optional) Adminer for DB UI
- [ ] \`docker-compose.test.yml\` with seeded test database
- [ ] README updated with \`docker-compose up\` instructions
- [ ] \`.env.example\` updated to work out of the box with Docker Compose defaults" \
  "devops,P3,architecture"

create_issue \
  "[P3] Add Kubernetes deployment configuration" \
  "## Problem
No Kubernetes manifests or Helm chart are provided. Deploying to a production Kubernetes cluster requires building configuration from scratch.

## Acceptance Criteria
- [ ] \`infra/k8s/\` directory with Deployment, Service, ConfigMap, HPA manifests
- [ ] Liveness and readiness probes configured to use \`/health\` endpoint
- [ ] Secrets referenced from Kubernetes secrets (not env vars in manifests)
- [ ] HPA: scale on CPU > 70% or request queue depth > 100" \
  "devops,P3,architecture"

create_issue \
  "[P3] Expand load testing suite with settlement and webhook scenarios" \
  "## Problem
\`load-tests/payments.k6.ts\` only covers payment creation. Settlement processing and webhook delivery under load are untested.

## Acceptance Criteria
- [ ] \`load-tests/settlements.k6.ts\` — settlement batch processing at scale
- [ ] \`load-tests/webhooks.k6.ts\` — webhook delivery throughput
- [ ] \`load-tests/README.md\` with results from baseline run
- [ ] Grafana k6 output integration for real-time visualization" \
  "testing,P3,performance"

create_issue \
  "[P3] Implement health check probes for Kubernetes liveness and readiness" \
  "## Problem
The health endpoint exists but may not be correctly separated into liveness (is the process alive?) vs readiness (is the process ready to serve traffic?) probes.

## Acceptance Criteria
- [ ] \`GET /health/live\` — liveness: only checks if process is running
- [ ] \`GET /health/ready\` — readiness: checks DB, Redis, and Stellar connection
- [ ] Kubernetes manifests use correct probe per path
- [ ] Health endpoint excludes external dependencies from liveness check" \
  "devops,P3,health"

create_issue \
  "[P3] Document production deployment checklist" \
  "## Problem
No production deployment checklist exists. Teams risk skipping steps like running migrations, updating secrets, or verifying health probes.

## Acceptance Criteria
- [ ] \`docs/deployment.md\` with pre-deploy, deploy, and post-deploy checklists
- [ ] Section: rollback procedure
- [ ] Section: database migration strategy (zero-downtime migrations)
- [ ] Section: secret rotation on deploy" \
  "documentation,P3,devops"

create_issue \
  "[P3] Add SorobanRpcException to Sentry error tracking" \
  "## Problem
\`SentryExceptionFilter\` exists but \`SorobanRpcException\` is not explicitly mapped, so Soroban RPC errors may be swallowed or not tagged correctly in Sentry.

## Acceptance Criteria
- [ ] \`SorobanRpcException\` tagged in Sentry with \`blockchain\` context
- [ ] Sentry breadcrumbs include the Soroban RPC method and parameters
- [ ] Test: simulate RPC failure and verify Sentry event created" \
  "observability,P3,blockchain"

create_issue \
  "[P3] Improve cache warming strategy on application startup" \
  "## Problem
A \`CacheWarmupService\` is referenced in \`app.module.ts\` but it is not initialized or implemented. Cold starts result in a cache miss storm that hammers the database.

## Acceptance Criteria
- [ ] \`CacheWarmupService.onApplicationBootstrap()\` warms critical caches
- [ ] Warm: XLM/USD rate, merchant configs for top 50 merchants by volume
- [ ] Cache warmup completes before readiness probe passes
- [ ] Warmup duration logged at INFO level" \
  "performance,P3,cache"

create_issue \
  "[P3] Implement changelog and release notes process" \
  "## Problem
There is no \`CHANGELOG.md\` or release notes process. Merchants integrating the API have no visibility into changes.

## Acceptance Criteria
- [ ] \`CHANGELOG.md\` following Keep a Changelog format
- [ ] Entries for all breaking changes, new features, and bug fixes
- [ ] \`RELEASING.md\` documenting the release process
- [ ] Semantic versioning applied to API and npm package" \
  "documentation,P3,architecture"

create_issue \
  "[P3] Add CORS configuration tests" \
  "## Problem
\`ALLOWED_ORIGINS\` is configurable but if not set in development, CORS may be wide open. This should be tested and validated.

## Acceptance Criteria
- [ ] Unit test: CORS allows configured origin
- [ ] Unit test: CORS blocks unlisted origin
- [ ] Startup validation: CORS not wildcard \`*\` in production
- [ ] \`ALLOWED_ORIGINS\` documented in \`.env.example\`" \
  "security,P3,auth"

create_issue \
  "[P3] Add audit logging for Merchant configuration changes" \
  "## Problem
Merchant profile updates (business name, bank account, webhook URL) are not captured in the audit log. Unauthorized changes are undetectable.

## Acceptance Criteria
- [ ] All PATCH/PUT on merchant settings create audit log entries
- [ ] Audit log: \`actorId\`, \`action\`, \`before\`, \`after\`, \`timestamp\`
- [ ] \`GET /merchant/audit-log\` with pagination
- [ ] Sensitive fields (bank account) masked in audit log" \
  "security,P3,audit"

create_issue \
  "[P3] Implement admin alert lifecycle tracking" \
  "## Problem
\`AdminAlert\` entities are raised via \`AdminAlertService\` but there is no way to acknowledge, assign, or resolve them. Alerts accumulate with no lifecycle management.

## Acceptance Criteria
- [ ] Alert statuses: \`OPEN\`, \`ACKNOWLEDGED\`, \`RESOLVED\`
- [ ] \`PATCH /admin/alerts/:id/acknowledge\`
- [ ] \`PATCH /admin/alerts/:id/resolve\`
- [ ] Alert age tracked; overdue open alerts escalated automatically
- [ ] Prometheus metric for open alert count" \
  "enhancement,P3,admin"

create_issue \
  "[P3] Add payment QR code expiry visual indicator" \
  "## Problem
QR codes are generated at payment creation and stored as base64 data URLs. There is no visual expiry indicator baked into the QR code or metadata for the frontend.

## Acceptance Criteria
- [ ] Payment response includes \`expiresAt\` ISO timestamp
- [ ] QR code URL includes expiry as a query param for frontend rendering
- [ ] Expired QR codes return 410 Gone when scanned
- [ ] Frontend integration guide in docs" \
  "enhancement,P3,payments"

create_issue \
  "[P3] Remove eslint-full-out.txt from repository" \
  "## Problem
\`dupdap-backend/eslint-full-out.txt\` is committed to the repo. This is a generated artifact that should not be in version control and may contain sensitive path information.

## Acceptance Criteria
- [ ] Delete \`eslint-full-out.txt\` from repository
- [ ] Add \`*.txt\` or specific filename to \`.gitignore\`
- [ ] CI linting replaces this file as the authoritative lint report" \
  "quality,P3,architecture"

create_issue \
  "[P3] Add Stellar testnet integration test environment" \
  "## Problem
Stellar interactions are only testable locally. There is no shared testnet environment for CI to run Soroban contract integration tests against.

## Acceptance Criteria
- [ ] \`test/stellar/\` directory with testnet integration tests
- [ ] Funded testnet keypair in CI secrets
- [ ] Tests verify: deposit, release, refund flows on testnet contracts
- [ ] Clearly marked as \`integration:stellar\` and skipped in unit test runs" \
  "testing,P3,blockchain"

create_issue \
  "[P3] Add OpenAPI spec export to CI build artifacts" \
  "## Problem
The Swagger UI is served at runtime but the OpenAPI JSON spec is not exported as a build artifact. External tools cannot auto-generate SDK clients.

## Acceptance Criteria
- [ ] \`npm run export:openapi\` script that boots app, exports \`/docs-json\`, and saves to \`openapi.json\`
- [ ] CI uploads \`openapi.json\` as a build artifact
- [ ] Version-tagged releases publish OpenAPI spec to GitHub releases
- [ ] SDK generation example added to docs" \
  "documentation,P3,architecture"

echo ""
echo "✅ Done creating GitHub issues."
