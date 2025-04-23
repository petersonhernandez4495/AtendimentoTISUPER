// lib/novo_chamado_screen.dart
import 'package:atendimento_ti_seduc/lista_chamados_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// --- Import do Firebase Auth ---
import 'package:firebase_auth/firebase_auth.dart'; // <--- ADICIONAR IMPORT
// --------------------------------

class NovoChamadoScreen extends StatefulWidget {
  // Adicionando construtor const se não houver parâmetros obrigatórios
  const NovoChamadoScreen({super.key});

  @override
  State<NovoChamadoScreen> createState() => _NovoChamadoScreenState();
}

class _NovoChamadoScreenState extends State<NovoChamadoScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controllers e variáveis de estado
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  String? _categoriaSelecionada;
  String? _departamentoSelecionado;
  final _equipamentoController = TextEditingController();
  String? _prioridadeSelecionada;
  final _tecnicoResponsavelController = TextEditingController(); // Opcional

  // Listas para Dropdowns
  // Removi Urgência, mantendo Prioridade. Ajuste se usar ambos.
  final List<String> _categorias = ['Hardware', 'Software', 'Rede', 'Acesso', 'Outro'];
  final List<String> _departamentos = [
    'Lotação', 'Recursos Humanos', 'GFISC', 'NTE', 'Transporte Escolar',
    'ADM/Financeiro/Nutrição', 'LIE', 'Inspeção Escolar', 'Pedagógico',
  ];
  final List<String> _prioridades = ['Baixa', 'Média', 'Alta', 'Crítica'];

  // Dispose controllers
  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _equipamentoController.dispose();
    _tecnicoResponsavelController.dispose();
    super.dispose();
  }

  // Função atualizada para enviar chamado
  Future<void> _enviarChamado() async {
    if (_formKey.currentState!.validate()) {
      // --- Obter Usuário Logado ---
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Se o usuário não estiver logado, mostrar erro e parar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Erro: Você precisa estar logado para criar um chamado.'))
          );
        }
        print("Erro: Usuário não está logado ao tentar criar chamado.");
        return; // Interrompe a execução
      }
      final creatorUid = user.uid;
      // Tenta pegar o nome de exibição, usa "Desconhecido" se for nulo
      final creatorName = user.displayName?.isNotEmpty ?? false ? user.displayName! : "Usuário Desconhecido";
      // -----------------------------

      // Mostra diálogo de carregamento
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) { /* ... diálogo de carregamento ... */
           return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text("Enviando chamado..."),
                ],
              ),
            ),
          );
        },
      );

      // Prepara os dados para o Firestore
      final dadosChamado = {
        'titulo': _tituloController.text.trim(),
        'descricao': _descricaoController.text.trim(),
        'categoria': _categoriaSelecionada,
        'departamento': _departamentoSelecionado,
        'equipamento': _equipamentoController.text.trim(),
        'prioridade': _prioridadeSelecionada,
        'tecnico_responsavel': _tecnicoResponsavelController.text.trim().isEmpty
            ? null
            : _tecnicoResponsavelController.text.trim(),
        'status': 'aberto',
        'data_criacao': FieldValue.serverTimestamp(),
        'data_atualizacao': FieldValue.serverTimestamp(),
        // --- Adiciona informações do criador ---
        'creatorUid': creatorUid,
        'creatorName': creatorName, // Salva o nome para fácil acesso
        // ---------------------------------------
      };

      // Tenta salvar no Firestore
      try {
        final chamadosCollection = FirebaseFirestore.instance.collection('chamados');
        await chamadosCollection.add(dadosChamado);

        // Fecha o diálogo (SUCESSO)
        if (mounted) Navigator.of(context, rootNavigator: true).pop();

        // Mostra mensagem e Navega (SUCESSO)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chamado aberto com sucesso!')));
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const ListaChamadosScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } catch (error) {
        // Fecha o diálogo (ERRO)
        if (mounted) Navigator.of(context, rootNavigator: true).pop();

        // Mostra mensagem (ERRO)
        print('Erro ao abrir chamado: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Erro ao abrir chamado. Tente novamente.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abrir Novo Chamado'),
      ),
      // O body com SingleChildScrollView e Form é mantido como no seu código anterior
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // --- Campos do Formulário (mantidos) ---
                 TextFormField(
                  controller: _tituloController,
                  decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
                  validator: (value) => value == null || value.isEmpty ? 'Por favor, digite um título' : null,
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _descricaoController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder()),
                  validator: (value) => value == null || value.isEmpty ? 'Por favor, digite uma descrição' : null,
                ),
                const SizedBox(height: 16.0),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                  value: _categoriaSelecionada,
                  items: _categorias.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                  onChanged: (newValue) => setState(() => _categoriaSelecionada = newValue),
                  validator: (value) => value == null || value.isEmpty ? 'Por favor, selecione a categoria' : null,
                ),
                const SizedBox(height: 16.0),
                DropdownButtonFormField<String>(
                   decoration: const InputDecoration(labelText: 'Departamento', border: OutlineInputBorder()),
                  value: _departamentoSelecionado,
                  isExpanded: true,
                   items: _departamentos.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text( value, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (newValue) => setState(() => _departamentoSelecionado = newValue),
                  validator: (value) => value == null || value.isEmpty ? 'Por favor, selecione o departamento' : null,
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _equipamentoController,
                  decoration: const InputDecoration(labelText: 'Equipamento/Sistema Afetado', border: OutlineInputBorder()),
                  validator: (value) => value == null || value.isEmpty ? 'Por favor, digite o equipamento/sistema afetado' : null,
                ),
                const SizedBox(height: 16.0),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Prioridade', border: OutlineInputBorder()),
                  value: _prioridadeSelecionada,
                  items: _prioridades.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                  onChanged: (newValue) => setState(() => _prioridadeSelecionada = newValue),
                  validator: (value) => value == null || value.isEmpty ? 'Por favor, selecione a prioridade' : null,
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _tecnicoResponsavelController,
                  decoration: const InputDecoration(labelText: 'Técnico Responsável (Opcional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24.0),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0)
                  ),
                  onPressed: _enviarChamado, // Chama a função atualizada
                  child: const Text('Enviar Chamado'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}