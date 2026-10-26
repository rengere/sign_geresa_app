import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';
import 'package:firmador_geresa/screens/nav/navi_bar.dart';
import 'package:firmador_geresa/services/signer_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NUEVO: necesario para que onWindowClose (abajo) funcione. Es lo
  // único que resuelve de forma confiable el cierre con el botón "X" en
  // Windows — didChangeAppLifecycleState solo, como tenías antes, no
  // siempre dispara 'detached' en escritorio, por eso la API no moría.
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);

  // Inicializar JSON Storage
  await JsonStorage.init();

  // Iniciar la API de Java en segundo plano
  await SignerService.start();

  // Iniciar la app
  runApp(const FirmadorApp());
}

class FirmadorApp extends StatefulWidget {
  const FirmadorApp({super.key});

  @override
  State<FirmadorApp> createState() => _FirmadorAppState();
}

class _FirmadorAppState extends State<FirmadorApp>
    with WidgetsBindingObserver, WindowListener {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    windowManager.addListener(this); // NUEVO
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this); // NUEVO
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      SignerService.stop();
    }
  }

  // NUEVO: este es el que de verdad va a matar la API cuando le des a
  // la X de la ventana.
  @override
  void onWindowClose() async {
    SignerService.stop();
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      title: 'Firmador GERESA Cusco',
      localizationsDelegates: const [
        ...GlobalMaterialLocalizations.delegates,
        ...mui.GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('es')],
      locale: const Locale('es'),
      home: const NaviBar(),
    );
  }
}
