import 'package:flutter/material.dart';

class Style {
  static const double iconSize = 40;
  static const double titleFontSize = 22;
  static const double cornerRadius = 4;

  static const columnPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
  static const textPadding =
      EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 8);
  static const bottomBarPadding = EdgeInsets.only(top: 15, bottom: 15);

  static const titleText =
      TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold);
  static const lockIdText =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w500);

  static const borderRadius = BorderRadius.all(Radius.circular(cornerRadius));
  static const inputDecoration = InputDecoration(border: OutlineInputBorder());

  static bottomBarDecoration(context) => BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.secondary,
            width: 0.3,
          ),
        ),
      );
}
