import 'package:flutter/material.dart';

import '../../core/archives/archives_store.dart';
import '../../core/archives/archived_month.dart';
import '../../core/comparison/comparison_period.dart';

// ✅ HUB (NOUVEL ÉCRAN)
import 'comparison_hub_screen.dart';

class ComparisonSelectorScreen extends StatefulWidget {
  const ComparisonSelectorScreen({super.key});

  @override
  State<ComparisonSelectorScreen> createState() =>
      _ComparisonSelectorScreenState();
}

class _ComparisonSelectorScreenState
    extends State<ComparisonSelectorScreen> {
  final Set<int> _selectedYears = {};
  final Set<String> _selectedMonthIds = {};

  @override
  Widget build(BuildContext context) {
    final years = ArchivesStore.years;
    final months = ArchivesStore.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparer'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─────────────────────────────────
          // 📆 ANNÉES
          // ─────────────────────────────────
          const Text(
            'Comparer des années',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (years.isEmpty)
            const Text('Aucune année disponible'),
          ...years.map((year) {
            return CheckboxListTile(
              title: Text(year.toString()),
              value: _selectedYears.contains(year),
              onChanged: (checked) {
                setState(() {
                  checked == true
                      ? _selectedYears.add(year)
                      : _selectedYears.remove(year);
                });
              },
            );
          }),

          const SizedBox(height: 24),

          // ─────────────────────────────────
          // 📅 MOIS
          // ─────────────────────────────────
          const Text(
            'Comparer des mois',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (months.isEmpty)
            const Text('Aucun mois disponible'),
          ...months.map((m) {
            return CheckboxListTile(
              title: Text(m.label),
              subtitle: Text(m.year.toString()),
              value: _selectedMonthIds.contains(m.id),
              onChanged: (checked) {
                setState(() {
                  checked == true
                      ? _selectedMonthIds.add(m.id)
                      : _selectedMonthIds.remove(m.id);
                });
              },
            );
          }),

          const SizedBox(height: 32),

          // ─────────────────────────────────
          // ▶ ACTION
          // ─────────────────────────────────
          ElevatedButton.icon(
            icon: const Icon(Icons.compare_arrows),
            label: const Text('Comparer'),
            onPressed: (_selectedYears.isEmpty &&
                    _selectedMonthIds.isEmpty)
                ? null
                : _goToComparison,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 🔁 BUILD PERIODS & NAVIGATE (VERS LE HUB)
  // ─────────────────────────────────────────────
  void _goToComparison() {
    final List<ComparisonPeriod> periods = [];

    // Années
    for (final year in _selectedYears) {
      final months = ArchivesStore.byYear(year);
      if (months.isEmpty) continue;

      periods.add(
        ComparisonPeriod.fromYear(year, months),
      );
    }

    // Mois
    for (final id in _selectedMonthIds) {
      final ArchivedMonth? month = ArchivesStore.all
          .cast<ArchivedMonth?>()
          .firstWhere(
            (m) => m?.id == id,
            orElse: () => null,
          );

      if (month != null) {
        periods.add(
          ComparisonPeriod.fromMonth(month),
        );
      }
    }

    if (periods.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComparisonHubScreen(
          periods: periods,
        ),
      ),
    );
  }
}
