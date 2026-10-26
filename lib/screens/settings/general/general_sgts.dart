import 'package:firmador_geresa/provider/home_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';


class GeneralStgs extends ConsumerWidget {
	const GeneralStgs({super.key});

	// Lista de los nombres exactos de tus ActionCards
	static const List<String> _tarjetasHome = [
		'Firma ditital GERESA',
		'Qellqa',
		'Correo Institucional',
		'Convertir Word a PDF',
		"Unir PDF's",
		'Dividir PDF',
		'Foliar PDF',
	];

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final visibilidad = ref.watch(homeVisibilityProvider);
		final notifier = ref.read(homeVisibilityProvider.notifier);

		return Scaffold(
			backgroundColor: Colors.transparent,
			body: Padding(
				padding: const EdgeInsets.only(top: 0, right: 24.0, bottom: 24.0, left: 24.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text(
							'Visibilidad del Inicio',
							style: TextStyle(
								fontSize: 20,
								fontWeight: FontWeight.w700,
								color: context.textDark,
							),
						),
						const SizedBox(height: 8),
						Text(
							'Activa o desactiva las herramientas que deseas ver en la pantalla principal.',
							style: TextStyle(fontSize: 14, color: context.textGrey),
						),
						const SizedBox(height: 24),
						
						// Lista de Switches
						Expanded(
							child: ListView.separated(
								itemCount: _tarjetasHome.length,
								separatorBuilder: (context, index) => Divider(color: context.borderColor, height: 1),
								itemBuilder: (context, index) {
									final nombre = _tarjetasHome[index];
									final isVisible = visibilidad[nombre] ?? true; // Por defecto visible

									return Padding(
										padding: const EdgeInsets.symmetric(vertical: 8.0),
										child: Row(
											mainAxisAlignment: MainAxisAlignment.spaceBetween,
											children: [
												Expanded(
													child: Text(
														nombre,
														style: TextStyle(
															fontSize: 16,
															fontWeight: FontWeight.w500,
															color: context.textDark,
														),
													),
												),
												// Switch estilizado
												Switch.adaptive(
													value: isVisible,
													activeColor: context.primaryPurple,
													onChanged: (value) {
														notifier.toggleVisibilidad(nombre, value);
													},
												),
											],
										),
									);
								},
							),
						),
					],
				),
			),
		);
	}
}