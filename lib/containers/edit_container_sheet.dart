import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/containers/containers_store.dart';
import '../core/containers/container_model.dart';
import '../core/containers/container_type.dart';
import '../shared/color_wheel_picker.dart';

class EditContainerSheet extends StatefulWidget {
  final ContainerModel? container;

  const EditContainerSheet({super.key, this.container});

  @override
  State<EditContainerSheet> createState() => _EditContainerSheetState();
}

class _EditContainerSheetState extends State<EditContainerSheet> {
  late TextEditingController _nameController;
  late TextEditingController _interestController;

  late TextEditingController _creditOriginalController;
  late TextEditingController _creditRemainingController;
  late TextEditingController _creditMonthlyController;
  late TextEditingController _creditRateController;
  late CreditKind _creditKind;

  late ContainerType _type;
  late Color _color;
  late bool _isPrimary;

  @override
  void initState() {
    super.initState();

    final store = context.read<ContainersStore>();
    final hasPrimary = store.primaryCurrentAccount != null;

    _nameController = TextEditingController(text: widget.container?.name ?? '');

    _type = widget.container?.type ??
        (hasPrimary
            ? ContainerType.currentAccount
            : ContainerType.currentAccount);

    _color = widget.container?.color ?? Colors.blue;
    _isPrimary = widget.container?.isPrimary ?? !hasPrimary;

    final lastRate = widget.container?.interestRates.isNotEmpty == true
        ? widget.container!.interestRates.last.rate
        : null;

    _interestController = TextEditingController(
      text: lastRate?.toStringAsFixed(2) ?? '',
    );

    _creditKind = widget.container?.creditKind ?? CreditKind.conso;
    _creditOriginalController = TextEditingController(
      text: widget.container?.creditOriginalAmount?.toStringAsFixed(2) ?? '',
    );
    _creditRemainingController = TextEditingController(
      text: widget.container?.creditRemainingBalance?.toStringAsFixed(2) ?? '',
    );
    _creditMonthlyController = TextEditingController(
      text: widget.container?.creditMonthlyPayment?.toStringAsFixed(2) ?? '',
    );
    _creditRateController = TextEditingController(
      text: widget.container?.creditAnnualRate?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _interestController.dispose();
    _creditOriginalController.dispose();
    _creditRemainingController.dispose();
    _creditMonthlyController.dispose();
    _creditRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<ContainersStore>();
    final isEditing = widget.container != null;
    final hasPrimary = store.primaryCurrentAccount != null;

    final forcePrimaryCreation = !hasPrimary && !isEditing;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? 'Modifier le support' : 'Créer un support',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),

            if (forcePrimaryCreation)
              Text(
                'Commencez par créer votre compte courant principal.\n'
                'Vous pourrez ajouter d’autres supports ensuite.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

            const SizedBox(height: 16),

            // ────────────────
            // NOM
            // ────────────────
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),

            const SizedBox(height: 12),

            // ────────────────
            // TYPE
            // ────────────────
            DropdownButtonFormField<ContainerType>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              items: ContainerType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    ),
                  )
                  .toList(),
              onChanged: forcePrimaryCreation
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _type = value;
                          if (_type != ContainerType.currentAccount) {
                            _isPrimary = false;
                          }
                        });
                      }
                    },
            ),

            const SizedBox(height: 12),

            // ────────────────
            // COMPTE PRINCIPAL (COURANT UNIQUEMENT)
            // ────────────────
            if (_type == ContainerType.currentAccount) ...[
              SwitchListTile(
                title: const Text('Compte courant principal'),
                subtitle: const Text(
                  'Compte de référence utilisé par le dashboard',
                ),
                value: _isPrimary,
                onChanged: forcePrimaryCreation
                    ? null
                    : (value) {
                        setState(() => _isPrimary = value);
                      },
              ),
              const SizedBox(height: 12),
            ],

            // ────────────────
            // TAUX D’INTÉRÊT (ÉPARGNE UNIQUEMENT)
            // ────────────────
            if (_type == ContainerType.savingsAccount) ...[
              TextField(
                controller: _interestController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Taux d’intérêt (%)',
                  helperText:
                      'Optionnel. Sera pris en compte à partir d’aujourd’hui.',
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ────────────────
            // CRÉDIT (IMMO / CONSO / REVOLVING)
            // ────────────────
            if (_type == ContainerType.credit) ...[
              DropdownButtonFormField<CreditKind>(
                initialValue: _creditKind,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type de crédit'),
                items: CreditKind.values
                    .map(
                        (k) => DropdownMenuItem(value: k, child: Text(k.label)))
                    .toList(),
                onChanged: (v) => setState(() => _creditKind = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _creditRemainingController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Capital restant dû (€)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _creditMonthlyController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Mensualité (€)',
                  helperText: 'Saisie manuellement, pas de calcul automatique.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _creditOriginalController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Montant emprunté initial (optionnel)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _creditRateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Taux d’intérêt annuel % (optionnel)',
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ────────────────
            // COULEUR
            // ────────────────
            Row(
              children: [
                const Text('Couleur'),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () async {
                    final color = await showColorWheelPicker(
                      context,
                      initialColor: _color,
                    );
                    if (color != null) {
                      setState(() => _color = color);
                    }
                  },
                  child: CircleAvatar(backgroundColor: _color),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ────────────────
            // VALIDATION
            // ────────────────
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () async {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;

                  final interestValue = double.tryParse(
                    _interestController.text.replaceAll(',', '.'),
                  );

                  final creditOriginal = double.tryParse(
                    _creditOriginalController.text.replaceAll(',', '.'),
                  );
                  final creditRemaining = double.tryParse(
                    _creditRemainingController.text.replaceAll(',', '.'),
                  );
                  final creditMonthly = double.tryParse(
                    _creditMonthlyController.text.replaceAll(',', '.'),
                  );
                  final creditRate = double.tryParse(
                    _creditRateController.text.replaceAll(',', '.'),
                  );

                  final now = DateTime.now();

                  ContainerModel container;

                  if (isEditing) {
                    final existingRates = List<InterestRatePeriod>.from(
                      widget.container!.interestRates,
                    );

                    if (_type == ContainerType.savingsAccount &&
                        interestValue != null &&
                        interestValue > 0) {
                      existingRates.add(
                        InterestRatePeriod(
                          rate: interestValue,
                          fromDate: now,
                        ),
                      );
                    }

                    container = widget.container!.copyWith(
                      name: name,
                      colorValue: _color.toARGB32(),
                      type: _type,
                      interestRates: existingRates,
                      isPrimary: _isPrimary,
                      creditKind:
                          _type == ContainerType.credit ? _creditKind : null,
                      creditOriginalAmount: creditOriginal,
                      creditRemainingBalance: creditRemaining,
                      creditMonthlyPayment: creditMonthly,
                      creditAnnualRate: creditRate,
                    );

                    await store.updateContainer(container);
                  } else {
                    final rates = <InterestRatePeriod>[];

                    if (_type == ContainerType.savingsAccount &&
                        interestValue != null &&
                        interestValue > 0) {
                      rates.add(
                        InterestRatePeriod(
                          rate: interestValue,
                          fromDate: now,
                        ),
                      );
                    }

                    container = await store.createContainer(
                      name: name,
                      colorValue: _color.toARGB32(),
                      type: _type,
                      interestRates: rates,
                      creditKind:
                          _type == ContainerType.credit ? _creditKind : null,
                      creditOriginalAmount: creditOriginal,
                      creditRemainingBalance: creditRemaining,
                      creditMonthlyPayment: creditMonthly,
                      creditAnnualRate: creditRate,
                    );
                  }

                  if (_isPrimary && _type == ContainerType.currentAccount) {
                    await store.setPrimaryCurrentAccount(container.id);
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('Valider'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
