import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:routerino/routerino.dart';

class CustomBottomSheet extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;

  const CustomBottomSheet({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RouterinoBottomSheet(
      title: title,
      description: description,
      backgroundColor: kSurface,
      borderRadius: 24,
      child: child,
    );
  }
}
