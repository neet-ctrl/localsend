import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/state/purchase_state.dart';
import 'package:localsend_app/pages/donation/donation_page_vm.dart';
// [FOSS_REMOVE_START]
import 'package:localsend_app/provider/purchase_provider.dart';
// [FOSS_REMOVE_END]
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DonationPage extends StatelessWidget {
  const DonationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: (ref) => donationPageVmProvider,
      // [FOSS_REMOVE_START]
      init: (context) => context.redux(purchaseProvider).dispatchAsync(FetchPricesAndPurchasesAction()), // ignore: discarded_futures
      // [FOSS_REMOVE_END]
      builder: (context, vm) {
        return Scaffold(
          backgroundColor: kBgDark,
          appBar: basicLocalSendAppbar(t.donationPage.title),
          body: Stack(
            children: [
              ResponsiveListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 50),

                  // Heart icon
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B9D), kAccentPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [BoxShadow(color: const Color(0xFFFF6B9D).withOpacity(0.35), blurRadius: 24)],
                      ),
                      child: const Icon(Icons.favorite, color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Info text
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: kGlassFill,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kGlassBorder, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            t.donationPage.info,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withOpacity(0.75), height: 1.55),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  if (vm.purchased.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Center(
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [kAccentCyan, kAccentPurple],
                          ).createShader(bounds),
                          child: Text(
                            t.donationPage.thanks,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (vm.platformSupportPayment)
                    _StoreDonation(vm)
                  else
                    const _LinkDonation(),
                ],
              ),
              if (vm.pending)
                ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: kGlassFill,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kGlassBorder, width: 1),
                          ),
                          child: const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(kAccentCyan),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StoreDonation extends StatelessWidget {
  final DonationPageVm vm;

  const _StoreDonation(this.vm);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...PurchaseItem.values.map((item) {
          final purchased = vm.purchased.contains(item);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: purchased
                    ? null
                    : const LinearGradient(colors: [Color(0xFFFF6B9D), kAccentPurple]),
                color: purchased ? kGlassFill : null,
                border: purchased ? Border.all(color: kGlassBorder, width: 1) : null,
                boxShadow: purchased
                    ? null
                    : [BoxShadow(color: const Color(0xFFFF6B9D).withOpacity(0.3), blurRadius: 16)],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: purchased ? null : () => vm.purchase(item),
                icon: Icon(purchased ? Icons.check_circle : Icons.favorite, size: 20),
                label: Text(
                  t.donationPage.donate(amount: vm.prices[item] ?? '...'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0.5)),
          onPressed: vm.restore,
          icon: const Icon(Icons.restore, size: 18),
          label: Text(t.donationPage.restore),
        ),
      ],
    );
  }
}

class _LinkDonation extends StatelessWidget {
  const _LinkDonation();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DonationLink(
          label: 'GitHub Sponsors',
          icon: Icons.favorite_border,
          url: 'https://github.com/sponsors/Tienisto',
          color: kAccentCyan,
        ),
        const SizedBox(height: 12),
        _DonationLink(
          label: 'Ko-fi',
          icon: Icons.local_cafe,
          url: 'https://ko-fi.com/tienisto',
          color: kAccentPurple,
        ),
      ],
    );
  }
}

class _DonationLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final String url;
  final Color color;

  const _DonationLink({
    required this.label,
    required this.icon,
    required this.url,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: () async => await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.35), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const Spacer(),
                  Icon(Icons.open_in_new, color: color.withOpacity(0.6), size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
