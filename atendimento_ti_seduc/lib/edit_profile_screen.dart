import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>(); // Chave para o formulário
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _institutionController = TextEditingController();

  User? _currentUser;
  bool _isLoading = true; // Para loading inicial
  bool _isSaving = false; // Para loading ao salvar
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _loadInitialData();
    } else {
      // Se não houver usuário logado, não deveria estar nesta tela
      // Poderia navegar de volta ou mostrar um erro permanente
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Usuário não autenticado.";
        });
      }
    }
  }

  @override
  void dispose() {
    // Limpa os controladores quando o widget for descartado
    _nameController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    _institutionController.dispose();
    super.dispose();
  }

  // Carrega os dados atuais do Firestore para preencher os campos
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>? ?? {};
        // Preenche os controladores com os dados existentes
        // Usa o displayName do Auth como prioridade se existir, senão o 'name' do Firestore
        _nameController.text = _currentUser!.displayName?.isNotEmpty ?? false
            ? _currentUser!.displayName!
            : (data['name'] as String? ?? '');
        _phoneController.text = data['phone'] as String? ?? '';
        _jobTitleController.text = data['jobTitle'] as String? ?? '';
        _institutionController.text = data['institution'] as String? ?? '';
      } else if (mounted) {
        // Se o documento não existe, preenche o nome com o displayName do Auth se disponível
         _nameController.text = _currentUser!.displayName?.isNotEmpty ?? false
            ? _currentUser!.displayName!
            : '';
         // Os outros campos ficam vazios
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Erro ao carregar dados para edição: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Erro ao carregar dados do perfil.";
        });
      }
    }
  }

  // Salva as alterações no Firestore e no Auth (displayName)
  Future<void> _saveProfile() async {
    // Valida o formulário
    if (!_formKey.currentState!.validate()) {
      return; // Não prossegue se a validação falhar
    }

    if (_currentUser == null || !mounted) return;

    setState(() => _isSaving = true); // Ativa o indicador de salvamento

    // Pega os novos valores dos controladores
    final newName = _nameController.text.trim();
    final newPhone = _phoneController.text.trim();
    final newJobTitle = _jobTitleController.text.trim();
    final newInstitution = _institutionController.text.trim();

    try {
      // 1. Atualiza o documento no Firestore
      await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).set({
        // Usamos .set com merge:true para criar o doc se não existir,
        // ou atualizar os campos se já existir.
        'name': newName, // Guarda o nome também no Firestore
        'phone': newPhone,
        'jobTitle': newJobTitle,
        'institution': newInstitution,
        // Mantém o email caso ele já exista no documento, ou adiciona se for o primeiro save
        'email': _currentUser!.email,
      }, SetOptions(merge: true)); // merge:true é importante para não sobrescrever outros campos existentes

      // 2. Atualiza o displayName no Firebase Auth se ele mudou
      if (_currentUser!.displayName != newName) {
        await _currentUser!.updateDisplayName(newName);
        // Opcional: recarregar o usuário para garantir que _currentUser está atualizado
        // await _currentUser!.reload();
        // _currentUser = FirebaseAuth.instance.currentUser;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso!'), backgroundColor: Colors.green),
        );
        // Retorna para a tela anterior (ProfileScreen) indicando sucesso
        Navigator.pop(context, true); // Passa 'true' para indicar que houve atualização
      }

    } catch (e) {
      print("Erro ao salvar perfil: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar perfil: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Garante que o indicador de salvamento seja desativado
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        actions: [
          // Botão Salvar na AppBar
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isSaving
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                : IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _saveProfile,
                    tooltip: 'Salvar Alterações',
                  ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    // Se não está carregando e não há erro, mostra o formulário
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Campo Nome
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome Completo',
              hintText: 'Como você gostaria de ser chamado',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Por favor, informe seu nome.';
              }
              return null;
            },
            textInputAction: TextInputAction.next, // Vai para o próximo campo
          ),
          const SizedBox(height: 16),

          // Campo Telefone
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Telefone',
              hintText: '(XX) XXXXX-XXXX (Opcional)',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            // Nenhuma validação obrigatória aqui, pode ser opcional
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          // Campo Cargo/Função
          TextFormField(
            controller: _jobTitleController,
            decoration: const InputDecoration(
              labelText: 'Cargo / Função',
              hintText: 'Ex: Desenvolvedor, Analista, Gerente (Opcional)',
              prefixIcon: Icon(Icons.work_outline),
              border: OutlineInputBorder(),
            ),
            // Nenhuma validação obrigatória
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          // Campo Instituição/Lotação
          TextFormField(
            controller: _institutionController,
            decoration: const InputDecoration(
              labelText: 'Instituição / Lotação',
              hintText: 'Onde você trabalha ou estuda (Opcional)',
              prefixIcon: Icon(Icons.account_balance_outlined),
              border: OutlineInputBorder(),
            ),
            // Nenhuma validação obrigatória
            textInputAction: TextInputAction.done, // Último campo
             onEditingComplete: _saveProfile, // Opcional: Salvar ao pressionar Done no teclado
          ),
          const SizedBox(height: 30),

           // Botão Salvar (alternativa ao da AppBar)
           /* ElevatedButton.icon(
             icon: Icon(Icons.save),
             label: Text('Salvar Alterações'),
             onPressed: _isSaving ? null : _saveProfile, // Desabilita enquanto salva
             style: ElevatedButton.styleFrom(
               padding: EdgeInsets.symmetric(vertical: 12),
               textStyle: TextStyle(fontSize: 16)
             ),
           ),
           if (_isSaving) ...[ // Mostra indicador abaixo do botão se estiver salvando
             const SizedBox(height: 10),
             const Center(child: CircularProgressIndicator()),
           ] */
        ],
      ),
    );
  }
}