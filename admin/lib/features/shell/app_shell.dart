import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../auth/admin_user.dart';
import '../auth/auth_controller.dart';
import '../dashboard/dashboard_repository.dart';
import '../enquiries/enquiry_alerts.dart';
import '../notifications/notifications_repository.dart';
import '../properties/properties_repository.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/landscape.dart';
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
  _NavItem('/', 'Dashboard', Icons.home_outlined),
  _NavItem('/properties', 'Properties', Icons.layers_outlined),
  _NavItem('/enquiries', 'Enquiries', Icons.mail_outline),
  _NavItem('/site-visits', 'Site visits', Icons.calendar_today_outlined),
  _NavItem('/bookings', 'Bookings', Icons.sell_outlined),
  _NavItem('/analytics', 'Analytics', Icons.bar_chart_rounded),
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
    final badges = {'/enquiries': summary?.newEnquiries ?? 0};

    final sidebar = _Sidebar(
      items: items,
      location: location,
      badges: badges,
      compact: mode == _NavMode.rail,
    );
    return Scaffold(
      drawer: mode == _NavMode.drawer
          ? Drawer(
              child: _Sidebar(items: items, location: location, badges: badges),
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
    required this.badges,
    this.compact = false,
  });

  final List<_NavItem> items;
  final String location;
  final Map<String, int> badges;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 80 : 256,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A4E3B), Color(0xFF053A2C)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 220,
            child: IgnorePointer(child: CustomPaint(painter: HillsPainter())),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 0 : 24,
                    26,
                    compact ? 0 : 16,
                    26,
                  ),
                  child: Row(
                    mainAxisAlignment: compact
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      const BrandMark(size: 38, onDark: true),
                      if (!compact) ...[
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AVANILANDS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Plots · Sites · Investments',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                                fontSize: 11,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (final item in items)
                        _SidebarTile(
                          item: item,
                          selected: _isSelected(item.path, location),
                          compact: compact,
                          badge: badges[item.path] ?? 0,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.compact,
    this.badge = 0,
  });

  final _NavItem item;
  final bool selected;
  final bool compact;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? BrandColors.forestDark
        : Colors.white.withValues(alpha: 0.88);
    final count = badge > 99 ? '99+' : '$badge';
    final icon = compact && badge > 0
        ? Badge(
            label: Text(count),
            backgroundColor: BrandColors.sand,
            textColor: BrandColors.forestDark,
            child: Icon(item.icon, color: color, size: 22),
          )
        : Icon(item.icon, color: color, size: 22);
    final tile = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: selected
            ? const LinearGradient(
                colors: [Color(0xFFF8EED6), Color(0xFFEBD49A)],
              )
            : null,
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          hoverColor: Colors.white.withValues(alpha: 0.07),
          onTap: () {
            if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
              Navigator.pop(context);
            }
            context.go(item.path);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                icon,
                if (!compact) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badge > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 24),
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? BrandColors.forest
                            : Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
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
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: BrandColors.line)),
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          if (wide)
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: const _QuickSearch(),
              ),
            ),
          const Spacer(),
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
          IconButton(
            tooltip: requestedVisits == 0
                ? 'No site visits waiting for confirmation'
                : '$requestedVisits site ${requestedVisits == 1 ? 'visit' : 'visits'} to confirm',
            onPressed: () =>
                context.go('/site-visits?status=requested&when=all'),
            icon: Badge(
              isLabelVisible: requestedVisits > 0,
              label: Text('$requestedVisits'),
              child: const Icon(Icons.calendar_today_outlined),
            ),
          ),
          if (wide)
            Container(
              width: 1,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: BrandColors.line,
            )
          else
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
                    radius: 20,
                    backgroundColor: const Color(0xFFF4E8D1),
                    child: Text(
                      _initials(admin.fullName),
                      style: const TextStyle(
                        color: BrandColors.forestDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width >= 600) ...[
                    const SizedBox(width: 10),
                    Text(
                      admin.fullName,
                      style: const TextStyle(
                        color: BrandColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more, size: 20),
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
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  /// Ctrl+K (⌘K on a Mac) jumps to the search box from anywhere.
  bool _onKey(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyK &&
        (keyboard.isControlPressed || keyboard.isMetaPressed)) {
      _focus.requestFocus();
      _text.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _text.text.length,
      );
      return true;
    }
    return false;
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
    const radius = BorderRadius.all(Radius.circular(14));
    return TextField(
      controller: _text,
      focusNode: _focus,
      style: const TextStyle(fontSize: 14.5),
      decoration: InputDecoration(
        hintText: 'Search: AL-0007, ENQ-000012 or properties…',
        hintStyle: const TextStyle(color: Color(0xFF68736F)),
        prefixIcon: const Icon(Icons.search, size: 22),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: BrandColors.line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Ctrl + K',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF68736F)),
            ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minHeight: 24),
        filled: true,
        fillColor: const Color(0xFFF9F8F4),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: BrandColors.line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: BrandColors.forest, width: 1.5),
        ),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: _submit,
    );
  }
}
