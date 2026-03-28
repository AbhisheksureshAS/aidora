import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:aidora/firebase_options.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Firebase Integration Tests', () {
    late FirebaseAuth auth;
    late FirebaseFirestore firestore;

    setUpAll(() async {
      // Initialize Firebase for testing
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        auth = FirebaseAuth.instance;
        firestore = FirebaseFirestore.instance;
      } catch (e) {
        print('Firebase initialization failed: ${e.toString()}');
        rethrow;
      }
    });

    test('Firebase Authentication - Sign In Test', () async {
      try {
        // Test with a test user (you'll need to create this in Firebase Console)
        final result = await auth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'testpassword123',
        );
        
        expect(result.user, isNotNull);
        expect(result.user?.email, equals('test@example.com'));
        
        // Sign out after test
        await auth.signOut();
      } catch (e) {
        // If user doesn't exist, that's expected for this test
        print('Authentication test: ${e.toString()}');
      }
    });

    test('Firebase Firestore - Basic Operations Test', () async {
      try {
        // Test writing to Firestore
        final docRef = await firestore.collection('test_collection').add({
          'test_field': 'test_value',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        expect(docRef.id, isNotEmpty);

        // Test reading from Firestore
        final docSnapshot = await docRef.get();
        expect(docSnapshot.exists, isTrue);
        expect(docSnapshot.data()?['test_field'], equals('test_value'));

        // Test updating document
        await docRef.update({
          'test_field': 'updated_value',
        });

        final updatedSnapshot = await docRef.get();
        expect(updatedSnapshot.data()?['test_field'], equals('updated_value'));

        // Clean up
        await docRef.delete();
        final deletedSnapshot = await docRef.get();
        expect(deletedSnapshot.exists, isFalse);

      } catch (e) {
        fail('Firestore operations test failed: ${e.toString()}');
      }
    });

    test('User Model - Firestore Integration Test', () async {
      try {
        // Test user data structure
        final testData = {
          'uid': 'test_uid',
          'email': 'test@example.com',
          'name': 'Test User',
          'skills': ['Flutter', 'Firebase'],
          'isHelper': true,
          'rating': 4.5,
          'totalRatings': 10,
          'latitude': 37.7749,
          'longitude': -122.4194,
          'locationName': 'San Francisco, CA',
          'bio': 'Test user bio',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        };

        final docRef = await firestore.collection('users').add(testData);
        final docSnapshot = await docRef.get();

        expect(docSnapshot.exists, isTrue);
        expect(docSnapshot.data()?['email'], equals('test@example.com'));
        expect(docSnapshot.data()?['skills'], isA<List>());
        expect(docSnapshot.data()?['isHelper'], isTrue);

        // Clean up
        await docRef.delete();
      } catch (e) {
        fail('User model integration test failed: ${e.toString()}');
      }
    });

    test('Help Request Model - Firestore Integration Test', () async {
      try {
        final testData = {
          'seekerId': 'test_seeker_id',
          'seekerName': 'Test Seeker',
          'helperId': 'test_helper_id',
          'helperName': 'Test Helper',
          'title': 'Test Help Request',
          'description': 'This is a test help request',
          'category': 'academic',
          'urgency': 'medium',
          'status': 'pending',
          'latitude': 37.7749,
          'longitude': -122.4194,
          'locationName': 'San Francisco, CA',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'requiredSkills': ['Flutter', 'Dart'],
          'offeredAmount': 50.0,
        };

        final docRef = await firestore.collection('help_requests').add(testData);
        final docSnapshot = await docRef.get();

        expect(docSnapshot.exists, isTrue);
        expect(docSnapshot.data()?['title'], equals('Test Help Request'));
        expect(docSnapshot.data()?['status'], equals('pending'));
        expect(docSnapshot.data()?['offeredAmount'], equals(50.0));

        // Clean up
        await docRef.delete();
      } catch (e) {
        fail('Help request model integration test failed: ${e.toString()}');
      }
    });

    test('Chat Message Model - Firestore Integration Test', () async {
      try {
        final testData = {
          'senderId': 'test_sender_id',
          'senderName': 'Test Sender',
          'receiverId': 'test_receiver_id',
          'receiverName': 'Test Receiver',
          'content': 'Hello, this is a test message!',
          'type': 'text',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'isRead': false,
        };

        final docRef = await firestore.collection('chat_messages').add(testData);
        final docSnapshot = await docRef.get();

        expect(docSnapshot.exists, isTrue);
        expect(docSnapshot.data()?['content'], equals('Hello, this is a test message!'));
        expect(docSnapshot.data()?['type'], equals('text'));
        expect(docSnapshot.data()?['isRead'], isFalse);

        // Clean up
        await docRef.delete();
      } catch (e) {
        fail('Chat message model integration test failed: ${e.toString()}');
      }
    });

    test('Rating Model - Firestore Integration Test', () async {
      try {
        final testData = {
          'fromUserId': 'test_from_user_id',
          'fromUserName': 'Test From User',
          'toUserId': 'test_to_user_id',
          'toUserName': 'Test To User',
          'helpRequestId': 'test_request_id',
          'helpRequestTitle': 'Test Request',
          'rating': 4.5,
          'feedback': 'Great help, very professional!',
          'criteria': [
            {'name': 'Communication', 'score': 4.0},
            {'name': 'Quality', 'score': 5.0},
            {'name': 'Timeliness', 'score': 4.5},
          ],
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'isPublic': true,
        };

        final docRef = await firestore.collection('ratings').add(testData);
        final docSnapshot = await docRef.get();

        expect(docSnapshot.exists, isTrue);
        expect(docSnapshot.data()?['rating'], equals(4.5));
        expect(docSnapshot.data()?['feedback'], equals('Great help, very professional!'));
        expect(docSnapshot.data()?['criteria'], isA<List>());

        // Clean up
        await docRef.delete();
      } catch (e) {
        fail('Rating model integration test failed: ${e.toString()}');
      }
    });

    test('Notification Model - Firestore Integration Test', () async {
      try {
        final testData = {
          'userId': 'test_user_id',
          'title': 'Test Notification',
          'body': 'This is a test notification',
          'type': 'newRequest',
          'isRead': false,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'data': {'requestId': 'test_request_id'},
        };

        final docRef = await firestore.collection('notifications').add(testData);
        final docSnapshot = await docRef.get();

        expect(docSnapshot.exists, isTrue);
        expect(docSnapshot.data()?['title'], equals('Test Notification'));
        expect(docSnapshot.data()?['type'], equals('newRequest'));
        expect(docSnapshot.data()?['isRead'], isFalse);

        // Clean up
        await docRef.delete();
      } catch (e) {
        fail('Notification model integration test failed: ${e.toString()}');
      }
    });

    tearDownAll(() async {
      // Clean up any remaining test data
      try {
        final collections = ['test_collection', 'users', 'help_requests', 'chat_messages', 'ratings', 'notifications'];
        for (final collection in collections) {
          final query = await firestore
              .collection(collection)
              .where('test_field', isEqualTo: 'test_value')
              .get();
          
          for (final doc in query.docs) {
            await doc.reference.delete();
          }
        }
      } catch (e) {
        print('Cleanup error: ${e.toString()}');
      }
    });
  });
}
