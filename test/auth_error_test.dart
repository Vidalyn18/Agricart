import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/services/supabase_service.dart';

void main() {
  test('authentication errors use friendly email-specific messages', () {
    expect(
      SupabaseService.errorMessage(
        AuthException('Invalid login credentials', statusCode: '400'),
      ),
      'Incorrect email or password.',
    );
    expect(
      SupabaseService.errorMessage(
        AuthException('User already registered', statusCode: '422'),
      ),
      'This email is already registered. Log in or use a different email.',
    );
    expect(
      SupabaseService.errorMessage(
        PostgrestException(
          message: '{"code":"PGRST205","message":"schema cache"}',
          code: 'PGRST205',
        ),
      ),
      'Profile data could not be loaded. Please try again.',
    );
  });
}
