
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/api_client.dart';
import 'package:mobile_app/core/format.dart';
import 'package:mobile_app/core/theme.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('formatting', () {
    test('peso groups thousands and keeps the sign', () {
      expect(peso(1234567.5), '₱1,234,567.50');
      expect(peso(-1000), '-₱1,000.00');
      expect(peso('250'), '₱250.00');
      expect(peso(null), '₱0.00');
    });

    test('isoDate pads month and day', () {
      expect(isoDate(DateTime(2026, 3, 5)), '2026-03-05');
    });

    test('asDouble / asInt accept numbers and strings', () {
      expect(asDouble('3.5'), 3.5);
      expect(asInt(4.0), 4);
      expect(asDouble('abc'), isNull);
    });
  });

  group('models and status colors', () {
    test('Farm.fromJson handles missing optional fields', () {
      final farm = Farm.fromJson({
        'farm_id': 3,
        'farm_code': 'FARM-1',
        'farm_name': 'Riverside',
        'location': 'Cabadbaran',
        'status': 'Active',
        'area_hectares': 2,
      });
      expect(farm.id, 3);
      expect(farm.areaHectares, 2.0);
      expect(farm.city, isNull);
    });

    test('statusColor maps API statuses', () {
      expect(statusColor('SUITABLE'), statusGood);
      expect(statusColor('CAUTION'), statusWarn);
      expect(statusColor('NOT SUITABLE'), statusBad);
      expect(statusColor('GOOD'), statusGood);
      expect(statusColor('NOT GOOD'), statusBad);
    });

    test('ApiException exposes its message', () {
      const e = ApiException('Invalid username or password.', 401);
      expect(e.toString(), 'Invalid username or password.');
      expect(e.isUnauthorized, isTrue);
    });
  });

  group('app', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('shows the login screen when there is no saved session',
        (tester) async {
      await tester.pumpWidget(const ClimateCropApp());
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
    });

    testWidgets('login form validates empty fields without calling the server',
        (tester) async {
      await tester.pumpWidget(const ClimateCropApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log In'));
      await tester.pump();

      expect(find.text('Enter your username'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });
  });
}
