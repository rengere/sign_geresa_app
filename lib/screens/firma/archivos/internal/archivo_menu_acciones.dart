import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum AccionArchivo {
	verEnApp,
	abrirExterno,
	mostrarCarpeta,
	descargar,
	compartir,
	renombrar,
	detalles,
	eliminar,
	suprimir,
}

/// Items compartidos por el botón ⋮ y por el clic derecho.
List<PopupMenuEntry<AccionArchivo>> construirItemsMenu(BuildContext context) {
	return [
		_item(context, AccionArchivo.verEnApp, Icons.visibility_outlined, 'Ver en la app'),
		_item(context, AccionArchivo.abrirExterno, Icons.open_in_new_rounded, 'Abrir documento'),
		_item(context, AccionArchivo.mostrarCarpeta, Icons.folder_open_outlined, 'Mostrar en carpeta'),
		_item(context, AccionArchivo.descargar, Icons.download_outlined, 'Descargar'),
		_item(context, AccionArchivo.compartir, Icons.share_outlined, 'Compartir'),
		_item(context, AccionArchivo.renombrar, Icons.drive_file_rename_outline_rounded, 'Renombrar'),
		_item(context, AccionArchivo.detalles, Icons.info_outline_rounded, 'Ver detalles'),
		const PopupMenuDivider(),
		_item(context, AccionArchivo.eliminar, Icons.delete_outline_rounded, 'Eliminar', color: context.accentCoral),
		_item(context, AccionArchivo.suprimir, Icons.delete_forever_outlined, 'Suprimir', color: context.errorRed),
	];
}

PopupMenuItem<AccionArchivo> _item(
	BuildContext context,
	AccionArchivo valor,
	IconData icono,
	String texto, {
	Color? color,
}) {
	return PopupMenuItem<AccionArchivo>(
		value: valor,
		height: 44,
		child: Row(
			children: [
				Icon(icono, size: 20, color: color ?? context.textGrey),
				const SizedBox(width: 12),
				Text(
					texto,
					style: TextStyle(color: color ?? context.textDark, fontSize: 14, fontWeight: FontWeight.w500),
				),
			],
		),
	);
}