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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () async {
        await Navigator.maybePop(context);
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? kGlassFill : const Color(0x0A000000),
          border: Border.all(
            color: isDark ? kGlassBorder : const Color(0x15000000),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
          color: color ?? (isDark ? kAccentCyan : const Color(0xFF0D1220)),
          size: 18,
        ),
      ),
    );
  }
}

PreferredSizeWidget basicLocalSendAppbar(String title) {
  // Creates a very simple new appBar to support bitsdojo_windows on mac and make them draggable
  // if you want have more items on here for a specific page, make sure to add it here as an option
  // so that mac users can still appreciate this near native new design
  return checkPlatform([TargetPlatform.macOS])
      ? PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 20.0,
                sigmaY: 20.0,
              ),
              child: MoveWindow(
                child: Container(
                  color: Colors.transparent,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Padding space for macOS traffic lights
                      if (!kIsWeb && Platform.isMacOS) const SizedBox(width: 60),
                      // Originally leading Icon
                      CustomBackButton(),
                      // Center Title
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(title, style: TextStyle(fontSize: 100, fontWeight: FontWeight.normal)),
                            ),
                          ),
                        ),
                      ),
                      // For true centering of the icon since it shifted
                      const SizedBox(width: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
      : AppBar(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          leading: const CustomBackButton(),
          leadingWidth: 56,
        );
}
