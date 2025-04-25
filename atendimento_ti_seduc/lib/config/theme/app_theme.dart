// lib/config/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // <<< IMPORT para ImageFilter

class AppTheme {
  AppTheme._();

  // --- Constantes de Cores (Refinadas) ---
  //static const Color kBackgroundColor = Color(0xFF1A1A2E); // <<< VOLTOU para Roxo/Azul Escuro
  static const Color kBackgroundGradientStart = Color(0xFF1A1A2E); // <<< COR INICIAL DO GRADIENTE
  static const Color kBackgroundGradientEnd = Colors.black;       // <<< COR FINAL DO GRADIENTE (PRETO)

  // <<< OPACIDADE REDUZIDA (ex: A0 = ~63%) para efeito Glassmorphism
  static const Color kSurfaceColor = Color(0xA02A2A3E);
  static const Color kPrimaryColor = Color(0xFF7B1FA2);
  static const Color kSecondaryColor = Color(0xFF9C27B0);
  static const Color kTextColor = Colors.white;
  static const Color kSecondaryTextColor = Colors.white70;
  static const Color kErrorColor = Colors.redAccent;
  static const Color kGradientStartColor = Color(0xFFE91E63); // Gradiente para outros usos
  static const Color kGradientEndColor = Color(0xFFFF8A65);

  // --- Objeto ThemeData (Atualizado com novas cores base) ---
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    primaryColor: kPrimaryColor,
    fontFamily: GoogleFonts.poppins().fontFamily,

    colorScheme: const ColorScheme.dark(
      primary: kPrimaryColor,
      secondary: kSecondaryColor,
      surface: kSurfaceColor, // <<< Usa nova superfície (menos opaca)
      background: kBackgroundGradientStart,
      error: kErrorColor,
      onPrimary: kTextColor,
      onSecondary: kTextColor,
      onSurface: kTextColor,
      onBackground: kTextColor,
      onError: kTextColor,
    ),

    textTheme: GoogleFonts.poppinsTextTheme( /* ... Mantido igual ... */
        ThemeData.dark().textTheme,).copyWith( headlineSmall: TextStyle(color: kTextColor.withOpacity(0.9), fontWeight: FontWeight.bold), headlineMedium: TextStyle(color: kTextColor.withOpacity(0.9), fontWeight: FontWeight.bold), titleLarge: TextStyle(color: kTextColor.withOpacity(0.9), fontWeight: FontWeight.bold), bodyLarge: const TextStyle(color: kTextColor), bodyMedium: const TextStyle(color: kSecondaryTextColor), labelLarge: const TextStyle(color: kTextColor, fontWeight: FontWeight.bold),),

    // CardTheme agora define SÓ a forma padrão, a cor/efeito será no widget
    cardTheme: CardTheme(
      elevation: 0, // Sem elevação padrão
      // Removendo a cor daqui, será aplicada no widget com BackdropFilter
      // color: kSurfaceColor,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0), // Mantém o raio padrão
         // A borda de prioridade será aplicada no widget TicketCard
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData( /* ... Mantido igual ... */ style: ElevatedButton.styleFrom( backgroundColor: kPrimaryColor, foregroundColor: kTextColor, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12.0), ), padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0), textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold), ),),

    appBarTheme: AppBarTheme( /* ... Mantido igual (transparente) ... */ backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: kTextColor), titleTextStyle: GoogleFonts.poppins( color: kTextColor, fontSize: 18, fontWeight: FontWeight.w600, ),),

    inputDecorationTheme: InputDecorationTheme( /* ... Atualizado para usar a nova kSurfaceColor ... */
       filled: true,
       fillColor: kSurfaceColor, // <<< Usa a nova cor base com sua opacidade inerente
       contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
       border: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none,),
       enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none, ),
       focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5), ),
       labelStyle: const TextStyle(color: kSecondaryTextColor),
       hintStyle: const TextStyle(color: kSecondaryTextColor),
     ),

    iconTheme: const IconThemeData( /* ... Mantido igual ... */ color: kSecondaryTextColor, size: 24.0,),
  );

  // --- Funções Helper (Mantidas Iguais) ---
  static Color? getPriorityColor(String prioridade) { /* ... Mantido igual ... */ switch (prioridade.toLowerCase()) { case 'urgente': case 'crítica': return Colors.redAccent[400]; case 'alta': return Colors.orangeAccent[400]; case 'média': case 'media': return Colors.amberAccent[400]; case 'baixa': return Colors.lightBlueAccent[200]; default: return null; } }
  static Color? getStatusColor(String status) { /* ... Mantido igual ... */ switch (status.toLowerCase()) { case 'aberto': return Colors.blue[400]; case 'em andamento': return Colors.orange[600]; case 'pendente': return Colors.deepPurple[400]; case 'resolvido': return Colors.green[500]; case 'fechado': return Colors.grey[600]; default: return Colors.grey[500]; } }
}