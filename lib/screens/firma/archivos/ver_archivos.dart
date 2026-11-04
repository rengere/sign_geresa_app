import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'tabla_doc_firmados.dart';
import 'tabla_doc_proyectados.dart';

class VerArchivos extends StatelessWidget {
	const VerArchivos({super.key});

	@override
	Widget build(BuildContext context) {
		return DefaultTabController(
			length: 2,
			child: Scaffold(
				backgroundColor: context.backgroundLight,
				appBar: AppBar(
					title: const Text('Ver Archivos'),
					bottom: TabBar(
						indicatorColor: context.primaryPurple,
						labelColor: context.primaryPurple,
						unselectedLabelColor: context.textGrey,
						tabs: const [
							Tab(text: 'Documentos Proyectados'),
							Tab(text: 'Documentos Firmados'),
						],
					),
				),
				body: Padding(
					padding: EdgeInsets.all(context.spaceLg),
					child: const TabBarView(
						children: [
							TablaDocProyectados(),   
							TablaDocFirmados(),      
						],
					),
				),
			),
		);
	}
}