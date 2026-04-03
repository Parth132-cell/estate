import 'package:estatex_app/payments/escrow_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EscrowState', () {
    test('supports expected states', () {
      expect(EscrowState.isValid(EscrowState.initiated), isTrue);
      expect(EscrowState.isValid(EscrowState.paymentPending), isTrue);
      expect(EscrowState.isValid(EscrowState.completed), isTrue);
      expect(EscrowState.isValid(EscrowState.cancelled), isTrue);
      expect(EscrowState.isValid('unknown'), isFalse);
    });

    test('enforces controlled transitions', () {
      expect(
        EscrowState.canTransition(
          from: EscrowState.initiated,
          to: EscrowState.paymentPending,
        ),
        isTrue,
      );
      expect(
        EscrowState.canTransition(
          from: EscrowState.initiated,
          to: EscrowState.completed,
        ),
        isFalse,
      );
      expect(
        EscrowState.canTransition(
          from: EscrowState.completed,
          to: EscrowState.cancelled,
        ),
        isFalse,
      );
    });
  });

  group('EscrowAuditLog', () {
    test('parses nullable payload safely', () {
      final log = EscrowAuditLog.fromMap(
        id: 'log_1',
        escrowId: 'esc_1',
        map: null,
      );

      expect(log.id, 'log_1');
      expect(log.escrowId, 'esc_1');
      expect(log.action, '');
      expect(log.metadata, isEmpty);
    });
  });
}
