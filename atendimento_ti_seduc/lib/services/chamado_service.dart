// lib/services/chamado_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart'; // Para desmascarar

// Importe suas constantes se movê-las para um arquivo separado
// ou redefina as necessárias aqui.
// Assumindo que as constantes kField... estão definidas em algum lugar acessível
// ou você pode redefini-las aqui ou passar como strings.
// Exemplo: import '../constants.dart';
// Por ora, usaremos as strings diretamente ou as constantes do import temporário:
import '../novo_chamado_screen.dart'; // Temporário para constantes de 'novo_chamado_screen'

// --- Constante para o novo campo de inatividade administrativa ---
const String kFieldAdminInativo = 'isAdministrativamenteInativo';
// (Certifique-se que as outras constantes como kFieldTipoSolicitante, etc.
//  estejam acessíveis, seja por este import temporário ou um arquivo dedicado)
const String kCollectionChamados = 'chamados'; // Definindo aqui se não vier do import

class ChamadoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Usado para remover a máscara do telefone antes de salvar
  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  /// Método para criar um novo chamado no Firestore.
  /// Inclui o campo 'isAdministrativamenteInativo' inicializado como false.
  Future<String> criarChamado({
    required String? tipoSelecionado,
    required String celularContato,
    required String? equipamentoSelecionado,
    required String? internetConectadaSelecionado,
    required String marcaModelo,
    required String patrimonio,
    required String? problemaSelecionado,
    required String tecnicoResponsavel,
    required String? cidadeSelecionada,
    required String? instituicaoSelecionada,
    required String? cargoSelecionado,
    required String? atendimentoParaSelecionado,
    required bool isProfessorSelecionado,
    required String? setorSuperSelecionado,
    required String cidadeSuper,
    required String instituicaoManual,
    required String equipamentoOutro,
    required String problemaOutro,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final String nomeFinalSolicitante = user.displayName?.trim().isNotEmpty ?? false
        ? user.displayName!.trim()
        : (user.email ?? "Usuário App (${user.uid.substring(0, 6)})");
    final String creatorUid = user.uid;
    final String creatorPhone = celularContato.trim();
    // Remove a máscara para salvar limpo
    final String unmaskedPhone = _phoneMaskFormatter.unmaskText(creatorPhone);

    final dadosChamado = <String, dynamic>{
      kFieldTipoSolicitante: tipoSelecionado,
      kFieldNomeSolicitante: nomeFinalSolicitante,
      kFieldCelularContato: creatorPhone, // Salva com máscara
      'celular_contato_unmasked': unmaskedPhone, // Salva sem máscara
      'equipamento_solicitacao': equipamentoSelecionado,
      'equipamento_conectado_internet': internetConectadaSelecionado,
      'marca_modelo_equipamento': marcaModelo.trim().isEmpty ? null : marcaModelo.trim(),
      'numero_patrimonio': patrimonio.trim(), // Garante trim
      'problema_ocorre': problemaSelecionado,
      // Salva null se o técnico for vazio após trim
      'tecnico_responsavel': tecnicoResponsavel.trim().isEmpty ? null : tecnicoResponsavel.trim(),
      'status': 'aberto', // Status operacional inicial
      'prioridade': 'Média', // Prioridade inicial padrão
      'data_criacao': FieldValue.serverTimestamp(),
      'data_atualizacao': FieldValue.serverTimestamp(),
      'creatorUid': creatorUid,
      'creatorName': nomeFinalSolicitante,
      'creatorPhone': creatorPhone, // Pode ser útil para consulta rápida
      'authUserDisplayName': user.displayName,
      'authUserEmail': user.email,

       // <<< Campo de inatividade administrativa inicializado >>>
      kFieldAdminInativo: false,

       // Campos condicionais baseados no tipo
      if (tipoSelecionado == 'ESCOLA') ...{
        kFieldCidade: cidadeSelecionada,
        'cargo_funcao': cargoSelecionado,
        'atendimento_para': atendimentoParaSelecionado,
        if (isProfessorSelecionado) 'observacao_cargo': 'Solicitante é Professor...',

        // Lógica para Instituição
        if (cidadeSelecionada == "OUTRO") ...{
          kFieldInstituicaoManual: instituicaoManual.trim(),
          kFieldInstituicao: 'OUTRO (Ver $kFieldInstituicaoManual)',
        } else ...{
          kFieldInstituicao: instituicaoSelecionada,
          kFieldInstituicaoManual: null,
        },
      } else if (tipoSelecionado == 'SUPERINTENDENCIA') ...{
        'setor_superintendencia': setorSuperSelecionado,
        kFieldCidadeSuperintendencia: cidadeSuper.trim(),
      },

      // Campos condicionais para "OUTRO" (com trim)
      kFieldEquipamentoOutro: equipamentoSelecionado == "OUTRO" ? equipamentoOutro.trim() : null,
      kFieldProblemaOutro: problemaSelecionado == "OUTRO" ? problemaOutro.trim() : null,
    };

    try {
      final docRef = await _db.collection(kCollectionChamados).add(dadosChamado);
      print("Chamado criado com ID: ${docRef.id}");
      return docRef.id;
    } catch (e, s) {
      print('Erro ao salvar chamado no Firestore: $e');
      print(s);
      // Re-lança a exceção para ser tratada na UI
      throw Exception('Falha ao salvar os dados do chamado. $e');
    }
  }

  /// Define se um chamado está administrativamente inativo (Ação de Admin).
  /// Atualiza o campo 'isAdministrativamenteInativo' e a data de atualização.
  /// A verificação se o usuário é Admin deve ser feita ANTES de chamar este método
  /// ou através de regras de segurança do Firestore.
  Future<void> definirInatividadeAdministrativa(String chamadoId, bool inativo) async {
    if (chamadoId.isEmpty) {
      throw ArgumentError('ID do chamado não pode ser vazio.');
    }
    // TODO: Considerar adicionar verificação de Admin aqui se não usar regras de segurança robustas
    // final isAdmin = await _checkCurrentUserAdmin(); // Exemplo
    // if (!isAdmin) throw Exception('Apenas administradores podem realizar esta ação.');

    final docRef = _db.collection(kCollectionChamados).doc(chamadoId);
    print('Definindo inatividade administrativa do chamado $chamadoId para $inativo');

    try {
      await docRef.update({
        kFieldAdminInativo: inativo, // Atualiza o campo booleano
        'data_atualizacao': FieldValue.serverTimestamp(), // Atualiza timestamp
        // Opcional: Registrar quem alterou
        // 'inatividadeAlteradaPorUid': _auth.currentUser?.uid,
      });
      print('Inatividade administrativa do chamado $chamadoId definida como $inativo com sucesso.');
    } catch (e, s) {
      print('Erro ao definir inatividade administrativa do chamado $chamadoId: $e');
      print(s);
      // Re-lança para ser tratado na UI
      throw Exception('Falha ao definir inatividade administrativa. $e');
    }
  }

  /// Atualiza o status operacional e opcionalmente a prioridade e o técnico responsável.
  /// (Método corrigido para aceitar parâmetros nomeados opcionais)
  Future<void> atualizarStatusOperacional(
    String chamadoId,
    String novoStatus, { // Status ainda é obrigatório posicional
    String? prioridade, // Parâmetro nomeado opcional
    String? tecnicoResponsavel, // Parâmetro nomeado opcional
  }) async {
    if (chamadoId.isEmpty || novoStatus.isEmpty) {
        throw ArgumentError('ID do chamado e novo status não podem ser vazios.');
    }
    // TODO: Adicionar verificação de permissão (ex: só admin ou técnico pode editar?)

    final docRef = _db.collection(kCollectionChamados).doc(chamadoId);
    print('Atualizando chamado $chamadoId: Status=$novoStatus, Prioridade=$prioridade, Técnico=$tecnicoResponsavel');

    // Cria o mapa de dados para atualização APENAS com os campos obrigatórios
    final Map<String, dynamic> dataToUpdate = {
      'status': novoStatus,
      'data_atualizacao': FieldValue.serverTimestamp(),
    };

    // Adiciona campos opcionais AO MAPA SE eles foram fornecidos (não são nulos)
    if (prioridade != null) {
      dataToUpdate['prioridade'] = prioridade;
    }
    // Adiciona tecnico_responsavel se fornecido, tratando string vazia como null
    if (tecnicoResponsavel != null) {
      dataToUpdate['tecnico_responsavel'] = tecnicoResponsavel.trim().isEmpty ? null : tecnicoResponsavel.trim();
    }
    // Se um parâmetro opcional for null na chamada, ele NÃO será adicionado ao mapa 'dataToUpdate'

    try {
        await docRef.update(dataToUpdate); // Atualiza com os dados definidos no mapa
        print('Chamado $chamadoId atualizado com sucesso.');
    } catch (e, s) {
        print('Erro ao atualizar status operacional/outros $chamadoId: $e');
        print(s);
        throw Exception('Falha ao atualizar status operacional. $e');
    }
  }

  // Você pode adicionar outros métodos aqui, como buscar chamados, etc.
  // Exemplo: Função auxiliar para verificar se usuário é admin (se não usar claims)
  // Future<bool> _checkCurrentUserAdmin() async { ... lógica ... }

}