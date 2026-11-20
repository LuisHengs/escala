/// Configuração vinda de --dart-define: nenhuma chave escrita no código.
/// A chave aqui é a PÚBLICA (publishable/anon). A service_role e o segredo do
/// Google NUNCA entram neste projeto.
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseChave = String.fromEnvironment('SUPABASE_KEY');

  static bool get configurado =>
      supabaseUrl.isNotEmpty && supabaseChave.isNotEmpty;
}
