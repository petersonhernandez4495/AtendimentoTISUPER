// lib/novo_chamado_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NovoChamadoScreen extends StatefulWidget {
  const NovoChamadoScreen({super.key});

  @override
  State<NovoChamadoScreen> createState() => _NovoChamadoScreenState();
}

class _NovoChamadoScreenState extends State<NovoChamadoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  String? _urgenciaSelecionada; // Mantendo Urgência por enquanto
  String? _categoriaSelecionada;
  String? _departamentoSelecionado;
  final _equipamentoController = TextEditingController();
  String? _prioridadeSelecionada;
  final _tecnicoResponsavelController = TextEditingController();

  final List<String> _niveisUrgencia = ['Baixa', 'Média', 'Alta'];
  final List<String> _categorias = ['Hardware', 'Software', 'Rede', 'Acesso', 'Outro'];
  final List<String> _departamentos = [
    'Lotação',
    'Recursos Humanos',
    'GFISC',
    'NTE',
    'Transporte Escolar',
    'ADM/Financeiro/Nutrição',
    'LIE',
    'Inspeção Escolar',
    'Pedagógico',
  ];
  final List<String> _prioridades = ['Baixa', 'Média', 'Alta', 'Crítica'];

  Future<void> _enviarChamado() async {
    if (_formKey.currentState!.validate()) {
      final chamadosCollection = FirebaseFirestore.instance.collection('chamados');
      try {
        await chamadosCollection.add({
          'titulo': _tituloController.text.trim(),
          'descricao': _descricaoController.text.trim(),
          'urgencia': _urgenciaSelecionada,
          'categoria': _categoriaSelecionada,
          'departamento': _departamentoSelecionado,
          'equipamento': _equipamentoController.text.trim(),
          'prioridade': _prioridadeSelecionada,
          'tecnico_responsavel': _tecnicoResponsavelController.text.trim(),
          'status': 'aberto',
          'data_criacao': Timestamp.now(),
          // Adicione o ID do usuário logado aqui posteriormente
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chamado aberto com sucesso!')));
        _tituloController.clear();
        _descricaoController.clear();
        _equipamentoController.clear();
        _tecnicoResponsavelController.clear();
        setState(() {
          _urgenciaSelecionada = null;
          _categoriaSelecionada = null;
          _departamentoSelecionado = null;
          _prioridadeSelecionada = null;
        });

        // Navegar de volta para a lista de chamados
        Navigator.pushReplacementNamed(context, '/lista_chamados');

      } catch (error) {
        print('Erro ao abrir chamado: $error');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao abrir chamado. Tente novamente.')));
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
          child: SingleChildScrollView( // Para evitar overflow em telas menores
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
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
                  decoration: const InputDecoration(labelText: 'Urgência', border: OutlineInputBorder()),
                  value: _urgenciaSelecionada,
                  items: _niveisUrgencia.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                  onChanged: (newValue) => setState(() => _urgenciaSelecionada = newValue),
                  validator: (value) => value == null || value.isEmpty ? 'Por favor, selecione a urgência' : null,
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
                  items: _departamentos.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
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