import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/env_config.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/theme_viewmodel.dart';
import 'viewmodels/transaction_viewmodel.dart';
import 'views/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();

  // Plugin C++ FlutterFire tidak tersedia di Linux Desktop; Web/Mobile memakai SDK native.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.linux) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Inisialisasi Firebase dilewati atau gagal: $e');
    }
  }

  // Bagikan satu instance AuthService agar sesi login terbaca saat backup Firestore di Linux.
  final authService = AuthService();
  final themeViewModel = ThemeViewModel();
  final authViewModel = AuthViewModel(authService: authService);
  final transactionViewModel = TransactionViewModel(authService: authService);

  // Jalankan UI lebih dulu agar frame pertama langsung tampil di desktop/web.
  runApp(
    FinoraApp(
      themeViewModel: themeViewModel,
      authViewModel: authViewModel,
      transactionViewModel: transactionViewModel,
    ),
  );

  unawaited(themeViewModel.loadTheme());
  unawaited(authViewModel.restoreSession());
  unawaited(transactionViewModel.initialize());
}

class FinoraApp extends StatelessWidget {
  const FinoraApp({
    super.key,
    required this.themeViewModel,
    required this.authViewModel,
    required this.transactionViewModel,
  });

  final ThemeViewModel themeViewModel;
  final AuthViewModel authViewModel;
  final TransactionViewModel transactionViewModel;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeViewModel>.value(value: themeViewModel),
        ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
        ChangeNotifierProvider<TransactionViewModel>.value(
          value: transactionViewModel,
        ),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeVm, _) {
          return MaterialApp(
            title: 'Finora',
            debugShowCheckedModeBanner: false,
            themeMode: themeVm.themeMode,
            theme: AppTheme.buildTheme(FinoraColors.light, Brightness.light),
            darkTheme: AppTheme.buildTheme(FinoraColors.dark, Brightness.dark),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
