import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../core/lang.dart';
import '../core/state.dart';
import 'brand.dart';
import 'lang_toggle.dart';
import 'phone_frame.dart';

/// How the app is shown on a wide screen (a computer): as a website (the
/// default) or inside the phone frame («عرض الجوال», for demos).
final phoneViewProvider = StateProvider<bool>((ref) => false);

/// Window width from which the app is laid out as a website.
const wideBreakpoint = 900.0;

/// Whether this part of the app is laid out as a website. Inside the phone
/// frame the width is the phone's, so this is false there.
bool isWebsite(BuildContext context) => MediaQuery.sizeOf(context).width >= wideBreakpoint;

/// Chooses the presentation: full-bleed on a phone or a tablet in portrait
/// (under 900); on a computer, the website — a header across the whole
/// window and the pages in a centred column, drawn larger on a large screen
/// — or the phone frame when the viewer asks for it.
class AdaptiveFrame extends ConsumerWidget {
  const AdaptiveFrame({super.key, required this.child});

  final Widget child;

  /// The header's width: the 1120 column and its 32 gutters.
  static const maxWidth = 1184.0;

  /// The pages' width: their own 20 gutters bring them to the same 1120
  /// column as the header.
  static const pageWidth = 1160.0;

  /// The website header's height.
  static const headerHeight = 76.0;

  /// A screen wider than [designWidth] draws the whole website larger, as a
  /// browser zoom would, so the page always fills about 90% of the width
  /// (the column is 1160 of 1300); up to [designWidth] nothing changes.
  static const designWidth = 1300.0;
  static const maxZoom = 2.5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    // Phones and tablets in portrait get the app itself, full-bleed.
    if (mq.size.width < wideBreakpoint) return child;
    if (!ref.watch(phoneViewProvider)) {
      final zoom = (mq.size.width / designWidth).clamp(1.0, maxZoom);
      if (zoom == 1.0) return _website(mq);
      final size = mq.size / zoom;
      return FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(size: size, child: _website(mq.copyWith(size: size))),
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: PhoneFrame(child: child)),
        PositionedDirectional(
          top: 14,
          end: 16,
          child: _ViewSwitch(phone: true, onTap: () => ref.read(phoneViewProvider.notifier).state = false),
        ),
      ],
    );
  }

  Widget _website(MediaQueryData mq) {
    final width = mq.size.width.clamp(0.0, pageWidth);
    final height = mq.size.height - headerHeight;
    return ColoredBox(
      color: BColors.bg,
      child: Column(
        children: [
          MediaQuery(data: mq, child: const _WebHeader()),
          Expanded(
            child: Center(
              child: SizedBox(
                width: width,
                child: MediaQuery(
                  data: mq.copyWith(
                    size: Size(width, height),
                    padding: mq.padding.copyWith(top: 0),
                    textScaler: const TextScaler.linear(1.1),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The website header: the brand, the main pages, «اسأل بصيرة», the
/// language and the phone-view switch. It sits above the Navigator, so it
/// navigates through the router and uses no Tooltip (there is no Overlay).
class _WebHeader extends ConsumerWidget {
  const _WebHeader();

  // (path, Arabic label, English label).
  static const _links = [('/home', 'الرئيسية', 'Home'), ('/explore', 'استكشف', 'Explore'), ('/library', 'مكتبتي', 'Library')];

  // Before the app is entered (splash, welcome, first «سياقي») only the brand
  // and the switches show.
  static const _intro = ['/splash', '/welcome'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final uri = router.routerDelegate.currentConfiguration.uri;
        final path = uri.path;
        final intro = _intro.contains(path) || (path == '/context' && uri.queryParameters['first'] == '1');
        // A Material gives the header's text its style and its ink.
        return Material(
          color: BColors.bg,
          child: Container(
            height: AdaptiveFrame.headerHeight,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: BColors.stroke)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AdaptiveFrame.maxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      Semantics(
                        button: !intro,
                        label: context.tr('بصيرة، الرئيسية', 'Basirah, home'),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          // The brand is the first focusable item: no grey box
                          // behind the logo when the page opens.
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          onTap: intro ? null : () => router.go('/home'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const BrandLogo(size: 36, tile: true),
                                const SizedBox(width: 10),
                                Text(context.tr('بصيرة', 'Basirah'), style: BText.brand(context.isEn ? 23 : 27)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 36),
                      if (!intro)
                        for (final (p, ar, en) in _links)
                          _HeaderLink(label: context.tr(ar, en), selected: path.startsWith(p), onTap: () => router.go(p)),
                      const Spacer(),
                      if (!intro) ...[
                        _AskButton(
                          selected: path.startsWith('/ask'),
                          onTap: () {
                            ref.read(askDraftProvider.notifier).state = null;
                            router.go('/ask');
                          },
                        ),
                        const SizedBox(width: 10),
                      ],
                      const LangToggle(tooltip: false),
                      const SizedBox(width: 10),
                      _ViewSwitch(phone: false, onTap: () => ref.read(phoneViewProvider.notifier).state = true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 4),
    child: Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? BColors.sand : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(
              label,
              style: BText.label(15, color: BColors.ink, weight: selected ? FontWeight.w600 : FontWeight.w500),
            ),
          ),
        ),
      ),
    ),
  );
}

/// «اسأل بصيرة»: the one dark button in the header.
class _AskButton extends StatelessWidget {
  const _AskButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: BColors.ink,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 17, color: BColors.gold),
              const SizedBox(width: 8),
              Text(
                context.tr('اسأل بصيرة', 'Ask Basirah'),
                style: BText.label(14, color: BColors.onInk, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.phone, required this.onTap});

  final bool phone;
  final VoidCallback onTap;

  @override
  // Above the Navigator (MaterialApp.builder): no Overlay, so no Tooltip.
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: BColors.surface,
      elevation: phone ? 2 : 0,
      shadowColor: const Color(0x22000000),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(phone ? Icons.desktop_windows_outlined : Icons.phone_iphone_rounded, size: 17, color: BColors.goldDeep),
              const SizedBox(width: 6),
              Text(
                phone ? context.tr('عرض الموقع', 'Website view') : context.tr('عرض الجوال', 'Phone view'),
                style: BText.label(13, color: BColors.goldDeep, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A page title: the brand face on the website (as the website's hero),
/// the display face on a phone.
TextStyle pageTitleStyle(BuildContext context, {double phone = 34}) =>
    isWebsite(context) ? BText.brand(context.isEn ? 38 : 44) : BText.display(phone);

/// Keeps a reading page (an answer, the references, «سياقي») to a
/// comfortable line length on a wide screen; no effect on a phone.
class ReadingWidth extends StatelessWidget {
  const ReadingWidth({super.key, required this.child, this.maxWidth = 860});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
