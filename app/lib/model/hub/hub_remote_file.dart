class HubRemoteFile {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final String? mimeType;
  final int? modified;

  const HubRemoteFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.mimeType,
    this.modified,
  });

  factory HubRemoteFile.fromJson(Map<String, dynamic> json) => HubRemoteFile(
    name: json['name'] as String,
    path: json['path'] as String,
    isDirectory: json['isDirectory'] as bool? ?? false,
    size: json['size'] as int?,
    mimeType: json['mimeType'] as String?,
    modified: json['modified'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'isDirectory': isDirectory,
    'size': size,
    'mimeType': mimeType,
    'modified': modified,
  };

  String get displaySize {
    if (size == null) return '';
    if (size! < 1024) return '${size}B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)}KB';
    if (size! < 1024 * 1024 * 1024) return '${(size! / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(size! / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
