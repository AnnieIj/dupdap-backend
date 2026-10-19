/**
 * Integration tests: scoped API key permission enforcement
 *
 * Verifies that every merchant-facing endpoint returns HTTP 403 when an API key
 * that lacks the required scope is used to call it.
 *
 * Prerequisites: a running Postgres instance reachable at DB_HOST/DB_PORT/DB_NAME_TEST
 * (same env vars used by the other integration specs).
 *
 * Run with:
 *   pnpm test:integration -- --testPathPattern=api-key-scopes
 */

import { INestApplication, RequestMethod, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { Connection } from 'typeorm';
import request from 'supertest';

import { AuthModule } from '../auth/auth.module';
import { MerchantsModule } from '../merchants/merchants.module';
import { PaymentsModule } from '../payments/payments.module';
import { SettlementsModule } from '../settlements/settlements.module';
import { WebhooksModule } from '../webhooks/webhooks.module';
import { AppThrottlerGuard } from '../auth/guards/throttler.guard';
import { Merchant } from '../merchants/entities/merchant.entity';
import { AdminAuditLog } from '../merchants/entities/admin-audit-log.entity';
import { Payment } from '../payments/entities/payment.entity';
import { Settlement } from '../settlements/entities/settlement.entity';
import { Webhook } from '../webhooks/entities/webhook.entity';
import { WaitlistEntry } from '../waitlist/entities/waitlist.entity';

const API = '/api/v1';
const TEST_ENTITIES = [Merchant, AdminAuditLog, Payment, Settlement, Webhook, WaitlistEntry];

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function buildApp(): Promise<INestApplication> {
  process.env.JWT_SECRET = process.env.JWT_SECRET ?? 'scope-test-jwt-secret-min32-chars!!';
  process.env.JWT_EXPIRES_IN = '1h';
  process.env.THROTTLE_DEFAULT_TTL_MS = '60000';
  process.env.THROTTLE_DEFAULT_LIMIT = '1000';
  process.env.THROTTLE_AUTHENTICATED_TTL_MS = '60000';
  process.env.THROTTLE_AUTHENTICATED_LIMIT = '1000';
  process.env.API_KEY_SALT = process.env.API_KEY_SALT ?? 'scopes-test-salt';

  const moduleFixture: TestingModule = await Test.createTestingModule({
    imports: [
      ConfigModule.forRoot({ isGlobal: true }),
      TypeOrmModule.forRoot({
        type: 'postgres',
        host: process.env.DB_HOST ?? 'localhost',
        port: Number(process.env.DB_PORT ?? 5432),
        username: process.env.DB_USER ?? 'postgres',
        password: process.env.DB_PASSWORD ?? 'postgres',
        database: process.env.DB_NAME_TEST ?? 'dupdub_test',
        entities: TEST_ENTITIES,
        synchronize: true,
        logging: false,
      }),
      ThrottlerModule.forRootAsync({
        imports: [ConfigModule],
        inject: [ConfigService],
        useFactory: (config: ConfigService) => ({
          throttlers: [
            {
              name: 'default',
              ttl: Number(config.get('THROTTLE_DEFAULT_TTL_MS', 60000)),
              limit: Number(config.get('THROTTLE_DEFAULT_LIMIT', 1000)),
            },
            {
              name: 'authenticated',
              ttl: Number(config.get('THROTTLE_AUTHENTICATED_TTL_MS', 60000)),
              limit: Number(config.get('THROTTLE_AUTHENTICATED_LIMIT', 1000)),
            },
          ],
        }),
      }),
      AuthModule,
      MerchantsModule,
      PaymentsModule,
      SettlementsModule,
      WebhooksModule,
    ],
    providers: [{ provide: APP_GUARD, useClass: AppThrottlerGuard }],
  }).compile();

  const app = moduleFixture.createNestApplication();
  app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
  app.setGlobalPrefix(API.slice(1), {
    exclude: [
      { path: 'health', method: RequestMethod.ALL },
      { path: 'health/ready', method: RequestMethod.ALL },
    ],
  });

  await app.init();
  return app;
}

async function truncate(app: INestApplication): Promise<void> {
  const conn = app.get(Connection);
  await conn.query(
    `TRUNCATE TABLE "merchants", "payments", "settlements", "webhooks" RESTART IDENTITY CASCADE`,
  );
}

/** Register a merchant and return a JWT. */
async function registerAndLogin(
  app: INestApplication,
  suffix = Date.now().toString(),
): Promise<string> {
  const res = await request(app.getHttpServer())
    .post(`${API}/auth/register`)
    .send({ email: `scope-test-${suffix}@example.com`, password: 'SecurePass123!', businessName: `Scope Co ${suffix}` })
    .expect(201);
  return res.body.accessToken as string;
}

/** Generate an API key restricted to the given scopes. Returns the raw key. */
async function issueApiKey(
  app: INestApplication,
  jwt: string,
  scopes: string[],
): Promise<string> {
  const res = await request(app.getHttpServer())
    .post(`${API}/merchants/api-keys`)
    .set('Authorization', `Bearer ${jwt}`)
    .send({ scopes })
    .expect(201);
  return res.body.apiKey as string;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

describe('API key scope enforcement (integration)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    app = await buildApp();
  });

  afterEach(async () => {
    await truncate(app);
  });

  afterAll(async () => {
    await app.close();
  });

  // ── payments:read ─────────────────────────────────────────────────────────

  describe('payments:read scope', () => {
    it('GET /payments → 200 with payments:read', async () => {
      const jwt = await registerAndLogin(app, `pr-ok-${Date.now()}`);
      const key = await issueApiKey(app, jwt, ['payments:read']);
      await request(app.getHttpServer())
        .get(`${API}/payments`)
        .set('X-API-Key', key)
        .expect(200);
    });

    it('GET /payments → 403 without payments:read', async () => {
      const jwt = await registerAndLogin(app, `pr-miss-${Date.now()}`);
      const key = await issueApiKey(app, jwt, ['payments:write']);
      await request(app.getHttpServer())
        .get(`${API}/payments`)
        .set('X-API-Key', key)
        .expect(403);
    });

    it('GET /payments/stats → 403 without payments:read', async () => {
      const jwt = await registerAndLogin(app, `pstats-${Date.now()}`);
      const key = await issueApiKey(app, jwt, ['settlements:read']);
      await request(app.getHttpServer())
        .get(`${API}/payments/stats`)
        .set('X-API-Key', key)
        .expect(403);
    });
  });

  // ── payments:write ────────────────────────────────────────────────────────

  describe('payments:write scope', () => {
    it('POST /payments → 403 without payments:write', async () => {
      const jwt = await registerAndLogin(app, `pw-miss-${Date.now()}`);
      const key = await issueApiKey(app, jwt, ['payments:read']);
      await request(app.getHttpServer())
        .post(`${API}/payments`)
        .set('X-API-Key', key)
        .send({ amountUsd: 10.0, description: 'Test' })
        .expect(403);
    });

    it('POST /payments/batch → 403 without payments:write', async () => {
      const jwt = await registerAndLogin(app, `pb-miss-${Date.now()}`);
      const key = await issueApiKey(app, jwt, ['payments:read']);
      await request(app.getHttpServer())
        .post(`${API}/payments/batch`)
        .set('X-API-Key', key)
        .send({ payments: [] })
        .expect(403);
    });
  });

  // ── settlements:read ──────────────────────────────────────────────────────

  describe('settlements:read scope', () => {
    it('GET /settlements → 200 with settlements:read', async () => {
      const jwt = await registerAndLogin(app, `sr-ok-${Date.now()}`);
      const key = await issueApiKey(app, jwt, ['settlements:read']);
      await request(app.getHttpServer())
        .get(`${API}/settlements`)
        .set('X-API-Key', key)
        .expect(200);
    });

    it('GET /settlements → 403 without settlements:read', async () => {
      const jwt = await registerAndLogin(app, `sr-miss-${Date.now()}`);
      const key = await issueApiKey(app, jwt, ['payments:read']);
      await request(app.getHttpServer())
        .get(`${API}/settlements`)
        .set('X-API-Key', key)
        .expect(403);
    });
  });

  // ── webhooks:manage ───────────────────────────────────────────────────────

  describe('webhooks:manage scope', () => {
    it('GET /webhooks → 200 with webhooks:manage', async () => {
      const jwt = await registerAndLogin(app, `wh-ok-${Date.now()}`);
      const key = await issueApiKey(app, jwt, ['webhooks:manage']);
      await request(app.getHttpServer())
        .get(`${API}/webhooks`)
        .set('X-API-Key', key)
        .expect(200);
    });

    it('GET /webhooks → 403 without webhooks:manage', async () => {
      const jwt = await registerAndLogin(app, `wh-miss-${Date.now()}`);
      const key = await issueApiKey(app, jwt, ['payments:read']);
      await request(app.getHttpServer())
        .get(`${API}/webhooks`)
        .set('X-API-Key', key)
        .expect(403);
    });

    it('POST /webhooks → 403 without webhooks:manage', async () => {
      const jwt = await registerAndLogin(app, `wh-post-miss-${Date.now()}`);
      const key = await issueApiKey(app, jwt, ['payments:read', 'payments:write']);
      await request(app.getHttpServer())
        .post(`${API}/webhooks`)
        .set('X-API-Key', key)
        .send({ url: 'https://example.com/hook', events: ['payment.confirmed'] })
        .expect(403);
    });
  });

  // ── profile:read ──────────────────────────────────────────────────────────

  describe('profile:read scope', () => {
    it('GET /merchants/me → 200 with profile:read', async () => {
      const jwt = await registerAndLogin(app, `prof-ok-${Date.now()}`);
      const key = await issueApiKey(app, jwt, ['profile:read']);
      await request(app.getHttpServer())
        .get(`${API}/merchants/me`)
        .set('X-API-Key', key)
        .expect(200);
    });

    it('GET /merchants/me → 403 without profile:read', async () => {
      const jwt = await registerAndLogin(app, `prof-miss-${Date.now()}`);
      const key = await issueApiKey(app, jwt, ['payments:read']);
      await request(app.getHttpServer())
        .get(`${API}/merchants/me`)
        .set('X-API-Key', key)
        .expect(403);
    });
  });

  // ── profile:write / merchant:manage ──────────────────────────────────────

  describe('profile:write / merchant:manage scope', () => {
    it('PATCH /merchants/me → 403 with any API key (requires merchant:manage, intentionally JWT-only)', async () => {
      const jwt = await registerAndLogin(app, `profw-any-${Date.now()}`);
      // Even a key with every assignable scope cannot reach merchant:manage endpoints
      const key = await issueApiKey(app, jwt, [
        'payments:read', 'payments:write', 'settlements:read',
        'webhooks:manage', 'analytics:read', 'notifications:read',
        'profile:read', 'profile:write', 'groups:manage',
      ]);
      await request(app.getHttpServer())
        .patch(`${API}/merchants/me`)
        .set('X-API-Key', key)
        .send({ businessName: 'New Name' })
        .expect(403);
    });

    it('POST /merchants/api-keys → 403 with any API key (requires merchant:manage, intentionally JWT-only)', async () => {
      const jwt = await registerAndLogin(app, `apikey-any-${Date.now()}`);
      const key = await issueApiKey(app, jwt, [
        'payments:read', 'payments:write', 'settlements:read',
        'webhooks:manage', 'profile:read', 'profile:write',
      ]);
      await request(app.getHttpServer())
        .post(`${API}/merchants/api-keys`)
        .set('X-API-Key', key)
        .send({ scopes: ['payments:read'] })
        .expect(403);
    });

    it('PATCH /merchants/me → 200 with a valid JWT (not an API key)', async () => {
      const jwt = await registerAndLogin(app, `profw-jwt-${Date.now()}`);
      await request(app.getHttpServer())
        .patch(`${API}/merchants/me`)
        .set('Authorization', `Bearer ${jwt}`)
        .send({ businessName: 'Updated via JWT' })
        .expect(200);
    });
  });

  // ── notifications:read ─────────────────────────────────────────────────────

  describe('notifications:read scope', () => {
    it('GET /merchants/me/notification-prefs → 403 without notifications:read', async () => {
      const jwt = await registerAndLogin(app, `notif-miss-${Date.now()}`);
      const key = await issueApiKey(app, jwt, ['payments:read']);
      await request(app.getHttpServer())
        .get(`${API}/merchants/me/notification-prefs`)
        .set('X-API-Key', key)
        .expect(403);
    });
  });

  // ── read-only key cannot perform write operations ─────────────────────────

  describe('read-only key (regression)', () => {
    it('key with only payments:read and settlements:read cannot write payments or manage webhooks', async () => {
      const jwt = await registerAndLogin(app, `readonly-${Date.now()}`);
      const key = await issueApiKey(app, jwt, ['payments:read', 'settlements:read']);

      // reads are allowed
      await request(app.getHttpServer())
        .get(`${API}/payments`)
        .set('X-API-Key', key)
        .expect(200);
      await request(app.getHttpServer())
        .get(`${API}/settlements`)
        .set('X-API-Key', key)
        .expect(200);

      // writes are blocked
      await request(app.getHttpServer())
        .post(`${API}/payments`)
        .set('X-API-Key', key)
        .send({ amountUsd: 10.0 })
        .expect(403);
      await request(app.getHttpServer())
        .post(`${API}/webhooks`)
        .set('X-API-Key', key)
        .send({ url: 'https://example.com/webhooks', events: ['payment.confirmed'] })
        .expect(403);
    });
  });

  // ── invalid / missing API key ─────────────────────────────────────────────

  describe('invalid key handling', () => {
    it('completely invalid API key → 401', async () => {
      await request(app.getHttpServer())
        .get(`${API}/payments`)
        .set('X-API-Key', 'cpk_invalid_garbage_key_value')
        .expect(401);
    });

    it('no credentials → 401', async () => {
      await request(app.getHttpServer())
        .get(`${API}/payments`)
        .expect(401);
    });
  });
});
