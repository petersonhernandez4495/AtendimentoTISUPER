// lib/novo_chamado_screen.dart
import 'package:atendimento_ti_seduc/lista_chamados_screen.dart'; // <--- IMPORT ADICIONADO
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Importe a tela da lista de chamados para poder navegar para ela
// Certifique-se que o caminho do import está correto
// import 'lista_chamados_screen.dart';

class NovoChamadoScreen extends StatefulWidget {
  const NovoChamadoScreen({super.key});

  @override
  State<NovoChamadoScreen> createState() => _NovoChamadoScreenState();
}

class _NovoChamadoScreenState extends State<NovoChamadoScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controllers e variáveis de estado (mantidos do seu código)
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  String? _urgenciaSelecionada; // Você pode remover 'Urgência' se 'Prioridade' for suficiente
  String? _categoriaSelecionada;
  String? _departamentoSelecionado;
  final _equipamentoController = TextEditingController();
  String? _prioridadeSelecionada;
  final _tecnicoResponsavelController = TextEditingController(); // Opcional

  // Listas para Dropdowns (mantidas do seu código)
  final List<String> _niveisUrgencia = ['Baixa', 'Média', 'Alta'];
  final List<String> _categorias = ['Hardware', 'Software', 'Rede', 'Acesso', 'Outro'];
  final List<String> _departamentos = [
    'Lotação', 'Recursos Humanos', 'GFISC', 'NTE', 'Transporte Escolar',
    'ADM/Financeiro/Nutrição', 'LIE', 'Inspeção Escolar', 'Pedagógico',
  ];
  // Ajuste: Prioridade pode ser diferente de Urgência. Mantenha ambas se necessário.
  final List<String> _prioridades = ['Baixa', 'Média', 'Alta', 'Crítica'];

  // Dispose controllers quando o widget for descartado
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
    // 1. Valida o formulário
    if (_formKey.currentState!.validate()) {
      // 2. Mostra diálogo de carregamento
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
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

      // 3. Prepara os dados para o Firestore
      final dadosChamado = {
        'titulo': _tituloController.text.trim(),
        'descricao': _descricaoController.text.trim(),
        // 'urgencia': _urgenciaSelecionada, // Descomente se ainda usar urgência
        'categoria': _categoriaSelecionada,
        'departamento': _departamentoSelecionado,
        'equipamento': _equipamentoController.text.trim(),
        'prioridade': _prioridadeSelecionada, // Usando prioridade
        'tecnico_responsavel': _tecnicoResponsavelController.text.trim().isEmpty
            ? null // Salva null se vazio
            : _tecnicoResponsavelController.text.trim(),
        'status': 'aberto', // Status inicial
        'data_criacao': FieldValue.serverTimestamp(), // Usa timestamp do servidor
        'data_atualizacao': FieldValue.serverTimestamp(), // Data da última atualização
        // 'userId': FirebaseAuth.instance.currentUser?.uid, // Exemplo: Adicionar ID do usuário logado
      };

      // 4. Tenta salvar no Firestore
      try {
        final chamadosCollection = FirebaseFirestore.instance.collection('chamados');
        await chamadosCollection.add(dadosChamado);

        // 5. Fecha o diálogo de carregamento (SUCESSO)
        // Usar rootNavigator: true é importante para fechar diálogos sobrepostos
        if (mounted) Navigator.of(context, rootNavigator: true).pop();

        // 6. Mostra mensagem de sucesso
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chamado aberto com sucesso!')));

          // 7. Navega para a Lista de Chamados, removendo as telas anteriores
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const ListaChamadosScreen()),
            (Route<dynamic> route) => false, // Remove todas as rotas anteriores
          );
        }
      } catch (error) {
        // 5. Fecha o diálogo de carregamento (ERRO)
        if (mounted) Navigator.of(context, rootNavigator: true).pop();

        // 6. Mostra mensagem de erro
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView( // Mantido para evitar overflow
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // --- Campos do Formulário (mantidos do seu código) ---
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
                // Removi o Dropdown de Urgência, assumindo que Prioridade é suficiente.
                // Se precisar de ambos, descomente e ajuste.
                // DropdownButtonFormField<String>(
                //   decoration: const InputDecoration(labelText: 'Urgência', border: OutlineInputBorder()),
                //   value: _urgenciaSelecionada,
                //   items: _niveisUrgencia.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                //   onChanged: (newValue) => setState(() => _urgenciaSelecionada = newValue),
                //   validator: (value) => value == null || value.isEmpty ? 'Por favor, selecione a urgência' : null,
                // ),
                // const SizedBox(height: 16.0),
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
                  // Melhora para o Dropdown não cortar texto longo
                  isExpanded: true, // Permite que o item ocupe mais espaço horizontal
                   items: _departamentos.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        overflow: TextOverflow.ellipsis, // Adiciona '...' se for muito longo
                      ),
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
                  // Sem validação obrigatória para campo opcional
                ),
                const SizedBox(height: 24.0),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0) // Botão um pouco maior
                  ),
                  onPressed: _enviarChamado,
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