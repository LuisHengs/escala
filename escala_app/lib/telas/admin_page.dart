import 'package:flutter/material.dart';

import '../data/escala_repository.dart';
import 'convites_page.dart';
import 'locais_page.dart';
import 'missas_page.dart';

/// O menu da área de administração. Cada item abre uma tela; novos itens
/// entram aqui conforme as telas ficam prontas.
///
/// O app só mostra o caminho até aqui para administradores, mas quem protege
/// de verdade é o banco: cada função confere o papel de quem chama.
class AdminPage extends StatelessWidget {
  final EscalaRepository repositorio;

  const AdminPage({super.key, required this.repositorio});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administração')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('Convites'),
            subtitle: const Text('Gerar o código de acesso de um coroinha'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ConvitesPage(repositorio: repositorio),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.church_outlined),
            title: const Text('Locais'),
            subtitle: const Text('Igrejas e capelas onde há missa'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LocaisPage(repositorio: repositorio),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Missas'),
            subtitle: const Text('Horários e locais das próximas missas'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MissasPage(repositorio: repositorio),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
