import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/debug/debug_page.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/local_send_logo.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

part 'contributors.dart';

part 'packagers.dart';

part 'translators.dart';

final _translatorWithGithubRegex = RegExp(r'(.+) \(@([\w\-_]+)\)');

class AboutPage extends StatelessWidget {
  const AboutPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: basicLocalSendAppbar(t.aboutPage.title),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: [
          const SizedBox(height: 24),

          // Logo hero
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kAccentCyan.withOpacity(0.08),
                    border: Border.all(color: kAccentCyan.withOpacity(0.25), width: 1.5),
                    boxShadow: [BoxShadow(color: kAccentCyan.withOpacity(0.18), blurRadius: 32)],
                  ),
                  child: const LocalSendLogo(withText: false),
                ),
                const SizedBox(height: 14),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [kAccentCyan, kAccentPurple],
                  ).createShader(bounds),
                  child: const Text(
                    'LocalSend',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '© ${DateTime.now().year} Tien Do Nam',
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: kAccentCyan),
                  onPressed: () async => await launchUrl(Uri.parse('https://localsend.org')),
                  child: const Text('localsend.org', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Description glass card
          _GlassCard(
            child: Text(
              t.aboutPage.description.join('\n\n'),
              style: TextStyle(color: Colors.white.withOpacity(0.72), height: 1.55),
            ),
          ),

          const SizedBox(height: 16),

          // Author section
          _SectionHeader(label: t.aboutPage.author),
          _GlassCard(
            child: Text.rich(
              _buildContributor(label: 'Tien Do Nam (@Tienisto)', primaryColor: kAccentCyan),
            ),
          ),

          const SizedBox(height: 16),

          // Contributors
          _SectionHeader(label: t.aboutPage.contributors),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _contributors.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text.rich(_buildContributor(label: c, primaryColor: kAccentCyan)),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Packagers
          _SectionHeader(label: t.aboutPage.packagers),
          _GlassCard(
            child: Table(
              columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
              children: _packagers.entries.map(
                (e) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 10, bottom: 6),
                      child: Text(e.key, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    ),
                    Text.rich(
                      TextSpan(
                        children: e.value.mapIndexed((i, t) => _buildContributor(label: t, primaryColor: kAccentCyan, newLine: i != 0)).toList(),
                      ),
                    ),
                  ],
                ),
              ).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Translators
          _SectionHeader(label: t.aboutPage.translators),
          _GlassCard(
            child: Table(
              columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
              children: _translators.entries.map(
                (e) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 10, bottom: 6),
                      child: Text(
                        e.key.translations.locale,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: e.value.mapIndexed((i, tt) => _buildContributor(label: tt, primaryColor: kAccentCyan, newLine: i != 0)).toList(),
                      ),
                    ),
                  ],
                ),
              ).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // Links glass card
          _GlassCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _LinkChip(label: 'Homepage', url: 'https://localsend.org'),
                _LinkChip(label: 'GitHub', url: 'https://github.com/localsend/localsend'),
                _LinkChip(label: 'Codeberg', url: 'https://codeberg.org/localsend/localsend'),
                _LinkChip(label: 'Apache License 2.0', url: 'https://www.apache.org/licenses/LICENSE-2.0'),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: kAccentCyan),
                  onPressed: () async => await context.push(() => const LicensePage()),
                  icon: const Icon(Icons.article_outlined, size: 16),
                  label: const Text('License Notices'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0.5)),
                  onPressed: () async => await context.push(() => const DebugPage()),
                  icon: const Icon(Icons.bug_report_outlined, size: 16),
                  label: const Text('Debugging'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 50),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: kGlassFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kGlassBorder, width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                colors: [kAccentCyan, kAccentPurple],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  final String label;
  final String url;
  const _LinkChip({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: kAccentCyan),
      onPressed: () async => await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      icon: const Icon(Icons.open_in_new, size: 14),
      label: Text(label),
    );
  }
}

InlineSpan _buildContributor({required String label, required Color primaryColor, bool newLine = false}) {
  final newLineStr = newLine ? '\n' : '';

  if (label.startsWith('@')) {
    return TextSpan(
      text: '$newLineStr$label',
      style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500),
      recognizer: TapGestureRecognizer()
        ..onTap = () async {
          await launchUrl(Uri.parse('https://github.com/${label.substring(1)}'), mode: LaunchMode.externalApplication);
        },
    );
  }

  final match = _translatorWithGithubRegex.firstMatch(label);
  if (match != null) {
    final fullName = match.group(1)!;
    final githubName = match.group(2)!;
    return TextSpan(
      children: [
        TextSpan(text: '$newLineStr$fullName', style: TextStyle(color: Colors.white.withOpacity(0.75))),
        const TextSpan(text: ' '),
        TextSpan(
          text: '@$githubName',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              await launchUrl(Uri.parse('https://github.com/$githubName'), mode: LaunchMode.externalApplication);
            },
        ),
      ],
    );
  }

  return TextSpan(text: '$newLineStr$label', style: TextStyle(color: Colors.white.withOpacity(0.75)));
}
