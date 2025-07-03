import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';

class TOTPService {
  static const int _secretLength = 32;
  static const int _windowSize = 1; // Allow 1 window tolerance
  static const int _timeStep = 30; // 30 seconds
  static const int _digits = 6;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generate a cryptographically secure random secret
  String generateSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(_secretLength, (i) => random.nextInt(256));
    return base32Encode(bytes);
  }

  /// Generate TOTP code for current time
  String generateTOTP(String secret) {
    final timeCounter = DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ _timeStep;
    return _generateHOTP(secret, timeCounter);
  }

  /// Verify TOTP code
  bool verifyTOTP(String secret, String code) {
    final timeCounter = DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ _timeStep;
    
    // Check current window and adjacent windows for clock skew tolerance
    for (int i = -_windowSize; i <= _windowSize; i++) {
      final testCode = _generateHOTP(secret, timeCounter + i);
      if (testCode == code) {
        return true;
      }
    }
    return false;
  }

  /// Generate HOTP (HMAC-based One-Time Password)
  String _generateHOTP(String secret, int counter) {
    final key = base32Decode(secret);
    final counterBytes = _intToBytes(counter);
    
    final hmac = Hmac(sha1, key);
    final hash = hmac.convert(counterBytes).bytes;
    
    final offset = hash[hash.length - 1] & 0x0F;
    final truncatedHash = ((hash[offset] & 0x7F) << 24) |
                         ((hash[offset + 1] & 0xFF) << 16) |
                         ((hash[offset + 2] & 0xFF) << 8) |
                         (hash[offset + 3] & 0xFF);
    
    final code = truncatedHash % pow(10, _digits);
    return code.toString().padLeft(_digits, '0');
  }

  /// Convert integer to 8-byte array
  Uint8List _intToBytes(int value) {
    final bytes = Uint8List(8);
    for (int i = 7; i >= 0; i--) {
      bytes[i] = value & 0xFF;
      value >>= 8;
    }
    return bytes;
  }

  /// Base32 encoding
  String base32Encode(List<int> bytes) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    String result = '';
    int buffer = 0;
    int bitsLeft = 0;
    
    for (int byte in bytes) {
      buffer = (buffer << 8) | byte;
      bitsLeft += 8;
      
      while (bitsLeft >= 5) {
        result += alphabet[(buffer >> (bitsLeft - 5)) & 31];
        bitsLeft -= 5;
      }
    }
    
    if (bitsLeft > 0) {
      result += alphabet[(buffer << (5 - bitsLeft)) & 31];
    }
    
    return result;
  }

  /// Base32 decoding
  List<int> base32Decode(String encoded) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final bytes = <int>[];
    int buffer = 0;
    int bitsLeft = 0;
    
    for (int i = 0; i < encoded.length; i++) {
      final char = encoded[i].toUpperCase();
      final value = alphabet.indexOf(char);
      if (value == -1) continue;
      
      buffer = (buffer << 5) | value;
      bitsLeft += 5;
      
      if (bitsLeft >= 8) {
        bytes.add((buffer >> (bitsLeft - 8)) & 255);
        bitsLeft -= 8;
      }
    }
    
    return bytes;
  }

  /// Generate QR code URI for authenticator apps
  String generateQRCodeURI({
    required String secret,
    required String accountName,
    required String issuer,
  }) {
    final uri = Uri(
      scheme: 'otpauth',
      host: 'totp',
      path: '/$issuer:$accountName',
      queryParameters: {
        'secret': secret,
        'issuer': issuer,
        'algorithm': 'SHA1',
        'digits': _digits.toString(),
        'period': _timeStep.toString(),
      },
    );
    return uri.toString();
  }

  /// Enable 2FA for current user
  Future<Map<String, dynamic>> enable2FA() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final secret = generateSecret();
    final qrCodeURI = generateQRCodeURI(
      secret: secret,
      accountName: user.email ?? user.uid,
      issuer: 'UPM Digital Certificates',
    );

    // Store secret temporarily (will be confirmed after verification)
    await _firestore.collection('temp_2fa_setup').doc(user.uid).set({
      'secret': secret,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now().add(const Duration(minutes: 10)),
    });

    return {
      'secret': secret,
      'qrCodeURI': qrCodeURI,
      'manualEntryKey': _formatSecretForManualEntry(secret),
    };
  }

  /// Verify 2FA code using secret
  Future<bool> verify2FACode(String secret, String code) async {
    return verifyTOTP(secret, code);
  }

  /// Confirm 2FA setup
  Future<void> confirm2FASetup(String secret) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    // Move secret to permanent storage
    await _firestore.collection('users').doc(user.uid).update({
      'twoFactorSecret': secret,
      'twoFactorEnabled': true,
      'twoFactorEnabledAt': FieldValue.serverTimestamp(),
    });

    // Generate backup codes
    final backupCodes = _generateBackupCodes();
    await _firestore.collection('users').doc(user.uid).update({
      'backupCodes': backupCodes,
    });

    // Clean up temporary data
    await _firestore.collection('temp_2fa_setup').doc(user.uid).delete();
  }

  /// Verify and confirm 2FA setup with code
  Future<bool> verify2FASetupWithCode(String code) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    // Get temporary secret
    final tempDoc = await _firestore.collection('temp_2fa_setup').doc(user.uid).get();
    if (!tempDoc.exists) throw Exception('2FA setup not found or expired');

    final secret = tempDoc.data()!['secret'] as String;
    
    // Verify the code
    if (!verifyTOTP(secret, code)) {
      return false;
    }

    // Confirm setup with the secret
    await confirm2FASetup(secret);
    return true;
  }

  /// Disable 2FA for current user
  Future<void> disable2FA(String code) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    // Get user's 2FA secret
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User not found');

    final userData = userDoc.data()!;
    final secret = userData['twoFactorSecret'] as String?;
    
    if (secret == null) throw Exception('2FA not enabled');

    // Verify the code before disabling
    if (!verifyTOTP(secret, code)) {
      throw Exception('Invalid verification code');
    }

    // Disable 2FA
    await _firestore.collection('users').doc(user.uid).update({
      'twoFactorSecret': FieldValue.delete(),
      'twoFactorEnabled': false,
      'twoFactorDisabledAt': FieldValue.serverTimestamp(),
      'backupCodes': FieldValue.delete(),
    });
  }

  /// Verify 2FA code during login
  Future<bool> verify2FALogin(String userId, String code) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return false;

    final userData = userDoc.data()!;
    final secret = userData['twoFactorSecret'] as String?;
    final backupCodes = userData['backupCodes'] as List?;
    
    if (secret == null) return false;

    // First try TOTP verification
    if (verifyTOTP(secret, code)) {
      return true;
    }

    // If TOTP fails, check backup codes
    if (backupCodes != null && backupCodes.contains(code)) {
      // Remove used backup code
      final updatedCodes = List.from(backupCodes)..remove(code);
      await _firestore.collection('users').doc(userId).update({
        'backupCodes': updatedCodes,
      });
      return true;
    }

    return false;
  }

  /// Check if 2FA is enabled for user
  Future<bool> is2FAEnabled(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return false;
    
    final userData = userDoc.data()!;
    return userData['twoFactorEnabled'] == true;
  }

  /// Generate backup codes
  List<String> _generateBackupCodes() {
    final random = Random.secure();
    final codes = <String>[];
    
    for (int i = 0; i < 10; i++) {
      final code = List.generate(8, (index) => random.nextInt(10)).join();
      codes.add(code);
    }
    
    return codes;
  }

  /// Format secret for manual entry (groups of 4)
  String _formatSecretForManualEntry(String secret) {
    final buffer = StringBuffer();
    for (int i = 0; i < secret.length; i += 4) {
      if (i > 0) buffer.write(' ');
      final end = (i + 4 < secret.length) ? i + 4 : secret.length;
      buffer.write(secret.substring(i, end));
    }
    return buffer.toString();
  }

  /// Get remaining time until next code
  int getRemainingTimeSeconds() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return _timeStep - (now % _timeStep);
  }

  /// Generate QR code widget
  Widget generateQRCodeWidget(String qrCodeURI, {double size = 200}) {
    return QrImageView(
      data: qrCodeURI,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
    );
  }
} 