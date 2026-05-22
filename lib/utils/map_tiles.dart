import 'package:flutter_map/flutter_map.dart';

/// Carto basemaps (OSM data) — allowed for mobile apps; do not use tile.openstreetmap.org.
abstract class AppMapTiles {
  static const _urlTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

  static TileLayer layer() => TileLayer(
        urlTemplate: _urlTemplate,
        subdomains: const ['a', 'b', 'c', 'd'],
        userAgentPackageName: 'com.example.main',
      );

  static RichAttributionWidget attribution() => const RichAttributionWidget(
        attributions: [
          TextSourceAttribution(
            'OpenStreetMap contributors',
            prependCopyright: true,
          ),
          TextSourceAttribution(
            'CARTO',
            prependCopyright: false,
          ),
        ],
      );
}
