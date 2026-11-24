import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';

class VisorAnexo extends StatefulWidget {
	final File archivo;
	const VisorAnexo({super.key, required this.archivo});

	@override
	State<VisorAnexo> createState() => _VisorAnexoState();
}

class _VisorAnexoState extends State<VisorAnexo> {
	final PdfViewerController _controller = PdfViewerController();
	late Future<Uint8List> _documento;

	@override
	void initState() {
		super.initState();
		_documento = _cargar();
	}

	Future<Uint8List> _cargar() async {
		if (p.extension(widget.archivo.path).toLowerCase() != '.pdf') {
			throw StateError('Solo se admiten archivos PDF.');
		}
		return widget.archivo.readAsBytes();
	}

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.all(24),
			child: Column(
				children: [
					Row(children: [
						const Icon(Icons.visibility_outlined),
						const SizedBox(width: 8),
						Expanded(child: Text(p.basename(widget.archivo.path), overflow: TextOverflow.ellipsis)),
						IconButton(tooltip: 'Alejar', onPressed: () { if (_controller.isReady) _controller.zoomDown(); }, icon: const Icon(Icons.remove)),
						IconButton(tooltip: 'Acercar', onPressed: () { if (_controller.isReady) _controller.zoomUp(); }, icon: const Icon(Icons.add)),
					]),
					Expanded(
						child: FutureBuilder<Uint8List>(
							future: _documento,
							builder: (context, snapshot) {
								if (snapshot.connectionState != ConnectionState.done) {
									return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Preparando vista previa...')]));
								}
								if (snapshot.hasError) {
									return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('No se pudo visualizar el anexo: ${snapshot.error}'), TextButton(onPressed: () => setState(() => _documento = _cargar()), child: const Text('Reintentar'))]));
								}
								return PdfViewer.data(snapshot.data!, sourceName: widget.archivo.path, controller: _controller, params: PdfViewerParams(backgroundColor: context.surfaceGrey));
							},
						),
					),
				],
			),
		);
	}
}
