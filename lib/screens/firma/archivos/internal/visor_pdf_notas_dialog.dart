import 'dart:io';
import 'dart:math' as math;
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'archivo_pdf.dart';
import 'notas_service.dart';

class VisorPdfNotasDialog extends StatefulWidget {
	final ArchivoPdf archivo;
	final VoidCallback onAbrirExterno;

	const VisorPdfNotasDialog({super.key, required this.archivo, required this.onAbrirExterno});

	@override
	State<VisorPdfNotasDialog> createState() => _VisorPdfNotasDialogState();
}

class _VisorPdfNotasDialogState extends State<VisorPdfNotasDialog> {
	final PdfViewerController _pdfController = PdfViewerController();
	final GlobalKey _stackKey = GlobalKey();
	
	List<Nota> _notas = [];
	bool _cargando = true;
	bool _mostrarBarra = false;
	final TextEditingController _notaCtrl = TextEditingController();

	// --- VARIABLES PARA EL NAVEGADOR DE PÁGINAS ---
	final TextEditingController _paginaCtrl = TextEditingController(text: '1');
	int _paginaActual = 1;
	int _totalPaginas = 1;

	@override
	void initState() {
		super.initState();
		_cargarNotas();
	}

	@override
	void dispose() {
		_notaCtrl.dispose();
		_paginaCtrl.dispose();
		super.dispose();
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
										icon: const Icon(Icons.sticky_note_2_outlined, size: 20),
										label: const Text('Notas'),
										style: TextButton.styleFrom(
											foregroundColor: _mostrarBarra ? Colors.white : context.primaryPurple,
											backgroundColor: _mostrarBarra ? context.primaryPurple : Colors.transparent,
											shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
										),
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
						
						// --- BODY ---
						Expanded(
							child: Row(
								children: [
									// Visor PDF
									Expanded(
										child: Stack(
											key: _stackKey,
											children: [
												PdfViewer.file(
													widget.archivo.ruta,
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
															return notasPagina.map((nota) {
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
															}).toList();
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
												child: Column(
													mainAxisAlignment: MainAxisAlignment.start,
													children: [
														Padding(
															padding: const EdgeInsets.all(16),
															child: Text('Notas del documento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.textDark)),
														),
														const Divider(height: 1),
														
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
														
														const Divider(height: 1),
														
														// Lista de notas
														Expanded(
															child: _notas.isEmpty
																? Center(child: Text('No hay notas', style: TextStyle(color: context.textGrey)))
																: ListView.builder(
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
																				// trailing: IconButton(
																				// 	icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
																				// 	onPressed: () => _ocultarNota(nota),
																				// 	constraints: const BoxConstraints(),
																				// 	padding: EdgeInsets.zero,
																				// ),
																			),
																		);
																	},
																),
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