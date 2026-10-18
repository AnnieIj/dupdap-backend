# Database Migration Strategy — Zero-Downtime Deploys

This document describes how DupDub runs schema migrations without taking downtime. All migrations **must** follow the expand-contract pattern described here. The accompanying sample migration (`1761000000001-ExpandContractColumnRenameExample`) is a living code reference for new contributors.

---

## Table of contents

1. [Why zero-downtime migrations matter](#why-zero-downtime-migrations-matter)
2. [The expand-contract pattern](#the-expand-contract-pattern)
3. [Worked example — column rename](#worked-example--column-rename)
   - [Phase 1 — Expand](#phase-1--expand)
   - [Phase 2 — Backfill](#phase-2--backfill)
   - [Phase 3 — Contract](#phase-3--contract)
4. [Other migration types](#other-migration-types)
   - [Adding a NOT NULL column](#adding-a-not-null-column)
   - [Dropping a column](#dropping-a-column)
   - [Changing a column type](#changing-a-column-type)
   - [Adding an index](#adding-an-index)
   - [Renaming a table](#renaming-a-table)
5. [Writing a migration file](#writing-a-migration-file)
6. [CI validation steps](#ci-validation-steps)
7. [Rollback scripts](#rollback-scripts)
8. [Checklist before merging](#checklist-before-merging)

---

## Why zero-downtime migrations matter

DupDub is a payment platform — downtime during a deploy directly blocks merchant settlements and customer payments. The Postgres schema and the running application code are deployed independently:

- The **new schema** is applied by `pnpm migration:run` inside the deploy pipeline, before the new pod/process starts.
- The **old application** processes requests against the new schema for a short window while pods roll over.
- The **new application** must continue working if a rollback of the code (not the DB) is needed after deploy.

This means every migration must leave the database in a state that both the **old** and **new** application version can read and write correctly.

---

## The expand-contract pattern

Expand-contract splits a breaking schema change across **three phases**, each deployed separately:

```
Phase 1 — Expand   → add new structures; keep old ones; both app versions work
Phase 2 — Backfill → copy/transform existing data into the new structure (can be
                     done in the same deploy as Phase 1 for small tables, or as a
                     background job for large ones)
Phase 3 — Contract → remove old structures once all app code uses the new ones
```

The key rule: **never remove or rename a column in the same deploy that adds the replacement**. Always ship the additive change first, let it ride in production, then clean up.

---

## Worked example — column rename

### Scenario

Rename `payments.metadata` → `payments.paymentMetadata` across the codebase.

---

### Phase 1 — Expand

**Goal**: add the new column alongside the old one. Both columns exist; the old application still reads/writes `metadata`; the new application reads/writes `paymentMetadata` and keeps `metadata` in sync.

```typescript
// src/database/migrations/1761000000001-ExpandContractColumnRenameExample.ts
// See the living reference file for the full annotated implementation.
```

Migration SQL (simplified):

```sql
-- Phase 1 up
ALTER TABLE "payments" ADD COLUMN "paymentMetadata" JSONB;
-- Copy existing data so the new column is populated immediately for small tables.
UPDATE "payments" SET "paymentMetadata" = "metadata" WHERE "paymentMetadata" IS NULL;

-- Application code in this deploy must write to BOTH columns:
--   this.paymentsRepository.save({ metadata: val, paymentMetadata: val });
```

Rollback (Phase 1 down):

```sql
ALTER TABLE "payments" DROP COLUMN IF EXISTS "paymentMetadata";
```

---

### Phase 2 — Backfill

For tables with millions of rows, run the backfill as a background job in batches rather than a single UPDATE inside the migration (which holds a lock for the full duration):

```sql
-- Run outside a transaction, in batches, e.g. via a one-off script or cron:
UPDATE "payments"
SET    "paymentMetadata" = "metadata"
WHERE  "paymentMetadata" IS NULL
AND    id IN (
    SELECT id FROM "payments"
    WHERE  "paymentMetadata" IS NULL
    LIMIT  1000
);
-- Repeat until zero rows updated.
```

The payments table is unlikely to be very large in DupDub's early stage; an inline UPDATE in Phase 1 is fine. Add the batched approach when the table exceeds ~500 k rows.

---

### Phase 3 — Contract

**Goal**: drop the old column once *all* app code (including any async queue consumers that may replay old jobs) uses `paymentMetadata`.

```sql
-- Phase 3 up  — deploy AFTER the Phase-1 app version is fully retired
ALTER TABLE "payments" DROP COLUMN "metadata";

-- Phase 3 down  — re-add as nullable so old data is not lost
ALTER TABLE "payments" ADD COLUMN "metadata" JSONB;
UPDATE "payments" SET "metadata" = "paymentMetadata";
```

> **Rule**: wait at least one full deploy cycle (i.e., no running pods use the old column name) before running Phase 3. In practice this means Phase 3 lands in the *next* sprint's release.

---

## Other migration types

### Adding a NOT NULL column

Never add a NOT NULL column without a default in a single step — Postgres must rewrite the entire table.

```sql
-- Safe pattern
-- Step 1: add nullable
ALTER TABLE "payments" ADD COLUMN "region" VARCHAR;

-- Step 2: backfill
UPDATE "payments" SET "region" = 'US' WHERE "region" IS NULL;

-- Step 3: set NOT NULL (after backfill, in a separate deploy)
ALTER TABLE "payments" ALTER COLUMN "region" SET NOT NULL;
```

Postgres 11+ handles `ADD COLUMN … DEFAULT constant_value NOT NULL` without a rewrite — use that where the default is a constant and is acceptable long-term.

---

### Dropping a column

```sql
-- Phase 1: stop reading/writing the column in app code (deploy this first)
-- Phase 2: drop the column (deploy after Phase 1 is fully rolled out)
ALTER TABLE "payments" DROP COLUMN "legacyField";

-- Rollback for Phase 2
ALTER TABLE "payments" ADD COLUMN "legacyField" TEXT;
```

---

### Changing a column type

Type changes (e.g., `VARCHAR` → `TEXT`, `INT` → `BIGINT`) are often safe but some require a full table rewrite:

| Change | Safe? | Strategy |
|---|---|---|
| `VARCHAR(n)` → `TEXT` | ✅ instant | Direct ALTER |
| `INT` → `BIGINT` | ✅ instant on Pg 14+ | Direct ALTER |
| `VARCHAR` → `JSONB` | ❌ rewrite | Add new column, backfill, drop old |
| Adding a constraint | ❌ lock | Use `NOT VALID` + `VALIDATE CONSTRAINT` |

For any change requiring a table rewrite, use the expand-contract pattern (add new typed column, backfill, drop old).

Adding a constraint safely:

```sql
-- Add without validating existing rows (no full-table lock)
ALTER TABLE "payments"
  ADD CONSTRAINT "CHK_payments_amount_positive"
  CHECK ("amount" > 0) NOT VALID;

-- Validate in a separate transaction (ShareUpdateExclusiveLock only)
ALTER TABLE "payments" VALIDATE CONSTRAINT "CHK_payments_amount_positive";
```

---

### Adding an index

Use `CREATE INDEX CONCURRENTLY` to avoid locking writes. TypeORM migrations run in a transaction by default — concurrent index creation cannot run inside a transaction, so mark the migration `transaction = false`:

```typescript
export class AddMyIndex1760000000001 implements MigrationInterface {
  // Opt out of the auto-wrapping transaction
  public transaction = false;

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE INDEX CONCURRENTLY IF NOT EXISTS "IDX_payments_my_field"
      ON "payments" ("myField")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX CONCURRENTLY IF EXISTS "IDX_payments_my_field"`);
  }
}
```

---

### Renaming a table

Table renames are the same as column renames — use a view as a compatibility shim:

```sql
-- Phase 1: rename + create view with old name
ALTER TABLE "old_table" RENAME TO "new_table";
CREATE VIEW "old_table" AS SELECT * FROM "new_table";

-- Phase 3: drop the view after all code uses new_table
DROP VIEW "old_table";
```

---

## Writing a migration file

### Naming and timestamp

Filenames follow: `<unix-timestamp-ms>-<PascalCaseDescription>.ts`

Generate the timestamp:

```bash
node -e "console.log(Date.now())"
```

### Template

```typescript
import { MigrationInterface, QueryRunner } from 'typeorm';

export class MyChange1760000000001 implements MigrationInterface {
  name = 'MyChange1760000000001';

  // Set to false only when using CONCURRENTLY or other non-transactional DDL.
  // public transaction = false;

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Use IF NOT EXISTS / IF EXISTS guards so migrations are idempotent
    // and safe to re-run in CI environments.
    await queryRunner.query(`
      ALTER TABLE "payments" ADD COLUMN IF NOT EXISTS "newField" TEXT
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "payments" DROP COLUMN IF EXISTS "newField"
    `);
  }
}
```

### Rules

1. **Always implement `down()`** — CI runs a full rollback check on every PR.
2. **Use `IF NOT EXISTS` / `IF EXISTS`** guards so migrations are idempotent.
3. **One logical change per file** — keeps rollback granular and review easy.
4. **Check table/column existence** before altering (`queryRunner.hasTable()`) when a migration could legitimately run on a DB that skipped an earlier migration.
5. **No raw `synchronize: true`** — TypeORM sync is disabled in `ormconfig.ts`; never enable it in a shared environment.
6. **Commit migration files** before opening a PR — `migration:uncommitted:check` will fail otherwise.

---

## CI validation steps

Three scripts run in CI on every PR that touches `src/database/migrations/` or the application entities:

| Script | npm script | What it does |
|---|---|---|
| Migration run check | `pnpm migration:check` | Applies all pending migrations to a test DB and exits non-zero on failure |
| Rollback check | `pnpm migration:rollback:check` | Applies then reverts **every** migration; verifies `down()` is complete and correct |
| Uncommitted check | `pnpm migration:uncommitted:check` | Fails if any migration file is not committed to git |

The GitHub Actions workflow (`.github/workflows/migration-safety.yml`) runs all three automatically. See that file for the full job definition.

### Running checks locally

```bash
# Requires a running Postgres — set DB_* env vars or use .env
pnpm migration:check
pnpm migration:rollback:check
pnpm migration:uncommitted:check
```

---

## Rollback scripts

### Revert the last migration (TypeORM)

```bash
pnpm migration:revert
```

This calls TypeORM's `undoLastMigration`, which executes the `down()` method of the most recently applied migration.

### Revert multiple migrations

```bash
# Revert N times
for i in $(seq 1 3); do pnpm migration:revert; done
```

Or use the rollback-check script directly (it reverts all migrations to the empty state):

```bash
pnpm migration:rollback:check
```

### Emergency point-in-time restore

If a migration causes data corruption and code rollback alone is insufficient:

1. Identify the last known-good Postgres backup in S3 (`BACKUP_S3_BUCKET`).
2. Follow the steps in [`src/backup/RECOVERY_DRILL.md`](../src/backup/RECOVERY_DRILL.md).
3. After restoring, run `pnpm migration:show` to confirm which migrations are recorded in `typeorm_migrations`.
4. Re-apply any migrations that were run after the backup point only if they are safe for the restored data state.

### Per-migration rollback reference

Each migration type has its rollback SQL documented inline above in the [Other migration types](#other-migration-types) section. As a quick reference:

| Change type | Rollback action |
|---|---|
| `ADD COLUMN` | `DROP COLUMN IF EXISTS` |
| `DROP COLUMN` | `ADD COLUMN` + re-populate from backup |
| `ADD INDEX CONCURRENTLY` | `DROP INDEX CONCURRENTLY IF EXISTS` |
| `CREATE TABLE` | `DROP TABLE` |
| `DROP TABLE` | Restore from backup |
| Expand phase of rename | `DROP COLUMN IF EXISTS` (new column only) |
| Contract phase of rename | `ADD COLUMN` + `UPDATE … SET old = new` |
| `ADD CONSTRAINT NOT VALID` | `ALTER TABLE … DROP CONSTRAINT` |

---

## Checklist before merging

- [ ] Migration timestamp is unique (no filename collisions with existing files)
- [ ] `down()` is implemented and tested locally via `pnpm migration:rollback:check`
- [ ] DDL uses `IF NOT EXISTS` / `IF EXISTS` guards
- [ ] Indexes use `CONCURRENTLY` and the migration sets `public transaction = false`
- [ ] The change follows expand-contract if it removes or renames anything
- [ ] Migration file is committed (`pnpm migration:uncommitted:check` passes)
- [ ] CI workflow `migration-safety` is green
