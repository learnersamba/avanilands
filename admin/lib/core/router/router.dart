import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/activity_page.dart';
import '../../features/admins/admins_page.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/forgot_password_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/set_password_page.dart';
import '../../features/auth/splash_page.dart';
import '../../features/bookings/booking_detail_page.dart';
import '../../features/bookings/booking_models.dart';
import '../../features/bookings/bookings_page.dart';
import '../../features/content/content_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/enquiries/enquiries_page.dart';
import '../../features/enquiries/enquiry_detail_page.dart';
import '../../features/enquiries/enquiry_models.dart';
import '../../features/lookups/lookups_page.dart';
import '../../features/analytics/analytics_models.dart';
import '../../features/analytics/analytics_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/placeholder/coming_soon_page.dart';
import '../../features/properties/editor/property_editor_page.dart';
import '../../features/properties/properties_list_page.dart';
import '../../features/properties/properties_repository.dart';
import '../../features/settings/settings_page.dart';
import '../../features/site_visits/site_visit_detail_page.dart';
import '../../features/site_visits/site_visit_models.dart';
import '../../features/site_visits/site_visits_page.dart';
import '../../features/shell/app_shell.dart';
import '../unsaved_changes.dart';
import 'redirect.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the sign-in state changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(authControllerProvider), state.uri),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/set-password',
        builder: (_, _) => const SetPasswordPage(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
          GoRoute(
            path: '/properties',
            builder: (_, state) =>
                PropertiesListPage(query: PropertyQuery.fromUri(state.uri)),
            routes: [
              GoRoute(
                path: 'new',
                onExit: confirmLeave,
                builder: (_, _) => const PropertyEditorPage(),
              ),
              GoRoute(
                path: ':id',
                onExit: confirmLeave,
                builder: (_, state) =>
                    PropertyEditorPage(id: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: '/enquiries',
            builder: (_, state) =>
                EnquiriesPage(query: EnquiryQuery.fromUri(state.uri)),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    EnquiryDetailPage(id: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/site-visits',
            builder: (_, state) =>
                SiteVisitsPage(query: SiteVisitQuery.fromUri(state.uri)),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    SiteVisitDetailPage(id: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/bookings',
            builder: (_, state) =>
                BookingsPage(query: BookingQuery.fromUri(state.uri)),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    BookingDetailPage(id: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: '/locations', builder: (_, _) => const LookupsPage()),
          GoRoute(path: '/activity', builder: (_, _) => const ActivityPage()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
          GoRoute(
            path: '/analytics',
            builder: (_, state) => AnalyticsPage(
              range: AnalyticsRange.fromQuery(state.uri.queryParameters),
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, state) => NotificationsPage(
              unreadOnly: state.uri.queryParameters['unread'] == '1',
            ),
          ),
          GoRoute(
            path: '/content',
            builder: (_, state) =>
                ContentPage(tab: state.uri.queryParameters['tab'] ?? 'home'),
          ),
          GoRoute(path: '/admins', builder: (_, _) => const AdminsPage()),
        ],
      ),
    ],
    errorBuilder: (_, _) =>
        const ComingSoonPage(title: 'Page not found', phase: null),
  );
});
