import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class TopMerchantItemDto {
  @ApiProperty({ description: 'Merchant UUID', example: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' })
  merchantId: string;

  @ApiProperty({ description: 'Merchant business name', example: 'Acme Corp' })
  name: string;

  @ApiProperty({
    description: 'Total settled payment volume in USD during the period',
    example: '25000.500000',
  })
  totalVolume: string;

  @ApiProperty({ description: 'Number of settled payments during the period', example: 142 })
  paymentCount: number;

  @ApiProperty({
    description: 'Average order value in USD (totalVolume / paymentCount)',
    example: '176.060000',
  })
  avgOrderValue: string;

  @ApiProperty({
    description: 'Percentage of non-failed/non-expired payments that reached settled status (0–100)',
    example: 94.37,
  })
  successRate: number;

  @ApiPropertyOptional({
    description: 'Country code of the merchant',
    example: 'US',
  })
  country?: string | null;
}

export class TopMerchantsResponseDto {
  @ApiProperty({ type: [TopMerchantItemDto] })
  data: TopMerchantItemDto[];

  @ApiProperty({
    description: 'Time period used for the query',
    enum: ['7d', '30d', '90d'],
    example: '30d',
  })
  period: string;

  @ApiProperty({ description: 'Start of the analytics window (ISO-8601)', example: '2026-09-18T00:00:00.000Z' })
  periodStart: string;

  @ApiProperty({ description: 'End of the analytics window (ISO-8601)', example: '2026-10-18T00:00:00.000Z' })
  periodEnd: string;

  @ApiPropertyOptional({
    description:
      'Cursor to pass as `cursor` query param to fetch the next page. Null when there are no more results.',
    example: 'eyJpZCI6ImFiYzEyMyIsInZvbHVtZSI6IjEwMDAwLjAwMDAwMCJ9',
    nullable: true,
  })
  nextCursor: string | null;

  @ApiProperty({ description: 'Whether this result came from cache', example: false })
  cacheHit: boolean;
}
