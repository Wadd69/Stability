import 'package:flutter_test/flutter_test.dart';
import 'package:stability/core/finance/forecast_service.dart';

void main() {
  group('MonthForecast.totalIncome / totalExpense', () {
    test('exclut les virements internes des totaux', () {
      final now = DateTime(2026, 1, 1);
      final forecast = MonthForecast(
        monthKey: '2026-02',
        containers: const [],
        items: [
          // Salaire réel : compte comme rentrée.
          ForecastItem(
            label: 'Salaire',
            containerId: 'compte-courant',
            signedAmount: 2000,
            date: now,
          ),
          // Loyer réel : compte comme dépense.
          ForecastItem(
            label: 'Loyer',
            containerId: 'compte-courant',
            signedAmount: -800,
            date: now,
          ),
          // Virement interne (épargne) : ne doit compter ni comme
          // rentrée ni comme dépense, dans aucun des deux sens.
          ForecastItem(
            label: 'Virement épargne',
            containerId: 'compte-courant',
            signedAmount: -300,
            date: now,
            isTransfer: true,
          ),
          ForecastItem(
            label: 'Virement épargne',
            containerId: 'livret',
            signedAmount: 300,
            date: now,
            isTransfer: true,
          ),
        ],
      );

      expect(forecast.totalIncome, 2000);
      expect(forecast.totalExpense, 800);
    });

    test('sans virement, additionne simplement les montants positifs/négatifs',
        () {
      final now = DateTime(2026, 1, 1);
      final forecast = MonthForecast(
        monthKey: '2026-02',
        containers: const [],
        items: [
          ForecastItem(
            label: 'Salaire',
            containerId: 'c1',
            signedAmount: 1500,
            date: now,
          ),
          ForecastItem(
            label: 'Freelance',
            containerId: 'c1',
            signedAmount: 500,
            date: now,
          ),
          ForecastItem(
            label: 'Courses',
            containerId: 'c1',
            signedAmount: -200,
            date: now,
          ),
        ],
      );

      expect(forecast.totalIncome, 2000);
      expect(forecast.totalExpense, 200);
    });
  });
}
