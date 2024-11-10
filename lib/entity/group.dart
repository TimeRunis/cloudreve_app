import 'dart:convert';

class Group {
  int id;
  String name;
  bool allowShare;
  bool allowRemoteDownload;
  bool allowArchiveDownload;
  bool shareDownload;
  bool compress;
  bool webdav;
  int sourceBatch;
  bool advanceDelete;
  bool allowWebDAVProxy;
  Group(
    this.id,
    this.name,
    this.allowShare,
    this.allowRemoteDownload,
    this.allowArchiveDownload,
    this.shareDownload,
    this.compress,
    this.webdav,
    this.sourceBatch,
    this.advanceDelete,
    this.allowWebDAVProxy,
  );

  Group copyWith({
    int? id,
    String? name,
    bool? allowShare,
    bool? allowRemoteDownload,
    bool? allowArchiveDownload,
    bool? shareDownload,
    bool? compress,
    bool? webdav,
    int? sourceBatch,
    bool? advanceDelete,
    bool? allowWebDAVProxy,
  }) {
    return Group(
      id ?? this.id,
      name ?? this.name,
      allowShare ?? this.allowShare,
      allowRemoteDownload ?? this.allowRemoteDownload,
      allowArchiveDownload ?? this.allowArchiveDownload,
      shareDownload ?? this.shareDownload,
      compress ?? this.compress,
      webdav ?? this.webdav,
      sourceBatch ?? this.sourceBatch,
      advanceDelete ?? this.advanceDelete,
      allowWebDAVProxy ?? this.allowWebDAVProxy,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'allowShare': allowShare,
      'allowRemoteDownload': allowRemoteDownload,
      'allowArchiveDownload': allowArchiveDownload,
      'shareDownload': shareDownload,
      'compress': compress,
      'webdav': webdav,
      'sourceBatch': sourceBatch,
      'advanceDelete': advanceDelete,
      'allowWebDAVProxy': allowWebDAVProxy,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      map['id'] as int,
      map['name'] as String,
      map['allowShare'] as bool,
      map['allowRemoteDownload'] as bool,
      map['allowArchiveDownload'] as bool,
      map['shareDownload'] as bool,
      map['compress'] as bool,
      map['webdav'] as bool,
      map['sourceBatch'] as int,
      map['advanceDelete'] as bool,
      map['allowWebDAVProxy'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory Group.fromJson(String source) => Group.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Group(id: $id, name: $name, allowShare: $allowShare, allowRemoteDownload: $allowRemoteDownload, allowArchiveDownload: $allowArchiveDownload, shareDownload: $shareDownload, compress: $compress, webdav: $webdav, sourceBatch: $sourceBatch, advanceDelete: $advanceDelete, allowWebDAVProxy: $allowWebDAVProxy)';
  }

  @override
  bool operator ==(covariant Group other) {
    if (identical(this, other)) return true;
  
    return 
      other.id == id &&
      other.name == name &&
      other.allowShare == allowShare &&
      other.allowRemoteDownload == allowRemoteDownload &&
      other.allowArchiveDownload == allowArchiveDownload &&
      other.shareDownload == shareDownload &&
      other.compress == compress &&
      other.webdav == webdav &&
      other.sourceBatch == sourceBatch &&
      other.advanceDelete == advanceDelete &&
      other.allowWebDAVProxy == allowWebDAVProxy;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      name.hashCode ^
      allowShare.hashCode ^
      allowRemoteDownload.hashCode ^
      allowArchiveDownload.hashCode ^
      shareDownload.hashCode ^
      compress.hashCode ^
      webdav.hashCode ^
      sourceBatch.hashCode ^
      advanceDelete.hashCode ^
      allowWebDAVProxy.hashCode;
  }
}
