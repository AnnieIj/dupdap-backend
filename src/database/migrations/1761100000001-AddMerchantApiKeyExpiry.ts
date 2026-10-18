import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddMerchantApiKeyExpiry1761100000001 implements MigrationInterface {
  name = 'AddMerchantApiKeyExpiry1761100000001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "merchants"
      ADD COLUMN IF NOT EXISTS "apiKeyExpiresAt"   TIMESTAMPTZ DEFAULT NULL,
      ADD COLUMN IF NOT EXISTS "apiKeyExpirySentAt" TIMESTAMPTZ DEFAULT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "merchants"
      DROP COLUMN IF EXISTS "apiKeyExpirySentAt",
      DROP COLUMN IF EXISTS "apiKeyExpiresAt"
    `);
  }
}
