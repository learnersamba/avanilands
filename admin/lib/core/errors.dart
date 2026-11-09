import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/media/media_rules.dart';

/// Turns any error into a short sentence an admin can act on.
///
/// Database rule errors (triggers and functions) are already written as
/// plain sentences ending in a full stop, so they are shown as they are.
String friendlyError(Object error) {
  if (error is MediaException) return error.message;
  if (error is StorageException) {
    return 'File storage refused this: ${error.message}';
  }
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (message.contains('should be different')) {
      return 'Choose a password different from your current one.';
    }
    if (message.contains('expired') || message.contains('invalid flow state')) {
      return 'This link has expired. Ask for a new one.';
    }
    if (error.statusCode == '429' || message.contains('rate limit')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (message.contains('password')) return error.message;
    return 'Sign-in problem: ${error.message}';
  }
  if (error is PostgrestException) {
    if (_isSentence(error.message)) return error.message;
    if (error.code == '42501') return 'You do not have permission to do this.';
    if (error.code == '23505') {
      return 'That value is already used. Choose another one.';
    }
    if (error.code == '23503') {
      return 'This is still used elsewhere, so it cannot be removed.';
    }
    if (error.code == '23514' ||
        error.code == '22P02' ||
        error.code == '22023') {
      return 'Some details are not valid. Please check the form.';
    }
    return 'The server refused the change. Please try again.';
  }
  if (error is FunctionException) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return 'The server could not complete this (${error.status}).';
  }
  final text = error.toString();
  if (text.contains('ClientException') ||
      text.contains('Failed to fetch') ||
      text.contains('SocketException')) {
    return "Can't reach the server. Check your internet connection.";
  }
  return 'Something went wrong. Please try again.';
}

bool _isSentence(String message) {
  final trimmed = message.trim();
  return trimmed.isNotEmpty &&
      trimmed[0] == trimmed[0].toUpperCase() &&
      trimmed.endsWith('.') &&
      !trimmed.contains('violates') &&
      !trimmed.contains('relation "');
}
