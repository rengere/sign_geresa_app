import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:firmador_geresa/assets/theme/app_theme.dart';

/// Panel independiente de anexos pendientes de transferencia.
class AnexosSlider extends StatelessWidget {
	final String nombreArchivo;
	final List<File> anexos;
	final ValueChanged<String> onEliminar;
	final VoidCallback onAgregar;
	final VoidCallback onCerrar;
	final bool ocupado;

	const AnexosSlider({
		super.key,
		required this.nombreArchivo,
		required this.anexos,
		required this.onEliminar,
		required this.onAgregar,
		required this.onCerrar,
		this.ocupado = false,
	});

	@override
	Widget build(BuildContext context) {
		return Container(
			width: 220,
			decoration: BoxDecoration(color: context.surfaceGrey.withValues(alpha: 0.5), border: Border(right: BorderSide(color: context.borderColor))),
			child: Column(
				children: [
					Padding(
						padding: const EdgeInsets.all(12),
						child: Row(children: [
							Expanded(child: Text('Anexos', style: TextStyle(fontWeight: FontWeight.bold, color: context.textDark))),
							IconButton(tooltip: 'Cerrar panel', onPressed: onCerrar, icon: const Icon(Icons.close)),
						]),
					),
					Container(
						margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
						padding: const EdgeInsets.all(8),
						decoration: BoxDecoration(color: context.surfaceWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.primaryPurple)),
						child: Row(children: [
							Icon(Icons.lock_outline, size: 20, color: context.primaryPurple),
							const SizedBox(width: 8),
							Expanded(child: Text(nombreArchivo, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.textDark))),
						]),
					),
					Expanded(
						child: anexos.isEmpty
							? Center(child: Padding(padding: const EdgeInsets.all(12), child: Text('Sin anexos seleccionados', textAlign: TextAlign.center, style: TextStyle(color: context.textGrey, fontSize: 12))))
							: ListView.builder(
							itemCount: anexos.length,
							itemBuilder: (context, index) {
								final archivo = anexos[index];
								return Container(
									key: ValueKey(archivo.path),
									margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
									padding: const EdgeInsets.all(8),
									decoration: BoxDecoration(color: context.surfaceWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.borderColor)),
									child: Row(children: [
										Icon(Icons.insert_drive_file_outlined, size: 20, color: context.textGrey),
										const SizedBox(width: 8),
										Expanded(child: Text(p.basename(archivo.path), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.textDark))),
										IconButton(tooltip: 'Quitar anexo', icon: Icon(Icons.close, size: 16, color: context.errorRed), onPressed: ocupado ? null : () => onEliminar(archivo.path), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
									]),
								);
							},
							),
					),
					Padding(
						padding: const EdgeInsets.all(12),
						child: SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: ocupado ? null : onAgregar, icon: const Icon(Icons.add), label: const Text('Añadir archivos'))),
					),
				],
			),
		);
	}
}
