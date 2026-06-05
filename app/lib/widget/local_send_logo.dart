import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/assets.gen.dart';

class LocalSendLogo extends StatelessWidget {
  final bool withText;

  const LocalSendLogo({required this.withText});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logo = Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isDark
            ? const RadialGradient(
                colors: [Color(0xFF1E3A5C), Color(0xFF070B14)],
              )
            : const RadialGradient(
                colors: [Color(0xFFCCF5FF), Color(0xFFE8F8FF)],
              ),
        border: Border.all(
          color: kAccentCyan.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: kAccentCyan.withValues(alpha: 0.25),
            blurRadius: 40,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: kAccentCyan.withValues(alpha: 0.1),
            blurRadius: 80,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            kAccentCyan,
            BlendMode.srcATop,
          ),
          child: Assets.img.logo512.image(
            width: 140,
            height: 140,
          ),
        ),
      ),
    );

    if (withText) {
      return Column(
        children: [
          logo,
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [kAccentCyan, Color(0xFF00B8D9)],
            ).createShader(bounds),
            child: const Text(
              'LocalSend',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    } else {
      return logo;
    }
  }
}
