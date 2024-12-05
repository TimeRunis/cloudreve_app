// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class File {
    String id;
    String name;
    String path;
    bool thumb;
    int size;
    String type;
    String date;
    String create_date;
    bool source_enabled;
  File({
    required this.id,
    required this.name,
    required this.path,
    required this.thumb,
    required this.size,
    required this.type,
    required this.date,
    required this.create_date,
    required this.source_enabled,
  });

  File copyWith({
    String? id,
    String? name,
    String? path,
    bool? thumb,
    int? size,
    String? Type,
    String? date,
    String? create_date,
    bool? source_enabled,
  }) {
    return File(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      thumb: thumb ?? this.thumb,
      size: size ?? this.size,
      type: type,
      date: date ?? this.date,
      create_date: create_date ?? this.create_date,
      source_enabled: source_enabled ?? this.source_enabled,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'path': path,
      'thumb': thumb,
      'size': size,
      'type': type,
      'date': date,
      'create_date': create_date,
      'source_enabled': source_enabled,
    };
  }

  factory File.fromMap(Map<String, dynamic> map) {
    return File(
      id: map['id'] as String,
      name: map['name'] as String,
      path: map['path'] as String,
      thumb: map['thumb'] as bool,
      size: map['size'] as int,
      type: map['type'] as String,
      date: map['date'] as String,
      create_date: map['create_date'] as String,
      source_enabled: map['source_enabled'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory File.fromJson(String source) => File.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'File(id: $id, name: $name, path: $path, thumb: $thumb, size: $size, Type: $Type, date: $date, create_date: $create_date, source_enabled: $source_enabled)';
  }

  @override
  bool operator ==(covariant File other) {
    if (identical(this, other)) return true;
  
    return 
      other.id == id &&
      other.name == name &&
      other.path == path &&
      other.thumb == thumb &&
      other.size == size &&
      other.type == type &&
      other.date == date &&
      other.create_date == create_date &&
      other.source_enabled == source_enabled;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      name.hashCode ^
      path.hashCode ^
      thumb.hashCode ^
      size.hashCode ^
      type.hashCode ^
      date.hashCode ^
      create_date.hashCode ^
      source_enabled.hashCode;
  }
}
