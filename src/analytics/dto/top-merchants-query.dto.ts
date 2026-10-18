import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsIn, IsInt, Min, Max, IsString } from 'class-validator';
import { Transform, Type } from 'class-transformer';

export class TopMerchantsQueryDto {
  @ApiPropertyOptional({
    description: 'Maximum number of merchants to return per page',
    example: 20,
    default: 10,
    minimum: 1,
    maximum: 100,
  })
  @IsOptional()
  @Transform(({ value }) => parseInt(value, 10))
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 10;

  @ApiPropertyOptional({
    description: 'Time period for analytics aggregation',
    enum: ['7d', '30d', '90d'],
    example: '30d',
    default: '30d',
  })
  @IsOptional()
  @IsIn(['7d', '30d', '90d'])
  period?: string = '30d';

  @ApiPropertyOptional({
    description:
      'Opaque cursor for keyset pagination. Pass the value of `nextCursor` from the previous page to get the next set of results.',
    example: 'eyJpZCI6ImFiYzEyMyIsInZvbHVtZSI6IjEwMDAwLjAwMDAwMCJ9',
  })
  @IsOptional()
  @IsString()
  cursor?: string;
}
