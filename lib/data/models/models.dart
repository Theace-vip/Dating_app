enum Gender { male, female, other }

enum MessageType { text, image, voice, emoji }

class UserModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String avatar; // emoji hoặc url
  final Gender gender;
  final int age;
  final String? bio;
  final List<String> tags;
  final List<String> photos;
  final bool isVip;
  final String? vipFrame;
  final bool isOnline;
  final int coins;
  final int diamonds;
  final bool profileCompleted;

  const UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.avatar,
    required this.gender,
    required this.age,
    this.bio,
    this.tags = const [],
    this.photos = const [],
    this.isVip = false,
    this.vipFrame,
    this.isOnline = false,
    this.coins = 100,
    this.diamonds = 10,
    this.profileCompleted = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    Gender parseGender(String? g) {
      for (final v in Gender.values) {
        if (v.name == g) return v;
      }
      return Gender.other;
    }

    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String? ?? '🙂',
      gender: parseGender(json['gender'] as String?),
      age: (json['age'] as num?)?.toInt() ?? 18,
      bio: json['bio'] as String?,
      tags: (json['tags'] as List?)?.map((e) => '$e').toList() ?? const [],
      photos: (json['photos'] as List?)?.map((e) => '$e').toList() ?? const [],
      isVip: json['isVip'] == true,
      vipFrame: json['isVip'] == true ? '👑' : null,
      isOnline: json['isOnline'] == true,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      diamonds: (json['diamonds'] as num?)?.toInt() ?? 0,
      profileCompleted: json['profileCompleted'] == true,
    );
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? avatar,
    Gender? gender,
    int? age,
    String? bio,
    List<String>? tags,
    List<String>? photos,
    bool? isVip,
    bool? isOnline,
    int? coins,
    int? diamonds,
    bool? profileCompleted,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      bio: bio ?? this.bio,
      tags: tags ?? this.tags,
      photos: photos ?? this.photos,
      isVip: isVip ?? this.isVip,
      vipFrame: vipFrame,
      isOnline: isOnline ?? this.isOnline,
      coins: coins ?? this.coins,
      diamonds: diamonds ?? this.diamonds,
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final bool isRead;
  final int? durationSeconds; // cho voice

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.type = MessageType.text,
    required this.createdAt,
    this.isRead = false,
    this.durationSeconds,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    MessageType parseType(String? t) {
      for (final v in MessageType.values) {
        if (v.name == t) return v;
      }
      return MessageType.text;
    }

    final content = json['content'] as String? ?? '';
    final parsedType = parseType(json['type'] as String?);
    final isUploadedImage =
        content.startsWith('/uploads/') ||
        (Uri.tryParse(content)?.path.startsWith('/uploads/') ?? false);

    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      content: content,
      // Compat: older server socket events incorrectly labelled uploaded images as text.
      type: parsedType == MessageType.text && isUploadedImage
          ? MessageType.image
          : parsedType,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] == true,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
    );
  }
}

class ConversationModel {
  final String id;
  final String partnerId;
  final String partnerName;
  final String partnerAvatar;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isOnline;

  const ConversationModel({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.partnerAvatar,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      partnerId: json['partnerId'] as String? ?? '',
      partnerName: json['partnerName'] as String? ?? '',
      partnerAvatar: json['partnerAvatar'] as String? ?? '🙂',
      lastMessage: json['lastMessage'] as String? ?? '',
      lastMessageAt:
          DateTime.tryParse(json['lastMessageAt'] as String? ?? '') ??
          DateTime.now(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      isOnline: json['isOnline'] == true,
    );
  }

  ConversationModel copyWithLast(String message, DateTime at) =>
      ConversationModel(
        id: id,
        partnerId: partnerId,
        partnerName: partnerName,
        partnerAvatar: partnerAvatar,
        lastMessage: message,
        lastMessageAt: at,
        unreadCount: unreadCount,
        isOnline: isOnline,
      );

  ConversationModel copyWithUnread(int n) => ConversationModel(
    id: id,
    partnerId: partnerId,
    partnerName: partnerName,
    partnerAvatar: partnerAvatar,
    lastMessage: lastMessage,
    lastMessageAt: lastMessageAt,
    unreadCount: n,
    isOnline: isOnline,
  );

  ConversationModel copyWithOnline(bool online) => ConversationModel(
    id: id,
    partnerId: partnerId,
    partnerName: partnerName,
    partnerAvatar: partnerAvatar,
    lastMessage: lastMessage,
    lastMessageAt: lastMessageAt,
    unreadCount: unreadCount,
    isOnline: online,
  );
}

/// Bản xem trước bài gốc được đính kèm trong một bài đăng lại.
class OriginalPostModel {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String? content;
  final List<String> media;

  const OriginalPostModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    this.content,
    this.media = const [],
  });

  factory OriginalPostModel.fromJson(Map<String, dynamic> json) =>
      OriginalPostModel(
        id: json['postId'] as String? ?? json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        userName: json['userName'] as String? ?? '',
        userAvatar: json['userAvatar'] as String? ?? '🙂',
        content: json['content'] as String?,
        media:
            (json['media'] as List?)?.map((item) => '$item').toList() ??
            const [],
      );
}

/// Bài feed có thể là bài gốc hoặc repost; snapshot gốc giúp render quote ổn định.
class PostModel {
  final String id;
  final OriginalPostModel? originalPost;
  final String repostCaption;
  final String userId;
  final String userName;
  final String userAvatar;
  final String? content;
  final List<String> media;
  final DateTime createdAt;
  final int likes;
  final int comments;
  final int shares;
  final bool likedByMe;

  const PostModel({
    required this.id,
    this.originalPost,
    this.repostCaption = '',
    required this.userId,
    required this.userName,
    required this.userAvatar,
    this.content,
    this.media = const [],
    required this.createdAt,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.likedByMe = false,
  });

  /// Chuyển payload REST/Socket sang model UI; payload repost có originalPost lồng bên trong.
  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      originalPost: json['originalPost'] is Map
          ? OriginalPostModel.fromJson(
              Map<String, dynamic>.from(json['originalPost'] as Map),
            )
          : null,
      repostCaption: json['originalPost'] is Map
          ? json['content'] as String? ?? ''
          : '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      userAvatar: json['userAvatar'] as String? ?? '🙂',
      content: json['content'] as String?,
      media: (json['media'] as List?)?.map((e) => '$e').toList() ?? const [],
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      comments: (json['comments'] as num?)?.toInt() ?? 0,
      shares: (json['shares'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] == true,
    );
  }

  PostModel copyWith({
    int? likes,
    int? comments,
    int? shares,
    bool? likedByMe,
  }) {
    return PostModel(
      id: id,
      originalPost: originalPost,
      repostCaption: repostCaption,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      content: content,
      media: media,
      createdAt: createdAt,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}

class RoomModel {
  final String id;
  final String name;
  final String hostName;
  final String hostAvatar;
  final int memberCount;
  final List<String> memberAvatars;
  final String? backgroundEmoji;
  final String topic;

  const RoomModel({
    required this.id,
    required this.name,
    required this.hostName,
    required this.hostAvatar,
    this.memberCount = 0,
    this.memberAvatars = const [],
    this.backgroundEmoji,
    this.topic = '',
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      hostName: json['hostName'] as String? ?? '',
      hostAvatar: json['hostAvatar'] as String? ?? '🙂',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      memberAvatars:
          (json['memberAvatars'] as List?)?.map((e) => '$e').toList() ??
          const [],
      backgroundEmoji: json['backgroundEmoji'] as String?,
      topic: json['topic'] as String? ?? '',
    );
  }

  RoomModel copyWithMembers(int count, List<String> avatars) => RoomModel(
    id: id,
    name: name,
    hostName: hostName,
    hostAvatar: hostAvatar,
    memberCount: count,
    memberAvatars: avatars,
    backgroundEmoji: backgroundEmoji,
    topic: topic,
  );
}

/// Dữ liệu hiển thị một bình luận trong feed.
class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      postId: json['postId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      userAvatar: json['userAvatar'] as String? ?? '🙂',
      content: json['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class RoomMessageModel {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String content;
  final DateTime createdAt;

  const RoomMessageModel({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.content,
    required this.createdAt,
  });

  factory RoomMessageModel.fromJson(Map<String, dynamic> json) {
    return RoomMessageModel(
      id: json['id'] as String,
      roomId: json['roomId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      senderAvatar: json['senderAvatar'] as String? ?? '🙂',
      content: json['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
