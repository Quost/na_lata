import 'package:flutter/material.dart';

abstract final class NaColors {
  static const green = Color(0xFF176B4D);
  static const cream = Color(0xFFF7F6F1);
  static const ink = Color(0xFF202923);
  static const muted = Color(0xFF56625A);
  static const border = Color(0xFFD6DDD6);
  static const red = Color(0xFFB3261E);
  static const amber = Color(0xFF805600);
}

abstract final class NaSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = EdgeInsets.all(xl);
}

abstract final class NaRadius {
  static const card = 16.0;
  static const control = 12.0;
}

abstract final class NaSize {
  static const touch = 48.0;
  static const content = 720.0;
}
