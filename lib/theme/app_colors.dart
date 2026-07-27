import 'package:flutter/material.dart';

/// Couleurs sémantiques réutilisées partout dans l'app (positif/négatif/
/// alerte). Accessibles via `context.appColors.positive` etc. — chaque
/// écran doit utiliser ça plutôt que des `Colors.green`/`Colors.red` en
/// dur, pour que le mode sombre reste cohérent et lisible partout.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color positive; // revenus, gains, valeurs positives
  final Color negative; // dépenses, pertes, suppression
  final Color warning; // dépassement, alerte, en attente

  const AppColors({
    required this.positive,
    required this.negative,
    required this.warning,
  });

  static const light = AppColors(
    positive: Color(0xFF2E7D32),
    negative: Color(0xFFC62828),
    warning: Color(0xFFEF6C00),
  );

  static const dark = AppColors(
    positive: Color(0xFF81C784),
    negative: Color(0xFFEF9A9A),
    warning: Color(0xFFFFB74D),
  );

  @override
  AppColors copyWith({Color? positive, Color? negative, Color? warning}) {
    return AppColors(
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
