class DeviceModel {
  final String id;
  final String name;
  final String platform;
  final bool isPhysical;
  final bool isOnline;
  final String? version;
  final String? architecture;
  final Map<String, dynamic> additionalInfo;
  
  const DeviceModel({
    required this.id,
    required this.name,
    required this.platform,
    required this.isPhysical,
    required this.isOnline,
    this.version,
    this.architecture,
    this.additionalInfo = const {},
  });
  
  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      platform: json['platform'] as String,
      isPhysical: json['isPhysical'] as bool,
      isOnline: json['isOnline'] as bool,
      version: json['version'] as String?,
      architecture: json['architecture'] as String?,
      additionalInfo: json['additionalInfo'] as Map<String, dynamic>? ?? {},
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'platform': platform,
      'isPhysical': isPhysical,
      'isOnline': isOnline,
      'version': version,
      'architecture': architecture,
      'additionalInfo': additionalInfo,
    };
  }
  
  DeviceModel copyWith({
    String? id,
    String? name,
    String? platform,
    bool? isPhysical,
    bool? isOnline,
    String? version,
    String? architecture,
    Map<String, dynamic>? additionalInfo,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      isPhysical: isPhysical ?? this.isPhysical,
      isOnline: isOnline ?? this.isOnline,
      version: version ?? this.version,
      architecture: architecture ?? this.architecture,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }
  
  @override
  String toString() {
    return 'DeviceModel(id: $id, name: $name, platform: $platform, isPhysical: $isPhysical, isOnline: $isOnline, version: $version)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is DeviceModel &&
      other.id == id &&
      other.name == name &&
      other.platform == platform &&
      other.isPhysical == isPhysical &&
      other.isOnline == isOnline &&
      other.version == version &&
      other.architecture == architecture;
  }
  
  @override
  int get hashCode {
    return id.hashCode ^
      name.hashCode ^
      platform.hashCode ^
      isPhysical.hashCode ^
      isOnline.hashCode ^
      version.hashCode ^
      architecture.hashCode;
  }
}