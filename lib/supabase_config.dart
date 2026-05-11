/// Supabase Konfiguration
/// Werte aus: https://supabase.com/dashboard/project/<dein-projekt>/settings/api
class SupabaseConfig {
  /// Deine Projekt-URL (z.B. https://xyzabc.supabase.co)
  static const String url = 'https://bvwppinkkuolvtxjeiue.supabase.co';

  /// Öffentlicher Anon-Key
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2d3BwaW5ra3VvbHZ0eGplaXVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0OTM1OTUsImV4cCI6MjA5MTA2OTU5NX0.KMffFIJwtmDO5QaEmTYwNB8sXWA08EbeDCG5X1LOAGk';

  static bool get isConfigured =>
      url != 'YOUR_SUPABASE_URL' && anonKey != 'YOUR_SUPABASE_ANON_KEY';
}
