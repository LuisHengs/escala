import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/supabase_escala_repository.dart';
import 'telas/raiz.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Config.configurado) {
    runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Faltam SUPABASE_URL e SUPABASE_KEY.\n'
                'Rode com: --dart-define-from-file=env.json',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  await Supabase.initialize(
    url: Config.supabaseUrl,
    publishableKey: Config.supabaseChave,
  );

  runApp(
    MaterialApp(
      title: 'Escala Coroinhas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Raiz(
        repositorio: SupabaseEscalaRepository(Supabase.instance.client),
      ),
    ),
  );
}
