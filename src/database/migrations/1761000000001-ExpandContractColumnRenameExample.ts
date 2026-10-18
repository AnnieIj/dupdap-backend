import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * LIVING REFERENCE — Expand-contract column rename
 * =================================================
 * This migration demonstrates the three-phase expand-contract pattern for a
 * zero-downtime column rename: `payments.metadata` → `payments.paymentMetadata`.
 *
 * This file is intentionally verbose so it can serve as a copy-paste template
 * for future contributors. See docs/migrations.md for the full strategy.
 *
 * ── DEPLOYMENT ORDER ────────────────────────────────────────────────────────
 *
 *  Phase 1 (this file): Add `paymentMetadata`, backfill from `metadata`.
 *    App code in the SAME deploy must write to BOTH columns and read from
 *    `paymentMetadata` with a fallback to `metadata`.
 *
 *  Phase 2 (background/inline): Confirm all rows have `paymentMetadata` set.
 *    For large tables run the backfill in batches outside this migration.
 *
 *  Phase 3 (next sprint): Drop `metadata` once no running pod reads it.
 *    See the companion migration 1761000000002-ExpandContractDropOldColumn.
 *
 * ── WHY NOT RENAME DIRECTLY? ────────────────────────────────────────────────
 *
 *  A direct ALTER TABLE … RENAME COLUMN is instant in Postgres, but it is a
 *  breaking change at deploy time: the old app version (still running while
 *  pods roll over) will immediately fail because it references the old name.
 *  Expand-contract avoids that window.
 */
export class ExpandContractColumnRenameExample1761000000001
  implements MigrationInterface
{
  name = 'ExpandContractColumnRenameExample1761000000001';

  // ── PHASE 1: EXPAND ────────────────────────────────────────────────────────

  public async up(queryRunner: QueryRunner): Promise<void> {
    const tableExists = await queryRunner.hasTable('payments');
    if (!tableExists) {
      // Defensive guard: safe to skip on a fresh database that doesn't yet
      // have the payments table (e.g., CI environments running a subset of
      // migrations). Remove this guard once the CreatePayments migration is
      // guaranteed to run before this one.
      return;
    }

    // ── Step 1: Add the new column as nullable so existing rows are unaffected.
    //
    //   We use IF NOT EXISTS so re-running this migration (e.g., in a CI reset)
    //   is idempotent and does not raise an error.
    await queryRunner.query(`
      ALTER TABLE "payments"
      ADD COLUMN IF NOT EXISTS "paymentMetadata" JSONB
    `);

    // ── Step 2: Backfill existing rows.
    //
    //   For the DupDub payments table (expected to be small at this stage) we
    //   can do this inline. For tables with > ~500 k rows, remove this UPDATE
    //   and run a batched background job instead — see docs/migrations.md.
    //
    //   The WHERE guard makes the UPDATE idempotent.
    await queryRunner.query(`
      UPDATE "payments"
      SET    "paymentMetadata" = "metadata"
      WHERE  "paymentMetadata" IS NULL
        AND  "metadata"        IS NOT NULL
    `);
  }

  // ── PHASE 1 ROLLBACK ───────────────────────────────────────────────────────
  //
  //   Rolling back Phase 1 is safe: we simply drop the new column. The old
  //   column was never touched, so no data is lost.

  public async down(queryRunner: QueryRunner): Promise<void> {
    const tableExists = await queryRunner.hasTable('payments');
    if (!tableExists) {
      return;
    }

    await queryRunner.query(`
      ALTER TABLE "payments"
      DROP COLUMN IF EXISTS "paymentMetadata"
    `);
  }
}
