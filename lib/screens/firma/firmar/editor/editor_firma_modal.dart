import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firmador_geresa/data/motivo_firma.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';
import 'package:firmador_geresa/services/api_service.dart';

enum PosicionFirma { arribaIzquierda, arribaCentro, arribaDerecha, abajoIzquierda, abajoCentro, abajoDerecha }

class DocumentoReferencial {
	final String id;
	final String nombre;
	final Uint8List bytes;
	DocumentoReferencial({required this.id, required this.nombre, required this.bytes});
}

class EditorFirmaModal extends StatefulWidget {
	final Uint8List pdfBytes;
	final String nombreArchivo;
	final Uint8List imagenFirmaBytes;      
	final Uint8List imagenVistoBuenoBytes; 
	final String nombreFirmante;
	final String dniFirmante;

	const EditorFirmaModal({
		super.key,
		required this.pdfBytes,
		required this.nombreArchivo,
		required this.imagenFirmaBytes,
		required this.imagenVistoBuenoBytes,
		required this.nombreFirmante,
		required this.dniFirmante,
	});

	@override
	State<EditorFirmaModal> createState() => _EditorFirmaModalState();
}

class _EditorFirmaModalState extends State<EditorFirmaModal> {
	final PdfViewerController _pdfController = PdfViewerController();
	final GlobalKey _stackKey = GlobalKey();
	final GlobalKey _selloKey = GlobalKey();
	
	final TextEditingController _paginaCtrl = TextEditingController(text: '1');

	bool _modoManual = true;
	bool _procesando = false;
	bool _foliarDocumento = false; // Variable para el switch

	static const double _anchoFirma = 240;
	static const double _altoFirma = 100; 
	static const double _lado = 54; 
	static const double _margen = 5; 

	Offset? _posicionPorcentual;
	int _paginaFirma = 1; 
	int _totalPaginas = 1;
	List<Size> _tamanos = const [];
	PosicionFirma _posicionAuto = PosicionFirma.abajoIzquierda;

	Uint8List _documentoUnido = Uint8List(0);
	List<DocumentoReferencial> _referenciales = [];
	Offset? _posicionAutoElegida;

	String _motivoSeleccionado = motivosPredeterminados.first;
	String? _cargoSeleccionado;
	List<String> _motivosDisponibles = [];
	List<String> _cargosDisponibles = [];
	String _direccionOficina = ''; 

	@override
	void initState() {
		super.initState();
		_cargarConfiguracionFirma();
		
		_documentoUnido = widget.pdfBytes;
		
		// Configuración inicial del switch y modo
		if (_motivoSeleccionado == 'Visto bueno') {
			_modoManual = false;
			_posicionAuto = PosicionFirma.abajoIzquierda;
			_foliarDocumento = false;
		} else {
			_modoManual = true;
			_foliarDocumento = true;
		}
	}

	@override
	void dispose() {
		_paginaCtrl.dispose();
		super.dispose();
	}

	void _cargarConfiguracionFirma() {
		final motivosExtra = (JsonStorage.getJson('firma_motivos_extra') as List?)?.cast<String>() ?? [];
		_motivosDisponibles = [...motivosPredeterminados, ...motivosExtra];
		_cargosDisponibles = (JsonStorage.getJson('firma_cargos') as List?)?.cast<String>() ?? [];
		
		final motivoActivo = JsonStorage.getString('firma_motivo_activo');
		if (motivoActivo != null && _motivosDisponibles.contains(motivoActivo)) {
			_motivoSeleccionado = motivoActivo;
		} else if (_motivosDisponibles.isNotEmpty) {
			_motivoSeleccionado = _motivosDisponibles.first;
		}

		final cargoActivo = JsonStorage.getString('firma_cargo_activo');
		if (cargoActivo != null && _cargosDisponibles.contains(cargoActivo)) {
			_cargoSeleccionado = cargoActivo;
		} else if (_cargosDisponibles.isNotEmpty) {
			_cargoSeleccionado = _cargosDisponibles.first;
		}

		_direccionOficina = JsonStorage.getString('firma_direccion_oficina') ?? '';
	}

	Future<void> _actualizarDocumentoUnido() async {
		if (_referenciales.isEmpty) {
			setState(() => _documentoUnido = widget.pdfBytes);
			return;
		}
		
		setState(() => _procesando = true);
		try {
			final documentoFinal = sf.PdfDocument();
			final List<Uint8List> todosLosPdfs = [widget.pdfBytes, ..._referenciales.map((r) => r.bytes)];
			sf.PdfSection? seccion;

			for (final bytesPdf in todosLosPdfs) {
				final documentoFuente = sf.PdfDocument(inputBytes: bytesPdf);
				for (int i = 0; i < documentoFuente.pages.count; i++) {
					final paginaFuente = documentoFuente.pages[i];
					final template = paginaFuente.createTemplate();
					if (seccion == null || seccion.pageSettings.size != template.size) {
						seccion = documentoFinal.sections!.add();
						seccion.pageSettings.size = template.size;
						seccion.pageSettings.margins.all = 0;
					}
					seccion.pages.add().graphics.drawPdfTemplate(template, const Offset(0, 0));
				}
				documentoFuente.dispose();
			}

			final List<int> resultado = await documentoFinal.save();
			documentoFinal.dispose();
			
			setState(() {
				_documentoUnido = Uint8List.fromList(resultado);
				_procesando = false;
			});
		} catch (e) {
			debugPrint('Error al unir: $e');
			setState(() => _procesando = false);
		}
	}

	Future<void> _agregarReferencial() async {
		setState(() => _procesando = true);
		bool yaFirmado = false;
		try {
			yaFirmado = await ApiService().estaFirmado(
				pdfBytes: widget.pdfBytes,
				nombreArchivo: widget.nombreArchivo,
			);
		} catch (e) {
			debugPrint('Error verificando firma: $e');
		} finally {
			setState(() => _procesando = false);
		}

		if (yaFirmado && mounted) {
			final anchoModal = MediaQuery.of(context).size.width * 0.6;

			final confirmar = await showDialog<bool>(
				context: context,
				barrierDismissible: false,
				builder: (ctx) => AlertDialog(
					shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ctx.radiusLg)),
					insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
					content: SizedBox(
						width: anchoModal,
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(Icons.warning_amber_rounded, color: ctx.errorRed, size: 48),
								const SizedBox(height: 16),
								Text(
									'Documento ya firmado',
									style: TextStyle(fontWeight: FontWeight.bold, color: ctx.errorRed, fontSize: 20),
									textAlign: TextAlign.center,
								),
								const SizedBox(height: 12),
								Text(
									'El documento actual ya contiene firmas digitales.',
									style: TextStyle(fontWeight: FontWeight.bold, color: ctx.textDark, fontSize: 14),
									textAlign: TextAlign.center,
								),
								const SizedBox(height: 12),
								Text(
									'Si añades un documento referencial, el sistema reconstruirá el PDF y **perderás todas las firmas existentes**. Esta acción no se puede deshacer.',
									style: TextStyle(color: ctx.textGrey, fontSize: 13),
									textAlign: TextAlign.center,
								),
							],
						),
					),
					actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
					actions: [
						Row(
							mainAxisAlignment: MainAxisAlignment.end,
							children: [
								TextButton(
									onPressed: () => Navigator.pop(ctx, false),
									style: TextButton.styleFrom(foregroundColor: ctx.textGrey),
									child: const Text('Cancelar'),
								),
								const SizedBox(width: 12),
								ElevatedButton(
									onPressed: () => Navigator.pop(ctx, true),
									style: ElevatedButton.styleFrom(backgroundColor: ctx.errorRed),
									child: const Text('Añadir y perder firmas'),
								),
							],
						),
					],
				),
			);

			if (confirmar != true) return;
		}

		final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
		if (result != null && result.files.single.bytes != null) {
			setState(() {
				_referenciales.add(DocumentoReferencial(
					id: DateTime.now().millisecondsSinceEpoch.toString(),
					nombre: result.files.single.name,
					bytes: result.files.single.bytes!,
				));
				_actualizarDocumentoUnido();
			});
		}
	}

	void _eliminarReferencial(String id) {
		setState(() {
			_referenciales.removeWhere((element) => element.id == id);
			_actualizarDocumentoUnido();
		});
	}

	Offset _limitar(Offset p, int pagina) {
		if (_tamanos.isEmpty) return p;
		final s = _tamanos[pagina - 1];
		final maxX = (1 - _anchoFirma / s.width).clamp(0.0, 1.0);
		final maxY = (1 - _altoFirma / s.height).clamp(0.0, 1.0);
		return Offset(p.dx.clamp(0.0, maxX), p.dy.clamp(0.0, maxY));
	}

	void _irAPagina(int pagina) {
		if (!_pdfController.isReady) return;
		_pdfController.goToPage(pageNumber: pagina, anchor: PdfPageAnchor.all);
	}

	void _cambiarPagina(int delta) {
		final nueva = (_paginaFirma + delta).clamp(1, _totalPaginas);
		if (nueva == _paginaFirma) return;
		
		setState(() {
			_paginaFirma = nueva;
			_paginaCtrl.text = nueva.toString();
			if (_posicionPorcentual != null) {
				_posicionPorcentual = _limitar(_posicionPorcentual!, nueva);
			}
		});
		_irAPagina(nueva);
	}

	void _irAPaginaInput(String valor) {
		final num = int.tryParse(valor);
		if (num != null && num >= 1 && num <= _totalPaginas) {
			if (num == _paginaFirma) return;
			setState(() {
				_paginaFirma = num;
				if (_posicionPorcentual != null) {
					_posicionPorcentual = _limitar(_posicionPorcentual!, num);
				}
			});
			_irAPagina(num);
		} else {
			_paginaCtrl.text = _paginaFirma.toString();
		}
	}

	void _colocarAutomatico() {
		if (_tamanos.isEmpty) return;
		final n = _totalPaginas;
		final s = _tamanos[n - 1];

		if (_motivoSeleccionado == 'Visto bueno') {
			_posicionAuto = PosicionFirma.abajoIzquierda;
		}

		final izq = _margen / s.width;
		final cen = (1 - _anchoFirma / s.width) / 2;
		final der = 1 - (_anchoFirma + _margen) / s.width;
		final arr = _margen / s.height;
		final aba = 1 - (_altoFirma + _margen) / s.height;

		final pos = switch (_posicionAuto) {
			PosicionFirma.arribaIzquierda => Offset(izq, arr),
			PosicionFirma.arribaCentro => Offset(cen, arr),
			PosicionFirma.arribaDerecha => Offset(der, arr),
			PosicionFirma.abajoIzquierda => Offset(izq, aba),
			PosicionFirma.abajoCentro => Offset(cen, aba),
			PosicionFirma.abajoDerecha => Offset(der, aba),
		};

		setState(() {
			_modoManual = false;
			_paginaFirma = 1;
			_paginaCtrl.text = '1';
			_posicionPorcentual = _limitar(pos, 1);
			_posicionAutoElegida = _posicionPorcentual;
		});
		_irAPagina(1);
	}

	void _elegirPosicionAuto(PosicionFirma p) {
		_posicionAuto = p;
		_colocarAutomatico();
	}

	void _colocarManual() {
		setState(() {
			_modoManual = true;
			_posicionPorcentual = null;
			_posicionAutoElegida = null;
		});
	}

	void _alSoltar(DragTargetDetails<Uint8List> details) {
		if (!_pdfController.isReady || _tamanos.isEmpty) return;
		final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
		if (box == null) return;
		final centroGlobal = details.offset + const Offset(_anchoFirma / 2, _altoFirma / 2);
		final local = box.globalToLocal(centroGlobal);
		final inversa = Matrix4.inverted(_pdfController.value);
		final doc = MatrixUtils.transformPoint(inversa, local);

		final layouts = _pdfController.layout.pageLayouts;
		int idx = 0;
		double mejor = double.infinity;
		for (int i = 0; i < layouts.length; i++) {
			final r = layouts[i];
			final dx = math.max(math.max(r.left - doc.dx, 0.0), doc.dx - r.right);
			final dy = math.max(math.max(r.top - doc.dy, 0.0), doc.dy - r.bottom);
			final d = dx * dx + dy * dy;
			if (d < mejor) { mejor = d; idx = i; }
		}

		final rect = layouts[idx];
		final size = _tamanos[idx];
		final cx = (doc.dx - rect.left) / rect.width;
		final cy = (doc.dy - rect.top) / rect.height;

		setState(() {
			_paginaFirma = idx + 1;
			_paginaCtrl.text = (idx + 1).toString();
			_posicionPorcentual = _limitar(Offset(cx - (_anchoFirma / size.width) / 2, cy - (_altoFirma / size.height) / 2), idx + 1);
		});
	}

	Future<void> _confirmar() async {
		if (_posicionPorcentual == null) return;
		
		setState(() => _procesando = true);
		try {
			// --- COMPROBACIÓN DE SEGURIDAD PARA EL FOLIADO ---
			bool yaFirmado = false;
			if (_foliarDocumento) {
				try {
					yaFirmado = await ApiService().estaFirmado(
						pdfBytes: widget.pdfBytes, // Verificamos el documento original
						nombreArchivo: widget.nombreArchivo,
					);
				} catch (e) {
					debugPrint('Error verificando firma para foliado: $e');
				}
			}

			final boundary = _selloKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
			if (boundary == null) throw Exception('No se encontró el sello visual');
			
			await Future.delayed(const Duration(milliseconds: 100));
			final image = await boundary.toImage(pixelRatio: 3.0);
			final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
			final pngBytes = byteData!.buffer.asUint8List();

			// 1. Preparamos el documento base (con o sin foliado)
			Uint8List documentoParaFirmar = _documentoUnido;

			if (_foliarDocumento && !yaFirmado) {
				final docFoliar = sf.PdfDocument(inputBytes: documentoParaFirmar);
				final int total = docFoliar.pages.count;
				final fuenteFoliar = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 8);
				final negroFoliar = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0));

				for (int i = 0; i < total; i++) {
					final page = docFoliar.pages[i];
					final numFolio = total - i;
					
					// Posición: Abajo a la derecha (margen de 20 puntos)
					final xFolio = page.size.width - 30;
					final yFolio = page.size.height - 20;
					
					page.graphics.drawString(
						'$numFolio', 
						fuenteFoliar, 
						brush: negroFoliar, 
						bounds: Rect.fromLTWH(xFolio, yFolio, 0, 0)
					);
				}
				final foliadoBytes = await docFoliar.save();
				docFoliar.dispose();
				documentoParaFirmar = Uint8List.fromList(foliadoBytes);
			}

			// 2. Estampamos la firma (Visto Bueno o Firma Normal)
			if (_motivoSeleccionado == 'Visto bueno') {
				final decoded = img.decodeImage(pngBytes);
				if (decoded == null) throw Exception('No se pudo decodificar la imagen');
				final bitmap = sf.PdfBitmap(img.encodePng(decoded));

				final document = sf.PdfDocument(inputBytes: documentoParaFirmar);
				final page = document.pages[_paginaFirma - 1];

				final pos = _posicionPorcentual!;
				final x = pos.dx * page.size.width;
				final y = pos.dy * page.size.height;
				final g = page.graphics;

				g.drawImage(
					bitmap,
					Rect.fromLTWH(x, y, _anchoFirma, _altoFirma),
				);

				final List<int> resultado = await document.save();
				document.dispose();

				if (!mounted) return;
				
				Navigator.of(context).pop({
					'pdfBytes': Uint8List.fromList(resultado),
					'requiereFirma': false,
				});
			} else {
				final pos = _posicionPorcentual!;
				final pageSize = _tamanos[_paginaFirma - 1];
				
				final xPuntos = pos.dx * pageSize.width;
				final yPuntos = pos.dy * pageSize.height;

				if (!mounted) return;
				
				Navigator.of(context).pop({
					'pdfBytes': documentoParaFirmar, 
					'requiereFirma': true,
					'imagenSello': pngBytes,
					'pagina': _paginaFirma,
					'x': xPuntos,
					'y': yPuntos,
					'ancho': _anchoFirma,
					'alto': _altoFirma,
				});
			}
		} catch (e) {
			debugPrint('[EditorFirma] Error: $e');
			if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
		} finally {
			if (mounted) setState(() => _procesando = false);
		}
	}

	Widget _imagenFirma({double? size}) {
		final bytes = _motivoSeleccionado == 'Visto bueno' 
				? widget.imagenVistoBuenoBytes 
				: widget.imagenFirmaBytes;
				
		return Image.memory(
			bytes, 
			width: size ?? _lado, 
			height: size ?? _lado, 
			fit: BoxFit.contain, 
			filterQuality: FilterQuality.high
		);
	}

	Widget _firmaVisual() {
		final ahora = DateTime.now();
		final fechaStr = '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year}';
		
		const estiloNormal = TextStyle(fontSize: 6.5, color: Colors.black, height: 1.0);
		const estiloNegrita = TextStyle(fontSize: 7.5, color: Colors.black, fontWeight: FontWeight.bold, height: 1.0);

		if (_motivoSeleccionado == 'Visto bueno') {
			const double ladoSello = 70; 

			return SizedBox(
				width: _anchoFirma, 
				height: _altoFirma, 
				child: Center( 
					child: SizedBox(
						width: ladoSello,
						height: ladoSello,
						child: Stack(
							alignment: Alignment.center,
							children: [
								Positioned.fill(
									child: _imagenFirma(),
								),
								Padding(
									padding: const EdgeInsets.symmetric(horizontal: 12),
									child: Column(
										mainAxisAlignment: MainAxisAlignment.center,
										crossAxisAlignment: CrossAxisAlignment.center,
										children: [
											if (_direccionOficina.isNotEmpty) ...[
												Text(
													_direccionOficina.toUpperCase(), 
													style: const TextStyle(fontSize: 6, color: Colors.black, fontWeight: FontWeight.bold, height: 1.0), 
													textAlign: TextAlign.center,
													maxLines: 1,
													overflow: TextOverflow.ellipsis,
												),
												const SizedBox(height: 2),
											],
											Text(
												fechaStr, 
												style: const TextStyle(fontSize: 5, color: Colors.black, height: 1.0), 
												textAlign: TextAlign.center,
												maxLines: 1,
												overflow: TextOverflow.ellipsis,
											),
											const SizedBox(height: 3),
											Text(
												_motivoSeleccionado, 
												style: const TextStyle(fontSize: 6, color: Colors.black, fontWeight: FontWeight.bold, height: 1.0), 
												textAlign: TextAlign.center,
												maxLines: 1,
												overflow: TextOverflow.ellipsis,
											),
										],
									),
								),
							],
						),
					),
				),
			);
		}

		return SizedBox(
			width: _anchoFirma,
			height: _altoFirma,
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.center,
				children: [
					SizedBox(width: _lado, height: _lado, child: _imagenFirma()),
					const SizedBox(width: 8),
					Expanded(
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								const Text('Firmado digitalmente por:', style: estiloNormal),
								Text(widget.nombreFirmante, style: estiloNormal),
								if (_cargoSeleccionado != null && _cargoSeleccionado!.isNotEmpty)
									Text(_cargoSeleccionado!, style: estiloNormal),
								Text('FIR (DNI ${widget.dniFirmante}) hard', style: estiloNormal),
								Text('F: $fechaStr | Folios: $_totalPaginas', style: estiloNormal), 
								Text('Motivo: $_motivoSeleccionado', style: estiloNormal),
							],
						),
					),
				],
			),
		);
	}

	Widget _botonZoom(IconData icono, String tooltip, VoidCallback onTap) {
		return Material(
			color: context.surfaceWhite,
			elevation: 2,
			borderRadius: BorderRadius.circular(context.radiusMd),
			child: IconButton(icon: Icon(icono, size: 20), tooltip: tooltip, color: context.textDark, onPressed: onTap),
		);
	}

	Widget _documentosSidebar() {
		return Container(
			width: 220,
			decoration: BoxDecoration(color: context.surfaceGrey.withValues(alpha: 0.5), border: Border(right: BorderSide(color: context.borderColor))),
			child: Column(
				children: [
					Container(padding: const EdgeInsets.all(16), child: Text('Documentos', style: TextStyle(fontWeight: FontWeight.bold, color: context.textDark))),
					Container(
						margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
						padding: const EdgeInsets.all(8),
						decoration: BoxDecoration(color: context.surfaceWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.primaryPurple)),
						child: Row(
							children: [
								Icon(Icons.lock_outline, size: 20, color: context.primaryPurple),
								const SizedBox(width: 8),
								Expanded(child: Text(widget.nombreArchivo, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.textDark))),
							],
						),
					),
					Expanded(
						child: ReorderableListView.builder(
							buildDefaultDragHandles: false, 
							itemCount: _referenciales.length,
							onReorder: (oldIndex, newIndex) {
								setState(() {
									if (newIndex > oldIndex) newIndex -= 1;
									final item = _referenciales.removeAt(oldIndex);
									_referenciales.insert(newIndex, item);
									_actualizarDocumentoUnido();
								});
							},
							itemBuilder: (context, index) {
								final doc = _referenciales[index];
								return Container(
									key: ValueKey(doc.id),
									margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
									padding: const EdgeInsets.all(8),
									decoration: BoxDecoration(color: context.surfaceWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.borderColor)),
									child: Row(
										children: [
											ReorderableDragStartListener(index: index, child: Icon(Icons.drag_indicator, size: 20, color: context.textGrey)),
											const SizedBox(width: 8),
											Expanded(child: Text(doc.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.textDark))),
											IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.red), onPressed: () => _eliminarReferencial(doc.id), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
										],
									),
								);
							},
						),
					),
				],
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final widgetFantasma = Positioned(
			left: -2000,
			child: Material(
				color: Colors.transparent,
				child: RepaintBoundary(
					key: _selloKey,
					child: SizedBox(
						width: _anchoFirma,
						height: _altoFirma,
						child: _firmaVisual(),
					),
				),
			),
		);

		return Scaffold(
			backgroundColor: context.backgroundLight,
			appBar: AppBar(title: const Text('Firma del documento'), elevation: 0, backgroundColor: context.surfaceWhite, foregroundColor: context.textDark),
			body: Row(
				children: [
					if (_referenciales.isNotEmpty) _documentosSidebar(),
					Expanded(
						child: Container(
							margin: const EdgeInsets.all(24),
							decoration: BoxDecoration(color: context.surfaceGrey, borderRadius: BorderRadius.circular(context.radiusLg), border: Border.all(color: context.borderColor)),
							child: ClipRRect(
								borderRadius: BorderRadius.circular(context.radiusLg),
								child: Stack(
									key: _stackKey,
									children: [
										if (_documentoUnido.isNotEmpty)
											PdfViewer.data(
												key: ValueKey(_documentoUnido.length),
												_documentoUnido,
												sourceName: widget.nombreArchivo,
												controller: _pdfController,
												params: PdfViewerParams(
													backgroundColor: context.surfaceGrey,
													onViewerReady: (document, controller) {
														setState(() {
															_totalPaginas = document.pages.length;
															_tamanos = document.pages.map((p) => Size(p.width, p.height)).toList();
															if (_posicionPorcentual != null) _posicionPorcentual = _limitar(_posicionPorcentual!, _paginaFirma);
														});
													},
													pageOverlaysBuilder: (context, pageRect, page) {
														if (_posicionPorcentual == null || page.pageNumber != _paginaFirma) return const [];
														
														final escala = pageRect.width / page.width;
														return [
															Positioned(
																left: _posicionPorcentual!.dx * pageRect.width,
																top: _posicionPorcentual!.dy * pageRect.height,
																width: _anchoFirma * escala,
																height: _altoFirma * escala,
																child: GestureDetector(
																	onPanUpdate: (details) {
																		setState(() {
																			final nuevo = Offset(_posicionPorcentual!.dx + details.delta.dx / pageRect.width, _posicionPorcentual!.dy + details.delta.dy / pageRect.height);
																			_posicionPorcentual = _limitar(nuevo, _paginaFirma);
																		});
																	},
																	child: MouseRegion(
																		cursor: SystemMouseCursors.grab,
																		child: FittedBox(
																			fit: BoxFit.fill,
																			child: _firmaVisual(),
																		),
																	),
																),
															),
														];
													},
												),
											),
										widgetFantasma,

										// --- PAGINADOR FLOTANTE ARRIBA ---
										if (_totalPaginas > 1)
											Positioned(
												top: 12,
												left: 0,
												right: 0,
												child: Center(
													child: Material(
														color: context.surfaceWhite,
														elevation: 3,
														borderRadius: BorderRadius.circular(context.radiusPill),
														child: Padding(
															padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
															child: Row(
																mainAxisSize: MainAxisSize.min,
																children: [
																	IconButton(
																		onPressed: _paginaFirma > 1 ? () {
																			setState(() {
																				_paginaFirma = 1;
																				_paginaCtrl.text = '1';
																				if (_posicionPorcentual != null) _posicionPorcentual = _limitar(_posicionPorcentual!, 1);
																			});
																			_irAPagina(1);
																		} : null,
																		icon: const Icon(Icons.first_page_rounded, size: 20),
																		padding: EdgeInsets.zero,
																		constraints: const BoxConstraints(minWidth: 32),
																		color: context.textDark,
																		tooltip: 'Ir al inicio',
																	),
																	
																	IconButton(
																		onPressed: _paginaFirma > 1 ? () => _cambiarPagina(-1) : null,
																		icon: const Icon(Icons.chevron_left_rounded, size: 20),
																		padding: EdgeInsets.zero,
																		constraints: const BoxConstraints(minWidth: 32),
																		color: context.textDark,
																	),

																	Padding(
																		padding: const EdgeInsets.symmetric(horizontal: 8),
																		child: Row(
																			children: [
																				Text('Página', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textGrey)),
																				const SizedBox(width: 8),
																				Container(
																					width: 36,
																					height: 28,
																					decoration: BoxDecoration(
																						color: context.surfaceGrey,
																						borderRadius: BorderRadius.circular(context.radiusSm),
																					),
																					alignment: Alignment.center,
																					child: TextField(
																						controller: _paginaCtrl,
																						textAlign: TextAlign.center,
																						style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textDark),
																						decoration: const InputDecoration(
																							isDense: true,
																							contentPadding: EdgeInsets.zero,
																							border: InputBorder.none,
																							enabledBorder: InputBorder.none,
																							focusedBorder: InputBorder.none,
																						),
																						onSubmitted: _irAPaginaInput,
																					),
																				),
																				const SizedBox(width: 8),
																				Text('de $_totalPaginas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textGrey)),
																			],
																		),
																	),

																	IconButton(
																		onPressed: _paginaFirma < _totalPaginas ? () => _cambiarPagina(1) : null,
																		icon: const Icon(Icons.chevron_right_rounded, size: 20),
																		padding: EdgeInsets.zero,
																		constraints: const BoxConstraints(minWidth: 32),
																		color: context.textDark,
																	),

																	IconButton(
																		onPressed: _paginaFirma < _totalPaginas ? () {
																			setState(() {
																				_paginaFirma = _totalPaginas;
																				_paginaCtrl.text = _totalPaginas.toString();
																				if (_posicionPorcentual != null) _posicionPorcentual = _limitar(_posicionPorcentual!, _totalPaginas);
																			});
																			_irAPagina(_totalPaginas);
																		} : null,
																		icon: const Icon(Icons.last_page_rounded, size: 20),
																		padding: EdgeInsets.zero,
																		constraints: const BoxConstraints(minWidth: 32),
																		color: context.textDark,
																		tooltip: 'Ir al final',
																	),
																],
															),
														),
													),
												),
											),

										Positioned.fill(
											child: DragTarget<Uint8List>(
												onAcceptWithDetails: _alSoltar,
												builder: (context, candidateData, rejectedData) {
													return IgnorePointer(child: Container(color: candidateData.isNotEmpty ? context.primaryPurple.withValues(alpha: 0.05) : Colors.transparent));
												},
											),
										),
										Positioned(
											top: 12,
											right: 12,
											child: Column(
												children: [
													_botonZoom(Icons.add_rounded, 'Acercar', () { if (_pdfController.isReady) _pdfController.zoomUp(); }),
													const SizedBox(height: 8),
													_botonZoom(Icons.remove_rounded, 'Alejar', () { if (_pdfController.isReady) _pdfController.zoomDown(); }),
													const SizedBox(height: 8),
													_botonZoom(Icons.fit_screen_rounded, 'Ajustar página', () { _irAPagina(_pdfController.pageNumber ?? 1); }),
												],
											),
										),
										Positioned(
											bottom: 24,
											left: 0,
											right: 0,
											child: Center(
												child: FloatingActionButton(
													onPressed: _procesando ? null : _agregarReferencial,
													backgroundColor: context.primaryPurple,
													foregroundColor: Colors.white,
													tooltip: _procesando ? 'Verificando documento...' : 'Añadir documento referencial',
													child: _procesando
															? const SizedBox(
																	width: 20,
																	height: 20,
																	child: CircularProgressIndicator(
																		strokeWidth: 2,
																		color: Colors.white,
																	),
																)
															: const Icon(Icons.attach_file_rounded),
												),
											),
										),
									],
								),
							),
						),
					),
					Container(
						width: 300,
						decoration: BoxDecoration(color: context.surfaceWhite, border: Border(left: BorderSide(color: context.borderColor))),
						child: Column(
							children: [
								Expanded(
									child: SingleChildScrollView(
										padding: const EdgeInsets.all(24),
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.stretch,
											children: [
												Text('Firma del documento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.textDark)),
												const SizedBox(height: 8),
												Text('Elige cómo deseas colocar tu firma antes de firmar el documento.', style: TextStyle(fontSize: 14, color: context.textGrey)),
												
												const SizedBox(height: 24),
												Text('Motivo de firma', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textDark)),
												const SizedBox(height: 4),
												DropdownButtonFormField<String>(
													value: _motivoSeleccionado,
													isExpanded: true,
													decoration: InputDecoration(
														contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
														border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
													),
													items: _motivosDisponibles.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
													onChanged: (val) { 
														if (val != null) {
															setState(() {
																if (_motivoSeleccionado == 'Visto bueno' && val != 'Visto bueno') {
																	_modoManual = true;
																	_posicionPorcentual = null;      
																	_posicionAutoElegida = null;
																	_foliarDocumento = true; // Al cambiar a firma, se activa por defecto
																} else if (val == 'Visto bueno') {
																	_foliarDocumento = false; // Al cambiar a visto bueno, se desactiva por defecto
																}
																_motivoSeleccionado = val;
															});
														} 
													},
												),

												if (_cargosDisponibles.isNotEmpty && _motivoSeleccionado != 'Visto bueno') ...[
													const SizedBox(height: 12),
													Text('Cargo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textDark)),
													const SizedBox(height: 4),
													DropdownButtonFormField<String>(
														value: _cargoSeleccionado,
														isExpanded: true,
														decoration: InputDecoration(
															contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
															border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
														),
														items: _cargosDisponibles.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
														onChanged: (val) { setState(() => _cargoSeleccionado = val); },
													),
												],
												const Divider(height: 32),

												// BOTÓN ÚNICO DE FIRMA MANUAL
												OutlinedButton.icon(
													onPressed: _colocarManual,
													style: OutlinedButton.styleFrom(
														backgroundColor: context.primaryPurple.withValues(alpha: 0.1),
														foregroundColor: context.primaryPurple,
														side: BorderSide(color: context.primaryPurple),
														padding: const EdgeInsets.symmetric(vertical: 16),
														shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusMd)),
													),
													icon: const Icon(Icons.touch_app_outlined, size: 20),
													label: const Text('Firma manual'),
												),

												const SizedBox(height: 24),
												
												// EL DRAGGABLE
												Center(
													child: Draggable<Uint8List>(
														data: widget.imagenFirmaBytes,
														dragAnchorStrategy: (draggable, context, position) => const Offset(_anchoFirma / 2, _altoFirma / 2),
														feedback: Material(color: Colors.transparent, child: Opacity(opacity: 0.85, child: _firmaVisual())),
														childWhenDragging: Opacity(opacity: 0.3, child: _imagenFirma(size: 50)),
														child: Container(
															padding: const EdgeInsets.all(8),
															decoration: BoxDecoration(color: context.surfaceGrey, borderRadius: BorderRadius.circular(context.radiusMd), border: Border.all(color: context.borderColor)),
															child: Column(
																children: [
																	_imagenFirma(size: 50),
																	const SizedBox(height: 8),
																	Text('Arrastra la firma hacia\nel documento', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.textGrey, fontWeight: FontWeight.w500)),
																],
															),
														),
													),
												),

												const SizedBox(height: 16),
												
												// SWITCH PARA FOLIAR
												Container(
													padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
													decoration: BoxDecoration(
														color: context.surfaceGrey,
														borderRadius: BorderRadius.circular(context.radiusMd),
														border: Border.all(color: context.borderColor),
													),
													child: Row(
														mainAxisAlignment: MainAxisAlignment.spaceBetween,
														children: [
															Row(
																children: [
																	Icon(Icons.format_list_numbered_rounded, size: 20, color: context.textDark),
																	const SizedBox(width: 8),
																	Text('Foliar documento', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textDark)),
																],
															),
															Switch(
																value: _foliarDocumento,
																activeColor: context.primaryPurple,
																onChanged: (val) => setState(() => _foliarDocumento = val),
															),
														],
													),
												),
											],
										),
									),
								),
								
								Container(
									padding: const EdgeInsets.all(24),
									decoration: BoxDecoration(
										border: Border(top: BorderSide(color: context.borderColor)),
									),
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											ElevatedButton(
												onPressed: _procesando || _posicionPorcentual == null ? null : _confirmar,
												style: ElevatedButton.styleFrom(
													backgroundColor: context.primaryPurple,
													foregroundColor: Colors.white,
													elevation: 0,
													minimumSize: const Size.fromHeight(56), // Un poco más alto para 2 líneas
													shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusPill)),
												),
												child: _procesando
														? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
														: Column(
																mainAxisAlignment: MainAxisAlignment.center,
																children: [
																	Text(
																		_motivoSeleccionado == 'Visto bueno' ? 'Confirmar' : 'Confirmar firma',
																		style: const TextStyle(fontSize: 14, height: 1.1, fontWeight: FontWeight.w500),
																	),
																	Text(
																		_motivoSeleccionado == 'Visto bueno' ? 'Visto Bueno' : 'digital',
																		style: const TextStyle(fontSize: 14, height: 1.1, fontWeight: FontWeight.w700),
																	),
																],
															),
											),
											const SizedBox(height: 8),
											TextButton(
												onPressed: () => Navigator.of(context).pop(null),
												style: TextButton.styleFrom(
													foregroundColor: context.textGrey,
													minimumSize: const Size.fromHeight(40),
												),
												child: const Text('Cancelar'),
											),
										],
									),
								),
							],
						),
					),
				],
			),
		);
	}
}