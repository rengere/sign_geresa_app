import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/widgets/link_text.dart';
import 'package:flutter/material.dart';

class VerifyRightPanel extends StatelessWidget {
	final bool cargando;
	final Map<String, dynamic>? resultado;
	final VoidCallback onCancelar; // Nuevo callback

	const VerifyRightPanel({
		super.key, 
		required this.cargando,
		required this.resultado,
		required this.onCancelar,
	});

	@override
	Widget build(BuildContext context) {
		if (cargando) {
			return Center(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						CircularProgressIndicator(color: context.primaryPurple),
						const SizedBox(height: 24),
						Text(
							'Verificando documento...',
							style: TextStyle(
								fontSize: 16,
								fontWeight: FontWeight.w600,
								color: context.textDark,
							),
						),
					],
				),
			);
		}

		if (resultado == null) {
			return Center(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Container(
							padding: const EdgeInsets.all(24),
							decoration: BoxDecoration(
								color: context.primaryPurple.withValues(alpha: 0.05),
								shape: BoxShape.circle,
							),
							child: Icon(
								Icons.fact_check_outlined,
								size: 64,
								color: context.primaryPurple,
							),
						),
						const SizedBox(height: 24),
						Text(
							'Esperando documento',
							style: TextStyle(
								fontSize: 22,
								fontWeight: FontWeight.w700,
								color: context.textDark,
							),
						),
						const SizedBox(height: 12),
						ConstrainedBox(
							constraints: const BoxConstraints(maxWidth: 350),
							child: RichText(
								textAlign: TextAlign.center,
								text: TextSpan(
									style: TextStyle(
										fontSize: 15,
										color: context.textGrey,
										height: 1.5,
									),
									children: [
										const TextSpan(
											text: 'Arrastra o selecciona un PDF para verificar su validez automáticamente, o verifícalo de forma externa ingresando',
										),
										LinkText(
											link: "https://apps.firmaperu.gob.pe/web/validador.xhtml",
											text: " aquí en gob.pe",
										),
										const TextSpan(text: '.'),
									],
								),
							),
						),
					],
				),
			);
		}

		// ... (El resto de tus estados de error, no firmado y verificado)
		// Al final de cada uno, agrega este botón para volver a empezar:
		
		Widget botonReiniciar = Padding(
			padding: const EdgeInsets.only(top: 32),
			child: OutlinedButton(
				onPressed: onCancelar,
				style: OutlinedButton.styleFrom(
					backgroundColor: context.surfaceWhite,
					foregroundColor: context.textGrey,
					side: BorderSide(color: context.borderColor),
					padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(context.radiusPill),
					),
				),
				child: const Text('Verificar otro documento'),
			),
		);

		if (resultado!['error'] != null) {
			return Center(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Container(
							padding: const EdgeInsets.all(24),
							decoration: BoxDecoration(
								color: context.errorRed.withValues(alpha: 0.1),
								shape: BoxShape.circle,
							),
							child: Icon(
								Icons.error_outline_rounded,
								size: 64,
								color: context.errorRed,
							),
						),
						const SizedBox(height: 24),
						Text(
							'Error al verificar',
							style: TextStyle(
								fontSize: 22,
								fontWeight: FontWeight.w700,
								color: context.textDark,
							),
						),
						const SizedBox(height: 12),
						ConstrainedBox(
							constraints: const BoxConstraints(maxWidth: 350),
							child: Text(
								'${resultado!['error']}',
								textAlign: TextAlign.center,
								style: TextStyle(
									fontSize: 15,
									color: context.textGrey,
									height: 1.5,
								),
							),
						),
						botonReiniciar, // <-- Agregado aquí
					],
				),
			);
		}

		final firmas = (resultado!['firmas'] as List?) ?? [];
		final estaFirmado = firmas.isNotEmpty &&
				firmas.any((f) => f is Map && f['error'] == null);

		if (!estaFirmado) {
			return Center(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Container(
							padding: const EdgeInsets.all(24),
							decoration: BoxDecoration(
								color: context.accentOrange.withValues(alpha: 0.1),
								shape: BoxShape.circle,
							),
							child: Icon(
								Icons.priority_high_rounded,
								size: 64,
								color: context.accentOrange,
							),
						),
						const SizedBox(height: 24),
						Text(
							'Documento no firmado',
							style: TextStyle(
								fontSize: 22,
								fontWeight: FontWeight.w700,
								color: context.textDark,
							),
						),
						const SizedBox(height: 12),
						ConstrainedBox(
							constraints: const BoxConstraints(maxWidth: 350),
							child: Text(
								'El documento no contiene firmas digitales válidas o no se pudo leer ninguna firma.',
								textAlign: TextAlign.center,
								style: TextStyle(
									fontSize: 15,
									color: context.textGrey,
									height: 1.5,
								),
							),
						),
						botonReiniciar, // <-- Agregado aquí
					],
				),
			);
		}

		final primera = firmas.first as Map;
		return Center(
			child: Container(
				padding: const EdgeInsets.all(32),
				decoration: BoxDecoration(
					color: context.surfaceWhite,
					borderRadius: BorderRadius.circular(context.radiusLg),
					boxShadow: AppTheme.shadowMd,
					border: Border.all(
						color: Colors.green.withValues(alpha: 0.3),
						width: 1,
					),
				),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Container(
							padding: const EdgeInsets.all(24),
							decoration: BoxDecoration(
								color: Colors.green.withValues(alpha: 0.1),
								shape: BoxShape.circle,
							),
							child: const Icon(
								Icons.check_circle_outline_rounded,
								size: 64,
								color: Colors.green,
							),
						),
						const SizedBox(height: 24),
						Text(
							'Documento verificado',
							style: TextStyle(
								fontSize: 22,
								fontWeight: FontWeight.w700,
								color: context.textDark,
							),
						),
						const SizedBox(height: 24),
						Container(
							width: double.infinity,
							padding: const EdgeInsets.all(16),
							decoration: BoxDecoration(
								color: context.surfaceGrey,
								borderRadius: BorderRadius.circular(context.radiusMd),
							),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										'Firmante',
										style: TextStyle(
											fontSize: 13,
											fontWeight: FontWeight.w600,
											color: context.textGrey,
										),
									),
									const SizedBox(height: 4),
									Text(
										'${primera['firmante']}',
										style: TextStyle(
											fontSize: 16,
											fontWeight: FontWeight.w600,
											color: context.textDark,
										),
									),
								],
							),
						),
						botonReiniciar, // <-- Agregado aquí
					],
				),
			),
		);
	}
}