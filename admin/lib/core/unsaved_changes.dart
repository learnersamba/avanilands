import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import 'widgets/common.dart';

/// True while a form has changes that are not saved yet.
final unsavedChanges = ValueNotifier<bool>(false);

/// Asks the browser to warn before closing or reloading the tab with
/// unsaved changes. Call once at start-up.
void installBeforeUnloadGuard() {
  web.window.addEventListener(
    'beforeunload',
    ((web.Event event) {
      if (!unsavedChanges.value) return;
      event.preventDefault();
      (event as web.BeforeUnloadEvent).returnValue = '';
    }).toJS,
  );
}

/// go_router `onExit`: confirm before leaving a page with unsaved changes.
Future<bool> confirmLeave(BuildContext context, GoRouterState state) async {
  if (!unsavedChanges.value) return true;
  final leave = await confirmAction(
    context,
    title: 'Leave without saving?',
    message: 'Your changes on this page will be lost.',
    confirmLabel: 'Leave',
    destructive: true,
  );
  if (leave) unsavedChanges.value = false;
  return leave;
}
