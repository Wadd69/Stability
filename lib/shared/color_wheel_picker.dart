import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

/// Sélecteur de couleur à roue, utilisé pour les catégories et les supports.
Future<Color?> showColorWheelPicker(
  BuildContext context, {
  required Color initialColor,
  String title = 'Choisir une couleur',
}) {
  Color picked = initialColor;

  return showDialog<Color>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: ColorPicker(
          color: initialColor,
          onColorChanged: (c) => picked = c,
          pickersEnabled: const {
            ColorPickerType.wheel: true,
            ColorPickerType.primary: false,
            ColorPickerType.accent: false,
            ColorPickerType.bw: false,
            ColorPickerType.custom: false,
            ColorPickerType.customSecondary: false,
          },
          enableShadesSelection: false,
          showColorCode: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, picked),
          child: const Text('Valider'),
        ),
      ],
    ),
  );
}
