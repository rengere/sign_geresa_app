import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';
import 'package:firmador_geresa/screens/nav/navi_bar.dart';
import 'package:firmador_geresa/services/signer_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:window_manager/window_manager.dart';

void main() async {
	WidgetsFlutterBinding.ensureInitialized();

	// Necesario para que onWindowClose (abajo) funcione: es lo que
	await windowManager.ensureInitialized();
	await windowManager.setPreventClose(true);

	// Inicializar JSON Storage
	await JsonStorage.init();

	// Iniciar la API de Java en segundo plano
	await SignerService.start();

	// Iniciar la app
	runApp(const ProviderScope(child: FirmadorApp()));
}

class FirmadorApp extends StatefulWidget {
	const FirmadorApp({super.key});

	@override
	State<FirmadorApp> createState() => _FirmadorAppState();
}

class _FirmadorAppState extends State<FirmadorApp> with WidgetsBindingObserver, WindowListener {
	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addObserver(this);
		windowManager.addListener(this);
	}

	@override
	void dispose() {
		WidgetsBinding.instance.removeObserver(this);
		windowManager.removeListener(this);
		super.dispose();
	}

	@override
	void didChangeAppLifecycleState(AppLifecycleState state) {
		if (state == AppLifecycleState.detached) {
			SignerService.stop();
		}
	}

	// Este es el que de verdad mata la API cuando se cierra la ventana
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