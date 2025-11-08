import 'package:flutter/cupertino.dart';

class MyGradients{
  static const LinearGradient blueGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0XFF131B63),
        Color(0XFF481162),
      ]
  );
  static const LinearGradient pinkGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0XFFFFFFFF),
        Color(0XFFB971A3),
        Color(0XFFA03E82),
      ]
  );

  static const LinearGradient purpleGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0XFF8462E1),
        Color(0XFF55389B),
        Color(0XFFA03E82),
      ]
  );
}