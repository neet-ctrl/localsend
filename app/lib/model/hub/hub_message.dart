enum HubMessageType { text, image, file, voiceNote }

class HubMessage {
  final String id;
  final String senderFingerprint;
  final String senderAlias;
  final String content;
  final int timestamp;
  final HubMessageType type;
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  // Network address of sender — injected by receiver's server from the HTTP connection
  final String? senderIp;
  final int? senderPort;
  final bool? senderHttps;
  bool delivered;
  bool read;

  HubMessage({
    required this.id,
    required this.senderFingerprint,
    required this.senderAlias,
    required this.content,
    required this.timestamp,
    this.type = HubMessageType.text,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.senderIp,
    this.senderPort,
    this.senderHttps,
    this.delivered = false,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderFingerprint': senderFingerprint,
    'senderAlias': senderAlias,
    'content': content,
    'timestamp': timestamp,
    'type': type.name,
    'filePath': filePath,
    'fileName': fileName,
    'fileSize': fileSize,
    'senderIp': senderIp,
    'senderPort': senderPort,
    'senderHttps': senderHttps,
    'delivered': delivered,
    'read': read,
  };

  factory HubMessage.fromJson(Map<String, dynamic> json) => HubMessage(
    id: json['id'] as String,
    senderFingerprint: json['senderFingerprint'] as String,
    senderAlias: json['senderAlias'] as String? ?? 'Unknown',
    content: json['content'] as String,
    timestamp: json['timestamp'] as int,
    type: HubMessageType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => HubMessageType.text,
    ),
    filePath: json['filePath'] as String?,
    fileName: json['fileName'] as String?,
    fileSize: json['fileSize'] as int?,
    senderIp: json['senderIp'] as String?,
    senderPort: json['senderPort'] as int?,
    senderHttps: json['senderHttps'] as bool?,
    delivered: json['delivered'] as bool? ?? false,
    read: json['read'] as bool? ?? false,
  );
}
