import 'dart:io';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/util/native/platform_check.dart';

class CustomBackButton extends StatelessWidget {
  final Color? color;

  const CustomBackButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return IconButton(
      icon: Icon(
        isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
        color: color ?? kAccentCyan,
      ),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () async {
        await Navigator.maybePop(context);
      },
    );
  }
}

PreferredSizeWidget basicLocalSendAppbar(String title) {
  return checkPlatform([TargetPlatform.macOS])
      ? PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: MoveWindow(
                child: Container(
                  decoration: BoxDecoration(
                    color: kGlassFill,
                    border: Border(bottom: BorderSide(color: kGlassBorder, width: 1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!kIsWeb && Platform.isMacOS) const SizedBox(width: 60),
                      const CustomBackButton(),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Colors.white, Color(0xFFCCEEFF)],
                                ).createShader(bounds),
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 100,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
      : _GlassAppBar(title: title);
}

class _GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const _GlassAppBar({required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: kGlassFill,
            border: Border(bottom: BorderSide(color: kGlassBorder, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  const CustomBackButton(),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
