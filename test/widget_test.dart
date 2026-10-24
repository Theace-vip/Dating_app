import 'package:flutter_test/flutter_test.dart';

import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';

void main() {
  group('UserModel.fromJson (payload từ server)', () {
    test('parse đầy đủ trường', () {
      final user = UserModel.fromJson({
        'id': 'u_1',
        'email': 'demo1@soulmate.app',
        'name': 'Minh Anh',
        'avatar': '🐱',
        'gender': 'female',
        'age': 21,
        'bio': 'Xin chào',
        'tags': ['Âm nhạc', 'Du lịch'],
        'photos': ['🌄'],
        'isVip': true,
        'coins': 2500,
        'diamonds': 120,
        'profileCompleted': true,
      });
      expect(user.id, 'u_1');
      expect(user.email, 'demo1@soulmate.app');
      expect(user.gender, Gender.female);
      expect(user.age, 21);
      expect(user.tags, ['Âm nhạc', 'Du lịch']);
      expect(user.isVip, isTrue);
      expect(user.vipFrame, '👑');
      expect(user.coins, 2500);
      expect(user.profileCompleted, isTrue);
    });

    test('giới tính lạ -> other, thiếu trường -> mặc định', () {
      final user = UserModel.fromJson({
        'id': 'x',
        'name': 'A',
        'gender': 'alien',
      });
      expect(user.gender, Gender.other);
      expect(user.age, 18);
      expect(user.profileCompleted, isFalse);
    });
  });

  group('PostModel repost', () {
    test('parse bài được đăng lại và giữ caption + snapshot bài gốc', () {
      final post = PostModel.fromJson({
        'id': 'p_repost',
        'userId': 'u_2',
        'userName': 'Người đăng lại',
        'userAvatar': '🐻',
        'content': 'Lời nhắn của tôi',
        'media': [],
        'originalPost': {
          'postId': 'p_original',
          'userId': 'u_1',
          'userName': 'Tác giả',
          'userAvatar': '🐱',
          'content': 'Bài gốc',
          'media': ['/uploads/photo.png'],
        },
        'createdAt': '2026-10-14T10:00:00.000Z',
        'shares': 0,
      });

      expect(post.repostCaption, 'Lời nhắn của tôi');
      expect(post.originalPost?.id, 'p_original');
      expect(post.originalPost?.userName, 'Tác giả');
      expect(post.originalPost?.media, ['/uploads/photo.png']);
      expect(post.copyWith(shares: 1).originalPost?.id, 'p_original');
    });
  });

  group('ConversationModel', () {
    test('fromJson + copyWithLast/copyWithUnread/copyWithOnline', () {
      final c = ConversationModel.fromJson({
        'id': 'c_1',
        'partnerId': 'u_2',
        'partnerName': 'Tuấn',
        'partnerAvatar': '🐻',
        'lastMessage': 'Chào',
        'lastMessageAt': '2026-09-27T10:00:00.000Z',
        'unreadCount': 2,
        'isOnline': true,
      });
      expect(c.unreadCount, 2);
      expect(c.isOnline, isTrue);

      final last = c.copyWithLast('Tin mới', DateTime(2026));
      expect(last.lastMessage, 'Tin mới');
      expect(last.unreadCount, 2);

      expect(c.copyWithUnread(0).unreadCount, 0);
      expect(c.copyWithOnline(false).isOnline, isFalse);
      expect(c.partnerName, 'Tuấn');
    });
  });

  group('AuthState', () {
    test('mới tạo -> đang khôi phục, chưa đăng nhập', () {
      const state = AuthState();
      expect(state.status, AuthStatus.restoring);
      expect(state.isRestoring, isTrue);
      expect(state.isLoggedIn, isFalse);
      expect(state.profileCompleted, isFalse);
    });

    test('đã đăng nhập + đủ hồ sơ', () {
      const user = UserModel(
        id: 'u_1',
        name: 'A',
        avatar: '🐱',
        gender: Gender.female,
        age: 20,
        profileCompleted: true,
      );
      const state = AuthState(status: AuthStatus.authenticated, user: user);
      expect(state.isLoggedIn, isTrue);
      expect(state.profileCompleted, isTrue);
    });
  });

  group('MessageModel.fromJson', () {
    test('parse thời gian ISO', () {
      final m = MessageModel.fromJson({
        'id': 'm_1',
        'conversationId': 'c_1',
        'senderId': 'u_2',
        'content': 'Hello',
        'type': 'text',
        'createdAt': '2026-09-27T10:00:00.000Z',
        'isRead': true,
      });
      expect(m.content, 'Hello');
      expect(m.type, MessageType.text);
      expect(m.isRead, isTrue);
      expect(m.createdAt.isUtc, isTrue);
    });

    test('tương thích sự kiện server cũ: URL uploads tự nhận dạng là ảnh', () {
      final message = MessageModel.fromJson({
        'id': 'm_image',
        'conversationId': 'c_1',
        'senderId': 'u_2',
        'content': '/uploads/img_test.png',
        'type': 'text',
        'createdAt': '2026-09-27T10:00:00.000Z',
      });
      expect(message.type, MessageType.image);
    });
  });
}
