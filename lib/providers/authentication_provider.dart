import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/constants.dart';
import 'package:flutter_chat_pro/models/user_model.dart';
import 'package:flutter_chat_pro/utilities/global_methods.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthenticationProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isSuccessful = false;
  String? _uid;
  String? _phoneNumber;
  UserModel? _userModel;

  bool get isLoading => _isLoading;
  bool get isSuccessful => _isSuccessful;
  String? get uid => _uid;
  String? get phoneNumber => _phoneNumber;
  UserModel? get userModel => _userModel;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // chech authentication state
  Future<bool> checkAuthenticationState() async {
    bool isSignedIn = false;
    await Future.delayed(const Duration(seconds: 2));

    try {
      if (_auth.currentUser != null) {
        _uid = _auth.currentUser!.uid;

        // get user data from firestore
        final exists = await getUserDataFromFireStore();

        if (exists) {
          // save user data to shared preferences
          await saveUserDataToSharedPreferences();
          notifyListeners();
          isSignedIn = true;
        } else {
          // If the user doc doesn't exist in this Firebase project (e.g. you switched google-services.json),
          // sign out to force a clean login and avoid crashes.
          await _auth.signOut();
          isSignedIn = false;
        }
      } else {
        isSignedIn = false;
      }
    } catch (_) {
      // Any unexpected error during boot should not block the app; fall back to login.
      isSignedIn = false;
    }

    return isSignedIn;
  }

  // sign in with Google
  Future<void> signInWithGoogle({required BuildContext context}) async {
    _isLoading = true;
    notifyListeners();

    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        // Force account chooser on web each time
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Ensure previous Google session is cleared so account chooser shows
        try {
          await GoogleSignIn().signOut();
          await GoogleSignIn().disconnect();
        } catch (_) {}

        final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
        if (gUser == null) {
          // user aborted
          _isLoading = false;
          notifyListeners();
          return;
        }
        final GoogleSignInAuthentication gAuth = await gUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: gAuth.accessToken,
          idToken: gAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      final user = userCredential.user!;
      _uid = user.uid;
      _phoneNumber = user.phoneNumber ?? '';

      // if user doc doesn't exist, create it with Google profile data
      final userDocRef = _firestore.collection(Constants.users).doc(_uid);
      final snapshot = await userDocRef.get();
      if (!snapshot.exists) {
        final newUser = UserModel(
          uid: _uid!,
          name: user.displayName ?? 'User',
          phoneNumber: _phoneNumber ?? '',
          image: user.photoURL ?? '',
          token: '',
          aboutMe: "Hey there, I'm using Flutter Chat Pro",
          lastSeen: DateTime.now().microsecondsSinceEpoch.toString(),
          createdAt: DateTime.now().microsecondsSinceEpoch.toString(),
          isOnline: true,
          friendsUIDs: [],
          friendRequestsUIDs: [],
          sentFriendRequestsUIDs: [],
        );

        await userDocRef.set(newUser.toMap());
        _userModel = newUser;
      } else {
        _userModel =
            UserModel.fromMap(snapshot.data() as Map<String, dynamic>);
      }

      // persist locally
      await saveUserDataToSharedPreferences();

      _isSuccessful = true;
      _isLoading = false;
      notifyListeners();

      // navigate to home
      Navigator.of(context).pushNamedAndRemoveUntil(
        Constants.homeScreen,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _isSuccessful = false;
      _isLoading = false;
      notifyListeners();
      showSnackBar(context, e.message ?? e.code);
    } catch (e) {
      _isSuccessful = false;
      _isLoading = false;
      notifyListeners();
      showSnackBar(context, e.toString());
    }
  }

  // chech if user exists
  Future<bool> checkUserExists() async {
    DocumentSnapshot documentSnapshot =
        await _firestore.collection(Constants.users).doc(_uid).get();
    if (documentSnapshot.exists) {
      return true;
    } else {
      return false;
    }
  }

  // update user status
  Future<void> updateUserStatus({required bool value}) async {
    await _firestore
        .collection(Constants.users)
        .doc(_auth.currentUser!.uid)
        .update({Constants.isOnline: value});
  }

  // get user data from firestore
  // returns true if the user document exists and was loaded
  Future<bool> getUserDataFromFireStore() async {
    final DocumentSnapshot documentSnapshot =
        await _firestore.collection(Constants.users).doc(_uid).get();

    if (!documentSnapshot.exists) {
      return false;
    }

    _userModel =
        UserModel.fromMap(documentSnapshot.data() as Map<String, dynamic>);
    notifyListeners();
    return true;
  }

  // save user data to shared preferences
  Future<void> saveUserDataToSharedPreferences() async {
    if (_userModel == null) return;
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setString(
        Constants.userModel, jsonEncode(_userModel!.toMap()));
  }

  // get data from shared preferences
  Future<void> getUserDataFromSharedPreferences() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    String userModelString =
        sharedPreferences.getString(Constants.userModel) ?? '';
    _userModel = UserModel.fromMap(jsonDecode(userModelString));
    _uid = _userModel!.uid;
    notifyListeners();
  }

  // sign in with phone number
  

  // save user data to firestore
  void saveUserDataToFireStore({
    required UserModel userModel,
    required File? fileImage,
    required Function onSuccess,
    required Function onFail,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (fileImage != null) {
        // upload image to storage
        String imageUrl = await storeFileToStorage(
            file: fileImage,
            reference: '${Constants.userImages}/${userModel.uid}');

        userModel.image = imageUrl;
      }

      userModel.lastSeen = DateTime.now().microsecondsSinceEpoch.toString();
      userModel.createdAt = DateTime.now().microsecondsSinceEpoch.toString();

      _userModel = userModel;
      _uid = userModel.uid;

      // save user data to firestore
      await _firestore
          .collection(Constants.users)
          .doc(userModel.uid)
          .set(userModel.toMap());

      _isLoading = false;
      onSuccess();
      notifyListeners();
    } on FirebaseException catch (e) {
      _isLoading = false;
      notifyListeners();
      onFail(e.toString());
    }
  }

  // get user stream
  Stream<DocumentSnapshot> userStream({required String userID}) {
    return _firestore.collection(Constants.users).doc(userID).snapshots();
  }

  // get all users stream
  Stream<QuerySnapshot> getAllUsersStream({required String userID}) {
    return _firestore
        .collection(Constants.users)
        .where(Constants.uid, isNotEqualTo: userID)
        .snapshots();
  }

  // send friend request
  Future<void> sendFriendRequest({
    required String friendID,
  }) async {
    try {
      // add our uid to friends request list
      await _firestore.collection(Constants.users).doc(friendID).update({
        Constants.friendRequestsUIDs: FieldValue.arrayUnion([_uid]),
      });

      // add friend uid to our friend requests sent list
      await _firestore.collection(Constants.users).doc(_uid).update({
        Constants.sentFriendRequestsUIDs: FieldValue.arrayUnion([friendID]),
      });
    } on FirebaseException catch (e) {
      print(e);
    }
  }

  Future<void> cancleFriendRequest({required String friendID}) async {
    try {
      // remove our uid from friends request list
      await _firestore.collection(Constants.users).doc(friendID).update({
        Constants.friendRequestsUIDs: FieldValue.arrayRemove([_uid]),
      });

      // remove friend uid from our friend requests sent list
      await _firestore.collection(Constants.users).doc(_uid).update({
        Constants.sentFriendRequestsUIDs: FieldValue.arrayRemove([friendID]),
      });
    } on FirebaseException catch (e) {
      print(e);
    }
  }

  Future<void> acceptFriendRequest({required String friendID}) async {
    // add our uid to friends list
    await _firestore.collection(Constants.users).doc(friendID).update({
      Constants.friendsUIDs: FieldValue.arrayUnion([_uid]),
    });

    // add friend uid to our friends list
    await _firestore.collection(Constants.users).doc(_uid).update({
      Constants.friendsUIDs: FieldValue.arrayUnion([friendID]),
    });

    // remove our uid from friends request list
    await _firestore.collection(Constants.users).doc(friendID).update({
      Constants.sentFriendRequestsUIDs: FieldValue.arrayRemove([_uid]),
    });

    // remove friend uid from our friend requests sent list
    await _firestore.collection(Constants.users).doc(_uid).update({
      Constants.friendRequestsUIDs: FieldValue.arrayRemove([friendID]),
    });
  }

  // remove friend
  Future<void> removeFriend({required String friendID}) async {
    // remove our uid from friends list
    await _firestore.collection(Constants.users).doc(friendID).update({
      Constants.friendsUIDs: FieldValue.arrayRemove([_uid]),
    });

    // remove friend uid from our friends list
    await _firestore.collection(Constants.users).doc(_uid).update({
      Constants.friendsUIDs: FieldValue.arrayRemove([friendID]),
    });
  }

  // get a list of friends
  Future<List<UserModel>> getFriendsList(
    String uid,
    List<String> groupMembersUIDs,
  ) async {
    List<UserModel> friendsList = [];

    DocumentSnapshot documentSnapshot =
        await _firestore.collection(Constants.users).doc(uid).get();

    List<dynamic> friendsUIDs = documentSnapshot.get(Constants.friendsUIDs);

    for (String friendUID in friendsUIDs) {
      // if groupMembersUIDs list is not empty and contains the friendUID we skip this friend
      if (groupMembersUIDs.isNotEmpty && groupMembersUIDs.contains(friendUID)) {
        continue;
      }
      DocumentSnapshot documentSnapshot =
          await _firestore.collection(Constants.users).doc(friendUID).get();
      UserModel friend =
          UserModel.fromMap(documentSnapshot.data() as Map<String, dynamic>);
      friendsList.add(friend);
    }

    return friendsList;
  }

  // get a list of friend requests
  Future<List<UserModel>> getFriendRequestsList({
    required String uid,
    required String groupId,
  }) async {
    List<UserModel> friendRequestsList = [];

    if (groupId.isNotEmpty) {
      DocumentSnapshot documentSnapshot =
          await _firestore.collection(Constants.groups).doc(groupId).get();

      List<dynamic> requestsUIDs =
          documentSnapshot.get(Constants.awaitingApprovalUIDs);

      for (String friendRequestUID in requestsUIDs) {
        DocumentSnapshot documentSnapshot = await _firestore
            .collection(Constants.users)
            .doc(friendRequestUID)
            .get();
        UserModel friendRequest =
            UserModel.fromMap(documentSnapshot.data() as Map<String, dynamic>);
        friendRequestsList.add(friendRequest);
      }

      return friendRequestsList;
    }

    DocumentSnapshot documentSnapshot =
        await _firestore.collection(Constants.users).doc(uid).get();

    List<dynamic> friendRequestsUIDs =
        documentSnapshot.get(Constants.friendRequestsUIDs);

    for (String friendRequestUID in friendRequestsUIDs) {
      DocumentSnapshot documentSnapshot = await _firestore
          .collection(Constants.users)
          .doc(friendRequestUID)
          .get();
      UserModel friendRequest =
          UserModel.fromMap(documentSnapshot.data() as Map<String, dynamic>);
      friendRequestsList.add(friendRequest);
    }

    return friendRequestsList;
  }

  Future logout() async {
    // Sign out Google so next login shows account chooser
    try {
      await GoogleSignIn().signOut();
      await GoogleSignIn().disconnect();
    } catch (_) {}
    await _auth.signOut();
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.clear();
    notifyListeners();
  }
}
