import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://ymsnnnhdxkgeamqbfiqs.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inltc25ubmhkeGtnZWFtcWJmaXFzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxNjQwOTEsImV4cCI6MjA2Nzc0MDA5MX0.u8WyiUsz_Nr_nitQkItFt7EG5_Fk4RY6O2EjKtUQWUc';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}

final supabase = Supabase.instance.client;
