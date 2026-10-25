/// The controller-choice model: one source of truth for "how many and which
/// pads", the inventory as one station sees it, and the friendly checks.
library;

import 'package:arena_ops/domain/entities/controller.dart';
import 'package:arena_ops/domain/services/pad_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sel = PadSelection();
  final t = DateTime.utc(2026, 10, 2);

  Controller pad(
    String id,
    String at, {
    ControllerStatus status = ControllerStatus.usable,
  }) => Controller(
    id: id,
    label: id.toUpperCase(),
    homeResourceId: at,
    currentResourceId: at,
    status: status,
    updatedAt: t,
  );

  // The seeded shape: 2 per PS5 station, 8 in all.
  List<Controller> seed() => [
    for (final s in const ['hex', 'void', 'ghost', 'rift'])
      for (final n in const [1, 2]) pad('${s}_$n', s),
  ];
  const names = {
    'hex': 'HEX',
    'void': 'VOID',
    'ghost': 'GHOST',
    'rift': 'RIFT',
  };

  PadBoard boardAt(
    String station, {
    List<Controller>? pads,
    List<OpenPadAllocation> open = const [],
    Set<String> busy = const {},
    Set<String> keep = const {},
  }) => sel.board(
    resourceId: station,
    resourceName: names[station]!,
    controllers: pads ?? seed(),
    open: open,
    resourceNames: names,
    busyStations: busy,
    keepIds: keep,
  );

  group('inventory', () {
    test('counts come from the rows: total, usable, free here / elsewhere', () {
      final pads = seed()
        ..[0] = pad('hex_1', 'hex', status: ControllerStatus.faulty)
        ..add(pad('old', 'void', status: ControllerStatus.retired));
      final b = boardAt(
        'void',
        pads: pads,
        open: const [
          OpenPadAllocation(controllerId: 'ghost_1', resourceId: 'ghost'),
        ],
      );
      expect(b.inventory.total, 8, reason: 'retired pad not counted');
      expect(b.inventory.usable, 7, reason: 'faulty HEX-1 not usable');
      expect(b.inventory.freeHere, 2);
      expect(b.inventory.freeElsewhere, 4, reason: 'HEX-2, GHOST-2, RIFT-1/2');
      expect(b.inventory.globallyFree, 6);
      expect(b.here.map((o) => o.label), ['OLD', 'VOID_1', 'VOID_2']);
      expect(b.here.first.note, 'retired');
    });

    test(
      'pads at a station running a count-only session are not borrowable',
      () {
        final occupants = const [
          StationOccupant(
            id: 'seg-1',
            resourceId: 'hex',
            usesControllers: true,
          ),
          StationOccupant(
            id: 'seg-2',
            resourceId: 'ghost',
            usesControllers: true,
          ),
          StationOccupant(
            id: 'seg-3',
            resourceId: 'rift',
            usesControllers: false,
          ),
        ];
        const open = [
          OpenPadAllocation(
            controllerId: 'ghost_1',
            resourceId: 'ghost',
            segmentId: 'seg-2',
          ),
        ];
        final busy = PadSelection.untrackedBusyStations(
          occupants: occupants,
          open: open,
        );
        expect(busy, {'hex'}, reason: 'GHOST tracked; RIFT is VR (no pads)');

        final b = boardAt('void', open: open, busy: busy);
        final hex1 = b.option('hex_1')!;
        expect(hex1.availability, PadAvailability.stationBusy);
        expect(hex1.note, 'HEX in use, not tracked');
        expect(
          b.option('ghost_2')!.availability,
          PadAvailability.free,
          reason: 'spare pad at a tracked station can be borrowed',
        );
        expect(b.option('rift_1')!.availability, PadAvailability.free);
      },
    );
  });

  group('choice: count and pads stay one value', () {
    test('requesting 1–4 auto-picks that many free pads AT the station', () {
      final b = boardAt('hex');
      final one = ControllerChoice.none.reconcile(b).request(1, b);
      expect(one.padIds, ['hex_1']);
      expect(one.count, 1);
      final two = one.request(2, b);
      expect(two.padIds, ['hex_1', 'hex_2']);
      expect(two.count, 2);
      expect(two.shortfall, 0);
    });

    test('asking for more than the station has is a shortfall, never a '
        'silent borrow or shrink', () {
      final b = boardAt('void');
      final four = ControllerChoice.none.reconcile(b).request(4, b);
      expect(four.requested, 4);
      expect(four.padIds, ['void_1', 'void_2']);
      expect(four.borrowIds, isEmpty, reason: 'borrowing is explicit');
      expect(four.shortfall, 2);
      final f = sel.check(four, b)!;
      expect(f.code, 'controllers_unavailable');
      expect(f.message, '4 requested, 2 selected — only 2 free at VOID.');
      expect(f.fix, contains('Borrow 2 from another station (6 free)'));
      expect(f.fix, isNot(contains('choose 0')));
    });

    test('raising then lowering keeps exact pads; lowering drops the last', () {
      final b = boardAt('void');
      var c = ControllerChoice.none.reconcile(b).request(2, b);
      // Borrow two explicitly to reach 4.
      c = c.toggle('hex_1', b).toggle('ghost_1', b);
      expect(c.padIds, ['void_1', 'void_2', 'hex_1', 'ghost_1']);
      expect(c.count, 4);
      expect(c.borrowIds, {'hex_1', 'ghost_1'});
      final three = c.request(3, b);
      expect(three.padIds, ['void_1', 'void_2', 'hex_1']);
      expect(three.borrowIds, {'hex_1'});
      expect(sel.check(three, b), isNull);
    });

    test('tapping a pad updates the count immediately', () {
      final b = boardAt('hex');
      var c = ControllerChoice.none.reconcile(b).request(2, b);
      c = c.toggle('hex_2', b);
      expect(c.count, 1);
      expect(c.requested, 1);
      c = c.toggle('hex_2', b);
      expect(c.count, 2);
    });

    test('borrowing toward a request never shrinks it (Start stays blocked '
        'until the request is met)', () {
      final b = boardAt('void');
      var c = ControllerChoice.none.reconcile(b).request(4, b);
      c = c.toggle('hex_1', b);
      expect(c.requested, 4, reason: 'still asking for 4');
      expect(c.count, 3);
      expect(c.shortfall, 1);
      expect(sel.check(c, b), isNotNull);
      c = c.toggle('hex_2', b);
      expect(c.shortfall, 0);
      expect(sel.check(c, b), isNull);
      // Un-picking lowers the count immediately.
      c = c.toggle('void_2', b);
      expect(c.requested, 3);
      expect(sel.check(c, b), isNull);
    });

    test('a busy or faulty pad cannot be toggled on', () {
      final b = boardAt(
        'hex',
        pads: seed()
          ..[1] = pad('hex_2', 'hex', status: ControllerStatus.faulty),
        open: const [
          OpenPadAllocation(controllerId: 'hex_1', resourceId: 'hex'),
        ],
      );
      final c = ControllerChoice.none.reconcile(b);
      expect(c.toggle('hex_1', b), c);
      expect(c.toggle('hex_2', b), c);
      expect(c.request(1, b).shortfall, 1);
    });

    test('a game limit trims the pick deterministically', () {
      final b = boardAt('hex');
      final two = ControllerChoice.none.reconcile(b).request(2, b);
      final capped = two.reconcile(b, max: 1);
      expect(capped.padIds, ['hex_1']);
      expect(
        sel.check(two, b, maxLocalPlayers: 1, gameName: 'GOW')!.message,
        'GOW supports 1 local player.',
      );
    });

    test('a pad taken elsewhere meanwhile is replaced on re-fit', () {
      final b0 = boardAt('hex');
      final c = ControllerChoice.none.reconcile(b0).request(1, b0);
      expect(c.padIds, ['hex_1']);
      final b1 = boardAt(
        'hex',
        open: const [
          OpenPadAllocation(controllerId: 'hex_1', resourceId: 'hex'),
        ],
      );
      expect(c.reconcile(b1).padIds, ['hex_2']);
    });

    test('a pad elsewhere must be explicitly borrowed', () {
      final b = boardAt('hex');
      const sneaky = ControllerChoice.tracked(
        requested: 1,
        padIds: ['void_1'],
      ); // no borrow flag
      expect(sel.check(sneaky, b)!.code, 'controller_elsewhere');
      final ok = ControllerChoice.none.reconcile(b).toggle('void_1', b);
      expect(ok.borrowIds, {'void_1'});
      expect(sel.check(ok, b), isNull);
    });

    test('the session’s own pads count as free to it', () {
      final open = const [
        OpenPadAllocation(
          controllerId: 'hex_1',
          resourceId: 'hex',
          segmentId: 's',
        ),
      ];
      final b = boardAt('hex', open: open, keep: {'hex_1'});
      const c = ControllerChoice.tracked(requested: 1, padIds: ['hex_1']);
      expect(sel.check(c, b), isNull);
      expect(
        sel.check(c, boardAt('hex', open: open))!.code,
        'controller_taken',
      );
    });
  });

  group('count-only (legacy)', () {
    test('a bare count is checked against free pads at the station', () {
      final b = boardAt('void');
      expect(sel.check(const ControllerChoice.count(2), b), isNull);
      final f = sel.check(const ControllerChoice.count(4), b)!;
      expect(f.message, '4 controllers needed, only 2 free at VOID.');
      // An existing count-only session that keeps its station is not re-checked.
      expect(
        sel.check(const ControllerChoice.count(4), b, requireSupply: false),
        isNull,
      );
    });

    test('with no inventory at all, the count is all there is', () {
      final b = boardAt('void', pads: const []);
      expect(b.tracked, isFalse);
      expect(sel.check(const ControllerChoice.count(4), b), isNull);
      expect(const ControllerChoice.count(3).reconcile(b).count, 3);
    });

    test('ports and missing counts', () {
      final b = boardAt('hex');
      expect(sel.check(ControllerChoice.none, b)!.code, 'controllers_required');
      expect(
        sel.check(const ControllerChoice.count(5), b)!.code,
        'controllers_exceeded',
      );
    });
  });
}
