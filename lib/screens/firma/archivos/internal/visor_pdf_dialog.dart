import 'dart:io';
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';

import 'archivo_pdf.dart';

class VisorPdfDialog extends StatelessWidget {
	final ArchivoPdf archivo;
	final VoidCallback onAbrirExterno;

	const VisorPdfDialog({super.key, required this.archivo, required this.onAbrirExterno});

	Future<void> _imprimir(BuildContext context) async {
		try {
			final bytes = await File(archivo.ruta).readAsBytes();
			await Printing.layoutPdf(
				onLayout: (format) async => bytes,
			);
		} catch (e) {
			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Error al imprimir: $e')),
				);
			}
		}
	}

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
									
									// NUEVO BOTÓN DE IMPRIMIR
									TextButton.icon(
										onPressed: () => _imprimir(context),
										icon: const Icon(Icons.print_rounded, size: 18),
										label: const Text('Imprimir'),
										style: TextButton.styleFrom(
											foregroundColor: context.primaryPurple,
										),
									),
									const SizedBox(width: 8),

									TextButton.icon(
										onPressed: onAbrirExterno,
										icon: const Icon(Icons.open_in_new_rounded, size: 18),
										label: const Text('Abrir externo'),
									),
									const SizedBox(width: 8),
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