import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/theme.dart';
import 'providers/user_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/tasks_provider.dart';
import 'providers/money_provider.dart';
import 'providers/events_provider.dart';
import 'providers/roam_provider.dart';
import 'providers/flashcards_provider.dart';
import 'providers/bucket_list_provider.dart';

import 'services/storage_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await StorageService.init();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => TasksProvider()),
        ChangeNotifierProvider(create: (_) => MoneyProvider()),
        ChangeNotifierProvider(create: (_) => EventsProvider()),
        ChangeNotifierProvider(create: (_) => RoamProvider()),
        ChangeNotifierProvider(create: (_) => FlashcardsProvider()),
        ChangeNotifierProvider(create: (_) => BucketListProvider()),
      ],
      child: const LifeOSApp(),
    ),
  );
}

class LifeOSApp extends StatelessWidget {
  const LifeOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    // [FIX] Listen to UserProvider for dynamic theme changes
    final userProvider = Provider.of<UserProvider>(context);

    return MaterialApp(
      title: 'LifeOS',
      debugShowCheckedModeBanner: false,
      
      // DYNAMIC THEME GENERATION
      theme: AppTheme.createTheme(
        isDark: userProvider.isDarkMode,
        accentColor: userProvider.accentColor,
      ),
      
      home: userProvider.user.id.isEmpty 
          ? const LoginScreen() 
          : const MainScaffold(),
    );
  }
}