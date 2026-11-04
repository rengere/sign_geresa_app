import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'archivo_fila.dart';
import 'archivo_menu_acciones.dart';
import 'archivo_pdf.dart';

class ArchivosTabla extends StatelessWidget {
	final List<ArchivoPdf> archivos;
	final Set<String> seleccion;
	final CampoOrden campoOrden;
	final bool ascendente;
	final ValueChanged<CampoOrden> onOrdenar;
	final ValueChanged<ArchivoPdf> onToggle;
	final VoidCallback onToggleTodos;
	final void Function(AccionArchivo accion, ArchivoPdf archivo) onAccion;

	const ArchivosTabla({
		super.key,
		required this.archivos,
		required this.seleccion,
		required this.campoOrden,
		required this.ascendente,
		required this.onOrdenar,
		required this.onToggle,
		required this.onToggleTodos,
		required this.onAccion,
	});

	@override
	Widget build(BuildContext context) {
		return Column(
			children: [
				_encabezado(context),
				const Divider(height: 1),
				Expanded(
					child: ListView.separated(
						itemCount: archivos.length,
						separatorBuilder: (context, index) => const Divider(height: 1),
						itemBuilder: (context, i) {
							final a = archivos[i];
							return ArchivoFila(
								archivo: a,
								seleccionado: seleccion.contains(a.ruta),
								onToggle: () => onToggle(a),
								onAccion: (accion) => onAccion(accion, a),
							);
						},
					),
				),
			],
		);
	}

	Widget _encabezado(BuildContext context) {
		final seleccionadosEnPagina = archivos.where((a) => seleccion.contains(a.ruta)).length;
		final bool? valorCheck = seleccionadosEnPagina == 0
				? false
				: (seleccionadosEnPagina == archivos.length ? true : null);

		return Container(
			height: 48,
			color: context.surfaceGrey,
			child: Row(
				children: [
					SizedBox(
						width: ColumnasTabla.check,
						child: Center(
							child: Checkbox(
								tristate: true,
								value: valorCheck,
								onChanged: (_) => onToggleTodos(),
							),
						),
					),
					Expanded(
						child: _CeldaOrden(
							texto: 'Nombre',
							activo: campoOrden == CampoOrden.nombre,
							ascendente: ascendente,
							onTap: () => onOrdenar(CampoOrden.nombre),
						),
					),
					SizedBox(
						width: ColumnasTabla.fecha,
						child: _CeldaOrden(
							texto: 'Fecha',
							activo: campoOrden == CampoOrden.fecha,
							ascendente: ascendente,
							onTap: () => onOrdenar(CampoOrden.fecha),
						),
					),
					SizedBox(
						width: ColumnasTabla.tamano,
						child: Text('Tamaño', style: Theme.of(context).textTheme.titleSmall),
					),
					const SizedBox(width: ColumnasTabla.menu),
				],
			),
		);
	}
}

class _CeldaOrden extends StatelessWidget {
	final String texto;
	final bool activo;
	final bool ascendente;
	final VoidCallback onTap;

	const _CeldaOrden({
		required this.texto,
		required this.activo,
		required this.ascendente,
		required this.onTap,
	});

	@override
	Widget build(BuildContext context) {
		final estilo = Theme.of(context).textTheme.titleSmall?.copyWith(
					color: activo ? context.primaryPurple : context.textGrey,
				);

		return InkWell(
			onTap: onTap,
			child: Align(
				alignment: Alignment.centerLeft,
				child: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						Text(texto, style: estilo),
						const SizedBox(width: 4),
						Icon(
							activo
									? (ascendente ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
									: Icons.unfold_more_rounded,
							size: 16,
							color: activo ? context.primaryPurple : context.textLight,
						),
					],
				),
			),
		);
	}
}