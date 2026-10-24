import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';
import 'package:firmador_geresa/screens/nav/navi_bar.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_ui/material_ui.dart' as mui;

void main() async {
	WidgetsFlutterBinding.ensureInitialized();
	await JsonStorage.init(); 
	runApp(const FirmadorApp());
}

class FirmadorApp extends StatelessWidget {
	const FirmadorApp({super.key});

	@override
	Widget build(BuildContext context) {
		return MaterialApp(
			debugShowCheckedModeBanner: false,
			theme: AppTheme.lightTheme,
			title: 'Firmador GERESA Cusco',
			localizationsDelegates: const [
				// Para el Material de siempre (tu app)
				...GlobalMaterialLocalizations.delegates,
				// Para material_ui (lo usa el calendario)
				...mui.GlobalMaterialLocalizations.delegates,
			],
			supportedLocales: const [Locale('es')],
			locale: const Locale('es'),
			// home: HomeScreenBtn(),
			home: const NaviBar(),
		);
	}
}