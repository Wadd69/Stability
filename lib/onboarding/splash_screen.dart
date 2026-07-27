import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Écran de lancement : le logo Stability se forme depuis l'obscurité
/// (flou → net), reste affiché un bref instant, puis un fondu au noir
/// laisse place au reste de l'application via [onFinished].
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _total = Duration(milliseconds: 4200);

  // Proportions du minutage validé sur la maquette (0.3s / 2.3s / 3.4s / 4.2s).
  static const double _formStart = 0.3 / 4.2;
  static const double _formEnd = 2.3 / 4.2;
  static const double _fadeStart = 3.4 / 4.2;

  late final AnimationController _sequence;
  late final AnimationController _pulse;
  late final Animation<double> _form;
  late final Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();

    _sequence = AnimationController(vsync: this, duration: _total)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onFinished();
        }
      })
      ..forward();

    _form = CurvedAnimation(
      parent: _sequence,
      curve: const Interval(_formStart, _formEnd, curve: Curves.easeOutCubic),
    );
    _fadeOut = CurvedAnimation(
      parent: _sequence,
      curve: const Interval(_fadeStart, 1.0, curve: Curves.easeIn),
    );

    // Respiration douce et continue de la lueur derrière le logo.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sequence.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([_sequence, _pulse]),
        builder: (context, _) {
          final formT = _form.value;
          final blurSigma = 6 * (1 - formT);
          final glowPulseFactor = 0.85 + 0.15 * _pulse.value;
          final glowOpacity = formT * glowPulseFactor;

          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Opacity(
                  opacity: glowOpacity,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0x73F4E8CD),
                          Color(0x1FD9B98A),
                          Color(0x00D9B98A),
                        ],
                        stops: [0, 0.5, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: formT,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: Image.asset(
                      'assets/branding/stability_logo.png',
                      width: 160,
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: _fadeOut.value,
                child: const ColoredBox(color: Colors.black),
              ),
            ],
          );
        },
      ),
    );
  }
}
