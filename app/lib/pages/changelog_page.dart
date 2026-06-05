import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/assets.gen.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/util/ui/nav_bar_padding.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';

class ChangelogPage extends StatelessWidget {
  const ChangelogPage();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: basicLocalSendAppbar(t.changelogPage.title),
      body: FutureBuilder(
        future: rootBundle.loadString(Assets.changelog), // ignore: discarded_futures
        builder: (context, data) {
          if (!data.hasData) {
            return Center(child: CircularProgressIndicator(color: kAccentCyan));
          }
          return Markdown(
            padding: EdgeInsets.only(
              left: 15 + MediaQuery.of(context).padding.left,
              right: 15 + MediaQuery.of(context).padding.right,
              top: 15,
              bottom: 15 + getNavBarPadding(context),
            ),
            styleSheet: MarkdownStyleSheet(
              h1: TextStyle(
                color: isDark ? kAccentCyan : const Color(0xFF0D3B52),
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              h2: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0D1220),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              h3: TextStyle(
                color: isDark ? const Color(0xFFB0BDD0) : const Color(0xFF4A5568),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              p: TextStyle(
                color: isDark ? const Color(0xFFB0BDD0) : const Color(0xFF4A5568),
                fontSize: 14,
                height: 1.5,
              ),
              code: TextStyle(
                color: isDark ? kAccentCyan : const Color(0xFF003D52),
                backgroundColor: isDark ? kGlassFill : const Color(0xFFF0F4FF),
                fontSize: 13,
              ),
              codeblockDecoration: BoxDecoration(
                color: isDark ? kGlassFill : const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? kGlassBorder : const Color(0x1A000000)),
              ),
            ),
            data: data.data!,
          );
        },
      ),
    );
  }
}
