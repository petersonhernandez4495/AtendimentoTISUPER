// lib/novo_chamado_screen.dart
// --- Import da tela principal de navegação ---
import 'package:atendimento_ti_seduc/main_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NovoChamadoScreen extends StatefulWidget {
  const NovoChamadoScreen({super.key});

  @override
  State<NovoChamadoScreen> createState() => _NovoChamadoScreenState();
}

class _NovoChamadoScreenState extends State<NovoChamadoScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- Título agora é Dropdown ---
  String? _tituloSelecionado; // <<< USA ESTADO EM VEZ DE CONTROLLER
  // --- LISTA DE TÍTULOS (!!! SUBSTITUA PELAS SUAS OPÇÕES REAIS !!!) ---
  final List<String> _listaTitulosExemplo = [
    'Problema com Impressora', 'Erro de Acesso ao Sistema', 'Computador não Liga',
    'Rede Lenta ou Indisponível', 'Solicitação de Software', 'Problema com Email',
    'Outro (Detalhar na Descrição)'
  ];
  // --------------------------------------------------------------------

  // Outros controllers e variáveis de estado
  final _descricaoController = TextEditingController();
  String? _categoriaSelecionada;
  final List<String> _categorias = ['Hardware', 'Software', 'Rede', 'Acesso', 'Outro'];
  String? _departamentoSelecionado;
  final List<String> _departamentos = [ 'Lotação', 'Recursos Humanos', 'GFISC', 'NTE', 'Transporte Escolar', 'ADM/Financeiro/Nutrição', 'LIE', 'Inspeção Escolar', 'Pedagógico', ];
  final _equipamentoController = TextEditingController();
  String? _prioridadeSelecionada;
  final List<String> _prioridades = ['Baixa', 'Média', 'Alta', 'Crítica'];
  final _tecnicoResponsavelController = TextEditingController();
  bool _isLoading = false; // Para botão de carregamento

  @override
  void dispose() {
    // _tituloController.dispose(); // Não existe mais
    _descricaoController.dispose();
    _equipamentoController.dispose();
    _tecnicoResponsavelController.dispose();
    super.dispose();
  }

  Future<void> _enviarChamado() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
         if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Erro: Você precisa estar logado.'))); setState(() { _isLoading = false; }); }
        return;
      }
      final creatorUid = user.uid;
      final creatorName = user.displayName?.isNotEmpty ?? false ? user.displayName! : "Usuário Desconhecido";

      // --- Buscar telefone do perfil do usuário no Firestore ---
      String creatorPhone = "Telefone não informado"; // Valor padrão
      try {
          final userProfileDoc = await FirebaseFirestore.instance.collection('users').doc(creatorUid).get();
          if (userProfileDoc.exists && userProfileDoc.data() != null) {
              // Use 'phone' ou o nome EXATO do campo salvo no cadastro
              creatorPhone = userProfileDoc.data()!['phone'] as String? ?? creatorPhone;
              print("Telefone do criador encontrado: $creatorPhone");
          } else { print("Documento de perfil não encontrado para UID: $creatorUid"); }
      } catch (e) { print("Erro ao buscar telefone do usuário $creatorUid: $e"); }
      // ---------------------------------------------------------

      // Prepara os dados para o Firestore
      final dadosChamado = {
        'titulo': _tituloSelecionado, // <<< USA O VALOR DO DROPDOWN
        'descricao': _descricaoController.text.trim(),
        'categoria': _categoriaSelecionada,
        'departamento': _departamentoSelecionado,
        'equipamento': _equipamentoController.text.trim(),
        'prioridade': _prioridadeSelecionada,
        'tecnico_responsavel': _tecnicoResponsavelController.text.trim().isEmpty ? null : _tecnicoResponsavelController.text.trim(),
        'status': 'aberto',
        'data_criacao': FieldValue.serverTimestamp(),
        'data_atualizacao': FieldValue.serverTimestamp(),
        'creatorUid': creatorUid,
        'creatorName': creatorName,
        'creatorPhone': creatorPhone, // <<< SALVA O TELEFONE NO CHAMADO
      };

      // Tenta salvar no Firestore
      try {
        final chamadosCollection = FirebaseFirestore.instance.collection('chamados');
        await chamadosCollection.add(dadosChamado);

        if (mounted) {
          // Limpar campos após sucesso
           _descricaoController.clear();
           _equipamentoController.clear();
           _tecnicoResponsavelController.clear();
           setState(() { // Reseta os dropdowns
              _tituloSelecionado = null; // <<< RESETA TÍTULO
              _categoriaSelecionada = null;
              _departamentoSelecionado = null;
              _prioridadeSelecionada = null;
           });

          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chamado aberto com sucesso!')));
          // --- NAVEGAÇÃO CORRIGIDA ---
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainNavigationScreen()), // <<< VAI PARA A TELA PRINCIPAL
            (Route<dynamic> route) => false,
          );
          // ---------------------------
        }
      } catch (error) {
        print('Erro ao abrir chamado: $error');
         if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar( content: Text('Erro ao abrir chamado. Tente novamente.'))); }
      } finally {
         if (mounted) { setState(() { _isLoading = false; }); }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Assume que esta tela PODE ter seu próprio Scaffold/AppBar,
    // mesmo sendo uma aba da MainNavigationScreen, pois é um formulário completo.
    // Se preferir SEM AppBar aqui, remova o Scaffold e AppBar.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abrir Novo Chamado'),
         automaticallyImplyLeading: false, // Remove botão voltar se está numa aba
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // --- CAMPO TÍTULO COMO DROPDOWN ---
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Título (Selecione)', border: OutlineInputBorder()),
                  value: _tituloSelecionado,
                  hint: const Text('Selecione o tipo de problema'), // Ajuda o usuário
                  // !!! SUBSTITUA _listaTitulosExemplo PELA SUA LISTA REAL !!!
                  items: _listaTitulosExemplo.map((String titulo) {
                    return DropdownMenuItem<String>(
                      value: titulo,
                      child: Text(titulo, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: _isLoading ? null : (String? newValue) {
                    setState(() { _tituloSelecionado = newValue; });
                  },
                  validator: (value) => value == null ? 'Selecione um título' : null,
                  isExpanded: true,
                ),
                // ----------------------------------
                const SizedBox(height: 16.0),
                TextFormField( controller: _descricaoController, enabled: !_isLoading, maxLines: 3, decoration: const InputDecoration(labelText: 'Descrição Detalhada', border: OutlineInputBorder()), validator: (v) => (v == null || v.isEmpty) ? 'Digite uma descrição' : null, ),
                const SizedBox(height: 16.0),
                DropdownButtonFormField<String>( decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()), value: _categoriaSelecionada, items: _categorias.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: _isLoading ? null : (v) => setState(() => _categoriaSelecionada = v), validator: (v) => v == null ? 'Selecione' : null, ),
                const SizedBox(height: 16.0),
                DropdownButtonFormField<String>( decoration: const InputDecoration(labelText: 'Departamento', border: OutlineInputBorder()), value: _departamentoSelecionado, isExpanded: true, items: _departamentos.map((v) => DropdownMenuItem(value: v, child: Text( v, overflow: TextOverflow.ellipsis))).toList(), onChanged: _isLoading ? null : (v) => setState(() => _departamentoSelecionado = v), validator: (v) => v == null ? 'Selecione' : null, ),
                const SizedBox(height: 16.0),
                TextFormField( controller: _equipamentoController, enabled: !_isLoading, decoration: const InputDecoration(labelText: 'Equipamento/Sistema Afetado', border: OutlineInputBorder()), validator: (v) => (v == null || v.isEmpty) ? 'Digite o equipamento' : null, ),
                const SizedBox(height: 16.0),
                DropdownButtonFormField<String>( decoration: const InputDecoration(labelText: 'Prioridade', border: OutlineInputBorder()), value: _prioridadeSelecionada, items: _prioridades.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: _isLoading ? null : (v) => setState(() => _prioridadeSelecionada = v), validator: (v) => v == null ? 'Selecione' : null, ),
                const SizedBox(height: 16.0),
                TextFormField( controller: _tecnicoResponsavelController, enabled: !_isLoading, decoration: const InputDecoration(labelText: 'Técnico Responsável (Opcional)', border: OutlineInputBorder()), ),
                const SizedBox(height: 24.0),
                ElevatedButton(
                  style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 16.0), textStyle: const TextStyle(fontSize: 16) ),
                  onPressed: _isLoading ? null : _enviarChamado,
                  child: _isLoading ? const SizedBox( width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white), ) : const Text('Enviar Chamado'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}