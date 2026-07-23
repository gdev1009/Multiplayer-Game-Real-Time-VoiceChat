import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Opaque so a disposed play route can never show through Home.
      backgroundColor: AppColors.deepPurpleDark,
      appBar: (studioFocus ||
              (title == null && !(actionsOnlyBar && actions != null)))
          ? null
          : AppBar(
              title: actionsOnlyBar
                  ? const SizedBox.shrink()
                  : Text(title!),
              toolbarHeight: (compactAppBar || actionsOnlyBar) ? 36 : null,
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
                      icon: Icon(Icons.arrow_back, size: compactAppBar ? 26 : 30),
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
          // Studio is full-bleed; only keep the home-indicator inset.
          top: false,
          bottom: !studioFocus ? true : true,
          minimum: EdgeInsets.zero,
          child: studioFocus
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
                  child: child,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.pagePadding),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(child: child),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
