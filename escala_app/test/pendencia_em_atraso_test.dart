import 'package:flutter_test/flutter_test.dart';
import 'package:escala_app/data/pendencia_em_atraso.dart';

void main() {
  group('PendenciaEmAtraso', () {
    final json = {
      'escalacao_id': 'esc-001',
      'missa_id': 'missa-001',
      'inicio': '2026-11-21T10:00:00Z',
      'coroinha_id': 'cor-001',
      'coroinha_nome': 'João',
      'funcao': 'Turiferário',
    };

    test('converte corretamente os dados retornados pelo Supabase', () {
      final pendencia = PendenciaEmAtraso.deJson(json);

      expect(pendencia.escalacaoId, 'esc-001');
      expect(pendencia.missaId, 'missa-001');
      expect(
        pendencia.inicio,
        DateTime.parse('2026-11-21T10:00:00Z').toLocal(),
      );
      expect(pendencia.coroinhaId, 'cor-001');
      expect(pendencia.coroinhaNome, 'João');
      expect(pendencia.funcao, 'Turiferário');
    });

    test('ordena as pendências pelo horário da missa', () {
      final linhas = [
        {...json, 'escalacao_id': 'esc-002', 'inicio': '2026-11-22T10:00:00Z'},
        {...json, 'escalacao_id': 'esc-001', 'inicio': '2026-11-21T10:00:00Z'},
      ];

      final resultado = PendenciaEmAtraso.listaDeJson(linhas);

      expect(resultado.first.escalacaoId, 'esc-001');
      expect(resultado.last.escalacaoId, 'esc-002');
    });

    test('ordena pelo nome quando os horários são iguais', () {
      final linhas = [
        {...json, 'coroinha_nome': 'Maria'},
        {...json, 'coroinha_nome': 'Ana'},
      ];

      final resultado = PendenciaEmAtraso.listaDeJson(linhas);

      expect(resultado.first.coroinhaNome, 'Ana');
      expect(resultado.last.coroinhaNome, 'Maria');
    });

    test('lança erro quando o horário é inválido', () {
      final dadosInvalidos = {...json, 'inicio': 'data-invalida'};

      expect(
        () => PendenciaEmAtraso.deJson(dadosInvalidos),
        throwsFormatException,
      );
    });
  });
}
