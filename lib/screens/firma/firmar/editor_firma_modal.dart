import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';

enum PosicionFirma {
	arribaIzquierda,
	arribaCentro,
	arribaDerecha,
	abajoIzquierda,
	abajoCentro,
	abajoDerecha,
}

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
	final String nombreFirmante;
	final String dniFirmante;

	const EditorFirmaModal({
		super.key,
		required this.pdfBytes,
		required this.nombreArchivo,
		required this.imagenFirmaBytes,
		required this.nombreFirmante,
		required this.dniFirmante,
	});

	@override
	State<EditorFirmaModal> createState() => _EditorFirmaModalState();
}

class _EditorFirmaModalState extends State<EditorFirmaModal> {
	final PdfViewerController _pdfController = PdfViewerController();
	final GlobalKey _stackKey = GlobalKey();

	bool _modoManual = true;
	bool _procesando = false;

	static const double _anchoFirma = 230;
	static const double _altoFirma = 65;
	static const double _lado = 54; 
	static const double _margen = 5; 

	Offset? _posicionPorcentual;
	int _paginaFirma = 1; 
	int _totalPaginas = 1;
	List<Size> _tamanos = const [];
	PosicionFirma _posicionAuto = PosicionFirma.arribaCentro;

	Uint8List _documentoUnido = Uint8List(0);
	List<DocumentoReferencial> _referenciales = [];
	Offset? _posicionAutoElegida;

	@override
	void initState() {
		super.initState();
		_actualizarDocumentoUnido();
	}

	// ---------- Lógica de Unión de PDFs ----------

	void _actualizarDocumentoUnido() async {
		setState(() => _procesando = true);
		try {
			final documentoFinal = sf.PdfDocument();
			final List<Uint8List> todosLosPdfs = [
				widget.pdfBytes,
				..._referenciales.map((r) => r.bytes),
			];

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
		final result = await FilePicker.platform.pickFiles(
			type: FileType.custom,
			allowedExtensions: ['pdf'],
			withData: true,
		);

		if (result != null && result.files.single.bytes != null) {
			final nuevo = DocumentoReferencial(
				id: DateTime.now().millisecondsSinceEpoch.toString(),
				nombre: result.files.single.name,
				bytes: result.files.single.bytes!,
			);
			setState(() {
				_referenciales.add(nuevo);
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

	// ---------- Utilidades de Posición ----------

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
		if (nueva == _paginaFirma || _posicionPorcentual == null) return;
		setState(() {
			_paginaFirma = nueva;
			_posicionPorcentual = _limitar(_posicionPorcentual!, nueva);
		});
		_irAPagina(nueva);
	}

	void _colocarAutomatico() {
		if (_tamanos.isEmpty) return;
		final n = _totalPaginas;
		final s = _tamanos[n - 1];

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
			if (d < mejor) {
				mejor = d;
				idx = i;
			}
		}

		final rect = layouts[idx];
		final size = _tamanos[idx];
		final cx = (doc.dx - rect.left) / rect.width;
		final cy = (doc.dy - rect.top) / rect.height;

		final pos = Offset(
			cx - (_anchoFirma / size.width) / 2,
			cy - (_altoFirma / size.height) / 2,
		);

		setState(() {
			_paginaFirma = idx + 1;
			_posicionPorcentual = _limitar(pos, idx + 1);
		});
	}

	List<String> _calcularNombreLineas(String nombre) {
		final textoFormateado = nombre.trim().split(' ').map((palabra) {
			if (palabra.isEmpty) return '';
			return palabra[0].toUpperCase() + palabra.substring(1).toLowerCase();
		}).join(' ');

		if (textoFormateado.length <= 22) return [textoFormateado];

		final palabras = textoFormateado.split(' ');
		if (palabras.length == 1) return [textoFormateado];

		int mejorCorte = -1;
		int largoActual = 0;

		for (int i = 0; i < palabras.length; i++) {
			largoActual += palabras[i].length + 1;
			if (largoActual > 22) {
				mejorCorte = i;
				break;
			}
		}

		if (mejorCorte <= 0) return [textoFormateado];
		return [
			palabras.sublist(0, mejorCorte).join(' '),
			palabras.sublist(mejorCorte).join(' ')
		];
	}

	// ---------- Confirmar ----------

	Future<void> _confirmar() async {
		if (_modoManual && _posicionPorcentual == null) return;
		if (!_modoManual && _posicionAutoElegida == null) return;
		
		setState(() => _procesando = true);
		sf.PdfDocument? document;
		try {
			final ahora = DateTime.now();
			final fechaStr = '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year}';
			final horaStr = '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';

			final decoded = img.decodeImage(widget.imagenFirmaBytes);
			if (decoded == null) throw Exception('No se pudo decodificar la imagen');
			final bitmap = sf.PdfBitmap(img.encodePng(decoded));

			document = sf.PdfDocument(inputBytes: _documentoUnido);
			
			final paginasAProcesar = _modoManual 
				? [_paginaFirma - 1] 
				: List.generate(document.pages.count, (index) => index); 

			for (final index in paginasAProcesar) {
				final page = document.pages[index];
				final pos = _modoManual ? _posicionPorcentual! : _posicionAutoElegida!;
				
				final x = pos.dx * page.size.width;
				final y = pos.dy * page.size.height;
				final g = page.graphics;

				final ratio = decoded.width / decoded.height;
				double w = _lado, h = _lado;
				if (ratio > 1) { h = _lado / ratio; } else { w = _lado * ratio; }
				g.drawImage(
					bitmap,
					Rect.fromLTWH(x + (_lado - w) / 2, y + (_altoFirma - h) / 2, w, h),
				);

				final fuente = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 6.5);
				final negrita = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 8, style: sf.PdfFontStyle.bold);
				final negro = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0));
				final tx = x + _lado + 8;

				final lineasNombre = _calcularNombreLineas(widget.nombreFirmante);
				final esDobleLinea = lineasNombre.length > 1;

				g.drawString('Firmado digitalmente por:', fuente, brush: negro, bounds: Rect.fromLTWH(tx, y + 8, 0, 0));
				g.drawString(lineasNombre[0], negrita, brush: negro, bounds: Rect.fromLTWH(tx, y + (esDobleLinea ? 15 : 19), 0, 0));
				
				if (esDobleLinea) {
					g.drawString(lineasNombre[1], negrita, brush: negro, bounds: Rect.fromLTWH(tx, y + 24, 0, 0));
					g.drawString('FIR (DNI ${widget.dniFirmante}) hard', fuente, brush: negro, bounds: Rect.fromLTWH(tx, y + 33, 0, 0));
					g.drawString('Fecha: $fechaStr - $horaStr', fuente, brush: negro, bounds: Rect.fromLTWH(tx, y + 41, 0, 0));
					g.drawString('Folios: $_totalPaginas', fuente, brush: negro, bounds: Rect.fromLTWH(tx, y + 49, 0, 0));
				} else {
					g.drawString('FIR (DNI ${widget.dniFirmante}) hard', fuente, brush: negro, bounds: Rect.fromLTWH(tx, y + 29, 0, 0));
					g.drawString('Fecha: $fechaStr - $horaStr', fuente, brush: negro, bounds: Rect.fromLTWH(tx, y + 37, 0, 0));
					g.drawString('Folios: $_totalPaginas', fuente, brush: negro, bounds: Rect.fromLTWH(tx, y + 45, 0, 0));
				}
			}

			final List<int> resultado = await document.save();

			if (!mounted) return;
			Navigator.of(context).pop(Uint8List.fromList(resultado));
		} catch (e) {
			debugPrint('[EditorFirma] Error: $e');
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Error al insertar la firma: $e')),
				);
			}
		} finally {
			document?.dispose();
			if (mounted) setState(() => _procesando = false);
		}
	}

	// ---------- UI ----------

	Widget _imagenFirma({double? size}) => Image.memory(
				widget.imagenFirmaBytes,
				width: size ?? _lado,
				height: size ?? _lado,
				fit: BoxFit.contain,
				filterQuality: FilterQuality.high,
			);

	Widget _firmaVisual() {
		final ahora = DateTime.now();
		final fechaStr = '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year}';
		final horaStr = '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';
		
		const estiloNormal = TextStyle(fontSize: 6.5, color: Colors.black, height: 1.1);
		const estiloNegrita = TextStyle(fontSize: 8, color: Colors.black, fontWeight: FontWeight.bold, height: 1.1);

		final lineasNombre = _calcularNombreLineas(widget.nombreFirmante);
		final esDobleLinea = lineasNombre.length > 1;

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
								Text(lineasNombre[0], style: estiloNegrita),
								if (esDobleLinea) Text(lineasNombre[1], style: estiloNegrita),
								Text('FIR (DNI ${widget.dniFirmante}) hard', style: estiloNormal),
								Text('Fecha: $fechaStr - $horaStr', style: estiloNormal),
								Text('Folios: $_totalPaginas', style: estiloNormal),
							],
						),
					),
				],
			),
		);
	}

	Widget _opcionPosicion(PosicionFirma p, String tooltip) {
		final seleccionado = _posicionAuto == p;
		return Tooltip(
			message: tooltip,
			child: InkWell(
				customBorder: const CircleBorder(),
				onTap: () => _elegirPosicionAuto(p),
				child: Padding(
					padding: const EdgeInsets.all(6),
					child: Icon(
						seleccionado ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
						size: 22,
						color: seleccionado ? context.primaryPurple : context.textGrey,
					),
				),
			),
		);
	}

	Widget _selectorPosicion() {
		return Container(
			margin: const EdgeInsets.only(top: 16),
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(
				color: context.surfaceGrey,
				borderRadius: BorderRadius.circular(context.radiusMd),
				border: Border.all(color: context.borderColor),
			),
			child: Column(
				children: [
					Text(
						'Posición en la página',
						style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textGrey),
					),
					const SizedBox(height: 8),
					Row(
						mainAxisAlignment: MainAxisAlignment.spaceBetween,
						children: [
							_opcionPosicion(PosicionFirma.arribaIzquierda, 'Arriba izquierda'),
							_opcionPosicion(PosicionFirma.arribaCentro, 'Arriba centro'),
							_opcionPosicion(PosicionFirma.arribaDerecha, 'Arriba derecha'),
						],
					),
					Row(
						mainAxisAlignment: MainAxisAlignment.spaceBetween,
						children: [
							_opcionPosicion(PosicionFirma.abajoIzquierda, 'Abajo izquierda'),
							_opcionPosicion(PosicionFirma.abajoCentro, 'Abajo centro'),
							_opcionPosicion(PosicionFirma.abajoDerecha, 'Abajo derecha'),
						],
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
			child: IconButton(
				icon: Icon(icono, size: 20),
				tooltip: tooltip,
				color: context.textDark,
				onPressed: onTap,
			),
		);
	}

	Widget _documentosSidebar() {
		return Container(
			width: 220,
			decoration: BoxDecoration(
				color: context.surfaceGrey.withValues(alpha: 0.5),
				border: Border(right: BorderSide(color: context.borderColor)),
			),
			child: Column(
				children: [
					Container(
						padding: const EdgeInsets.all(16),
						child: Text(
							'Documentos',
							style: TextStyle(fontWeight: FontWeight.bold, color: context.textDark),
						),
					),
					
					// Documento principal (fijo)
					Container(
						margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
						padding: const EdgeInsets.all(8),
						decoration: BoxDecoration(
							color: context.surfaceWhite,
							borderRadius: BorderRadius.circular(8),
							border: Border.all(color: context.primaryPurple),
						),
						child: Row(
							children: [
								Icon(Icons.lock_outline, size: 20, color: context.primaryPurple),
								const SizedBox(width: 8),
								Expanded(
									child: Text(
										widget.nombreArchivo,
										maxLines: 2,
										overflow: TextOverflow.ellipsis,
										style: TextStyle(fontSize: 12, color: context.textDark),
									),
								),
							],
						),
					),

					// Lista de documentos referenciales (arrastrables)
					Expanded(
						child: ReorderableListView.builder(
							buildDefaultDragHandles: false, // Ocultar el icono de arrastre por defecto
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
									decoration: BoxDecoration(
										color: context.surfaceWhite,
										borderRadius: BorderRadius.circular(8),
										border: Border.all(color: context.borderColor),
									),
									child: Row(
										children: [
											// El arrastre solo se activa si tocas el icono de la izquierda
											ReorderableDragStartListener(
												index: index,
												child: Icon(Icons.drag_indicator, size: 20, color: context.textGrey),
											),
											const SizedBox(width: 8),
											Expanded(
												child: Text(
													doc.nombre,
													maxLines: 2,
													overflow: TextOverflow.ellipsis,
													style: TextStyle(fontSize: 12, color: context.textDark),
												),
											),
											IconButton(
												icon: const Icon(Icons.close, size: 16, color: Colors.red),
												onPressed: () => _eliminarReferencial(doc.id),
												padding: EdgeInsets.zero,
												constraints: const BoxConstraints(),
											),
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
		return Scaffold(
			backgroundColor: context.backgroundLight,
			appBar: AppBar(
				title: const Text('Firma del documento'),
				elevation: 0,
				backgroundColor: context.surfaceWhite,
				foregroundColor: context.textDark,
			),
			body: Row(
				children: [
					if (_referenciales.isNotEmpty) _documentosSidebar(),
					
					Expanded(
						child: Container(
							margin: const EdgeInsets.all(24),
							decoration: BoxDecoration(
								color: context.surfaceGrey,
								borderRadius: BorderRadius.circular(context.radiusLg),
								border: Border.all(color: context.borderColor),
							),
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
															if (_modoManual && _posicionPorcentual != null) {
																_posicionPorcentual = _limitar(_posicionPorcentual!, _paginaFirma);
															}
														});
													},
													pageOverlaysBuilder: (context, pageRect, page) {
														if (_modoManual) {
															if (_posicionPorcentual == null || page.pageNumber != _paginaFirma) return const [];
															final escala = pageRect.width / page.width;
															return [
																Positioned(
																	left: _posicionPorcentual!.dx * pageRect.width,
																	top: _posicionPorcentual!.dy * pageRect.height,
																	child: GestureDetector(
																		onPanUpdate: (details) {
																			setState(() {
																				final nuevo = Offset(
																					_posicionPorcentual!.dx + details.delta.dx / pageRect.width,
																					_posicionPorcentual!.dy + details.delta.dy / pageRect.height,
																				);
																				_posicionPorcentual = _limitar(nuevo, _paginaFirma);
																			});
																		},
																		child: MouseRegion(
																			cursor: SystemMouseCursors.grab,
																			child: SizedBox(
																				width: _anchoFirma * escala,
																				height: _altoFirma * escala,
																				child: FittedBox(
																					fit: BoxFit.fill,
																					child: _firmaVisual(),
																				),
																			),
																		),
																	),
																),
															];
														} else {
															if (_posicionAutoElegida == null) return const [];
															final escala = pageRect.width / page.width;
															return [
																Positioned(
																	left: _posicionAutoElegida!.dx * pageRect.width,
																	top: _posicionAutoElegida!.dy * pageRect.height,
																	child: IgnorePointer(
																		child: SizedBox(
																			width: _anchoFirma * escala,
																			height: _altoFirma * escala,
																			child: FittedBox(
																				fit: BoxFit.fill,
																				child: _firmaVisual(),
																			),
																		),
																	),
																),
															];
														}
													},
												),
											),

										if (_modoManual)
											Positioned.fill(
												child: DragTarget<Uint8List>(
													onAcceptWithDetails: _alSoltar,
													builder: (context, candidateData, rejectedData) {
														return IgnorePointer(
															child: Container(
																color: candidateData.isNotEmpty
																		? context.primaryPurple.withValues(alpha: 0.05)
																		: Colors.transparent,
															),
														);
													},
												),
											),

										Positioned(
											top: 12,
											right: 12,
											child: Column(
												children: [
													_botonZoom(Icons.add_rounded, 'Acercar', () {
														if (_pdfController.isReady) _pdfController.zoomUp();
													}),
													const SizedBox(height: 8),
													_botonZoom(Icons.remove_rounded, 'Alejar', () {
														if (_pdfController.isReady) _pdfController.zoomDown();
													}),
													const SizedBox(height: 8),
													_botonZoom(Icons.fit_screen_rounded, 'Ajustar página', () {
														_irAPagina(_pdfController.pageNumber ?? 1);
													}),
												],
											),
										),

										Positioned(
											bottom: 24,
											left: 0,
											right: 0,
											child: Center(
												child: FloatingActionButton(
													onPressed: _agregarReferencial,
													backgroundColor: context.primaryPurple,
													foregroundColor: Colors.white,
													tooltip: 'Añadir documento referencial',
													child: const Icon(Icons.attach_file_rounded),
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
						padding: const EdgeInsets.all(24),
						decoration: BoxDecoration(
							color: context.surfaceWhite,
							border: Border(left: BorderSide(color: context.borderColor)),
						),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Text(
									'Firma del documento',
									style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.textDark),
								),
								const SizedBox(height: 8),
								Text(
									'Elige cómo deseas colocar tu firma antes de firmar el documento.',
									style: TextStyle(fontSize: 14, color: context.textGrey),
								),
								const SizedBox(height: 32),

								OutlinedButton.icon(
									onPressed: _colocarManual,
									style: OutlinedButton.styleFrom(
										backgroundColor: _modoManual ? context.primaryPurple.withValues(alpha: 0.1) : Colors.transparent,
										foregroundColor: _modoManual ? context.primaryPurple : context.textGrey,
										side: BorderSide(color: _modoManual ? context.primaryPurple : context.borderColor),
										padding: const EdgeInsets.symmetric(vertical: 16),
										shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusMd)),
									),
									icon: Icon(_modoManual ? Icons.check_circle_rounded : Icons.touch_app_outlined, size: 20),
									label: const Text('Firma manual'),
								),

								if (_modoManual) ...[
									const SizedBox(height: 24),
									Center(
										child: Draggable<Uint8List>(
											data: widget.imagenFirmaBytes,
											dragAnchorStrategy: (draggable, context, position) => const Offset(_anchoFirma / 2, _altoFirma / 2),
											feedback: Material(
												color: Colors.transparent,
												child: Opacity(opacity: 0.85, child: _firmaVisual()),
											),
											childWhenDragging: Opacity(opacity: 0.3, child: _imagenFirma(size: 50)),
											child: Container(
												padding: const EdgeInsets.all(8),
												decoration: BoxDecoration(
													color: context.surfaceGrey,
													borderRadius: BorderRadius.circular(context.radiusMd),
													border: Border.all(color: context.borderColor),
												),
												child: Column(
													children: [
														_imagenFirma(size: 50),
														const SizedBox(height: 8),
														Text(
															'Arrastra la firma hacia\nel documento',
															textAlign: TextAlign.center,
															style: TextStyle(fontSize: 12, color: context.textGrey, fontWeight: FontWeight.w500),
														),
													],
												),
											),
										),
									),
								],

								const SizedBox(height: 12),

								OutlinedButton.icon(
									onPressed: _colocarAutomatico,
									style: OutlinedButton.styleFrom(
										backgroundColor: !_modoManual ? context.primaryPurple.withValues(alpha: 0.1) : Colors.transparent,
										foregroundColor: !_modoManual ? context.primaryPurple : context.textGrey,
										side: BorderSide(color: !_modoManual ? context.primaryPurple : context.borderColor),
										padding: const EdgeInsets.symmetric(vertical: 16),
										shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusMd)),
									),
									icon: Icon(!_modoManual ? Icons.check_circle_rounded : Icons.auto_awesome_rounded, size: 20),
									label: const Text('Firma automática'),
								),

								if (!_modoManual) _selectorPosicion(),

								if (_modoManual && _posicionPorcentual != null && _totalPaginas > 1) ...[
									const SizedBox(height: 24),
									Row(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											IconButton(
												onPressed: _paginaFirma > 1 ? () => _cambiarPagina(-1) : null,
												icon: const Icon(Icons.chevron_left_rounded),
											),
											Text(
												'Página $_paginaFirma de $_totalPaginas',
												style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textDark),
											),
											IconButton(
												onPressed: _paginaFirma < _totalPaginas ? () => _cambiarPagina(1) : null,
												icon: const Icon(Icons.chevron_right_rounded),
											),
										],
									),
								],

								const Spacer(),

								ElevatedButton(
									onPressed: _procesando || (_modoManual && _posicionPorcentual == null) || (!_modoManual && _posicionAutoElegida == null) 
										? null 
										: _confirmar,
									style: ElevatedButton.styleFrom(
										backgroundColor: context.primaryPurple,
										foregroundColor: Colors.white,
										elevation: 0,
										padding: const EdgeInsets.symmetric(vertical: 16),
										shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusPill)),
									),
									child: _procesando
											? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
											: const Text('Confirmar firma'),
								),
								const SizedBox(height: 8),
								TextButton(
									onPressed: () => Navigator.of(context).pop(null),
									style: TextButton.styleFrom(foregroundColor: context.textGrey),
									child: const Text('Cancelar'),
								),
							],
						),
					),
				],
			),
		);
	}
}