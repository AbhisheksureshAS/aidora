import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aidora/firebase_options.dart';

/// Simple Firebase connection test
/// Run with: dart test/simple_firebase_test.dart
void main() async {
  print('🔍 Testing Firebase Connection...\n');

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    print('📋 Project: ${Firebase.app().options.projectId}');
    print('📋 App ID: ${Firebase.app().options.appId}');

    // Test Authentication
    print('\n🔐 Testing Authentication...');
    final auth = FirebaseAuth.instance;
    print('✅ FirebaseAuth available');
    print('📋 Current user: ${auth.currentUser?.email ?? "Not logged in"}');

    // Test Firestore
    print('\n🗄️ Testing Firestore...');
    final firestore = FirebaseFirestore.instance;
    print('✅ Firestore available');

    // Test basic write/read
    final testDoc = await firestore.collection('connection_test').add({
      'test': 'firebase_connection',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    print('✅ Write successful: ${testDoc.id}');

    final snapshot = await testDoc.get();
    print('✅ Read successful: ${snapshot.exists ? "EXISTS" : "NOT FOUND"}');

    // Clean up
    await testDoc.delete();
    print('✅ Delete successful');

    // Test query
    final query = await firestore
        .collection('connection_test')
        .where('test', isEqualTo: 'firebase_connection')
        .limit(1)
        .get();
    print('✅ Query successful: ${query.docs.length} results');

    print('\n🎉 All Firebase services are working correctly!');
    print('📱 You can now run the app with: flutter run --debug');

  } catch (e) {
    print('❌ Firebase test failed: $e');
    print('\n🔧 Troubleshooting:');
    print('1. Check internet connection');
    print('2. Verify Firebase project configuration');
    print('3. Ensure Firebase rules allow read/write access');
    print('4. Check if Firebase services are enabled in console');
    exit(1);
  }
}
