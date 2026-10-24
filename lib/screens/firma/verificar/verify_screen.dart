import 'package:firmador_geresa/screens/firma/verificar/panel_left.dart';
import 'package:flutter/material.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';


class VerifyScreen extends StatelessWidget {
	const VerifyScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Verificar Firma')),
			backgroundColor: context.backgroundLight,
			body: const VerifyLayout(),
		);
	}
}

