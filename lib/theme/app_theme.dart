import 'package:flutter/material.dart';

/// Identidade visual centralizada do Adedanha Offline.
///
/// Concentra cores e estilos num só lugar. As telas continuam usando os
/// widgets padrão (ElevatedButton, TextField, Scaffold, AppBar), que herdam
/// este tema automaticamente — sem estilização manual em cada tela.
class AppTheme {
  AppTheme._(); // Só membros estáticos: a classe não precisa ser instanciada.

  /// Azul principal: transmite confiança e estabilidade.
  /// Usado em botões, no cabeçalho (AppBar) e em destaques.
  static const Color azulPrimario = Color(0xFF1B4F8C);

  /// Azul bem claro: fundo de cartões e áreas de destaque suave.
  static const Color azulClaro = Color(0xFFEAF1FA);

  /// Quase preto (não 100% preto): leitura confortável, com menos cansaço.
  static const Color pretoTexto = Color(0xFF1C1C1C);

  /// Laranja de destaque: chama atenção para ênfases e ações secundárias.
  static const Color laranjaAccent = Color(0xFFF2A65A);

  /// Laranja bem claro: fundo quente para avisos/destaques leves.
  static const Color laranjaClaro = Color(0xFFFCEEDD);

  /// Fundo neutro e aconchegante: evita o branco puro, mais suave aos olhos.
  static const Color fundoConfortavel = Color(0xFFFAF8F5);

  /// Tema claro do app.
  static ThemeData claro() {
    // Paleta derivada do azul principal; o laranja entra como cor secundária.
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: azulPrimario,
      primary: azulPrimario,
      secondary: laranjaAccent,
    );

    // Base Material 3 para herdar espaçamentos/alturas corretos; depois
    // aumentamos os tamanhos pensando na legibilidade para terceira idade.
    final TextTheme baseText = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
    ).textTheme;

    // Nada abaixo de 14 no corpo de texto; títulos bem destacados.
    final TextTheme textTheme = baseText.copyWith(
      displayLarge: const TextStyle(
          fontSize: 40, fontWeight: FontWeight.bold, color: azulPrimario),
      displayMedium: const TextStyle(
          fontSize: 34, fontWeight: FontWeight.bold, color: azulPrimario),
      displaySmall: const TextStyle(
          fontSize: 28, fontWeight: FontWeight.bold, color: azulPrimario),
      headlineLarge: const TextStyle(
          fontSize: 30, fontWeight: FontWeight.w700, color: pretoTexto),
      headlineMedium: const TextStyle(
          fontSize: 26, fontWeight: FontWeight.w700, color: pretoTexto),
      headlineSmall: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: pretoTexto),
      titleLarge: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w600, color: pretoTexto),
      titleMedium: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: pretoTexto),
      titleSmall: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, color: pretoTexto),
      bodyLarge: const TextStyle(fontSize: 18, color: pretoTexto),
      bodyMedium: const TextStyle(fontSize: 16, color: pretoTexto),
      bodySmall: const TextStyle(fontSize: 14, color: pretoTexto),
      labelLarge: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: pretoTexto),
      labelMedium: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: pretoTexto),
      labelSmall: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: pretoTexto),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: fundoConfortavel,
      textTheme: textTheme,

      // Botões elevados: fundo azul, texto branco e cantos arredondados.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: azulPrimario,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52), // alvo de toque confortável
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Campos de texto: borda arredondada e foco em azul.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: pretoTexto),
        hintStyle: TextStyle(color: pretoTexto.withValues(alpha: 0.55)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: azulPrimario),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: azulPrimario),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: azulPrimario, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),

      // AppBar em azul com texto branco, mantendo o topo consistente.
      appBarTheme: const AppBarTheme(
        backgroundColor: azulPrimario,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}
