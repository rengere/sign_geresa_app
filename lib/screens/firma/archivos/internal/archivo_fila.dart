import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'archivo_menu_acciones.dart';
import 'archivo_pdf.dart';

/// Anchos de columna compartidos entre encabezado y filas.
class ColumnasTabla {
	static const double check = 56;
	static const double fecha = 190;
	static const double tamano = 110;
	static const double menu = 64;
}

class ArchivoFila extends StatelessWidget {
	final ArchivoPdf archivo;
	final bool seleccionado;
	final VoidCallback onToggle;
	final ValueChanged<AccionArchivo> onAccion;

	const ArchivoFila({
		super.key,
		required this.archivo,
		required this.seleccionado,
		required this.onToggle,
		required this.onAccion,
	});

	Future<void> _menuContextual(BuildContext context, Offset posicion) async {
		final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
		final accion = await showMenu<AccionArchivo>(
			context: context,
			position: RelativeRect.fromRect(posicion & const Size(1, 1), Offset.zero & overlay.size),
			color: context.surfaceWhite,
			elevation: 8,
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusMd)),
			items: construirItemsMenu(context),
		);
		if (accion != null) onAccion(accion);
	}

	@override
	Widget build(BuildContext context) {
		final textos = Theme.of(context).textTheme;

		return Material(
			color: seleccionado ? context.primaryPurple.withValues(alpha: 0.06) : Colors.transparent,
			child: InkWell(
				hoverColor: context.primaryPurple.withValues(alpha: 0.04),
				onDoubleTap: () => onAccion(AccionArchivo.verEnApp),
				onSecondaryTapDown: (d) => _menuContextual(context, d.globalPosition),
				child: Padding(
					padding: const EdgeInsets.symmetric(vertical: 6),
					child: Row(
						children: [
							SizedBox(
								width: ColumnasTabla.check,
								child: Center(
									child: Checkbox(value: seleccionado, onChanged: (_) => onToggle()),
								),
							),
							Expanded(
								child: Row(
									children: [
										Container(
											width: 36,
											height: 36,
											decoration: BoxDecoration(
												color: context.accentCoral.withValues(alpha: 0.12),
												borderRadius: BorderRadius.circular(context.radiusSm),
											),
											child: Icon(Icons.picture_as_pdf_rounded, size: 20, color: context.accentCoral),
										),
										const SizedBox(width: 12),
										Expanded(
											child: Tooltip(
												message: archivo.nombre,
												waitDuration: const Duration(milliseconds: 600),
												child: Text(
													archivo.nombre,
													maxLines: 1,
													overflow: TextOverflow.ellipsis,
													style: textos.bodyLarge,
												),
											),
										),
									],
								),
							),
							SizedBox(
								width: ColumnasTabla.fecha,
								child: Text(archivo.fechaTexto, style: textos.bodyMedium),
							),
							SizedBox(
								width: ColumnasTabla.tamano,
								child: Text(archivo.tamanoTexto, style: textos.bodyMedium),
							),
							SizedBox(
								width: ColumnasTabla.menu,
								child: PopupMenuButton<AccionArchivo>(
									tooltip: 'Acciones',
									icon: Icon(Icons.more_vert_rounded, color: context.textGrey),
									position: PopupMenuPosition.under,
									color: context.surfaceWhite,
									elevation: 8,
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusMd)),
									onSelected: onAccion,
									itemBuilder: construirItemsMenu,
								),
							),
						],
					),
				),
			),
		);
	}
}