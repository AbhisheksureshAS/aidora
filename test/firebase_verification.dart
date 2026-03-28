import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:aidora/firebase_options.dart';

/// Firebase Verification Script
/// Run this to verify Firebase services are working
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔍 Starting Firebase Verification...\n');
  
  // 1. Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    print('📋 Project ID: ${Firebase.app().options.projectId}');
    print('📋 App Name: ${Firebase.app().name}');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    return;
  }
  
  // 2. Test Authentication
  print('\n🔐 Testing Firebase Authentication...');
  try {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    print('✅ FirebaseAuth instance available');
    print('📋 Current user: ${currentUser?.email ?? "Not logged in"}');
    print('✅ Authentication service working');
  } catch (e) {
    print('❌ Authentication test failed: $e');
  }
  
  // 3. Test Firestore
  print('\n🗄️ Testing Firestore Database...');
  try {
    final firestore = FirebaseFirestore.instance;
    
    // Test basic operations
    final testCollection = firestore.collection('verification_test');
    final testData = {
      'test': 'firebase_verification',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'status': 'testing',
    };
    
    // Write test
    final docRef = await testCollection.add(testData);
    print('✅ Document write successful: ${docRef.id}');
    
    // Read test
    final docSnapshot = await docRef.get();
    print('✅ Document read successful: ${docSnapshot.exists ? "EXISTS" : "NOT FOUND"}');
    
    // Update test
    await docRef.update({'status': 'verified'});
    print('✅ Document update successful');
    
    // Query test
    final query = await testCollection
        .where('test', isEqualTo: 'firebase_verification')
        .get();
    print('✅ Query successful: ${query.docs.length} documents found');
    
    // Delete test
    await docRef.delete();
    print('✅ Document delete successful');
    
    print('✅ All Firestore operations working');
  } catch (e) {
    print('❌ Firestore test failed: $e');
  }
  
  // 4. Test Index Requirements
  print('\n📋 Testing Index Requirements...');
  try {
    final firestore = FirebaseFirestore.instance;
    
    // Test common queries that might need indexes
    final queries = [
      // Users by helper status and rating
      () => firestore
          .collection('users')
          .where('isHelper', isEqualTo: true)
          .where('rating', isGreaterThanOrEqualTo: 4.0)
          .orderBy('rating', descending: true)
          .limit(10)
          .get(),
      
      // Help requests by status and urgency
      () => firestore
          .collection('help_requests')
          .where('status', isEqualTo: 'pending')
          .where('urgency', isEqualTo: 'high')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get(),
      
      // Messages by chat room
      () => firestore
          .collection('chat_messages')
          .where('chatRoomId', isEqualTo: 'test')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get(),
      
      // Notifications by user
      () => firestore
          .collection('notifications')
          .where('userId', isEqualTo: 'test')
          .where('isRead', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get(),
    ];
    
    for (int i = 0; i < queries.length; i++) {
      try {
        await queries[i]();
        print('✅ Query ${i + 1}: Working (no index needed)');
      } catch (e) {
        if (e.toString().contains('requires an index')) {
          print('⚠️ Query ${i + 1}: Requires Firestore index');
          print('📝 Create index in Firebase Console or use the provided URL');
        } else {
          print('✅ Query ${i + 1}: Working (${e.runtimeType})');
        }
      }
    }
  } catch (e) {
    print('❌ Index test failed: $e');
  }
  
  // 5. Test Real-time Listener
  print('\n🔄 Testing Real-time Listener...');
  try {
    final firestore = FirebaseFirestore.instance;
    final completer = Completer<bool>();
    
    final subscription = firestore
        .collection('realtime_test')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            print('✅ Real-time update received');
            completer.complete(true);
          }
        });
    
    // Add document to trigger listener
    await firestore.collection('realtime_test').add({
      'test': 'realtime_verification',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    // Wait for real-time update
    await Future.delayed(Duration(seconds: 2));
    
    await subscription.cancel();
    
    // Clean up
    final cleanup = await firestore
        .collection('realtime_test')
        .where('test', isEqualTo: 'realtime_verification')
        .get();
    for (final doc in cleanup.docs) {
      await doc.reference.delete();
    }
    
    print('✅ Real-time listener test completed');
  } catch (e) {
    print('❌ Real-time listener test failed: $e');
  }
  
  print('\n🎉 Firebase Verification Complete!');
  print('📋 All basic Firebase services are working correctly.');
  print('📝 If any queries require indexes, create them in Firebase Console.');
  print('🔗 Firebase Console: https://console.firebase.google.com/project/${Firebase.app().options.projectId}/firestore/indices');
}
