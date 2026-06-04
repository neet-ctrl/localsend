import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/assets.gen.dart';

class LocalSendLogo extends StatelessWidget {
  final bool withText;

  const LocalSendLogo({required this.withText});

  @override
  Widget build(BuildContext context) {
    final logo = ColorFiltered(
      colorFilter: const ColorFilter.mode(
        kAccentCyan,
        BlendMode.srcATop,
      ),
      child: Assets.img.logo512.image(
        width: 80,
        height: 80,
      ),
    );

    if (withText) {
      return Column(
        children: [
          logo,
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [kAccentCyan, kAccentPurple],
            ).createShader(bounds),
            child: const Text(
              'LocalSend',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
