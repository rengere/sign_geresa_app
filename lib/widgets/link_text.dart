import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';

class LinkText extends WidgetSpan {
	LinkText({
		required String link,
		required String text,
	}) : super(
		alignment: PlaceholderAlignment.baseline,
		baseline: TextBaseline.alphabetic,
		child: Builder(
			builder: (context) {
				return MouseRegion(
					cursor: SystemMouseCursors.click,
					child: GestureDetector(
						onTap: () {
							if (Platform.isWindows) {
								Process.run('start', [link], runInShell: true);
							} else if (Platform.isMacOS) {
								Process.run('open', [link]);
							} else if (Platform.isLinux) {
								Process.run('xdg-open', [link]);
							}
						},
						child: Text(
							text,
							style: TextStyle(
								fontSize: 15,
								color: context.primaryPurple,
								height: 1.5,
								fontWeight: FontWeight.w600,
								decoration: TextDecoration.underline,
							),
						),
					),
				);
			},
		),
	);
}