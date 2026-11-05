import 'dart:io';
import 'dart:typed_data';
import 'package:firmador_geresa/assets/tools/files_manag/folder_path_nxc.dart';
import 'package:firmador_geresa/data/rutas_carpetas_docs.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor/editor_firma_modal.dart';

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

		final mensajeCarga = ValueNotifier<String>('Procesando documento...');
		_mostrarCarga(context, mensajeCarga);

		try {
			Uint8List bytesPdf = bytesOriginales;
			String nombreFinal = nombre;

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
			Navigator.of(context, rootNavigator: true).pop();

			// --- CARGA DE LAS DOS IMÁGENES ---
			// Cargamos la imagen normal
			final dataNormal = await DefaultAssetBundle.of(context).load('lib/assets/images/logo_firma.png');
			final bytesNormal = dataNormal.buffer.asUint8List();

			// Cargamos la imagen del Visto Bueno
			final dataVB = await DefaultAssetBundle.of(context).load('lib/assets/images/logo_vb.png');
			final bytesVB = dataVB.buffer.asUint8List();

			if (!context.mounted) return;

			final resultadoEditor = await Navigator.of(context).push<Map<String, dynamic>>(
				MaterialPageRoute(
					builder: (_) => EditorFirmaModal(
						pdfBytes: bytesPdf,
						nombreArchivo: nombreFinal,
						imagenFirmaBytes: bytesNormal,
						imagenVistoBuenoBytes: bytesVB, // <-- Se la pasamos al editor
						nombreFirmante: titular!.nombre,
						dniFirmante: titular.dni,
					),
				),
			);

			if (resultadoEditor == null || !context.mounted) return;

			final pdfProcesado = resultadoEditor['pdfBytes'] as Uint8List;
			final requiereFirma = resultadoEditor['requiereFirma'] as bool;
			final obtrutaNxc = obtenerRutaNextcloud();

			// Extraemos los datos del sello
			final imgSello = resultadoEditor['imagenSello'] as Uint8List?;
			final pagina = resultadoEditor['pagina'] as int?;
			final x = resultadoEditor['x'] as double?;
			final y = resultadoEditor['y'] as double?;
			final ancho = resultadoEditor['ancho'] as double?;
			final alto = resultadoEditor['alto'] as double?;

			final rutaDestino = requiereFirma 
				? "$obtrutaNxc$firmados" 
				: "$obtrutaNxc$proyectados";

			await showDialog(
				context: context,
				barrierDismissible: false,
				builder: (_) => PopupFirma(
					pdfBytes: pdfProcesado,
					nombreArchivo: nombreFinal,
					rutaBackup: rutaDestino, 
					esVistoBueno: !requiereFirma, 
					imagenSello: imgSello,
					pagina: pagina,
					x: x,
					y: y,
					ancho: ancho,
					alto: alto,
				),
			);
		} catch (e) {
			if (!context.mounted) return;
			Navigator.of(context, rootNavigator: true).pop();
			_mostrarErrorLectura(context);
		} finally {
			mensajeCarga.dispose();
		}
	}

	// Modal de carga flotante, centrado, sin fondo oscuro.
	void _mostrarCarga(BuildContext context, ValueNotifier<String> mensaje) {
		showDialog(
			context: context,
			barrierDismissible: false,
			barrierColor: Colors.transparent,
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