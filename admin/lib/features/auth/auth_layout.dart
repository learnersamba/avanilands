import 'package:flutter/material.dart';

import '../../core/theme.dart';

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
                const _BrandMark(),
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

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: BrandColors.forest,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.landscape_outlined,
            color: BrandColors.sand,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Avanilands Admin',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: BrandColors.forest,
            fontWeight: FontWeight.w700,
          ),
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
