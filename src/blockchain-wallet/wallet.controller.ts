import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import {
  ApiOperation,
  ApiTags,
  ApiBearerAuth,
  ApiOkResponse,
  ApiUnauthorizedResponse,
  ApiForbiddenResponse,
  ApiSecurity,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt.guard';
import { Scopes } from '../auth/decorators/scopes.decorator';
import { BlockchainWalletService } from './blockchain-wallet.service';
import { WalletResponseDto } from './dto/wallet-response.dto';

@ApiTags('Wallet')
@ApiBearerAuth('bearer')
@ApiSecurity('api-key')
@UseGuards(JwtAuthGuard)
@Controller('wallet')
export class WalletController {
  constructor(private readonly walletService: BlockchainWalletService) {}

  @Get()
  @Scopes('profile:read')
  @ApiOperation({ summary: 'Get current user wallet info' })
  @ApiOkResponse({ type: WalletResponseDto, description: 'Wallet details' })
  @ApiUnauthorizedResponse({ description: 'Missing or invalid JWT / API key' })
  @ApiForbiddenResponse({ description: 'API key missing profile:read scope' })
  async getWallet(@Req() req: any): Promise<WalletResponseDto> {
    const wallet = await this.walletService.getWallet(req.user.merchantId);
    return WalletResponseDto.from(wallet);
  }

  @Get('balance')
  @Scopes('profile:read')
  @ApiOperation({ summary: 'Sync and return fresh wallet balance' })
  @ApiOkResponse({ type: WalletResponseDto, description: 'Updated wallet balance' })
  @ApiUnauthorizedResponse({ description: 'Missing or invalid JWT / API key' })
  @ApiForbiddenResponse({ description: 'API key missing profile:read scope' })
  async getBalance(@Req() req: any): Promise<WalletResponseDto> {
    const wallet = await this.walletService.syncBalance(req.user.merchantId);
    return WalletResponseDto.from(wallet);
  }
}
