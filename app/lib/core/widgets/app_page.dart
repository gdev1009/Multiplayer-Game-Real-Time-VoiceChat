import 'package:flutter/material.dart';
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
  });

  final Widget child;
  final String? title;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              automaticallyImplyLeading: showBack,
              leading: showBack
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back, size: 30),
                      tooltip: 'Go back',
                      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    )
                  : null,
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(child: child),
              ),
            );
          },
        ),
      ),
    );
  }
}
