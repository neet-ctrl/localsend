import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:routerino/routerino.dart';

class PinDialog extends StatefulWidget {
  final String? pin;
  final bool showInvalidPin;
  final bool obscureText;
  final bool generateRandom;

  const PinDialog({
    this.pin,
    required this.obscureText,
    this.showInvalidPin = false,
    this.generateRandom = false,
    super.key,
  });

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textController.text = widget.pin ?? (widget.generateRandom ? nanoid(alphabet: Alphabet.noDoppelganger, length: 6) : '');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kAccentPurple.withOpacity(0.35), width: 1),
              boxShadow: [BoxShadow(color: kAccentPurple.withOpacity(0.1), blurRadius: 20)],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kAccentPurple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kAccentPurple.withOpacity(0.4), width: 1),
                      ),
                      child: const Icon(Icons.vpn_key, color: kAccentPurple, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.dialogs.pin.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _textController,
                  autofocus: true,
                  obscureText: widget.obscureText,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: widget.obscureText ? null : 'RobotoMono',
                    fontSize: 18,
                    letterSpacing: widget.obscureText ? 3 : 2,
                  ),
                  cursorColor: kAccentPurple,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: kGlassFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kGlassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kAccentPurple.withOpacity(0.6), width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kGlassBorder),
                    ),
                  ),
                  onFieldSubmitted: (value) => context.pop(value),
                ),
                if (widget.showInvalidPin)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      t.web.invalidPin,
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0.55)),
                      onPressed: () => context.pop(),
                      child: Text(t.general.cancel),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: kAccentPurple.withOpacity(0.2),
                        border: Border.all(color: kAccentPurple.withOpacity(0.5), width: 1),
                        boxShadow: [BoxShadow(color: kAccentPurple.withOpacity(0.25), blurRadius: 12)],
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: kAccentPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        onPressed: () => context.pop(_textController.text),
                        child: Text(t.general.confirm, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
