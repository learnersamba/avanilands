import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/brand_mark.dart';

/// Centered card used by the sign-in, reset and set-password screens.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Lockup(),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: BrandColors.ink,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(subtitle!, style: textTheme.bodyMedium),
                        ],
                        const SizedBox(height: 24),
                        child,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Lockup extends StatelessWidget {
  const _Lockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const BrandMark(),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AVANILANDS',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: BrandColors.forest,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                height: 1.1,
              ),
            ),
            Text(
              'Admin panel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: BrandColors.ink.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Inline message box (error or info) shown above a form.
class FormMessage extends StatelessWidget {
  const FormMessage({super.key, required this.message, this.isError = true});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? BrandColors.danger : BrandColors.available;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}
