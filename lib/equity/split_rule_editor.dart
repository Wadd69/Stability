import 'package:flutter/material.dart';

import 'account_member.dart';
import 'split_rule.dart';

/// Éditeur de règle de répartition entre membres d'un compte partagé —
/// utilisé dans l'éditeur de catégorie (règle par défaut) et l'éditeur
/// de transaction récurrente (surcharge ponctuelle, voir [allowInherit]).
/// Ne s'affiche que si le compte compte au moins 2 membres.
class SplitRuleEditor extends StatefulWidget {
  final SplitRule? initialValue;
  final ValueChanged<SplitRule?> onChanged;
  final List<AccountMember> members;

  /// Si vrai, propose une option "Suivre la catégorie" (valeur `null`)
  /// en plus des modes de répartition — utilisé pour les surcharges par
  /// récurrence.
  final bool allowInherit;

  const SplitRuleEditor({
    super.key,
    required this.initialValue,
    required this.onChanged,
    required this.members,
    this.allowInherit = false,
  });

  @override
  State<SplitRuleEditor> createState() => _SplitRuleEditorState();
}

class _SplitRuleEditorState extends State<SplitRuleEditor> {
  SplitMode? _mode;
  String? _assignedUserId;
  late Map<String, TextEditingController> _percentControllers;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialValue?.mode;
    _assignedUserId = widget.initialValue?.assignedUserId ??
        (widget.members.isNotEmpty ? widget.members.first.userId : null);

    final equal = widget.members.isEmpty ? 0.0 : 100 / widget.members.length;
    _percentControllers = {
      for (final m in widget.members)
        m.userId: TextEditingController(
          text: (widget.initialValue?.customPercents?[m.userId] ?? equal)
              .toStringAsFixed(0),
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _percentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    switch (_mode) {
      case null:
        widget.onChanged(null);
        break;
      case SplitMode.proportional:
        widget.onChanged(SplitRule.proportional);
        break;
      case SplitMode.equal:
        widget.onChanged(SplitRule.equal);
        break;
      case SplitMode.assigned:
        widget.onChanged(
          SplitRule(mode: SplitMode.assigned, assignedUserId: _assignedUserId),
        );
        break;
      case SplitMode.custom:
        widget.onChanged(
          SplitRule(
            mode: SplitMode.custom,
            customPercents: {
              for (final e in _percentControllers.entries)
                e.key: double.tryParse(e.value.text.replaceAll(',', '.')) ?? 0,
            },
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.members.length < 2) return const SizedBox.shrink();

    final percentTotal = _percentControllers.values.fold<double>(
      0,
      (s, c) => s + (double.tryParse(c.text.replaceAll(',', '.')) ?? 0),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition entre membres',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _mode == null ? '__inherit__' : _mode!.name,
            decoration: const InputDecoration(labelText: 'Mode'),
            items: [
              if (widget.allowInherit)
                const DropdownMenuItem(
                  value: '__inherit__',
                  child: Text('Suivre la catégorie'),
                ),
              ...SplitMode.values.map(
                (m) => DropdownMenuItem(value: m.name, child: Text(m.label)),
              ),
            ],
            onChanged: (v) {
              setState(() {
                _mode = v == '__inherit__'
                    ? null
                    : SplitMode.values.firstWhere((m) => m.name == v);
              });
              _emit();
            },
          ),
          if (_mode == SplitMode.assigned) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _assignedUserId,
              decoration: const InputDecoration(labelText: 'Membre qui paie'),
              items: widget.members
                  .map(
                    (m) => DropdownMenuItem(
                      value: m.userId,
                      child:
                          Text(m.displayName, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => _assignedUserId = v);
                _emit();
              },
            ),
          ],
          if (_mode == SplitMode.custom) ...[
            const SizedBox(height: 8),
            for (final m in widget.members)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child:
                          Text(m.displayName, overflow: TextOverflow.ellipsis),
                    ),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        controller: _percentControllers[m.userId],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(suffixText: '%'),
                        onChanged: (_) {
                          setState(() {});
                          _emit();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              'Total : ${percentTotal.toStringAsFixed(0)} % (doit faire 100 %)',
              style: TextStyle(
                color: (percentTotal - 100).abs() > 0.5
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
