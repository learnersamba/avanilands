import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../auth/admin_user.dart';
import '../auth/auth_controller.dart';
import '../dashboard/dashboard_repository.dart';
import '../enquiries/enquiry_alerts.dart';
import '../notifications/notifications_repository.dart';
import '../properties/properties_repository.dart';
import '../../core/widgets/common.dart';

class _NavItem {
  const _NavItem(
    this.path,
    this.label,
    this.icon, {
    this.superAdminOnly = false,
  });

  final String path;
  final String label;
  final IconData icon;
  final bool superAdminOnly;
}

const _items = [
  _NavItem('/', 'Dashboard', Icons.space_dashboard_outlined),
  _NavItem('/properties', 'Properties', Icons.landscape_outlined),
  _NavItem('/enquiries', 'Enquiries', Icons.mail_outline),
  _NavItem('/site-visits', 'Site visits', Icons.event_available_outlined),
  _NavItem('/bookings', 'Bookings', Icons.key_outlined),
  _NavItem('/analytics', 'Analytics', Icons.insights_outlined),
  _NavItem('/locations', 'Locations & lists', Icons.place_outlined),
  _NavItem('/activity', 'Activity log', Icons.history),
  _NavItem(
    '/admins',
    'Admin users',
    Icons.admin_panel_settings_outlined,
    superAdminOnly: true,
  ),
  _NavItem(
    '/content',
    'Website content',
    Icons.web_outlined,
    superAdminOnly: true,
  ),
  _NavItem(
    '/settings',
    'Settings',
    Icons.settings_outlined,
    superAdminOnly: true,
  ),
];

/// Sidebar + top bar around every signed-in page.
/// Wide: full sidebar. Medium: icon rail. Narrow (phones): drawer.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(currentAdminProvider);
    final items = [
      for (final item in _items)
        if (!item.superAdminOnly || admin.isSuperAdmin) item,
    ];
    final width = MediaQuery.sizeOf(context).width;
    final mode = width >= 1100
        ? _NavMode.full
        : (width >= 720 ? _NavMode.rail : _NavMode.drawer);
    final summary = ref.watch(dashboardSummaryProvider).value;
    final requestedVisits = summary?.requestedSiteVisits ?? 0;

    final sidebar = _Sidebar(
      items: items,
      location: location,
      compact: mode == _NavMode.rail,
    );
    return Scaffold(
      drawer: mode == _NavMode.drawer
          ? Drawer(
              child: _Sidebar(items: items, location: location),
            )
          : null,
      body: Row(
        children: [
          if (mode != _NavMode.drawer) sidebar,
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  admin: admin,
                  showMenu: mode == _NavMode.drawer,
                  requestedVisits: requestedVisits,
                ),
                const Divider(height: 1),
                Expanded(child: EnquiryAlerts(child: child)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _NavMode { full, rail, drawer }

bool _isSelected(String itemPath, String location) => itemPath == '/'
    ? location == '/'
    : location == itemPath || location.startsWith('$itemPath/');

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.location,
    this.compact = false,
  });

  final List<_NavItem> items;
  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 76 : 248,
      color: BrandColors.forest,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 0 : 20,
                vertical: 22,
              ),
              child: Row(
                mainAxisAlignment: compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  const Icon(Icons.landscape_outlined, color: BrandColors.sand),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    const Text(
                      'Avanilands',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            for (final item in items)
              _SidebarTile(
                item: item,
                selected: _isSelected(item.path, location),
                compact: compact,
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.compact,
  });

  final _NavItem item;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BrandColors.forestDark : Colors.white;
    final tile = Material(
      color: selected ? BrandColors.sand : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
            Navigator.pop(context);
          }
          context.go(item.path);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(item.icon, color: color, size: 22),
              if (!compact) ...[
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: compact ? Tooltip(message: item.label, child: tile) : tile,
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.admin,
    required this.showMenu,
    required this.requestedVisits,
  });

  final AdminUser admin;
  final bool showMenu;
  final int requestedVisits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          if (MediaQuery.sizeOf(context).width >= 900)
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: SizedBox(width: 320, child: _QuickSearch()),
            ),
          const Spacer(),
          IconButton(
            tooltip: requestedVisits == 0
                ? 'No site visits waiting for confirmation'
                : '$requestedVisits site ${requestedVisits == 1 ? 'visit' : 'visits'} to confirm',
            onPressed: () =>
                context.go('/site-visits?status=requested&when=all'),
            icon: Badge(
              isLabelVisible: requestedVisits > 0,
              label: Text('$requestedVisits'),
              child: const Icon(Icons.event_available_outlined),
            ),
          ),
          Builder(
            builder: (context) {
              final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
              return IconButton(
                tooltip: unread == 0
                    ? 'Notifications'
                    : '$unread unread ${unread == 1 ? 'notification' : 'notifications'}',
                onPressed: () => context.go(
                  unread == 0 ? '/notifications' : '/notifications?unread=1',
                ),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread > 99 ? '99+' : '$unread'),
                  child: const Icon(Icons.notifications_none),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Account',
            onSelected: (value) {
              switch (value) {
                case 'password':
                  context.go('/set-password');
                case 'signout':
                  ref.read(authControllerProvider.notifier).signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      admin.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: BrandColors.ink,
                      ),
                    ),
                    Text(
                      '${admin.email} · ${admin.role.label}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'password',
                child: Text('Change password'),
              ),
              const PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: BrandColors.sand,
                    child: Text(
                      _initials(admin.fullName),
                      style: const TextStyle(
                        color: BrandColors.forestDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width >= 600) ...[
                    const SizedBox(width: 8),
                    Text(admin.fullName),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

/// Type a property code (AL-0007) to open it, or any words to search the
/// property list. Enquiry (ENQ-…) and site visit (SV-…) references open
/// their lists.
class _QuickSearch extends ConsumerStatefulWidget {
  const _QuickSearch();

  @override
  ConsumerState<_QuickSearch> createState() => _QuickSearchState();
}

class _QuickSearchState extends ConsumerState<_QuickSearch> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final upper = query.toUpperCase();
    if (RegExp(r'^AL-\d+$').hasMatch(upper)) {
      final id = await ref.read(propertiesRepositoryProvider).idForCode(upper);
      if (!mounted) return;
      if (id == null) {
        showMessage(context, 'No property with code $upper.', error: true);
        return;
      }
      _text.clear();
      context.go('/properties/$id');
    } else if (upper.startsWith('BKG-')) {
      _text.clear();
      context.go(
        Uri(
          path: '/bookings',
          queryParameters: {'q': upper, 'all': '1'},
        ).toString(),
      );
    } else if (upper.startsWith('SV-')) {
      _text.clear();
      context.go(
        Uri(
          path: '/site-visits',
          queryParameters: {'q': upper, 'when': 'all'},
        ).toString(),
      );
    } else if (upper.startsWith('ENQ-')) {
      _text.clear();
      context.go(
        Uri(path: '/enquiries', queryParameters: {'q': upper}).toString(),
      );
    } else {
      _text.clear();
      context.go(
        Uri(path: '/properties', queryParameters: {'q': query}).toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _text,
      decoration: const InputDecoration(
        hintText: 'Search: AL-0007, ENQ-000012 or a place',
        prefixIcon: Icon(Icons.search, size: 20),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: _submit,
    );
  }
}
