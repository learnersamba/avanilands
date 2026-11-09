import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'config/env.dart';

/// Opens a property's public page in a new tab (the page is built in Phase 7).
void openOnWebsite(String slug) =>
    web.window.open('${Env.websiteUrl}/land/$slug', '_blank');

/// Opens a tel:, mailto: or web link (web links in a new tab).
void openLink(String url) {
  final anchor = web.HTMLAnchorElement()..href = url;
  if (url.startsWith('http')) {
    anchor
      ..target = '_blank'
      ..rel = 'noopener';
  }
  anchor.click();
}

/// Saves text as a file (e.g. a CSV export). A byte-order mark is added so
/// Excel reads Telugu and ₹ correctly.
void downloadText(String filename, String text, {String type = 'text/csv'}) {
  final blob = web.Blob(
    ['﻿$text'.toJS].toJS,
    web.BlobPropertyBag(type: '$type;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..click();
  Future<void>.delayed(
    const Duration(seconds: 5),
    () => web.URL.revokeObjectURL(url),
  );
}

/// 'granted', 'denied', 'default' (not asked yet) or 'unsupported'.
String notificationPermission() {
  if (!web.window.has('Notification')) return 'unsupported';
  return web.Notification.permission;
}

Future<String> requestNotificationPermission() async {
  if (!web.window.has('Notification')) return 'unsupported';
  return (await web.Notification.requestPermission().toDart).toDart;
}

/// Whether the admin is looking at another tab or window.
bool get pageHidden => web.document.hidden;

/// A desktop notification (only if allowed). Clicking it focuses the tab.
void showDesktopNotification(
  String title,
  String body, {
  String? tag,
  void Function()? onClick,
}) {
  if (notificationPermission() != 'granted') return;
  final notification = web.Notification(
    title,
    web.NotificationOptions(body: body, tag: tag ?? ''),
  );
  notification.onclick = ((web.Event _) {
    web.window.focus();
    notification.close();
    onClick?.call();
  }).toJS;
}
