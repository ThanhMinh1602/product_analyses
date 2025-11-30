import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service để quản lý API keys từ Firestore
class ApiKeyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _collectionName = 'api_keys';
  static const String _defaultKey = 'AIzaSyAJMiI18Oz0Si3E3Yas0mE43Q_V-W3-z7w';

  /// Lấy API key đang active từ Firestore
  /// Nếu không có, trả về default key
  Future<String> getActiveApiKey() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('isActive', isEqualTo: true)
          .where('isValid', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        return data['key'] as String? ?? _defaultKey;
      }

      // Nếu không có active key, lấy key đầu tiên có isValid = true
      final fallbackQuery = await _firestore
          .collection(_collectionName)
          .where('isValid', isEqualTo: true)
          .limit(1)
          .get();

      if (fallbackQuery.docs.isNotEmpty) {
        final doc = fallbackQuery.docs.first;
        final data = doc.data();
        return data['key'] as String? ?? _defaultKey;
      }

      return _defaultKey;
    } catch (e) {
      print('Error getting API key from Firestore: $e');
      return _defaultKey;
    }
  }

  /// Thêm API key mới vào Firestore
  Future<void> addApiKey(String key, {String? name}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection(_collectionName).add({
        'key': key,
        'name': name ?? 'API Key ${DateTime.now().millisecondsSinceEpoch}',
        'isActive': false,
        'isValid': true,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsed': null,
        'usageCount': 0,
        'rateLimitExceeded': false,
      });
    } catch (e) {
      print('Error adding API key: $e');
      rethrow;
    }
  }

  /// Set API key làm active
  Future<void> setActiveApiKey(String keyId) async {
    try {
      // Deactivate all keys first
      final allKeys = await _firestore.collection(_collectionName).get();
      final batch = _firestore.batch();

      for (final doc in allKeys.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      // Activate the selected key
      final keyDoc = _firestore.collection(_collectionName).doc(keyId);
      batch.update(keyDoc, {'isActive': true});

      await batch.commit();
    } catch (e) {
      print('Error setting active API key: $e');
      rethrow;
    }
  }

  /// Đánh dấu API key là invalid (hết rate limit hoặc lỗi)
  Future<void> markApiKeyAsInvalid(String keyId, {bool rateLimitExceeded = false}) async {
    try {
      await _firestore.collection(_collectionName).doc(keyId).update({
        'isValid': false,
        'rateLimitExceeded': rateLimitExceeded,
        'lastError': FieldValue.serverTimestamp(),
      });

      // Nếu key này đang active, tự động chuyển sang key khác
      if (rateLimitExceeded) {
        await _switchToNextAvailableKey();
      }
    } catch (e) {
      print('Error marking API key as invalid: $e');
    }
  }

  /// Chuyển sang API key khác khi key hiện tại hết rate limit
  Future<void> _switchToNextAvailableKey() async {
    try {
      final availableKeys = await _firestore
          .collection(_collectionName)
          .where('isValid', isEqualTo: true)
          .where('rateLimitExceeded', isEqualTo: false)
          .orderBy('usageCount')
          .limit(1)
          .get();

      if (availableKeys.docs.isNotEmpty) {
        await setActiveApiKey(availableKeys.docs.first.id);
      }
    } catch (e) {
      print('Error switching to next API key: $e');
    }
  }

  /// Cập nhật usage count cho API key
  Future<void> updateUsageCount(String keyId) async {
    try {
      final keyDoc = _firestore.collection(_collectionName).doc(keyId);
      await keyDoc.update({
        'usageCount': FieldValue.increment(1),
        'lastUsed': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating usage count: $e');
    }
  }

  /// Lấy tất cả API keys (cho admin UI)
  Future<List<Map<String, dynamic>>> getAllApiKeys() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting all API keys: $e');
      return [];
    }
  }

  /// Xóa API key
  Future<void> deleteApiKey(String keyId) async {
    try {
      await _firestore.collection(_collectionName).doc(keyId).delete();
    } catch (e) {
      print('Error deleting API key: $e');
      rethrow;
    }
  }

  /// Tìm API key ID từ key value
  Future<String?> findKeyIdByValue(String keyValue) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('key', isEqualTo: keyValue)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      print('Error finding key ID: $e');
      return null;
    }
  }
}

