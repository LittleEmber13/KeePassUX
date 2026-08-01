import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keepassux/utils/kdbx_icons.dart';

class KDBXIconWidget extends StatelessWidget {
  const KDBXIconWidget({
    required this.icon,
    this.customIconData,
    this.size = 24,
    this.color,
    super.key,
  });

  final int icon;
  final Uint8List? customIconData;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (customIconData != null) {
      return Image.memory(
        customIconData!,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }
    return Icon(
      kdbxIconToFlutter(KdbxIcon.values[icon]),
      size: size,
      color: color,
    );
  }
}
