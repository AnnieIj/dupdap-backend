import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import {
  ApiOperation,
  ApiTags,
  ApiBearerAuth,
  ApiOkResponse,
  ApiCreatedResponse,
  ApiUnauthorizedResponse,
  ApiForbiddenResponse,
  ApiNotFoundResponse,
  ApiSecurity,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt.guard';
import { Scopes } from '../auth/decorators/scopes.decorator';
import { GroupsService } from './groups.service';
import {
  CreateGroupDto,
  GroupResponseDto,
  SearchGroupsDto,
  SetTokenGateDto,
  UpdateGroupDto,
} from './dto/groups.dto';

@ApiTags('Groups')
@ApiBearerAuth('bearer')
@ApiSecurity('api-key')
@UseGuards(JwtAuthGuard)
@Controller('groups')
export class GroupsController {
  constructor(private readonly groupsService: GroupsService) {}

  @Post()
  @Scopes('groups:manage')
  @ApiOperation({ summary: 'Create a new group' })
  @ApiCreatedResponse({ type: GroupResponseDto, description: 'Group created' })
  @ApiUnauthorizedResponse({ description: 'Missing or invalid JWT / API key' })
  @ApiForbiddenResponse({ description: 'API key missing groups:manage scope' })
  create(@Body() dto: CreateGroupDto, @Req() req: any): Promise<GroupResponseDto> {
    return this.groupsService.createGroup(dto, req.user.merchantId);
  }

  @Get('search')
  @Scopes('groups:manage')
  @ApiOperation({ summary: 'Search groups by name with pagination' })
  @ApiOkResponse({ description: 'Matching groups' })
  @ApiUnauthorizedResponse({ description: 'Missing or invalid JWT / API key' })
  @ApiForbiddenResponse({ description: 'API key missing groups:manage scope' })
  search(@Query() dto: SearchGroupsDto, @Req() req: any) {
    return this.groupsService.searchGroups(dto, req.user.merchantId);
  }

  @Get(':id')
  @Scopes('groups:manage')
  @ApiOperation({ summary: 'Get group by ID' })
  @ApiOkResponse({ type: GroupResponseDto, description: 'Group details' })
  @ApiUnauthorizedResponse({ description: 'Missing or invalid JWT / API key' })
  @ApiForbiddenResponse({ description: 'API key missing groups:manage scope' })
  @ApiNotFoundResponse({ description: 'Group not found' })
  findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: any,
  ): Promise<GroupResponseDto> {
    return this.groupsService.getGroup(id, req.user.merchantId);
  }

  @Patch(':id')
  @Scopes('groups:manage')
  @ApiOperation({ summary: 'Update group metadata' })
  @ApiOkResponse({ type: GroupResponseDto, description: 'Updated group' })
  @ApiUnauthorizedResponse({ description: 'Missing or invalid JWT / API key' })
  @ApiForbiddenResponse({ description: 'API key missing groups:manage scope' })
  @ApiNotFoundResponse({ description: 'Group not found' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateGroupDto,
    @Req() req: any,
  ): Promise<GroupResponseDto> {
    return this.groupsService.updateGroup(id, dto, req.user.merchantId);
  }

  @Delete(':id')
  @Scopes('groups:manage')
  @ApiOperation({ summary: 'Soft-delete a group' })
  @ApiOkResponse({ description: 'Group deleted' })
  @ApiUnauthorizedResponse({ description: 'Missing or invalid JWT / API key' })
  @ApiForbiddenResponse({ description: 'API key missing groups:manage scope' })
  @ApiNotFoundResponse({ description: 'Group not found' })
  remove(@Param('id', ParseUUIDPipe) id: string, @Req() req: any): Promise<void> {
    return this.groupsService.deleteGroup(id, req.user.merchantId);
  }

  @Post(':id/invite-code')
  @Scopes('groups:manage')
  @ApiOperation({ summary: 'Regenerate invite code' })
  @ApiOkResponse({ description: 'New invite code' })
  @ApiUnauthorizedResponse({ description: 'Missing or invalid JWT / API key' })
  @ApiForbiddenResponse({ description: 'API key missing groups:manage scope' })
  @ApiNotFoundResponse({ description: 'Group not found' })
  regenerateInviteCode(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: any,
  ): Promise<{ inviteCode: string }> {
    return this.groupsService.generateInviteCode(id, req.user.merchantId);
  }

  @Post('join/:inviteCode')
  @Scopes('groups:manage')
  @ApiOperation({ summary: 'Join group by invite code' })
  @ApiOkResponse({ type: GroupResponseDto, description: 'Joined group' })
  @ApiUnauthorizedResponse({ description: 'Missing or invalid JWT / API key' })
  @ApiForbiddenResponse({ description: 'API key missing groups:manage scope' })
  @ApiNotFoundResponse({ description: 'Invalid invite code' })
  join(
    @Param('inviteCode') inviteCode: string,
    @Req() req: any,
  ): Promise<GroupResponseDto> {
    return this.groupsService.joinByInviteCode(inviteCode, req.user.merchantId);
  }

  @Post(':id/gate')
  @Scopes('groups:manage')
  @ApiOperation({ summary: 'Set token gate on group' })
  @ApiOkResponse({ type: GroupResponseDto, description: 'Group with token gate set' })
  @ApiUnauthorizedResponse({ description: 'Missing or invalid JWT / API key' })
  @ApiForbiddenResponse({ description: 'API key missing groups:manage scope' })
  @ApiNotFoundResponse({ description: 'Group not found' })
  setGate(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetTokenGateDto,
    @Req() req: any,
  ): Promise<GroupResponseDto> {
    return this.groupsService.setTokenGate(id, dto, req.user.merchantId);
  }

  @Delete(':id/gate')
  @Scopes('groups:manage')
  @ApiOperation({ summary: 'Remove token gate from group' })
  @ApiOkResponse({ type: GroupResponseDto, description: 'Group with token gate removed' })
  @ApiUnauthorizedResponse({ description: 'Missing or invalid JWT / API key' })
  @ApiForbiddenResponse({ description: 'API key missing groups:manage scope' })
  @ApiNotFoundResponse({ description: 'Group not found' })
  removeGate(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: any,
  ): Promise<GroupResponseDto> {
    return this.groupsService.removeTokenGate(id, req.user.merchantId);
  }
}
