import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Você pode acessar propriedades específicas do tema se precisar:
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final TextStyle? titleStyle = Theme.of(context).textTheme.headlineSmall;

    return Scaffold(
      // AppBar usará automaticamente o appBarTheme
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search), // Ícone usará a cor do iconTheme da AppBar
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      // O fundo do Scaffold já está definido no tema
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Adiciona um padding geral
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Texto usará o textTheme (headlineSmall)
            Text(
              'Estatísticas',
              style: titleStyle, // Pode usar o estilo do tema diretamente
            ),
            const SizedBox(height: 16.0),

            // Card usará o cardTheme (cor, bordas arredondadas)
            Card(
              child: Container( // Usamos Container para dar altura fixa ao card de exemplo
                height: 200,
                width: double.infinity,
                alignment: Alignment.center,
                // Texto dentro do Card usará a cor onSurface definida no colorScheme
                child: const Text('Aqui viria o gráfico...'),
              ),
            ),
            const SizedBox(height: 24.0),

            Text(
              'Chamadas Ativas',
              style: Theme.of(context).textTheme.headlineSmall, // Outra forma de acessar
            ),
            const SizedBox(height: 16.0),

            // Outro Card
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  // backgroundColor: primaryColor, // Pode usar cores do tema
                  child: Icon(Icons.person),
                ),
                title: const Text('Nome da Pessoa'), // Usará bodyLarge/bodyMedium
                subtitle: const Text('Informação secundária'), // Usará bodyMedium
                trailing: Icon(Icons.phone_in_talk, color: Colors.greenAccent.shade400), // Cor customizada para o ícone
              ),
            ),
            const SizedBox(height: 24.0),

            // Botão usará o elevatedButtonTheme
            Center(
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Ver Mais Detalhes'),
              ),
            ),
             const SizedBox(height: 24.0),

             // Exemplo de TextField
             const TextField(
              // Usará o inputDecorationTheme
              decoration: InputDecoration(
                labelText: 'Procurar usuário...',
                hintText: 'Digite o nome',
                prefixIcon: Icon(Icons.person_search), // Ícone usará iconTheme
              ),
            )
          ],
        ),
      ),
    );
  }
}