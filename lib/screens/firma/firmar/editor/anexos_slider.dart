import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:firmador_geresa/assets/theme/app_theme.dart';

/// Panel independiente de anexos pendientes de transferencia.
class AnexosSlider extends StatefulWidget {
	final String nombreArchivo;
	final List<File> anexos;
	final ValueChanged<String> onEliminar;
	final VoidCallback onAgregar;
	final VoidCallback onCerrar;
	final VoidCallback onReiniciar;
	final bool ocupado;

	const AnexosSlider({
		super.key,
		required this.nombreArchivo,
		required this.anexos,
		required this.onEliminar,
		required this.onAgregar,
		required this.onCerrar,
		required this.onReiniciar,
		this.ocupado = false,
	});

	@override
	State<AnexosSlider> createState() => _AnexosSliderState();
}

class _AnexosSliderState extends State<AnexosSlider> {
	final ScrollController _scrollController = ScrollController();

	@override
	void dispose() {
		_scrollController.dispose();
		super.dispose();
	}

	Future<void> _confirmarReinicio() async {
		if (widget.ocupado || widget.anexos.isEmpty) return;
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('¿Reiniciar anexos?'),
				content: const Text('Se quitarán todos los anexos pendientes y el código QR del documento. Los archivos originales no se eliminarán.'),
				actions: [
					TextButton(
						onPressed: () => Navigator.of(ctx).pop(false),
						child: const Text('Cancelar'),
					),
					ElevatedButton(
						style: ElevatedButton.styleFrom(backgroundColor: ctx.errorRed, foregroundColor: Colors.white),
						onPressed: () => Navigator.of(ctx).pop(true),
						child: const Text('Reiniciar'),
					),
				],
			),
		);
		if (!mounted || confirmar != true || widget.ocupado) return;
		widget.onReiniciar();
		if (_scrollController.hasClients) _scrollController.jumpTo(0);
	}

	@override
	Widget build(BuildContext context) {
		return SizedBox(
			width: 248,
			child: Stack(
				children: [
					Positioned.fill(
						right: 28,
						child: Container(
							decoration: BoxDecoration(color: context.surfaceGrey.withValues(alpha: 0.5), border: Border(right: BorderSide(color: context.borderColor))),
							child: Column(
								children: [
									Padding(
										padding: const EdgeInsets.all(12),
										child: Row(children: [
											Expanded(child: Text('Anexos', style: TextStyle(fontWeight: FontWeight.bold, color: context.textDark))),
											IconButton(
												tooltip: 'Reiniciar anexos',
												onPressed: widget.ocupado || widget.anexos.isEmpty ? null : _confirmarReinicio,
												icon: const Icon(Icons.restart_alt_rounded),
												color: context.errorRed,
											),
										]),
									),
									Container(
										margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
										padding: const EdgeInsets.all(8),
										decoration: BoxDecoration(color: context.surfaceWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.primaryPurple)),
										child: Row(children: [
											Icon(Icons.lock_outline, size: 20, color: context.primaryPurple),
											const SizedBox(width: 8),
											Expanded(child: Text(widget.nombreArchivo, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.textDark))),
										]),
									),
									Expanded(
										child: ScrollConfiguration(
											behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
											child: Scrollbar(
												controller: _scrollController,
												thumbVisibility: true,
												interactive: true,
												thickness: 6,
												radius: const Radius.circular(8),
												child: ListView.builder(
													controller: _scrollController,
													padding: EdgeInsets.zero,
													itemCount: widget.anexos.isEmpty ? 2 : widget.anexos.length + 1,
													itemBuilder: (context, index) {
														if (widget.anexos.isEmpty && index == 0) {
															return Padding(padding: const EdgeInsets.all(12), child: Text('Sin anexos seleccionados', textAlign: TextAlign.center, style: TextStyle(color: context.textGrey, fontSize: 12)));
														}
														if (index == (widget.anexos.isEmpty ? 1 : widget.anexos.length)) {
															return Padding(
																padding: const EdgeInsets.all(12),
																child: SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: widget.ocupado ? null : widget.onAgregar, icon: const Icon(Icons.add), label: const Text('Añadir archivos'))),
															);
														}
														final archivo = widget.anexos[index];
														return Container(
															key: ValueKey(archivo.path),
															margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
															padding: const EdgeInsets.all(8),
															decoration: BoxDecoration(color: context.surfaceWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.borderColor)),
															child: Row(children: [
																Icon(Icons.insert_drive_file_outlined, size: 20, color: context.textGrey),
																const SizedBox(width: 8),
																Expanded(child: Text(p.basename(archivo.path), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.textDark))),
																IconButton(tooltip: 'Quitar anexo', icon: Icon(Icons.close, size: 16, color: context.errorRed), onPressed: widget.ocupado ? null : () => widget.onEliminar(archivo.path), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
															]),
														);
													},
												),
											),
										),
									),
								],
							),
						),
					),
					Align(
						alignment: Alignment.centerRight,
						child: Material(
							color: context.primaryPurple,
							elevation: 3,
							borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
							child: SizedBox(
								width: 28,
								height: 48,
								child: IconButton(
									tooltip: 'Ocultar anexos',
									onPressed: widget.onCerrar,
									padding: EdgeInsets.zero,
									color: Colors.white,
									icon: const Icon(Icons.chevron_left_rounded),
								),
							),
						),
					),
				],
			),
		);
	}
}
