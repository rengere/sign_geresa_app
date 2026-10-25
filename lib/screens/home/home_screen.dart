import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/screens/firma/firma_screen.dart';
import 'package:firmador_geresa/screens/home/action_card.dart';
import 'package:firmador_geresa/screens/home/home_box.dart';
import 'package:firmador_geresa/widgets/webview.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
	const HomeScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: context.backgroundLight,
			body: HomeBox(
				children: [


					ActionCard(
						iconBackgroundColor: const Color(0xFFDCFCE7),
						icono: const Icon(Icons.verified_user_rounded, size: 40, color: Color(0xFF10B981)),
						titulo: 'Firma ditital GERESA',
						descripcion: 'Revisa la validez de las firmas digitales en tus documentos.',
						onTap: () {
							// Ahora este Navigator.push se ejecuta DENTRO del Navigator anidado,
							// por lo que el sidebar NO desaparece.
							Navigator.push(
								context,
								MaterialPageRoute(builder: (context) => const FirmaScreen()),
							);
						},
					),

					ActionCard(
						iconBackgroundColor: const Color(0xFFFFEDD5),
						icono: const Icon(Icons.open_in_new_rounded, size: 40, color: Color(0xFFF97316)),
						titulo: 'Qellqa',
						descripcion: 'Accede a la aplicación Qellqa desde aquí.',
						onTap: () {
							Navigator.push(
								context,
								MaterialPageRoute(builder: (context) => const WebView(
									url: "https://qellqa.regioncusco.gob.pe/auth",
									titulo: 'Qellqa'
								)),
							);
						},
					),

					ActionCard(
						iconBackgroundColor: const Color(0xFFEDE9FE),
						icono: const Icon(Icons.email_outlined, size: 40, color: Color(0xFF8B5CF6)),
						titulo: 'Correo Institucional',
						descripcion: 'Organiza y guarda tus archivos de forma rápida y segura.',
						onTap: () {
							Navigator.push(
								context,
								MaterialPageRoute(builder: (context) => const WebView(
									url: "https://webmail.diresacusco.gob.pe/",
									titulo: 'Correo Institucional'
								)),
							);
						},
					),
					
					ActionCard(
						iconBackgroundColor: const Color(0xFFDBEAFE),
						icono: const Row(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								Icon(Icons.description, size: 24, color: Color(0xFF3B82F6)),
								SizedBox(width: 4),
								Icon(Icons.arrow_forward, size: 16, color: Color(0xFF6B7280)),
								SizedBox(width: 4),
								Icon(Icons.picture_as_pdf, size: 24, color: Color(0xFFEF4444)),
							],
						),
						titulo: 'Convertir Word a PDF',
						descripcion: 'Convierte tus documentos de Word a formato PDF.',
						onTap: () {
							Navigator.push(
								context,
								MaterialPageRoute(builder: (context) => const WebView(
									url: "https://www.ilovepdf.com/es/word_a_pdf",
									titulo: 'Unir Archivos PDF'
								)),
							);
						},
					),

					ActionCard(
						iconBackgroundColor: const Color(0xFFF3E8FF),
						icono: const Icon(Icons.copy_all_rounded, size: 40, color: Color(0xFF8B5CF6)),
						titulo: "Unir PDF's",
						descripcion: 'Combina varios archivos PDF en uno solo.',
						onTap: () {
							Navigator.push(
								context,
								MaterialPageRoute(builder: (context) => const WebView(
									url: "https://www.ilovepdf.com/es/unir_pdf",
									titulo: 'Unir Archivos PDF'
								)),
							);
						},
					),

					ActionCard(
						iconBackgroundColor: const Color(0xFFCCFBF1),
						icono: const Icon(Icons.call_split, size: 40, color: Color(0xFF14B8A6)),
						titulo: 'Dividir PDF',
						descripcion: 'Divide un documento PDF en varios.',
						onTap: () {
							Navigator.push(
								context,
								MaterialPageRoute(builder: (context) => const WebView(
									url: "https://www.ilovepdf.com/es/dividir_pdf",
									titulo: 'Dividir PDF'
								)),
							);
						},
					),

					ActionCard(
						iconBackgroundColor: const Color(0xFFCCFBF1),
						icono: const Icon(Icons.format_list_numbered, size: 40, color: Color(0xFF14B8A6)),
						titulo: 'Foliar PDF',
						descripcion: 'Añade un numero a un documento PDF.',
						onTap: () {
							Navigator.push(
								context,
								MaterialPageRoute(builder: (context) => const WebView(
									url: "https://www.ilovepdf.com/es/insertar_numeros_de_pagina_pdf",
									titulo: 'Foliar PDF'
								)),
							);
						},
					),
					



				],
			),
		);
	}
}



