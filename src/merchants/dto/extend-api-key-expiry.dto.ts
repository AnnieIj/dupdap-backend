import { ApiProperty } from '@nestjs/swagger';
import { IsDate, MaxDate } from 'class-validator';
import { Type } from 'class-transformer';

const oneYearFromNow = () => {
  const d = new Date();
  d.setFullYear(d.getFullYear() + 1);
  return d;
};

export class ExtendApiKeyExpiryDto {
  @ApiProperty({
    type: String,
    format: 'date-time',
    description: 'New expiry timestamp for the API key (ISO 8601). Maximum 1 year from now.',
    example: '2027-10-18T00:00:00.000Z',
  })
  @Type(() => Date)
  @IsDate()
  @MaxDate(oneYearFromNow, {
    message: 'newExpiresAt must not be more than 1 year from now',
  })
  newExpiresAt: Date;
}
