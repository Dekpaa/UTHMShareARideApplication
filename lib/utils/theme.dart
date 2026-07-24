import 'package:flutter/material.dart';

class AppTheme {
  // 🎨 Main Colours
  static const Color accentBlue = Color(0xFF7CA9C9);     // fokus
  static const Color unfocusedGrey = Color(0xFF4E4E4E);  // border biasa
  static const Color errorRed = Colors.redAccent;        // error
  static const Color fillColor = Color.fromARGB(30, 255, 255, 255);
  
  // 🎨 Additional colors for buttons
  static const Color buttonBackground = accentBlue;
  static const Color buttonText = Colors.white;

  // 🟦 Borders
  static OutlineInputBorder enabledBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(width: 1.2, color: unfocusedGrey),
  );

  static OutlineInputBorder focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(width: 2.0, color: accentBlue),
  );

  static OutlineInputBorder errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(width: 2.0, color: errorRed),
  );

  // 🎨 FULL THEME (NO PURPLE ANYWHERE)
  static ThemeData theme = ThemeData(
    brightness: Brightness.dark,
    
    // 🎯 CRITICAL: Override default purple colors
    primaryColor: accentBlue,
    primaryColorDark: accentBlue.withOpacity(0.8),
    primaryColorLight: accentBlue.withOpacity(0.3),
    useMaterial3: true, // Use Material 3 design system
    
    // 🎨 Color Scheme (comprehensive)
    colorScheme: ColorScheme.dark(
      primary: accentBlue,
      secondary: accentBlue,
      surface: Colors.black,
      background: Colors.black,
      error: errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onBackground: Colors.white,
      onSurface: Colors.white,
      onError: Colors.white,
    ),
    
    // 🔘 Text Buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentBlue,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    
    // 🔵 Elevated Buttons (SERING JADI PENYEBAB UNGU!)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentBlue,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    ),
    
    // ⏺️ Filled Buttons (Material 3)
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: accentBlue,
      ),
    ),
    
    // 🌀 Floating Action Button
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accentBlue,
      foregroundColor: Colors.white,
      extendedSizeConstraints: const BoxConstraints(
        minHeight: 56,
        minWidth: 80,
      ),
    ),
    
    // 📱 App Bar Theme
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: accentBlue),
    ),
    
    // 🖌 Cursor, selection
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: accentBlue,
      selectionColor: Color.fromARGB(120, 124, 169, 201),
      selectionHandleColor: accentBlue,
    ),

    // ☐ Checkbox
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return accentBlue;
        }
        return null;
      }),
      checkColor: const MaterialStatePropertyAll(Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),

    // ⚪ Radio
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return accentBlue;
        }
        return Colors.grey;
      }),
    ),

    // 🧾 TextField Global Style
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white54),
      prefixIconColor: Colors.white70,
      suffixIconColor: Colors.white70,
      enabledBorder: enabledBorder,
      focusedBorder: focusedBorder,
      errorBorder: errorBorder,
      focusedErrorBorder: errorBorder,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
    ),
    
    // 📝 Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.white),
      displayMedium: TextStyle(color: Colors.white),
      displaySmall: TextStyle(color: Colors.white),
      headlineMedium: TextStyle(color: Colors.white),
      headlineSmall: TextStyle(color: Colors.white),
      titleLarge: TextStyle(color: Colors.white),
      titleMedium: TextStyle(color: Colors.white),
      titleSmall: TextStyle(color: Colors.white),
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Colors.white70),
      labelLarge: TextStyle(color: Colors.white),
      labelMedium: TextStyle(color: Colors.white),
      labelSmall: TextStyle(color: Colors.white70),
    ),
  );
}

class ExampleScreen extends StatelessWidget {
  const ExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.theme,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('No Purple Theme'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // 🔵 Elevated Button (tidak akan ungu!)
              ElevatedButton(
                onPressed: () {},
                child: const Text('Elevated Button'),
              ),
              
              const SizedBox(height: 20),
              
              // 🔘 Text Button
              TextButton(
                onPressed: () {},
                child: const Text('Text Button'),
              ),
              
              const SizedBox(height: 20),
              
              // 📝 Text Field
              TextField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                ),
              ),
              
              const SizedBox(height: 20),
              
              // ☐ Checkbox
              Row(
                children: [
                  Checkbox(value: true, onChanged: (_) {}),
                  const Text('Agree to terms'),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // ⚪ Radio
              Row(
                children: [
                  Radio(value: 1, groupValue: 1, onChanged: (_) {}),
                  const Text('Option 1'),
                ],
              ),
            ],
          ),
        ),
        
        // 🌀 Floating Action Button
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}