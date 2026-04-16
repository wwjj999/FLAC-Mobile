import 'package:flutter/material.dart';
import 'package:spotiflac_android/providers/extension_provider.dart';

IconData resolveProviderIcon(
  String providerId, {
  IconData tidalIcon = Icons.music_note,
  IconData builtInDefaultIcon = Icons.album,
  IconData deezerIcon = Icons.graphic_eq,
  IconData fallbackIcon = Icons.extension,
}) {
  final builtIn = builtInProviderSpecForId(providerId);
  if (builtIn != null) {
    if (providerId == 'tidal') {
      return tidalIcon;
    }
    return builtInDefaultIcon;
  }

  if (providerId == 'deezer') {
    return deezerIcon;
  }

  return fallbackIcon;
}
