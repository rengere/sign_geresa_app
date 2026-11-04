import 'dart:io';

import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'archivo_pdf.dart';
import 'archivos_service.dart';

// ==========================================
// BASE COMÚN
// ==========================================
class _DialogoBase extends StatelessWidget {
	final Widget child;
	final double ancho;

	const _DialogoBase({required this.child, this.ancho = 440});

	@override
	Widget build(BuildContext context) {
		return Dialog(
			backgroundColor: context.surfaceWhite,
			surfaceTintColor: Colors.transparent,
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusLg)),
			child: ConstrainedBox(
				constraints: BoxConstraints(maxWidth: ancho),
				child: Padding(padding: const EdgeInsets.all(28), child: child),
			),
		);
	}
}

// ==========================================
// CONFIRMACIÓN (signo de admiración rojo)
// ==========================================
Future<bool> mostrarConfirmacion(
	BuildContext context, {
	required String titulo,
	required String mensaje,
	required String textoConfirmar,
	required Color colorConfirmar,
}) async {
	final r = await showDialog<bool>(
		context: context,
		builder: (ctx) => _DialogoBase(
			ancho: 420,
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Container(
						width: 84,
						height: 84,
						decoration: BoxDecoration(color: ctx.errorRed.withValues(alpha: 0.12), shape: BoxShape.circle),
						child: Center(
							child: Container(
								width: 56,
								height: 56,
								decoration: BoxDecoration(color: ctx.errorRed, shape: BoxShape.circle),
								child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 34),
							),
						),
					),
					const SizedBox(height: 20),
					Text(titulo, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleLarge),
					const SizedBox(height: 10),
					Text(mensaje, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodyMedium),
					const SizedBox(height: 24),
					Row(
						children: [
							Expanded(
								child: OutlinedButton(
									onPressed: () => Navigator.pop(ctx, false),
									child: const Text('Cancelar'),
								),
							),
							const SizedBox(width: 12),
							Expanded(
								child: ElevatedButton(
									style: ElevatedButton.styleFrom(backgroundColor: colorConfirmar),
									onPressed: () => Navigator.pop(ctx, true),
									child: Text(textoConfirmar),
								),
							),
						],
					),
				],
			),
		),
	);
	return r ?? false;
}

// ==========================================
// RENOMBRAR
// ==========================================
/// Devuelve el nuevo nombre completo (con .pdf) o null si se cancela.
Future<String?> mostrarRenombrar(
	BuildContext context, {
	required String nombreActual,
	required Set<String> existentes,
}) {
	return showDialog<String>(
		context: context,
		builder: (_) => _RenombrarDialog(nombreActual: nombreActual, existentes: existentes),
	);
}

class _RenombrarDialog extends StatefulWidget {
	final String nombreActual;
	final Set<String> existentes;

	const _RenombrarDialog({required this.nombreActual, required this.existentes});

	@override
	State<_RenombrarDialog> createState() => _RenombrarDialogState();
}

class _RenombrarDialogState extends State<_RenombrarDialog> {
	late final TextEditingController _ctrl;
	String? _error;

	@override
	void initState() {
		super.initState();
		final base = widget.nombreActual.toLowerCase().endsWith('.pdf')
				? widget.nombreActual.substring(0, widget.nombreActual.length - 4)
				: widget.nombreActual;
		_ctrl = TextEditingController(text: base);
		_ctrl.selection = TextSelection(baseOffset: 0, extentOffset: base.length);
	}

	@override
	void dispose() {
		_ctrl.dispose();
		super.dispose();
	}

	String? _validar(String valor) {
		var t = valor.trim();
		if (t.toLowerCase().endsWith('.pdf')) t = t.substring(0, t.length - 4).trim();
		if (t.isEmpty) return 'Escribe un nombre';
		if (RegExp(r'[\\/:*?"<>|]').hasMatch(t)) return 'No puede contener \\ / : * ? " < > |';
		if (t.startsWith(ArchivosService.prefijoEliminado)) return 'No puede empezar con ${ArchivosService.prefijoEliminado}';
		if (widget.existentes.contains('$t.pdf'.toLowerCase())) return 'Ya existe un archivo con ese nombre';
		return null;
	}

	void _guardar() {
		final error = _validar(_ctrl.text);
		if (error != null) {
			setState(() => _error = error);
			return;
		}
		var t = _ctrl.text.trim();
		if (t.toLowerCase().endsWith('.pdf')) t = t.substring(0, t.length - 4).trim();
		Navigator.pop(context, '$t.pdf');
	}

	@override
	Widget build(BuildContext context) {
		return _DialogoBase(
			child: Column(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text('Renombrar archivo', style: Theme.of(context).textTheme.titleLarge),
					const SizedBox(height: 16),
					TextField(
						controller: _ctrl,
						autofocus: true,
						onChanged: (_) {
							if (_error != null) setState(() => _error = null);
						},
						onSubmitted: (_) => _guardar(),
						decoration: InputDecoration(
							hintText: 'Nuevo nombre',
							suffixText: '.pdf',
							errorText: _error,
						),
					),
					const SizedBox(height: 24),
					Row(
						mainAxisAlignment: MainAxisAlignment.end,
						children: [
							OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
							const SizedBox(width: 12),
							ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
						],
					),
				],
			),
		);
	}
}

// ==========================================
// DETALLES
// ==========================================
class DetallesArchivoDialog extends StatefulWidget {
	final ArchivoPdf archivo;

	const DetallesArchivoDialog({super.key, required this.archivo});

	@override
	State<DetallesArchivoDialog> createState() => _DetallesArchivoDialogState();
}

class _DetallesArchivoDialogState extends State<DetallesArchivoDialog> {
	late final Future<int?> _paginas = _contarPaginas();

	Future<int?> _contarPaginas() async {
		try {
			final bytes = await File(widget.archivo.ruta).readAsBytes();
			final doc = PdfDocument(inputBytes: bytes);
			final n = doc.pages.count;
			doc.dispose();
			return n;
		} catch (_) {
			return null;
		}
	}

	@override
	Widget build(BuildContext context) {
		final a = widget.archivo;

		return _DialogoBase(
			ancho: 520,
			child: Column(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Row(
						children: [
							Container(
								width: 44,
								height: 44,
								decoration: BoxDecoration(
									color: context.accentCoral.withValues(alpha: 0.12),
									borderRadius: BorderRadius.circular(context.radiusSm),
								),
								child: Icon(Icons.picture_as_pdf_rounded, color: context.accentCoral),
							),
							const SizedBox(width: 12),
							Expanded(child: Text('Detalles del archivo', style: Theme.of(context).textTheme.titleLarge)),
						],
					),
					const SizedBox(height: 20),
					_Dato(etiqueta: 'Nombre', valor: a.nombre),
					_Dato(etiqueta: 'Ubicación', valor: a.carpeta),
					_Dato(etiqueta: 'Tamaño', valor: a.tamanoTexto),
					_Dato(etiqueta: 'Modificado', valor: a.fechaTexto),
					FutureBuilder<int?>(
						future: _paginas,
						builder: (context, snap) {
							final texto = snap.connectionState != ConnectionState.done
									? 'Calculando…'
									: (snap.data?.toString() ?? 'No disponible');
							return _Dato(etiqueta: 'Páginas', valor: texto);
						},
					),
					const SizedBox(height: 20),
					Align(
						alignment: Alignment.centerRight,
						child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
					),
				],
			),
		);
	}
}

class _Dato extends StatelessWidget {
	final String etiqueta;
	final String valor;

	const _Dato({required this.etiqueta, required this.valor});

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 6),
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					SizedBox(width: 100, child: Text(etiqueta, style: Theme.of(context).textTheme.titleSmall)),
					Expanded(child: SelectableText(valor, style: Theme.of(context).textTheme.bodyLarge)),
				],
			),
		);
	}
}

// ==========================================
// COMPARTIR
// ==========================================
Future<OpcionCompartir?> mostrarCompartir(BuildContext context, {required int cantidad}) {
	return showDialog<OpcionCompartir>(
		context: context,
		builder: (ctx) => _DialogoBase(
			child: Column(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						cantidad == 1 ? 'Compartir archivo' : 'Compartir $cantidad archivos',
						style: Theme.of(ctx).textTheme.titleLarge,
					),
					const SizedBox(height: 16),
					_OpcionTile(
						icono: Icons.chat_rounded,
						color: const Color(0xFF25D366),
						titulo: 'WhatsApp',
						detalle: 'Abre WhatsApp y copia el archivo para pegarlo (Ctrl+V)',
						onTap: () => Navigator.pop(ctx, OpcionCompartir.whatsapp),
					),
					const SizedBox(height: 10),
					_OpcionTile(
						icono: Icons.mail_outline_rounded,
						color: ctx.primaryPurple,
						titulo: 'Correo electrónico',
						detalle: 'Abre un correo nuevo y copia el archivo para adjuntarlo',
						onTap: () => Navigator.pop(ctx, OpcionCompartir.correo),
					),
					const SizedBox(height: 10),
					_OpcionTile(
						icono: Icons.folder_open_rounded,
						color: ctx.accentOrange,
						titulo: 'Mostrar en carpeta',
						detalle: 'Para arrastrar el archivo a cualquier aplicación',
						onTap: () => Navigator.pop(ctx, OpcionCompartir.carpeta),
					),
					const SizedBox(height: 20),
					Align(
						alignment: Alignment.centerRight,
						child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
					),
				],
			),
		),
	);
}

class _OpcionTile extends StatelessWidget {
	final IconData icono;
	final Color color;
	final String titulo;
	final String detalle;
	final VoidCallback onTap;

	const _OpcionTile({
		required this.icono,
		required this.color,
		required this.titulo,
		required this.detalle,
		required this.onTap,
	});

	@override
	Widget build(BuildContext context) {
		return Material(
			color: context.surfaceGrey,
			borderRadius: BorderRadius.circular(context.radiusMd),
			child: InkWell(
				borderRadius: BorderRadius.circular(context.radiusMd),
				onTap: onTap,
				child: Padding(
					padding: const EdgeInsets.all(14),
					child: Row(
						children: [
							Container(
								width: 44,
								height: 44,
								decoration: BoxDecoration(
									color: color.withValues(alpha: 0.14),
									borderRadius: BorderRadius.circular(12),
								),
								child: Icon(icono, color: color),
							),
							const SizedBox(width: 14),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(titulo, style: Theme.of(context).textTheme.titleMedium),
										const SizedBox(height: 2),
										Text(detalle, style: Theme.of(context).textTheme.bodyMedium),
									],
								),
							),
							Icon(Icons.chevron_right_rounded, color: context.textLight),
						],
					),
				),
			),
		);
	}
}