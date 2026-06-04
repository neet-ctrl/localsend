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
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: basicLocalSendAppbar(t.changelogPage.title),
      body: FutureBuilder(
        future: rootBundle.loadString(Assets.changelog), // ignore: discarded_futures
        builder: (context, data) {
          if (!data.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(kAccentCyan),
                strokeWidth: 2,
              ),
            );
          }
          return Markdown(
            padding: EdgeInsets.only(
              left: 15 + MediaQuery.of(context).padding.left,
              right: 15 + MediaQuery.of(context).padding.right,
              top: 15,
              bottom: 15 + getNavBarPadding(context),
            ),
            data: data.data!,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: TextStyle(color: Colors.white.withOpacity(0.75), height: 1.55),
              h1: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
              h2: TextStyle(
                color: kAccentCyan,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
              h3: TextStyle(
                color: kAccentPurple,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              listBullet: TextStyle(color: kAccentCyan.withOpacity(0.8)),
              code: TextStyle(
                color: kAccentCyan,
                backgroundColor: kAccentCyan.withOpacity(0.08),
                fontSize: 13,
              ),
              codeblockDecoration: BoxDecoration(
                color: kGlassFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kGlassBorder, width: 1),
              ),
            ),
          );
        },
      ),
    );
  }
}
