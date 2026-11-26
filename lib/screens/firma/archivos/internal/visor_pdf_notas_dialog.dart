import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:firmador_geresa/services/api_service.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor/correlativo_visual.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor/config_sello_firma.dart';
import 'dart:math' as math;
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'archivo_pdf.dart';
import 'notas_service.dart';

class _ArrastreCorrelativo {
	const _ArrastreCorrelativo();
}

class VisorPdfNotasDialog extends StatefulWidget {
	final ArchivoPdf archivo;
	final VoidCallback onAbrirExterno;

	const VisorPdfNotasDialog({super.key, required this.archivo, required this.onAbrirExterno});

	@override
	State<VisorPdfNotasDialog> createState() => _VisorPdfNotasDialogState();
}

class _VisorPdfNotasDialogState extends State<VisorPdfNotasDialog> {
	PdfViewerController _pdfController = PdfViewerController();
	final GlobalKey _stackKey = GlobalKey();
	
	List<Nota> _notas = [];
	bool _cargando = true;
	bool _mostrarBarra = true;
	bool _sinFirma = false;
	bool _guardandoCorrelativo = false;
	Uint8List? _bytesVerificados;
	Uint8List? _bytesVisor;
	String? _errorVisor;
	int _revisionPdf = 0;
	final _correlativoCtrl = TextEditingController();
	double _fuenteCorrelativo = 12;
	Offset? _posicionCorrelativo;
	int _paginaCorrelativo = 1;
	static const double _anchoCorrelativo = ConfigSelloFirma.anchoCorrelativo;
	static const double _altoCorrelativo = ConfigSelloFirma.altoCorrelativo;
	final TextEditingController _notaCtrl = TextEditingController();

	// --- VARIABLES PARA EL NAVEGADOR DE PÁGINAS ---
	final TextEditingController _paginaCtrl = TextEditingController(text: '1');
	int _paginaActual = 1;
	int _totalPaginas = 1;

	@override
	void initState() {
		super.initState();
		_cargarNotas();
		_verificarDocumento();
	}

	@override
	void dispose() {
		_correlativoCtrl.dispose();
		_notaCtrl.dispose();
		_paginaCtrl.dispose();
		super.dispose();
	}

	Future<bool> _verificarSinFirma(Uint8List bytes) async {
		final respuesta = await ApiService().verificar(pdfBytes: bytes, nombreArchivo: widget.archivo.nombre);
		final firmas = respuesta['firmas'];
		return respuesta['error'] == null && firmas is List && firmas.isEmpty;
	}

	Future<void> _verificarDocumento() async {
		try {
			final bytes = await File(widget.archivo.ruta).readAsBytes();
			if (!mounted) return;
			setState(() => _bytesVisor = bytes);
			final sinFirma = await _verificarSinFirma(bytes);
			if (!mounted) return;
			setState(() {
				_sinFirma = sinFirma;
				_bytesVerificados = sinFirma ? bytes : null;
			});
		} catch (e) {
			debugPrint('[Correlativo] No se pudo verificar: $e');
			if (mounted) setState(() {
				_sinFirma = false;
				if (_bytesVisor == null) _errorVisor = 'No se pudo abrir el PDF: $e';
			});
		}
	}

	Offset _limitarCorrelativo(Offset pos, double ancho, double alto) {
		return Offset(
			pos.dx.clamp(0.0, math.max(0.0, 1 - _anchoCorrelativo / ancho)).toDouble(),
			pos.dy.clamp(0.0, math.max(0.0, 1 - _altoCorrelativo / alto)).toDouble(),
		);
	}

	void _alSoltarCorrelativo(DragTargetDetails<_ArrastreCorrelativo> details) {
		if (!_sinFirma || _guardandoCorrelativo || !_pdfController.isReady) return;
		final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
		if (box == null) return;
		final centro = details.offset + const Offset(_anchoCorrelativo / 2, _altoCorrelativo / 2);
		final doc = MatrixUtils.transformPoint(Matrix4.inverted(_pdfController.value), box.globalToLocal(centro));
		final layouts = _pdfController.layout.pageLayouts;
		for (int i = 0; i < layouts.length; i++) {
			final rect = layouts[i];
			if (!rect.contains(doc)) continue;
			setState(() {
				_paginaCorrelativo = i + 1;
				_posicionCorrelativo = _limitarCorrelativo(Offset((doc.dx - rect.left - _anchoCorrelativo / 2) / rect.width, (doc.dy - rect.top - _altoCorrelativo / 2) / rect.height), rect.width, rect.height);
			});
			break;
		}
	}

	Widget _vistaCorrelativo() => CorrelativoVisual(texto: _correlativoCtrl.text, fuente: _fuenteCorrelativo, ancho: _anchoCorrelativo, alto: _altoCorrelativo);

	Future<void> _guardarCorrelativo() async {
		if (!_sinFirma || _guardandoCorrelativo || _posicionCorrelativo == null || _correlativoCtrl.text.trim().isEmpty) return;
		final pos = _posicionCorrelativo!;
		final pagina = _paginaCorrelativo;
		final texto = _correlativoCtrl.text.trim();
		final fuente = _fuenteCorrelativo;
		setState(() => _guardandoCorrelativo = true);
		File? temporal;
		try {
			final archivo = File(widget.archivo.ruta);
			final bytes = await archivo.readAsBytes();
			if (!listEquals(bytes, _bytesVerificados) || !await _verificarSinFirma(bytes)) {
				if (mounted) setState(() { _sinFirma = false; _posicionCorrelativo = null; });
				throw StateError('El documento cambió o contiene firmas. Vuelve a abrirlo.');
			}
			if (!mounted) return;
			final documento = sf.PdfDocument(inputBytes: bytes);
			late List<int> resultado;
			try {
				final page = documento.pages[pagina - 1];
				final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, fuente, style: sf.PdfFontStyle.bold);
				final medida = font.measureString(texto);
				if (medida.width > page.size.width || medida.height > page.size.height) throw StateError('El texto excede el tamaño de la página.');
				final x = (pos.dx * page.size.width + _anchoCorrelativo / 2 - medida.width / 2).clamp(0.0, page.size.width - medida.width).toDouble();
				final y = (pos.dy * page.size.height + _altoCorrelativo / 2 - 0.718 * fuente / 2).clamp(0.0, page.size.height - medida.height).toDouble();
				page.graphics.drawString(texto, font, brush: sf.PdfSolidBrush(sf.PdfColor(0, 0, 0)), bounds: Rect.fromLTWH(x, y, 0, 0));
				resultado = await documento.save();
			} finally {
				documento.dispose();
			}
			temporal = File('${archivo.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
			await temporal.writeAsBytes(resultado, flush: true);
			if (!mounted) return;
			if (!listEquals(await archivo.readAsBytes(), bytes)) throw StateError('El documento cambió durante el guardado.');
			await temporal.rename(archivo.path);
			if (!mounted) return;
			setState(() {
				_bytesVisor = Uint8List.fromList(resultado);
				_bytesVerificados = _bytesVisor;
				_posicionCorrelativo = null;
				_correlativoCtrl.clear();
				_pdfController = PdfViewerController();
				_revisionPdf++;
			});
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correlativo guardado en el PDF.')));
		} catch (e) {
			if (mounted) {
				setState(() => _sinFirma = false);
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
			}
		} finally {
			try { if (temporal != null && await temporal.exists()) await temporal.delete(); } catch (_) {}
			if (mounted) setState(() => _guardandoCorrelativo = false);
		}
	}

	Widget _tituloHerramienta(String titulo) {
		return Padding(
			padding: const EdgeInsets.all(16),
			child: Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.textDark)),
		);
	}

	Widget _divisorHerramientas() => Divider(height: 1, thickness: 1, color: context.borderColor);

	Widget _herramientaCorrelativo() {
		return Padding(
			padding: const EdgeInsets.all(16),
			child: Column(
				children: [
					Row(children: [
						Expanded(child: Text('Tamaño de fuente', style: TextStyle(fontSize: 12, color: context.textGrey))),
						IconButton(tooltip: 'Disminuir fuente', onPressed: _guardandoCorrelativo ? null : () => setState(() => _fuenteCorrelativo = (_fuenteCorrelativo - 2).clamp(8.0, 30.0).toDouble()), icon: const Icon(Icons.keyboard_arrow_down)),
						Text(_fuenteCorrelativo.toStringAsFixed(0), style: TextStyle(color: context.textDark, fontWeight: FontWeight.w600)),
						IconButton(tooltip: 'Aumentar fuente', onPressed: _guardandoCorrelativo ? null : () => setState(() => _fuenteCorrelativo = (_fuenteCorrelativo + 2).clamp(8.0, 30.0).toDouble()), icon: const Icon(Icons.keyboard_arrow_up)),
						IconButton(tooltip: 'Quitar correlativo pendiente', onPressed: _guardandoCorrelativo ? null : () => setState(() { _correlativoCtrl.clear(); _posicionCorrelativo = null; }), icon: const Icon(Icons.close)),
					]),
					const SizedBox(height: 8),
					TextField(controller: _correlativoCtrl, enabled: !_guardandoCorrelativo, decoration: const InputDecoration(hintText: 'Correlativo', border: OutlineInputBorder(), isDense: true), onChanged: (v) => setState(() { if (v.trim().isEmpty) _posicionCorrelativo = null; })),
					if (_correlativoCtrl.text.trim().isNotEmpty) ...[
						const SizedBox(height: 8),
						Draggable<_ArrastreCorrelativo>(data: const _ArrastreCorrelativo(), maxSimultaneousDrags: _guardandoCorrelativo ? 0 : 1, dragAnchorStrategy: (_, __, ___) => const Offset(_anchoCorrelativo / 2, _altoCorrelativo / 2), feedback: Material(color: Colors.transparent, child: _vistaCorrelativo()), child: _vistaCorrelativo()),
						Text('Arrastra al PDF', style: TextStyle(fontSize: 12, color: context.textGrey)),
					],
					const SizedBox(height: 8),
					TextButton.icon(onPressed: _guardandoCorrelativo || _posicionCorrelativo == null ? null : _guardarCorrelativo, icon: const Icon(Icons.save_outlined), label: Text(_guardandoCorrelativo ? 'Guardando...' : 'Guardar correlativo')),
				],
			),
		);
	}

	Future<void> _cargarNotas() async {
		final notas = await NotasService.cargarNotas(widget.archivo.ruta);
		if (mounted) {
			setState(() {
				_notas = notas.where((n) => !n.oculta).toList();
				_cargando = false;
			});
		}
	}

	Future<void> _guardarNota(Nota nuevaNota) async {
		if (nuevaNota.texto.trim().isEmpty) return;
		
		setState(() {
			_notas.add(nuevaNota);
		});
		
		await NotasService.guardarNotas(widget.archivo.ruta, _notas);
		
		setState(() {
			_notaCtrl.clear();
		});
	}

	Future<void> _ocultarNota(Nota nota) async {
		final index = _notas.indexWhere((n) => n.id == nota.id);
		if (index != -1) {
			setState(() {
				_notas[index] = Nota(
					id: nota.id,
					texto: nota.texto,
					pagina: nota.pagina,
					x: nota.x,
					y: nota.y,
					oculta: true,
				);
			});
			await NotasService.guardarNotas(widget.archivo.ruta, _notas);
			_cargarNotas();
		}
	}

	void _alSoltarNota(DragTargetDetails<Nota> details) {
		if (!_pdfController.isReady) return;
		final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
		if (box == null) return;

		final centroGlobal = details.offset;
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
		final cx = (doc.dx - rect.left) / rect.width;
		final cy = (doc.dy - rect.top) / rect.height;

		final nuevaNota = Nota(
			id: DateTime.now().millisecondsSinceEpoch.toString(),
			texto: details.data.texto,
			pagina: idx + 1,
			x: cx.clamp(0.0, 1.0),
			y: cy.clamp(0.0, 1.0),
		);

		_guardarNota(nuevaNota);
	}

	Future<void> _imprimir(BuildContext context) async {
		try {
			final bytes = await File(widget.archivo.ruta).readAsBytes();
			await Printing.layoutPdf(onLayout: (format) async => bytes);
		} catch (e) {
			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al imprimir: $e')));
			}
		}
	}

	// --- NAVEGACIÓN DE PÁGINAS ---
	void _irAPagina(int pagina) {
		if (!_pdfController.isReady) return;
		_pdfController.goToPage(pageNumber: pagina, anchor: PdfPageAnchor.all);
	}

	void _irAPaginaInput(String valor) {
		final num = int.tryParse(valor);
		if (num != null && num >= 1 && num <= _totalPaginas) {
			setState(() {
				_paginaActual = num;
				_irAPagina(num);
			});
		} else {
			_paginaCtrl.text = _paginaActual.toString();
		}
	}

	Widget _botonZoom(IconData icono, String tooltip, VoidCallback onTap) {
		return Material(
			color: context.surfaceWhite,
			elevation: 2,
			borderRadius: BorderRadius.circular(context.radiusMd),
			child: IconButton(icon: Icon(icono, size: 20), tooltip: tooltip, color: context.textDark, onPressed: onTap),
		);
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
				width: 1200,
				child: Column(
					children: [
						// --- HEADER ---
						Padding(
							padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
							child: Row(
								children: [
									Icon(Icons.picture_as_pdf_rounded, color: context.accentCoral),
									const SizedBox(width: 12),
									Expanded(
										child: Text(
											widget.archivo.nombre,
											maxLines: 1,
											overflow: TextOverflow.ellipsis,
											style: Theme.of(context).textTheme.titleMedium,
										),
									),
									TextButton.icon(
										onPressed: () => _imprimir(context),
										icon: const Icon(Icons.print_rounded, size: 18),
										label: const Text('Imprimir'),
										style: TextButton.styleFrom(foregroundColor: context.primaryPurple),
									),
									const SizedBox(width: 8),
									TextButton.icon(
										onPressed: widget.onAbrirExterno,
										icon: const Icon(Icons.open_in_new_rounded, size: 18),
										label: const Text('Abrir externo'),
									),
									const SizedBox(width: 8),
									
									// --- BOTÓN DE NOTAS ---
									TextButton.icon(
										onPressed: () => setState(() => _mostrarBarra = !_mostrarBarra),
										icon: const Icon(Icons.build_outlined, size: 20),
										label: const Text('Herramientas'),
										style: TextButton.styleFrom(
											foregroundColor: _mostrarBarra ? Colors.white : context.primaryPurple,
											backgroundColor: _mostrarBarra ? context.primaryPurple : Colors.transparent,
											shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
										),
									),
									
									const SizedBox(width: 8),
									IconButton(
										tooltip: 'Cerrar',
										onPressed: _guardandoCorrelativo ? null : () => Navigator.pop(context),
										icon: const Icon(Icons.close_rounded),
									),
								],
							),
						),
						const Divider(height: 1),
						
						// --- BODY ---
						Expanded(
							child: Row(
								children: [
									// Visor PDF
									Expanded(
										child: Stack(
											key: _stackKey,
											children: [
												if (_bytesVisor == null)
													Center(child: _errorVisor == null ? const CircularProgressIndicator() : Text(_errorVisor!))
												else
												PdfViewer.data(
													_bytesVisor!,
													sourceName: '${widget.archivo.ruta}#$_revisionPdf',
													key: ValueKey(_revisionPdf),
													controller: _pdfController,
													params: PdfViewerParams(
														onViewerReady: (document, controller) {
															setState(() {
																_totalPaginas = document.pages.length;
															});
														},
														onPageChanged: (pageNumber) {
															setState(() {
																_paginaActual = pageNumber ?? 1;
																_paginaCtrl.text = _paginaActual.toString();
															});
														},
														pageOverlaysBuilder: (context, pageRect, page) {
															final notasPagina = _notas.where((n) => n.pagina == page.pageNumber).toList();
															final overlays = <Widget>[...notasPagina.map((nota) {
																return Positioned(
																	left: nota.x * pageRect.width,
																	top: nota.y * pageRect.height,
																	child: Tooltip(
																		message: nota.texto,
																		preferBelow: false,
																		textStyle: const TextStyle(fontSize: 15, color: Colors.white),
																		child: Container(
																			padding: const EdgeInsets.all(4),
																			decoration: BoxDecoration(
																				color: context.primaryPurple,
																				shape: BoxShape.circle,
																				boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
																			),
																			child: const Icon(Icons.question_mark, size: 14, color: Colors.white),
																		),
																	),
																);
															}).toList()];
															if (_sinFirma && _posicionCorrelativo != null && page.pageNumber == _paginaCorrelativo) {
																final escala = pageRect.width / page.width;
																overlays.add(Positioned(left: _posicionCorrelativo!.dx * pageRect.width, top: _posicionCorrelativo!.dy * pageRect.height, width: _anchoCorrelativo * escala, height: _altoCorrelativo * escala, child: GestureDetector(onPanUpdate: _guardandoCorrelativo ? null : (d) => setState(() => _posicionCorrelativo = _limitarCorrelativo(_posicionCorrelativo! + Offset(d.delta.dx / pageRect.width, d.delta.dy / pageRect.height), page.width, page.height)), child: FittedBox(fit: BoxFit.fill, child: _vistaCorrelativo()))));
															}
															return overlays;
														},
													),
												),
												
												// --- NAVEGADOR DE PÁGINAS (CENTRO SUPERIOR) ---
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
																				onPressed: _paginaActual > 1 ? () {
																					setState(() {
																						_paginaActual = 1;
																						_paginaCtrl.text = '1';
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
																				onPressed: _paginaActual > 1 ? () {
																					setState(() {
																						_paginaActual--;
																						_paginaCtrl.text = _paginaActual.toString();
																					});
																					_irAPagina(_paginaActual);
																				} : null,
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
																				onPressed: _paginaActual < _totalPaginas ? () {
																					setState(() {
																						_paginaActual++;
																						_paginaCtrl.text = _paginaActual.toString();
																					});
																					_irAPagina(_paginaActual);
																				} : null,
																				icon: const Icon(Icons.chevron_right_rounded, size: 20),
																				padding: EdgeInsets.zero,
																				constraints: const BoxConstraints(minWidth: 32),
																				color: context.textDark,
																			),

																			IconButton(
																				onPressed: _paginaActual < _totalPaginas ? () {
																					setState(() {
																						_paginaActual = _totalPaginas;
																						_paginaCtrl.text = _totalPaginas.toString();
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
												
												// --- HERRAMIENTAS DE ZOOM (DERECHA) ---
												Positioned(
													top: 12,
													right: 12,
													child: Column(
														children: [
															_botonZoom(Icons.add_rounded, 'Acercar', () { if (_pdfController.isReady) _pdfController.zoomUp(); }),
															const SizedBox(height: 8),
															_botonZoom(Icons.remove_rounded, 'Alejar', () { if (_pdfController.isReady) _pdfController.zoomDown(); }),
															const SizedBox(height: 8),
															_botonZoom(Icons.fit_screen_rounded, 'Ajustar página', () { 
																if (_pdfController.isReady) _irAPagina(_pdfController.pageNumber ?? 1); 
															}),
														],
													),
												),
												
														if (_sinFirma)
															Positioned.fill(child: DragTarget<_ArrastreCorrelativo>(onAcceptWithDetails: _alSoltarCorrelativo, builder: (_, __, ___) => const IgnorePointer(child: SizedBox.expand()))),
												Positioned.fill(
													child: DragTarget<Nota>(
														onAcceptWithDetails: _alSoltarNota,
														builder: (context, candidateData, rejectedData) {
															return IgnorePointer(
																child: Container(
																	color: candidateData.isNotEmpty ? context.primaryPurple.withValues(alpha: 0.1) : Colors.transparent,
																),
															);
														},
													),
												),
											],
										),
									),
									
									// Barra Lateral (FIJA, NO COLAPSABLE)
									if (_mostrarBarra)
										SizedBox(
											width: 320,
											child: Container(
												decoration: BoxDecoration(
													color: context.surfaceWhite,
													border: Border(left: BorderSide(color: context.borderColor)),
												),
												child: ListView(
													children: [
														if (_sinFirma) ...[
															_tituloHerramienta('Correlativo'),
															_divisorHerramientas(),
															_herramientaCorrelativo(),
															_divisorHerramientas(),
														],
														_tituloHerramienta('Notas del documento'),
														_divisorHerramientas(),

														// Input para nueva nota
														Padding(
															padding: const EdgeInsets.all(16),
															child: Column(
																children: [
																	TextField(
																		controller: _notaCtrl,
																		decoration: const InputDecoration(
																			hintText: 'Escribe tu nota aquí...',
																			border: OutlineInputBorder(),
																			isDense: true,
																		),
																		maxLines: 2,
																		onChanged: (_) => setState(() {}),
																	),
																	const SizedBox(height: 8),
																	SizedBox(
																		width: 280,
																		child: Draggable<Nota>(
																			data: Nota(
																				id: 'temp', 
																				texto: _notaCtrl.text, 
																				pagina: 1, 
																				x: 0, 
																				y: 0
																			),
																			maxSimultaneousDrags: _notaCtrl.text.trim().isEmpty ? 0 : 1, 
																			dragAnchorStrategy: (draggable, context, position) => const Offset(16, 16),
																			feedback: Material(
																				color: Colors.transparent, 
																				child: Opacity(
																					opacity: 0.85, 
																					child: Container(
																						padding: const EdgeInsets.all(6),
																						decoration: BoxDecoration(color: context.primaryPurple, shape: BoxShape.circle),
																						child: const Icon(Icons.question_mark, color: Colors.white, size: 16),
																					),
																				),
																			),
																			childWhenDragging: Opacity(opacity: 0.3, child: Icon(Icons.question_mark, color: context.primaryPurple)),
																			child: Opacity(
																				opacity: _notaCtrl.text.trim().isEmpty ? 0.5 : 1.0,
																				child: Container(
																					width: double.infinity,
																					padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
																					decoration: BoxDecoration(
																						color: context.primaryPurple.withValues(alpha: 0.1),
																						borderRadius: BorderRadius.circular(8),
																						border: Border.all(color: context.primaryPurple),
																					),
																					child: Row(
																						mainAxisAlignment: MainAxisAlignment.center,
																						children: [
																							Icon(Icons.drag_indicator, color: context.primaryPurple, size: 16),
																							const SizedBox(width: 4),
																							Flexible(
																								child: Text(
																									'Arrastra al PDF', 
																									style: TextStyle(color: context.primaryPurple, fontWeight: FontWeight.bold, fontSize: 12),
																									maxLines: 1,
																									overflow: TextOverflow.ellipsis,
																								),
																							),
																						],
																					),
																				),
																			),
																		),
																	),
																],
															),
														),
														
														
														
														// Lista de notas
														Padding(
															padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
															child: Text('Notas guardadas', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.textDark)),
														),
														_notas.isEmpty
																? Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: Center(child: Text('No hay notas', style: TextStyle(color: context.textGrey))))
																: ListView.builder(
																	shrinkWrap: true,
																	physics: const NeverScrollableScrollPhysics(),
																	padding: const EdgeInsets.all(8),
																	itemCount: _notas.length,
																	itemBuilder: (context, index) {
																		final nota = _notas[index];
																		return Card(
																			margin: const EdgeInsets.only(bottom: 8),
																			child: ListTile(
																				contentPadding: const EdgeInsets.symmetric(horizontal: 8),
																				dense: true,
																				leading: const Icon(Icons.question_mark, color: Colors.purple, size: 20),
																				title: Text(
																					nota.texto, 
																					maxLines: 1, 
																					overflow: TextOverflow.ellipsis,
																					style: const TextStyle(fontSize: 12),
																				),
																				trailing: IconButton(
																					icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
																					onPressed: () => _ocultarNota(nota),
																					constraints: const BoxConstraints(),
																					padding: EdgeInsets.zero,
																				),
																			),
																		);
																	},
																),
													],
												),
											),
										),
								],
							),
						),
					],
				),
			),
		);
	}
}