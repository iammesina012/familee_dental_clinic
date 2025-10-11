import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

/// Service for automatic backup file encryption/decryption
/// Uses device-specific key generation for Owner-only access
class EncryptionService {
  static const String _appSecret = 'familee_2021';
  static const String _encryptionPrefix = 'ENCRYPTED:';

  /// Generate a consistent encryption key based on user account info
  static String _generateEncryptionKey(String userId, String userEmail) {
    // Combine user info with app secret for consistent key generation
    final keySource = '${userId}_${userEmail}_$_appSecret';

    // Create SHA-256 hash and take first 32 characters for AES key
    final bytes = utf8.encode(keySource);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 32);
  }

  /// Encrypt data using AES encryption
  static String encryptData(String data, String userId, String userEmail) {
    try {
      final key = _generateEncryptionKey(userId, userEmail);
      final keyBytes = utf8.encode(key);
      final keyObj = Key(keyBytes);
      final iv = IV.fromSecureRandom(16); // Generate random IV

      final encrypter = Encrypter(AES(keyObj));
      final encrypted = encrypter.encrypt(data, iv: iv);

      // Combine IV and encrypted data, then base64 encode
      final combined = iv.bytes + encrypted.bytes;
      final base64Encoded = base64.encode(combined);

      // Add prefix to identify as encrypted
      return '$_encryptionPrefix$base64Encoded';
    } catch (e) {
      print('Encryption error: $e');
      return data; // Return original data if encryption fails
    }
  }

  /// Decrypt data using AES decryption
  static String decryptData(
      String encryptedData, String userId, String userEmail) {
    try {
      // Check if data is encrypted
      if (!encryptedData.startsWith(_encryptionPrefix)) {
        return encryptedData; // Return as-is if not encrypted
      }

      // Remove prefix and decode
      final base64Data = encryptedData.substring(_encryptionPrefix.length);
      final combined = base64.decode(base64Data);

      // Extract IV (first 16 bytes) and encrypted data (rest)
      final ivBytes = combined.sublist(0, 16);
      final encryptedBytes = combined.sublist(16);

      final key = _generateEncryptionKey(userId, userEmail);
      final keyBytes = utf8.encode(key);
      final keyObj = Key(keyBytes);
      final iv = IV(ivBytes);

      final encrypter = Encrypter(AES(keyObj));
      final encrypted = Encrypted(encryptedBytes);

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      print('Decryption error: $e');
      return encryptedData; // Return original data if decryption fails
    }
  }

  /// Check if data appears to be encrypted
  static bool isEncrypted(String data) {
    return data.startsWith(_encryptionPrefix);
  }

  /// Generate a secure random string for testing
  static String generateRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }
}
