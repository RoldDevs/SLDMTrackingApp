import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Provider for Firebase Auth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

// Provider for Firestore instance
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// Provider for the current user
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// Provider to check if user is admin
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return false;
  
  // Check if the email is the admin email
  return user.email == 'sldmcentralized@management.app';
});

// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider));
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._firestore);

  // Sign in with email and password
  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign up with email and password
  Future<UserCredential> signUp(String email, String password, String username, String contactNumber) async {
    try {
      // Create user with email and password
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final uid = userCredential.user!.uid;
      
      // Save additional user data to Firestore
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'username': username,
        'contactNumber': contactNumber,
        'isAdmin': email == 'sldmcentralized@management.app',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Create student record in students collection
      await _firestore.collection('students').doc(uid).set({
        'username': username,
        'userUID': uid,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Create initial billing record
      await _firestore.collection('billings').doc(uid).set({
        'studentName': username,
        'userUID': uid,
        'email': email,
        'description': 'Tuition fees',
        'summary': 'Initial enrollment',
        'remainingBalance': 15000,
        'amount': 15000,
        'paymentDueDates': [
          {
            'dueDate': _getNextMonthDate(),
            'amount': 5000,
          },
          {
            'dueDate': _getNextMonthDate(2),
            'amount': 5000,
          },
          {
            'dueDate': _getNextMonthDate(3),
            'amount': 5000,
          },
        ],
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Helper method to get date for next month(s)
  String _getNextMonthDate([int monthsToAdd = 1]) {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + monthsToAdd, 1);
    return '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-01';
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}