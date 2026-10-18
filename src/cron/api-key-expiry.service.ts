import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between, IsNull, Not, LessThan } from 'typeorm';
import { Merchant } from '../merchants/entities/merchant.entity';
import { EmailService } from '../email/email.service';
import { CronJobService } from './cron-job.service';

/** Number of days before expiry to send the reminder. */
const REMINDER_DAYS = 14;

@Injectable()
export class ApiKeyExpiryService {
  private readonly logger = new Logger(ApiKeyExpiryService.name);

  constructor(
    @InjectRepository(Merchant)
    private readonly merchantsRepo: Repository<Merchant>,
    private readonly emailService: EmailService,
    private readonly cronJobService: CronJobService,
  ) {}

  /**
   * Runs every day at 08:00 UTC.
   * Finds merchants whose API key expires within the next REMINDER_DAYS days,
   * where the reminder has not yet been sent, and sends them an email.
   */
  @Cron(CronExpression.EVERY_DAY_AT_8AM)
  async sendExpiryReminders(): Promise<void> {
    await this.cronJobService.run('api-key-expiry-reminders', async () => {
      const now = new Date();
      const windowEnd = new Date(now.getTime() + REMINDER_DAYS * 24 * 60 * 60 * 1000);

      // Keys that expire within the reminder window and haven't had a reminder sent yet
      const merchants = await this.merchantsRepo.find({
        where: {
          apiKeyExpiresAt: Between(now, windowEnd),
          apiKeyExpirySentAt: IsNull(),
        },
        select: ['id', 'email', 'businessName', 'apiKey', 'apiKeyExpiresAt'],
      });

      if (merchants.length === 0) {
        this.logger.log('api-key-expiry-reminders: no reminders to send');
        return;
      }

      let sent = 0;
      let failed = 0;

      for (const merchant of merchants) {
        try {
          const expiresAt = merchant.apiKeyExpiresAt!;
          const daysRemaining = Math.ceil(
            (expiresAt.getTime() - now.getTime()) / (24 * 60 * 60 * 1000),
          );

          await this.emailService.queue(
            merchant.email,
            'api-key-expiry-reminder',
            {
              subject: `Action required: your DupDub API key expires in ${daysRemaining} day${daysRemaining !== 1 ? 's' : ''}`,
              merchantName: merchant.businessName,
              businessName: merchant.businessName,
              // The stored apiKey field is a masked prefix like "cpk_abc123..."
              keyPrefix: merchant.apiKey ?? 'cpk_…',
              expiresAt: expiresAt.toUTCString(),
              daysRemaining,
              dashboardUrl: 'https://app.dupdub.xyz/settings/api-keys',
            },
            merchant.id,
          );

          // Mark the reminder as sent so we don't re-send on subsequent cron runs
          await this.merchantsRepo.update(merchant.id, {
            apiKeyExpirySentAt: new Date(),
          });

          sent++;
        } catch (error) {
          this.logger.error(
            `Failed to send expiry reminder to merchant ${merchant.id}: ${error instanceof Error ? error.message : String(error)}`,
          );
          failed++;
        }
      }

      this.logger.log(
        `api-key-expiry-reminders: sent=${sent}, failed=${failed}, total=${merchants.length}`,
      );
    });
  }

  /**
   * Exposed for testing: same logic but callable directly without waiting
   * for the cron schedule.
   */
  async runManually(): Promise<void> {
    return this.sendExpiryReminders();
  }
}
