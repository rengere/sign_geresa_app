import 'dart:io';
import 'dart:typed_data';
import 'package:firmador_geresa/screens/firma/verificar/panel_right.dart';
import 'package:firmador_geresa/services/api_service.dart';
import 'package:firmador_geresa/widgets/file_drop_zone.dart';
import 'package:flutter/material.dart';

class VerifyLayout extends StatefulWidget {
	const VerifyLayout({super.key});

	@override
	State<VerifyLayout> createState() => _VerifyLayoutState();
}

class _VerifyLayoutState extends State<VerifyLayout> {
	Uint8List? _pdfBytes;
	String? _nombreArchivo;
	bool _cargando = false;
	Map<String, dynamic>? _resultado;

	void _onArchivoCargado(String path, String nombre) async {
		final archivo = await File(path).readAsBytes();
		if (!mounted) return;
		
		setState(() {
			_pdfBytes = archivo;
			_nombreArchivo = nombre;
			_resultado = null;
		});

		// Llamamos automáticamente a la verificación
		_onVerificar();
	}

	void _onCancelar() {
		setState(() {
			_pdfBytes = null;
			_nombreArchivo = null;
			_resultado = null;
			_cargando = false;
		});
	}

	Future<void> _onVerificar() async {
		if (_pdfBytes == null || _nombreArchivo == null) return;
		setState(() {
			_cargando = true;
			_resultado = null;
		});

		final api = ApiService();
		try {
			final respuesta = await api.verificar(
				pdfBytes: _pdfBytes!,
				nombreArchivo: _nombreArchivo!,
			);
			debugPrint('[Confirmar] Respuesta: $respuesta');
			if (!mounted) return;
			setState(() {
				_resultado = respuesta;
				_cargando = false;
			});
		} catch (e) {
			debugPrint('[Confirmar] Error: $e');
			if (!mounted) return;
			setState(() {
				_resultado = {'error': '$e'};
				_cargando = false;
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.all(32),
			child: Transform.translate(
				offset: const Offset(0, -50),
				child: Row(
					crossAxisAlignment: CrossAxisAlignment.center,
					children: [
						Container(
							width: 400,
							margin: const EdgeInsets.only(left: 16),
							child: FileDropZone(
								width: 400,
								height: 380,
								onFileDropped: _onArchivoCargado,
							),
						),
						const SizedBox(width: 32),
						Expanded(
							child: VerifyRightPanel(
								cargando: _cargando,
								resultado: _resultado,
								onCancelar: _onCancelar,
							),
						),
					],
				),
			),
		);
	}
}