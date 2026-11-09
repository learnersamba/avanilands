import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';

/// Stand-in for sections built in later phases.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.title, required this.phase});

  final String title;
  final int? phase;

  @override
  Widget build(BuildContext context) {
    final body = PageBody(
      children: [
        PageHeader(title: title),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                EmptyState(
                  icon: phase == null
                      ? Icons.search_off
                      : Icons.construction_outlined,
                  message: phase == null
                      ? 'This page does not exist.'
                      : 'This section is built in Phase $phase.',
                ),
                if (phase == null)
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Go to the dashboard'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    // The not-found page is shown outside the shell.
    return phase == null ? Scaffold(body: body) : body;
  }
}
