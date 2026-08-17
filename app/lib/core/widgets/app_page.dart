import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_responsive.dart';

/// A consistent page wrapper: safe area, generous padding, optional title bar,
/// and a scrollable body so content never gets cut off on small screens.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.child,
    this.title,
    this.showBack = false,
    this.onBack,
    this.actions,
    this.compactAppBar = false,
    this.studioFocus = false,
    this.actionsOnlyBar = false,
    this.scrollable = true,
  });

  final Widget child;
  final String? title;
  final bool showBack;
  final VoidCallback? onBack;

  /// Optional app-bar action widgets (e.g. the sound button).
  final List<Widget>? actions;

  /// A shorter app bar so more vertical space goes to the game studio.
  final bool compactAppBar;

  /// When true the body fills the screen without an app bar or scroll padding —
  /// used on the live play screen so the studio dominates the layout.
  final bool studioFocus;

  /// Thin app bar with no title — only [actions] (e.g. sound button).
  final bool actionsOnlyBar;

  /// When false, the body fills the viewport (use with [Expanded]/[Spacer]
  /// columns). When true, content scrolls on short phones.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Opaque so a disposed play route can never show through Home.
      backgroundColor: AppColors.deepPurpleDark,
      // Keep the studio at full height while typing — never shrink seats/Guy.
      resizeToAvoidBottomInset: !studioFocus,
      appBar: (studioFocus ||
              (title == null && !(actionsOnlyBar && actions != null)))
          ? null
          : AppBar(
              title: actionsOnlyBar
                  ? const SizedBox.shrink()
                  : Text(title!),
              toolbarHeight: (compactAppBar || actionsOnlyBar)
                  ? AppResponsive.s(context, 36)
                  : null,
              titleTextStyle: compactAppBar
                  ? Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      )
                  : null,
              automaticallyImplyLeading: showBack,
              actions: actions,
              flexibleSpace: const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.brandGradient),
              ),
              leading: showBack
                  ? IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        size: compactAppBar ? 26 : 30,
                      ),
                      tooltip: 'Go back',
                      onPressed:
                          onBack ?? () => Navigator.of(context).maybePop(),
                    )
                  : null,
            ),
      body: Container(
        decoration: BoxDecoration(
          gradient: studioFocus
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2A1548),
                    AppColors.deepPurpleDark,
                    Color(0xFF4A2578),
                  ],
                )
              : AppColors.pageGradient,
        ),
        child: SafeArea(
          // Live play is full-bleed under the status bar; other screens
          // keep top inset so Skip / titles never sit under the notch.
          top: !studioFocus,
          bottom: true,
          minimum: EdgeInsets.zero,
          child: studioFocus
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
                  child: child,
                )
              : _PageBody(
                  scrollable: scrollable,
                  child: child,
                ),
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.scrollable,
    required this.child,
  });

  final bool scrollable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final insets = AppResponsive.pageInsets(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppResponsive.contentMaxWidth,
              minWidth: 0,
              minHeight: scrollable
                  ? (constraints.maxHeight - insets.vertical)
                      .clamp(0.0, double.infinity)
                  : constraints.maxHeight,
              maxHeight: scrollable ? double.infinity : constraints.maxHeight,
            ),
            child: Padding(
              padding: scrollable ? EdgeInsets.zero : insets,
              child: child,
            ),
          ),
        );

        if (!scrollable) {
          // Fill mode — parents can use Expanded / Spacer safely.
          return Padding(
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: content,
            ),
          );
        }

        return SingleChildScrollView(
          padding: insets,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              minHeight: (constraints.maxHeight - insets.vertical)
                  .clamp(0.0, double.infinity),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppResponsive.contentMaxWidth,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
