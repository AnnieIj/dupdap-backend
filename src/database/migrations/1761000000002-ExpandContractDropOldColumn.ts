import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * LIVING REFERENCE — Expand-contract column rename (Phase 3: Contract)
 * =====================================================================
 * Drops the old `payments.metadata` column once all application code has been
 * updated to use `payments.paymentMetadata` and no running pod references the
 * old name.
 *
 * ── WHEN TO RUN THIS ────────────────────────────────────────────────────────
 *
 *  Deploy this migration only AFTER:
 *  1. Phase 1 (1761000000001-ExpandContractColumnRenameExample) has been in
 *     production for at least one full deploy cycle.
 *  2. All application code (services, repositories, queue consumers) has been
 *     updated to read/write `paymentMetadata` exclusively.
 *  3. No running pod still references `metadata` — check Datadog / logs for
 *     any remaining SELECT/UPDATE on that column before deploying.
 *
 * See docs/migrations.md for the full three-phase strategy.
 */
export class ExpandContractDropOldColumn1761000000002
  implements MigrationInterface
{
  name = 'ExpandContractDropOldColumn1761000000002';

  // ── PHASE 3: CONTRACT ──────────────────────────────────────────────────────

  public async up(queryRunner: QueryRunner): Promise<void> {
    const tableExists = await queryRunner.hasTable('payments');
    if (!tableExists) {
      return;
    }

    await queryRunner.query(`
      ALTER TABLE "payments"
      DROP COLUMN IF EXISTS "metadata"
    `);
  }

  // ── PHASE 3 ROLLBACK ───────────────────────────────────────────────────────
  //
  //   Re-add the old column and copy data back from the new column so that any
  //   app version that still references `metadata` can function again.
  //
  //   Note: if this rollback is triggered in production, also roll back the
  //   application code to the version that wrote to both columns (Phase 1 app).

  public async down(queryRunner: QueryRunner): Promise<void> {
    const tableExists = await queryRunner.hasTable('payments');
    if (!tableExists) {
      return;
    }

    // Re-add the column as nullable (the original may have been nullable).
    await queryRunner.query(`
      ALTER TABLE "payments"
      ADD COLUMN IF NOT EXISTS "metadata" JSONB
    `);

    // Repopulate from the new column so data integrity is preserved.
    await queryRunner.query(`
      UPDATE "payments"
      SET    "metadata" = "paymentMetadata"
      WHERE  "metadata" IS NULL
        AND  "paymentMetadata" IS NOT NULL
    `);
  }
}
