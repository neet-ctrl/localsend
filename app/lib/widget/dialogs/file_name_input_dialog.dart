import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:legalize/legalize.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/util/file_path_helper.dart';
import 'package:routerino/routerino.dart';

class FileNameInputDialog extends StatefulWidget {
  final String originalName;
  final String initialName;

  const FileNameInputDialog({
    required this.originalName,
    required this.initialName,
  });

  @override
  State<FileNameInputDialog> createState() => _FileNameInputDialogState();
}

class _FileNameInputDialogState extends State<FileNameInputDialog> {
  final _textController = TextEditingController();
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _textController.text = widget.initialName;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool _validate(String input) {
    if (_textController.text.isEmpty) {
      setState(() => _errorMessage = t.sanitization.empty);
      return false;
    }
    if (!isValidFilename(input, os: Platform.operatingSystem)) {
      setState(() => _errorMessage = t.sanitization.invalid);
      return false;
    }
    if (_errorMessage.isNotEmpty) setState(() => _errorMessage = '');
    return true;
  }

  void _submit() {
    if (!mounted) return;
    String input = _textController.text.trim();
    if (!_validate(_textController.text)) return;
    if (!input.contains('.') && widget.originalName.contains('.')) {
      input = input.withExtension(widget.originalName.extension);
    }
    context.pop(input);
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
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGlassBorder, width: 1),
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
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(colors: [kAccentCyan, kAccentPurple]),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.dialogs.fileNameInput.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  t.dialogs.fileNameInput.original(original: widget.originalName),
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _textController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: kAccentCyan,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: kGlassFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kGlassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kAccentCyan.withOpacity(0.5), width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kGlassBorder),
                    ),
                    errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                    errorStyle: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                  ),
                  onChanged: (value) => _validate(value.trim()),
                  onFieldSubmitted: (_) => _submit(),
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
                        gradient: const LinearGradient(colors: [kAccentCyan, kAccentPurple]),
                        boxShadow: [BoxShadow(color: kAccentCyan.withOpacity(0.3), blurRadius: 12)],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        onPressed: _submit,
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
