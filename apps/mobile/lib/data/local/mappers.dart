/// Maps Drift row classes to pure domain entities.
library;

import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/domain/entities/activity.dart';
import 'package:arena_ops/domain/entities/booking.dart';
import 'package:arena_ops/domain/entities/controller.dart';
import 'package:arena_ops/domain/entities/customer.dart';
import 'package:arena_ops/domain/entities/game.dart';
import 'package:arena_ops/domain/entities/payment.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/domain/pricing/pricing_rule.dart';
import 'package:arena_ops/domain/value/enums.dart';

Customer customerFromRow(CustomerRow r) => Customer(
      id: r.id,
      name: r.name,
      phone: r.phone,
      notes: r.notes,
      lastVisitAt: r.lastVisitAt,
      isGuest: r.isGuest,
      birthYear: r.birthYear,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );

Activity activityFromRow(ActivityRow r) => Activity(
      id: r.id,
      code: r.code,
      name: r.name,
      usesControllers: r.usesControllers,
      usesGames: r.usesGames,
      durationModel: DurationModel.fromCode(r.durationModel),
      sortOrder: r.sortOrder,
      active: r.active,
      overtimeGraceMinutes: r.overtimeGraceMinutes,
    );

Resource resourceFromRow(ResourceRow r, List<String> activityCodes) => Resource(
      id: r.id,
      name: r.name,
      kind: ResourceKind.fromCode(r.kind),
      status: ResourceStatus.fromCode(r.status),
      sortOrder: r.sortOrder,
      activityCodes: activityCodes,
      currentMode: r.currentMode,
    );

Controller controllerFromRow(ControllerRow r) => Controller(
      id: r.id,
      label: r.label,
      homeResourceId: r.homeResourceId,
      currentResourceId: r.currentResourceId,
      status: ControllerStatus.fromCode(r.status),
      notes: r.notes,
      loanReturnTo: r.loanReturnTo,
      loanSessionRef: r.loanSessionRef,
      updatedAt: r.updatedAt,
    );

Game gameFromRow(GameRow r, {String? categoryName}) => Game(
      id: r.id,
      name: r.name,
      aliases: r.aliases,
      categoryId: r.categoryId,
      categoryName: categoryName,
      platforms: r.platforms,
      playModes: PlayerMode.fromCodes(r.playModes),
      maxLocalPlayers: r.maxLocalPlayers,
      active: r.active,
      lastPlayedAt: r.lastPlayedAt,
    );

GameResource gameResourceFromRow(GameResourceRow r) => GameResource(
      gameId: r.gameId,
      resourceId: r.resourceId,
      status: GameAvailability.fromCode(r.status),
      notes: r.notes,
      updatedAt: r.updatedAt,
    );

GameCategory categoryFromRow(GameCategoryRow r) =>
    GameCategory(id: r.id, name: r.name, sortOrder: r.sortOrder);

GameControl controlFromRow(GameControlRow r) => GameControl(
      id: r.id,
      gameId: r.gameId,
      section: r.section,
      action: r.action,
      buttons: r.buttons,
      explanation: r.explanation,
      notes: r.notes,
      imageUrl: r.imageUrl,
      sortOrder: r.sortOrder,
    );

Session sessionFromRow(SessionRow r) => Session(
      id: r.id,
      bookingId: r.bookingId,
      customerId: r.customerId,
      status: SessionStatus.fromCode(r.status),
      paymentStatus: PaymentStatus.fromCode(r.paymentStatus),
      startedAt: r.startedAt,
      scheduledEndAt: r.scheduledEndAt,
      actualEndedAt: r.actualEndedAt,
      pricingSnapshot: r.pricingSnapshot,
      billedAmountPaise: r.billedAmountPaise,
      voidReason: r.voidReason,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );

SessionSegment segmentFromRow(SessionSegmentRow r) => SessionSegment(
      id: r.id,
      sessionId: r.sessionId,
      index: r.index,
      resourceId: r.resourceId,
      activityCode: r.activityCode,
      gameId: r.gameId,
      controllerCount: r.controllerCount,
      startedAt: r.startedAt,
      endedAt: r.endedAt,
      createdAt: r.createdAt,
    );

Booking bookingFromRow(BookingRow r) => Booking(
      id: r.id,
      customerId: r.customerId,
      activityCode: r.activityCode,
      gameId: r.gameId,
      resourceId: r.resourceId,
      scheduledStart: r.scheduledStart,
      scheduledEnd: r.scheduledEnd,
      playersRequired: r.playersRequired,
      controllerRequirement: r.controllerRequirement,
      status: BookingStatus.fromCode(r.status),
      partyName: r.partyName,
      phone: r.phone,
      notes: r.notes,
      reminderStatus: ReminderStatus.fromCode(r.reminderStatus),
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );

Payment paymentFromRow(PaymentRow r) => Payment(
      id: r.id,
      sessionId: r.sessionId,
      amountPaise: r.amountPaise,
      method: PaymentMethod.fromCode(r.method),
      isRefund: r.isRefund,
      note: r.note,
      reason: r.reason,
      createdAt: r.createdAt,
    );

SessionExtension extensionFromRow(SessionExtensionRow r) => SessionExtension(
      id: r.id,
      sessionId: r.sessionId,
      addedMinutes: r.addedMinutes,
      oldEndAt: r.oldEndAt,
      newEndAt: r.newEndAt,
      addedAmountPaise: r.addedAmountPaise,
      reason: r.reason,
      createdAt: r.createdAt,
    );

SessionCharge chargeFromRow(SessionChargeRow r) => SessionCharge(
      id: r.id,
      sessionId: r.sessionId,
      segmentId: r.segmentId,
      segmentIndex: r.segmentIndex,
      bandCode: r.bandCode,
      activityCode: r.activityCode,
      resourceId: r.resourceId,
      controllerCount: r.controllerCount,
      segmentStart: r.segmentStart,
      segmentEnd: r.segmentEnd,
      playedMinutes: r.playedMinutes,
      billedMinutes: r.billedMinutes,
      unitMinutes: r.unitMinutes,
      unitPricePaise: r.unitPricePaise,
      amountPaise: r.amountPaise,
    );

PricingRule pricingRuleFromRow(PricingRuleRow r) => PricingRule(
      id: r.id,
      name: r.name,
      priority: r.priority,
      days: r.days,
      startMin: r.startMin,
      endMin: r.endMin,
      holidayMode: RuleHolidayMode.fromCode(r.holidayMode),
      validFrom: r.validFrom == null ? null : IstDate.parse(r.validFrom!),
      validUntil: r.validUntil == null ? null : IstDate.parse(r.validUntil!),
      activityCodes: r.activityCodes,
      adjustKind: RuleAdjustKind.fromCode(r.adjustKind),
      adjustValue: r.adjustValue,
    );
