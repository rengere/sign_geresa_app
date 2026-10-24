import 'package:firmador_geresa/screens/firma/archivos/ver_archivos.dart';
import 'package:firmador_geresa/widgets/tab_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:firmador_geresa/screens/firma/firmar/sign_screen.dart';
import 'package:firmador_geresa/screens/firma/verificar/verify_screen.dart';


class FirmaScreen extends StatelessWidget {
	const FirmaScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return const TabScaffold(
			children: [
				FirmaTabItem(
					title: 'Firmar Documento',
					icon: Icons.edit_document,
					screen: SignScreen(),
				),
				FirmaTabItem(
					title: 'Ver Archivos',
					icon: Icons.verified_user_rounded,
					screen: VerArchivos(),
				),
				FirmaTabItem(
					title: 'Verificar Firma',
					icon: Icons.verified_user_rounded,
					screen: VerifyScreen(),
				),
			],
		);
	}
}
