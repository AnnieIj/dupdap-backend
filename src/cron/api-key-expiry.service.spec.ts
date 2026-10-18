import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Between, IsNull } from 'typeorm';
import { ApiKeyExpiryService } from './api-key-expiry.service';
import { Merchant } from '../merchants/entities/merchant.entity';
import { EmailService } from '../email/email.service';
import { CronJobService } from './cron-job.service';

const mockMerchantsRepo = {
  find: jest.fn(),
  update: jest.fn(),
};

const mockEmailService = {
  queue: jest.fn(),
};

/** Wraps the fn immediately — no job log overhead for tests. */
const mockCronJobService = {
  run: jest.fn().mockImplementation((_name: string, fn: () => Promise<unknown>) => fn()),
};

function makeMerchant(overrides: Partial<Merchant> = {}): Partial<Merchant> {
  return {
    id: 'merchant-1',
    email: 'merchant@example.com',
    businessName: 'Acme Corp',
    apiKey: 'cpk_abc123...',
    apiKeyExpiresAt: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000), // 10 days from now
    apiKeyExpirySentAt: null,
    ...overrides,
  };
}

describe('ApiKeyExpiryService', () => {
  let service: ApiKeyExpiryService;

  beforeEach(async () => {
    jest.resetAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ApiKeyExpiryService,
        { provide: getRepositoryToken(Merchant), useValue: mockMerchantsRepo },
        { provide: EmailService, useValue: mockEmailService },
        { provide: CronJobService, useValue: mockCronJobService },
      ],
    }).compile();

    service = module.get<ApiKeyExpiryService>(ApiKeyExpiryService);
  });

  it('queries merchants expiring within 14 days that have no reminder sent', async () => {
    mockMerchantsRepo.find.mockResolvedValue([]);

    await service.sendExpiryReminders();

    expect(mockMerchantsRepo.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          apiKeyExpirySentAt: IsNull(),
        }),
      }),
    );
  });

  it('sends a reminder email and marks apiKeyExpirySentAt when a merchant is found', async () => {
    const merchant = makeMerchant();
    mockMerchantsRepo.find.mockResolvedValue([merchant]);
    mockEmailService.queue.mockResolvedValue({ id: 'email-log-1' });
    mockMerchantsRepo.update.mockResolvedValue(undefined);

    await service.sendExpiryReminders();

    expect(mockEmailService.queue).toHaveBeenCalledTimes(1);
    expect(mockEmailService.queue).toHaveBeenCalledWith(
      merchant.email,
      'api-key-expiry-reminder',
      expect.objectContaining({
        merchantName: merchant.businessName,
        daysRemaining: expect.any(Number),
      }),
      merchant.id,
    );

    expect(mockMerchantsRepo.update).toHaveBeenCalledWith(
      merchant.id,
      expect.objectContaining({ apiKeyExpirySentAt: expect.any(Date) }),
    );
  });

  it('does not send email when there are no merchants in the window', async () => {
    mockMerchantsRepo.find.mockResolvedValue([]);

    await service.sendExpiryReminders();

    expect(mockEmailService.queue).not.toHaveBeenCalled();
    expect(mockMerchantsRepo.update).not.toHaveBeenCalled();
  });

  it('continues processing remaining merchants when one email fails', async () => {
    const m1 = makeMerchant({ id: 'merchant-1', email: 'a@example.com' });
    const m2 = makeMerchant({ id: 'merchant-2', email: 'b@example.com' });
    mockMerchantsRepo.find.mockResolvedValue([m1, m2]);

    // First email throws, second succeeds
    mockEmailService.queue
      .mockRejectedValueOnce(new Error('SMTP timeout'))
      .mockResolvedValueOnce({ id: 'email-log-2' });
    mockMerchantsRepo.update.mockResolvedValue(undefined);

    // Should not throw — errors are swallowed and logged
    await expect(service.sendExpiryReminders()).resolves.not.toThrow();

    // Second merchant should still be processed
    expect(mockEmailService.queue).toHaveBeenCalledTimes(2);
    // update should only have been called once (for the successful send)
    expect(mockMerchantsRepo.update).toHaveBeenCalledTimes(1);
    expect(mockMerchantsRepo.update).toHaveBeenCalledWith(m2.id, expect.anything());
  });

  it('exposes runManually() which delegates to sendExpiryReminders()', async () => {
    mockMerchantsRepo.find.mockResolvedValue([]);

    const spy = jest.spyOn(service, 'sendExpiryReminders');
    await service.runManually();

    expect(spy).toHaveBeenCalledTimes(1);
  });
});
