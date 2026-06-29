import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads Supabase credentials from the bundled `.env` file.
///
/// Never hard-code keys in source. Copy `.env.example` to `.env` and fill in
/// your project's URL and anon key (Supabase dashboard → Settings → API).
class AppConfig {
  AppConfig._();

  static String get supabaseUrl {
    final value = dotenv.env['SUPABASE_URL'];
    if (value == null || value.isEmpty) {
      throw StateError(
        'SUPABASE_URL is missing. Copy .env.example to .env and fill it in.',
      );
    }
    return value;
  }

  static String get supabaseAnonKey {
    final value = dotenv.env['SUPABASE_ANON_KEY'];
    if (value == null || value.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY is missing. Copy .env.example to .env and fill it in.',
      );
    }
    return value;
  }
}
