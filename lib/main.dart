import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';
import 'package:firmador_geresa/screens/nav/navi_bar.dart';
import 'package:firmador_geresa/services/signer_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_ui/material_ui.dart' as mui;

void main() async {
	WidgetsFlutterBinding.ensureInitialized();
	
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

class _FirmadorAppState extends State<FirmadorApp> with WidgetsBindingObserver {
	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addObserver(this);
	}

	@override
	void dispose() {
		WidgetsBinding.instance.removeObserver(this);
		super.dispose();
	}

	@override
	void didChangeAppLifecycleState(AppLifecycleState state) {
		// Si el usuario cierra la ventana de la app (o la minimiza y se suspende)
		if (state == AppLifecycleState.detached) {
			SignerService.stop(); // Matamos la API al salir
		}
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