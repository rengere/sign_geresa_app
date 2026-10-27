import 'dart:io';
import 'dart:typed_data';
import 'package:firmador_geresa/assets/tools/files_manag/folder_path_nxc.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor_firma_modal.dart';
import 'package:firmador_geresa/screens/firma/firmar/popup_firma.dart';
import 'package:firmador_geresa/widgets/file_drop_zone.dart';
import 'package:flutter/material.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/services/api_service.dart';

class SignScreen extends StatelessWidget {
	const SignScreen({super.key});

	// Extensiones de Word que sí podemos convertir (.docx, formato XML
	// moderno). El formato viejo (.doc, binario) no lo soporta docx4j.
	bool _esDocx(String nombre) => nombre.toLowerCase().endsWith('.docx');
	bool _esDocViejo(String nombre) =>
			nombre.toLowerCase().endsWith('.doc') && !_esDocx(nombre);

	Future<void> _procesarArchivo(BuildContext context, String path, String nombre) async {
		final archivo = File(path);
		final bytesOriginales = await archivo.readAsBytes();

		if (!context.mounted) return;

		if (_esDocViejo(nombre)) {
			_mostrarErrorFormatoDoc(context);
			return;
		}

		// Mensaje del popup de carga: reactivo, para poder cambiar el texto
		// (p.ej. "Convirtiendo..." -> "Leyendo DNIe...") sin cerrar y volver
		// a abrir el diálogo.
		final mensajeCarga = ValueNotifier<String>('Procesando documento...');
		_mostrarCarga(context, mensajeCarga);

		try {
			Uint8List bytesPdf = bytesOriginales;
			String nombreFinal = nombre;

			// Si es Word (.docx), convertir a PDF antes de seguir. Si ya es
			// PDF (o cualquier otra cosa), no se toca.
			//
			// Este paso va en su propio try/catch: si falla, hay que
			// mostrar el error REAL de conversión, no el mensaje genérico
			// de "no se pudo leer el DNIe" (que es para el paso de más
			// abajo y no tiene nada que ver con esto).
			if (_esDocx(nombre)) {
				mensajeCarga.value = 'Convirtiendo documento a PDF...';

				try {
					bytesPdf = await ApiService().convertirWordAPdf(
						docxBytes: bytesOriginales,
						nombreArchivo: nombre,
					);
				} catch (e) {
					if (!context.mounted) return;
					Navigator.of(context, rootNavigator: true).pop();
					_mostrarErrorConversion(context, '$e');
					return;
				}

				// A partir de acá el documento ya es un PDF: el nombre debe
				// reflejarlo, para que el popup de firma (que arma el nombre
				// final del archivo) no arrastre el ".docx" original.
				nombreFinal = '${nombre.substring(0, nombre.length - 5)}.pdf';
			}

			mensajeCarga.value = 'Leyendo DNIe...';

			final api = ApiService();
			TitularCertificado? titular;

			// --- LÓGICA DE REINTENTO ASÍNCRONO REACTIVO ---
			int intentos = 0;
			const maxIntentos = 5;

			while (intentos < maxIntentos) {
				try {
					titular = await api.obtenerTitular();
					break;
				} catch (e) {
					intentos++;
					if (intentos >= maxIntentos) {
						rethrow;
					}
					await Future.delayed(const Duration(milliseconds: 200));
				}
			}

			if (!context.mounted) return;
			// Cerrar el modal de carga usando el rootNavigator
			Navigator.of(context, rootNavigator: true).pop();

			final imagenFirmaBytes = await _obtenerImagenFirma(context);
			if (!context.mounted) return;

			final pdfConImagen = await Navigator.of(context).push<Uint8List>(
				MaterialPageRoute(
					builder: (_) => EditorFirmaModal(
						pdfBytes: bytesPdf,
						nombreArchivo: nombreFinal,
						imagenFirmaBytes: imagenFirmaBytes,
						nombreFirmante: titular!.nombre,
						dniFirmante: titular.dni,
					),
				),
			);

			if (pdfConImagen == null || !context.mounted) return;

			await showDialog(
				context: context,
				barrierDismissible: false,
				builder: (_) => PopupFirma(
					pdfBytes: pdfConImagen,
					nombreArchivo: nombreFinal,
					rutaBackup: obtenerRutaNextcloud(), // <-- Función llamada al momento
				),
			);
		} catch (e) {
			if (!context.mounted) return;
			Navigator.of(context, rootNavigator: true).pop(); // Cerrar carga en caso de error
			_mostrarErrorLectura(context);
		} finally {
			mensajeCarga.dispose();
		}
	}

	// Modal de carga flotante, centrado, sin fondo oscuro. El texto es
	// reactivo: cambia según el ValueNotifier que se le pase, sin cerrar
	// ni volver a abrir el diálogo.
	void _mostrarCarga(BuildContext context, ValueNotifier<String> mensaje) {
		showDialog(
			context: context,
			barrierDismissible: false,
			barrierColor: Colors.transparent, // Sin fondo oscuro
			builder: (ctx) => Center(
				child: Material(
					color: Colors.transparent,
					child: Container(
						padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
						decoration: BoxDecoration(
							color: ctx.surfaceWhite,
							borderRadius: BorderRadius.circular(ctx.radiusLg),
							boxShadow: [
								BoxShadow(
									color: Colors.black.withValues(alpha: 0.1),
									blurRadius: 10,
									offset: const Offset(0, 4),
								),
							],
						),
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								SizedBox(
									width: 24,
									height: 24,
									child: CircularProgressIndicator(
										strokeWidth: 2.5,
										color: ctx.primaryPurple,
									),
								),
								const SizedBox(width: 16),
								ValueListenableBuilder<String>(
									valueListenable: mensaje,
									builder: (_, texto, __) => Text(
										texto,
										style: TextStyle(
											fontSize: 14,
											fontWeight: FontWeight.w500,
											color: ctx.textDark,
										),
									),
								),
							],
						),
					),
				),
			),
		);
	}

	void _mostrarErrorLectura(BuildContext context) {
		showDialog(
			context: context,
			builder: (ctx) => AlertDialog(
				shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ctx.radiusLg)),
				title: Row(
					children: [
						Icon(Icons.error_outline_rounded, color: ctx.errorRed),
						const SizedBox(width: 8),
						const Text('Error de lectura'),
					],
				),
				content: const Text(
					'No se pudo leer el certificado del DNIe.\n\n'
					'Asegúrate de que el DNIe esté insertado correctamente y vuelve a intentarlo.',
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.of(ctx).pop(),
						child: const Text('Entendido'),
					),
				],
			),
		);
	}

	void _mostrarErrorConversion(BuildContext context, String detalle) {
		showDialog(
			context: context,
			builder: (ctx) => AlertDialog(
				shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ctx.radiusLg)),
				title: Row(
					children: [
						Icon(Icons.error_outline_rounded, color: ctx.errorRed),
						const SizedBox(width: 8),
						const Text('No se pudo convertir el documento'),
					],
				),
				content: Text(
					'Ocurrió un problema al convertir el documento Word a PDF.\n\n$detalle',
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.of(ctx).pop(),
						child: const Text('Entendido'),
					),
				],
			),
		);
	}

	void _mostrarErrorFormatoDoc(BuildContext context) {
		showDialog(
			context: context,
			builder: (ctx) => AlertDialog(
				shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ctx.radiusLg)),
				title: Row(
					children: [
						Icon(Icons.error_outline_rounded, color: ctx.errorRed),
						const SizedBox(width: 8),
						const Text('Formato no compatible'),
					],
				),
				content: const Text(
					'Los archivos .doc (el formato antiguo de Word) no se pueden convertir.\n\n'
					'Abre el documento en Word, guárdalo como .docx (o como PDF), y vuelve a intentarlo.',
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.of(ctx).pop(),
						child: const Text('Entendido'),
					),
				],
			),
		);
	}

	Future<Uint8List> _obtenerImagenFirma(BuildContext context) async {
		final data = await DefaultAssetBundle.of(context).load('lib/assets/images/logo_firma.png');
		return data.buffer.asUint8List();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Firmar Documento')),
			backgroundColor: context.backgroundLight,
			body: Align(
				alignment: const Alignment(0, -0.4),
				child: FileDropZone(
					width: 500,
					height: 300,
					onFileDropped: (path, nombre) => _procesarArchivo(context, path, nombre),
				),
			),
		);
	}
}