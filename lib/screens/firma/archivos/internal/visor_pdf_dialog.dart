import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'archivo_pdf.dart';

class VisorPdfDialog extends StatelessWidget {
	final ArchivoPdf archivo;
	final VoidCallback onAbrirExterno;

	const VisorPdfDialog({super.key, required this.archivo, required this.onAbrirExterno});

	@override
	Widget build(BuildContext context) {
		return Dialog(
			backgroundColor: context.surfaceWhite,
			surfaceTintColor: Colors.transparent,
			insetPadding: const EdgeInsets.all(32),
			clipBehavior: Clip.antiAlias,
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusLg)),
			child: SizedBox(
				width: 1000,
				child: Column(
					children: [
						Padding(
							padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
							child: Row(
								children: [
									Icon(Icons.picture_as_pdf_rounded, color: context.accentCoral),
									const SizedBox(width: 12),
									Expanded(
										child: Text(
											archivo.nombre,
											maxLines: 1,
											overflow: TextOverflow.ellipsis,
											style: Theme.of(context).textTheme.titleMedium,
										),
									),
									TextButton.icon(
										onPressed: onAbrirExterno,
										icon: const Icon(Icons.open_in_new_rounded, size: 18),
										label: const Text('Abrir en programa predeterminado'),
									),
									const SizedBox(width: 4),
									IconButton(
										tooltip: 'Cerrar',
										onPressed: () => Navigator.pop(context),
										icon: const Icon(Icons.close_rounded),
									),
								],
							),
						),
						const Divider(height: 1),
						Expanded(
							child: ColoredBox(
								color: context.surfaceGrey,
								child: PdfViewer.file(archivo.ruta),
							),
						),
					],
				),
			),
		);
	}
}