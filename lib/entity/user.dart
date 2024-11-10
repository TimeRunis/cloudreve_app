// ignore_for_file: public_member_api_docs, sort_constructors_first, non_constant_identifier_names
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'group.dart';

class User {
  String id;
  String user_name;
  String nickname;
  int status;
  String avatar;
  String created_at;
  bool anonymous;
  Group group;
  List tags;
  User(
    this.id,
    this.user_name,
    this.nickname,
    this.status,
    this.avatar,
    this.created_at,
    this.anonymous,
    this.group,
    this.tags,
  );
  

  User copyWith({
    String? id,
    String? userName,
    String? nickname,
    int? status,
    String? avatar,
    String? created_at,
    bool? anonymous,
    Group? group,
    List? tags,
  }) {
    return User(
      id ?? this.id,
      userName ?? this.user_name,
      nickname ?? this.nickname,
      status ?? this.status,
      avatar ?? this.avatar,
      created_at ?? this.created_at,
      anonymous ?? this.anonymous,
      group ?? this.group,
      tags ?? this.tags,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'user_name': user_name,
      'nickname': nickname,
      'status': status,
      'avatar': avatar,
      'created_at': created_at,
      'anonymous': anonymous,
      'group': group.toMap(),
      'tags': tags,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      map['id'] as String,
      map['user_name'] as String,
      map['nickname'] as String,
      map['status'] as int,
      map['avatar'] as String,
      map['created_at'] as String,
      map['anonymous'] as bool,
      Group.fromMap(map['group'] as Map<String,dynamic>),
      List.from((map['tags']),
    ));
  }

  String toJson() => json.encode(toMap());

  factory User.fromJson(String source) {
    return User.fromMap(json.decode(source) as Map<String, dynamic>);
  }

  @override
  String toString() {
    return 'User(id: $id, userName: $user_name, nickname: $nickname, status: $status, avatar: $avatar, created_at: $created_at, anonymous: $anonymous, group: $group, tags: $tags)';
  }

  @override
  bool operator ==(covariant User other) {
    if (identical(this, other)) return true;
  
    return 
      other.id == id &&
      other.user_name == user_name &&
      other.nickname == nickname &&
      other.status == status &&
      other.avatar == avatar &&
      other.created_at == created_at &&
      other.anonymous == anonymous &&
      other.group == group &&
      listEquals(other.tags, tags);
  }

  @override
  int get hashCode {
    return id.hashCode ^
      user_name.hashCode ^
      nickname.hashCode ^
      status.hashCode ^
      avatar.hashCode ^
      created_at.hashCode ^
      anonymous.hashCode ^
      group.hashCode ^
      tags.hashCode;
  }
}
