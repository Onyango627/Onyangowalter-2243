import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/customer.dart';
import '../models/product.dart';
import '../models/sale.dart';

class CartLine {
  final Product product;
  final int qty;
  const CartLine(this.product, this.qty);
}

/// Single source of truth for the app. Everything is persisted locally in
/// SharedPreferences, so the app keeps working with no internet connection.
class AppState extends ChangeNotifier {
  SharedPreferences? _prefs;
  StreamSubscription? _connSub;
  Future<void> _cloudWrite = Future<void>.value();
  String? cloudSyncError;

  // ---- data ----
  List<Product> products = [];
  List<Customer> customers = [];
  List<Sale> sales = [];

  // ---- current sale ----
  final Map<String, int> cart = {};
  Customer? selectedCustomer; // null = walk-in customer
  String paymentMethod = 'Cash';

  // ---- business / account ----
  String businessName = 'My Store';
  String businessType = 'Retail Store';
  String ownerName = 'Business Owner';
  String account = 'owner@business.com';
  int themeColor = 0xFF1E6FE0;
  double taxRate = 0.18;
  int defaultReorder = 20;
  Map<String, bool> enabledMethods = {
    'Cash': true,
    'Card': true,
    'Mobile Money': true,
    'Bank Transfer': true,
  };

  // ---- session / connectivity ----
  bool loggedIn = false;
  String? authError;
  bool forceOffline = false;
  bool networkOnline = true;

  bool get isOnline => networkOnline && !forceOffline;
  Color get primary => Color(themeColor);

  // Load / save

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;

    final pj = p.getString('products');
    if (pj == null) {
      _seed();
    } else {
      products = (jsonDecode(pj) as List)
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      customers = (jsonDecode(p.getString('customers') ?? '[]') as List)
          .map((e) => Customer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      sales = (jsonDecode(p.getString('sales') ?? '[]') as List)
          .map((e) => Sale.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    businessName = p.getString('businessName') ?? businessName;
    businessType = p.getString('businessType') ?? businessType;
    ownerName = p.getString('ownerName') ?? ownerName;
    account = p.getString('account') ?? account;
    themeColor = p.getInt('themeColor') ?? themeColor;
    taxRate = p.getDouble('taxRate') ?? taxRate;
    defaultReorder = p.getInt('defaultReorder') ?? defaultReorder;
    final offlineSessionEmail = p.getString('offlineSessionEmail');
    final offlineAccount = offlineSessionEmail == null
        ? null
        : _offlineAccounts()[offlineSessionEmail];
    loggedIn =
        FirebaseAuth.instance.currentUser != null ||
        (offlineSessionEmail != null && offlineAccount != null);
    if (FirebaseAuth.instance.currentUser == null && offlineAccount != null) {
      account = offlineSessionEmail!;
      ownerName = offlineAccount['name'] as String? ?? account;
    }
    final em = p.getString('enabledMethods');
    if (em != null) {
      enabledMethods = Map<String, bool>.from(jsonDecode(em) as Map);
    }

    // Watch connectivity; when we come back online, mark offline sales synced.
    final first = await Connectivity().checkConnectivity();
    networkOnline = !first.contains(ConnectivityResult.none);
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      networkOnline = !results.contains(ConnectivityResult.none);
      if (isOnline) {
        _syncPending();
        _queueCloudSave();
      }
      notifyListeners();
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (_prefs?.getBool('cloudSyncPending') == true) {
        _queueCloudSave();
        await _cloudWrite;
      } else {
        await _restoreCloudData(user);
      }
    }
  }

  void _seed() {
    products = [
      Product(
        id: 'p1',
        name: 'Coca Cola 500ml',
        price: 2500,
        stock: 50,
        reorder: 20,
        category: 'Beverages',
      ),
      Product(
        id: 'p2',
        name: 'Sprite 500ml',
        price: 2500,
        stock: 40,
        reorder: 20,
        category: 'Beverages',
      ),
      Product(
        id: 'p3',
        name: 'Water 500ml',
        price: 1500,
        stock: 100,
        reorder: 30,
        category: 'Beverages',
      ),
      Product(
        id: 'p4',
        name: 'Bread',
        price: 3000,
        stock: 30,
        reorder: 10,
        category: 'Groceries',
      ),
      Product(
        id: 'p5',
        name: 'Chips',
        price: 2000,
        stock: 45,
        reorder: 15,
        category: 'Snacks',
      ),
    ];
    customers = [
      Customer(id: 'c1', name: 'John Mwangi', phone: '+256 700 123 456'),
      Customer(id: 'c2', name: 'Sarah Nakato', phone: '+256 782 987 654'),
      Customer(id: 'c3', name: 'David Kato', phone: '+256 703 456 789'),
      Customer(id: 'c4', name: 'Aisha Namuindwa', phone: '+256 751 234 567'),
      Customer(id: 'c5', name: 'Peter Ssemanda', phone: '+256 787 654 321'),
    ];
    // A little history so the reports screen has something to show.
    final now = DateTime.now();
    const methods = ['Cash', 'Card', 'Mobile Money'];
    for (var d = 9; d >= 0; d--) {
      final p = products[d % products.length];
      final qty = 8 + (d * 7) % 15;
      final sub = p.price * qty;
      sales.add(
        Sale(
          id: 'seed$d',
          date: DateTime(
            now.year,
            now.month,
            now.day,
            10,
            15,
          ).subtract(Duration(days: d)),
          items: [
            SaleItem(productId: p.id, name: p.name, price: p.price, qty: qty),
          ],
          customer: 'Walk-in Customer',
          method: methods[d % 3],
          subtotal: sub,
          tax: sub * taxRate,
          total: sub * (1 + taxRate),
        ),
      );
    }
    _save();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(
      'products',
      jsonEncode(products.map((e) => e.toJson()).toList()),
    );
    await p.setString(
      'customers',
      jsonEncode(customers.map((e) => e.toJson()).toList()),
    );
    await p.setString(
      'sales',
      jsonEncode(sales.map((e) => e.toJson()).toList()),
    );
    await p.setString('businessName', businessName);
    await p.setString('businessType', businessType);
    await p.setString('ownerName', ownerName);
    await p.setString('account', account);
    await p.setInt('themeColor', themeColor);
    await p.setDouble('taxRate', taxRate);
    await p.setInt('defaultReorder', defaultReorder);
    await p.setBool('loggedIn', loggedIn);
    await p.setString('enabledMethods', jsonEncode(enabledMethods));
    _queueCloudSave();
  }

  void _queueCloudSave() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!isOnline) {
      _prefs?.setBool('cloudSyncPending', true);
      return;
    }

    final snapshot = <String, dynamic>{
      'uid': user.uid,
      'email': user.email ?? account,
      'ownerName': ownerName,
      'businessName': businessName,
      'businessType': businessType,
      'themeColor': themeColor,
      'taxRate': taxRate,
      'defaultReorder': defaultReorder,
      'enabledMethods': enabledMethods,
      'products': products.map((item) => item.toJson()).toList(),
      'customers': customers.map((item) => item.toJson()).toList(),
      'sales': sales.map((item) => item.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    _cloudWrite = _cloudWrite
        .catchError((_) {})
        .then((_) => doc.set(snapshot, SetOptions(merge: true)))
        .then((_) {
          cloudSyncError = null;
          _prefs?.setBool('cloudSyncPending', false);
          notifyListeners();
        })
        .catchError((Object error) {
          _prefs?.setBool('cloudSyncPending', true);
          cloudSyncError =
              error is FirebaseException && error.code == 'permission-denied'
              ? 'Firebase data access is blocked. Deploy the Firestore rules in firestore.rules.'
              : 'Could not sync business data to Firebase. It remains saved on this device.';
          notifyListeners();
        });
  }

  Future<void> _restoreCloudData(User user) async {
    if (!isOnline) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data();
      if (data == null) return;

      final remoteProducts = data['products'];
      final remoteCustomers = data['customers'];
      final remoteSales = data['sales'];
      if (remoteProducts is List) {
        products = remoteProducts
            .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      if (remoteCustomers is List) {
        customers = remoteCustomers
            .map((e) => Customer.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      if (remoteSales is List) {
        sales = remoteSales
            .map((e) => Sale.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      businessName = data['businessName'] as String? ?? businessName;
      businessType = data['businessType'] as String? ?? businessType;
      ownerName = data['ownerName'] as String? ?? ownerName;
      themeColor = data['themeColor'] as int? ?? themeColor;
      taxRate = (data['taxRate'] as num?)?.toDouble() ?? taxRate;
      defaultReorder = data['defaultReorder'] as int? ?? defaultReorder;
      final remoteMethods = data['enabledMethods'];
      if (remoteMethods is Map) {
        enabledMethods = Map<String, bool>.from(remoteMethods);
      }
      await _saveLocally();
      cloudSyncError = null;
    } on FirebaseException catch (e) {
      cloudSyncError = e.code == 'permission-denied'
          ? 'Firebase data access is blocked. Deploy the Firestore rules in firestore.rules.'
          : 'Could not load business data from Firebase.';
    } catch (_) {
      cloudSyncError = 'Could not load saved business data from Firebase.';
    }
  }

  Future<void> _saveLocally() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(
      'products',
      jsonEncode(products.map((e) => e.toJson()).toList()),
    );
    await p.setString(
      'customers',
      jsonEncode(customers.map((e) => e.toJson()).toList()),
    );
    await p.setString(
      'sales',
      jsonEncode(sales.map((e) => e.toJson()).toList()),
    );
    await p.setString('businessName', businessName);
    await p.setString('businessType', businessType);
    await p.setString('ownerName', ownerName);
    await p.setString('account', account);
    await p.setInt('themeColor', themeColor);
    await p.setDouble('taxRate', taxRate);
    await p.setInt('defaultReorder', defaultReorder);
    await p.setString('enabledMethods', jsonEncode(enabledMethods));
  }

  void _syncPending() {
    // Placeholder for uploading to a backend: here we just flag as synced.
    var changed = false;
    for (final s in sales) {
      if (!s.synced) {
        s.synced = true;
        changed = true;
      }
    }
    if (changed) _save();
  }

  int get pendingSyncCount => sales.where((s) => !s.synced).length;

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  // Authentication
  static Future<void>? _googleSignInInitialization;

  Future<bool> login(
    String email,
    String password, {
    required bool remember,
  }) async {
    authError = null;
    final normalizedEmail = _normalizeEmail(email);
    final offlineAccount = _offlineAccounts()[normalizedEmail];
    if (!isOnline && offlineAccount != null) {
      if (_verifyOfflinePassword(offlineAccount, password)) {
        await _setOfflineUser(normalizedEmail, offlineAccount);
        return true;
      }
      authError = 'Email or password is incorrect.';
      notifyListeners();
      return false;
    }
    try {
      authError = null;
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      await _prefs?.remove('offlineSessionEmail');
      await _setAuthenticatedUser(credential.user);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' &&
          offlineAccount != null &&
          _verifyOfflinePassword(offlineAccount, password)) {
        try {
          final credential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: normalizedEmail,
                password: password,
              );
          await credential.user?.updateDisplayName(
            offlineAccount['name'] as String? ?? normalizedEmail,
          );
          await _prefs?.remove('offlineSessionEmail');
          await _setAuthenticatedUser(
            credential.user,
            fallbackName: offlineAccount['name'] as String? ?? normalizedEmail,
          );
          return true;
        } on FirebaseAuthException catch (promotionError) {
          if (promotionError.code == 'network-request-failed') {
            await _setOfflineUser(normalizedEmail, offlineAccount);
            return true;
          }
          authError = _authMessage(promotionError.code);
          notifyListeners();
          return false;
        }
      }
      if ((e.code == 'network-request-failed' || e.code == 'user-not-found') &&
          offlineAccount != null &&
          _verifyOfflinePassword(offlineAccount, password)) {
        await _setOfflineUser(normalizedEmail, offlineAccount);
        return true;
      }
      authError = _authMessage(e.code);
      notifyListeners();
      return false;
    } catch (_) {
      authError = 'Could not connect to authentication. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    final normalizedEmail = _normalizeEmail(email);
    if (!isOnline) {
      final created = await _createOfflineAccount(
        name.trim(),
        normalizedEmail,
        password,
      );
      if (!created) return false;
      await _setOfflineUser(
        normalizedEmail,
        _offlineAccounts()[normalizedEmail]!,
      );
      return true;
    }
    try {
      authError = null;
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
      try {
        await credential.user?.updateDisplayName(name.trim());
      } catch (_) {
        // Account creation succeeds even if the display name update fails.
      }
      await _prefs?.remove('offlineSessionEmail');
      await _setAuthenticatedUser(credential.user, fallbackName: name.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        final created = await _createOfflineAccount(
          name.trim(),
          normalizedEmail,
          password,
        );
        if (!created) return false;
        await _setOfflineUser(
          normalizedEmail,
          _offlineAccounts()[normalizedEmail]!,
        );
        return true;
      }
      authError = _authMessage(e.code);
      notifyListeners();
      return false;
    } catch (_) {
      authError = 'Could not connect to authentication. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      authError = null;
      if (kIsWeb) {
        final credential = await FirebaseAuth.instance.signInWithPopup(
          GoogleAuthProvider(),
        );
        await _prefs?.remove('offlineSessionEmail');
        await _setAuthenticatedUser(credential.user);
        return true;
      }

      _googleSignInInitialization ??= GoogleSignIn.instance.initialize();
      await _googleSignInInitialization;
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        authError = 'Google sign-in did not return an ID token.';
        notifyListeners();
        return false;
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      await _prefs?.remove('offlineSessionEmail');
      await _setAuthenticatedUser(result.user);
      return true;
    } on FirebaseAuthException catch (e) {
      authError = _authMessage(e.code);
      notifyListeners();
      return false;
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        authError = e.description ?? 'Google sign-in failed (${e.code.name}).';
      }
      notifyListeners();
      return false;
    } catch (_) {
      authError = 'Google sign-in failed. Check your connection and try again.';
      notifyListeners();
      return false;
    }
  }

  /// Sends Firebase's password reset email for an online email account.
  /// Offline-only accounts have no remote identity provider to recover through.
  Future<String?> sendPasswordResetEmail(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedEmail)) {
      return 'Enter a valid email address.';
    }
    if (_offlineAccounts().containsKey(normalizedEmail)) {
      return 'This account was created offline and is stored only on this device. It has no email password reset option.';
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: normalizedEmail,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'invalid-email' => 'Enter a valid email address.',
        'user-not-found' => 'No account was found for that email address.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        'too-many-requests' =>
          'Too many attempts. Wait a moment and try again.',
        _ => 'Could not send the reset email. Please try again (${e.code}).',
      };
    } catch (_) {
      return 'Could not send the reset email. Check your connection and try again.';
    }
  }

  Future<void> _setAuthenticatedUser(User? user, {String? fallbackName}) async {
    if (user == null) return;
    loggedIn = true;
    account = user.email ?? account;
    ownerName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : fallbackName ?? account;
    if (_prefs?.getBool('cloudSyncPending') == true) {
      _queueCloudSave();
      await _cloudWrite;
    } else {
      await _restoreCloudData(user);
    }
    if (user.displayName?.trim().isNotEmpty != true &&
        fallbackName != null &&
        ownerName == account) {
      ownerName = fallbackName;
    }
    await _save();
    await _cloudWrite;
    notifyListeners();
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Map<String, Map<String, dynamic>> _offlineAccounts() {
    final raw = _prefs?.getString('offlineAccounts');
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (email, values) =>
            MapEntry(email, Map<String, dynamic>.from(values as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<bool> _createOfflineAccount(
    String name,
    String email,
    String password,
  ) async {
    authError = null;
    if (password.length < 6) {
      authError = 'Password must be at least 6 characters.';
      notifyListeners();
      return false;
    }
    final accounts = _offlineAccounts();
    if (accounts.containsKey(email)) {
      authError =
          'An offline account already exists for this email. Sign in instead.';
      notifyListeners();
      return false;
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    accounts[email] = {
      'name': name,
      'salt': base64Encode(salt),
      'passwordHash': _offlinePasswordHash(password, salt),
    };
    await _prefs?.setString('offlineAccounts', jsonEncode(accounts));
    return true;
  }

  bool _verifyOfflinePassword(Map<String, dynamic> account, String password) {
    try {
      final salt = base64Decode(account['salt'] as String);
      return _offlinePasswordHash(password, salt) == account['passwordHash'];
    } catch (_) {
      return false;
    }
  }

  String _offlinePasswordHash(String password, List<int> salt) {
    var digest = sha256.convert([...utf8.encode(password), ...salt]);
    for (var i = 1; i < 60000; i++) {
      digest = sha256.convert([...digest.bytes, ...salt]);
    }
    return digest.toString();
  }

  Future<void> _setOfflineUser(
    String email,
    Map<String, dynamic> offlineAccount,
  ) async {
    await _prefs?.setString('offlineSessionEmail', email);
    loggedIn = true;
    account = email;
    ownerName = offlineAccount['name'] as String? ?? email;
    authError = null;
    await _save();
    notifyListeners();
  }

  String _authMessage(String code) => switch (code) {
    'invalid-email' => 'Enter a valid email address.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'Email or password is incorrect.',
    'email-already-in-use' => 'An account already exists for this email.',
    'weak-password' => 'Choose a stronger password (at least 6 characters).',
    'operation-not-allowed' =>
      'Enable this sign-in method in Firebase Authentication.',
    'network-request-failed' => 'Check your internet connection and try again.',
    'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
    _ => 'Sign-in failed ($code).',
  };

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await _prefs?.remove('offlineSessionEmail');
    if (_googleSignInInitialization != null) {
      await GoogleSignIn.instance.signOut();
    }
    loggedIn = false;
    authError = null;
    cart.clear();
    _save();
    notifyListeners();
  }

  // Cart / sale

  List<CartLine> get cartLines {
    final out = <CartLine>[];
    cart.forEach((id, q) {
      final i = products.indexWhere((p) => p.id == id);
      if (i >= 0) out.add(CartLine(products[i], q));
    });
    return out;
  }

  int get cartCount => cart.values.fold(0, (a, b) => a + b);
  double get subtotal =>
      cartLines.fold(0.0, (a, l) => a + l.product.price * l.qty);
  double get tax => subtotal * taxRate;
  double get total => subtotal + tax;

  /// Returns false when there isn't enough stock.
  bool addToCart(Product p) {
    final cur = cart[p.id] ?? 0;
    if (cur + 1 > p.stock) return false;
    cart[p.id] = cur + 1;
    notifyListeners();
    return true;
  }

  void changeQty(Product p, int delta) {
    final next = (cart[p.id] ?? 0) + delta;
    if (next <= 0) {
      cart.remove(p.id);
    } else if (next <= p.stock) {
      cart[p.id] = next;
    }
    notifyListeners();
  }

  void setCustomer(Customer? c) {
    selectedCustomer = c;
    notifyListeners();
  }

  void setPaymentMethod(String m) {
    paymentMethod = m;
    notifyListeners();
  }

  Sale completeSale() {
    final lines = cartLines;
    final sale = Sale(
      id: 'S${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      items: lines
          .map(
            (l) => SaleItem(
              productId: l.product.id,
              name: l.product.name,
              price: l.product.price,
              qty: l.qty,
            ),
          )
          .toList(),
      customer: selectedCustomer?.name ?? 'Walk-in Customer',
      method: paymentMethod,
      subtotal: subtotal,
      tax: tax,
      total: total,
      synced: isOnline,
    );
    for (final l in lines) {
      l.product.stock -= l.qty;
    }
    sales.add(sale);
    cart.clear();
    selectedCustomer = null;
    _save();
    notifyListeners();
    return sale;
  }

  // Inventory / customers

  void addProduct(
    String name,
    double price,
    int stock,
    int reorder,
    String category,
  ) {
    products.add(
      Product(
        id: 'p${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        price: price,
        stock: stock,
        reorder: reorder,
        category: category,
      ),
    );
    _save();
    notifyListeners();
  }

  void updateStock(Product p, int stock, int reorder) {
    p.stock = stock;
    p.reorder = reorder;
    _save();
    notifyListeners();
  }

  void addCustomer(String name, String phone) {
    customers.add(
      Customer(
        id: 'c${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        phone: phone,
      ),
    );
    _save();
    notifyListeners();
  }

  double spentBy(Customer c) =>
      sales.where((s) => s.customer == c.name).fold(0.0, (a, s) => a + s.total);
  int visitsBy(Customer c) => sales.where((s) => s.customer == c.name).length;

  // Settings

  void updateBusiness({String? name, String? type, int? color}) {
    if (name != null) businessName = name;
    if (type != null) businessType = type;
    if (color != null) themeColor = color;
    _save();
    notifyListeners();
  }

  void setTaxRate(double r) {
    taxRate = r;
    _save();
    notifyListeners();
  }

  void setDefaultReorder(int n) {
    defaultReorder = n;
    _save();
    notifyListeners();
  }

  void toggleMethod(String m, bool on) {
    enabledMethods[m] = on;
    if (!on && paymentMethod == m) {
      paymentMethod = enabledMethods.entries
          .firstWhere(
            (e) => e.value,
            orElse: () => const MapEntry('Cash', true),
          )
          .key;
    }
    _save();
    notifyListeners();
  }

  void setForceOffline(bool v) {
    forceOffline = v;
    if (isOnline) _syncPending();
    notifyListeners();
  }

  Future<void> resetData() async {
    await FirebaseAuth.instance.signOut();
    if (_googleSignInInitialization != null) {
      await GoogleSignIn.instance.signOut();
    }
    await _prefs?.clear();
    cart.clear();
    sales = [];
    products = [];
    customers = [];
    businessName = 'My Store';
    loggedIn = false;
    _seed();
    notifyListeners();
  }

  // =====================================================================
  // Reports (computed live from the local sales list)
  // =====================================================================
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Sale> salesBetween(DateTime from, DateTime to) {
    final a = _day(from);
    final b = _day(to).add(const Duration(days: 1));
    return sales
        .where((s) => !s.date.isBefore(a) && s.date.isBefore(b))
        .toList();
  }

  double totalBetween(DateTime from, DateTime to) =>
      salesBetween(from, to).fold(0.0, (a, s) => a + s.total);

  List<double> dailyTotals(DateTime from, DateTime to) {
    final a = _day(from);
    final days = _day(to).difference(a).inDays + 1;
    final out = List<double>.filled(days < 1 ? 1 : days, 0);
    for (final s in salesBetween(from, to)) {
      final i = _day(s.date).difference(a).inDays;
      if (i >= 0 && i < out.length) out[i] += s.total;
    }
    return out;
  }

  Map<String, int> topProducts(DateTime from, DateTime to) {
    final m = <String, int>{};
    for (final s in salesBetween(from, to)) {
      for (final i in s.items) {
        m[i.name] = (m[i.name] ?? 0) + i.qty;
      }
    }
    final entries = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in entries) e.key: e.value};
  }

  Map<String, double> paymentBreakdown(DateTime from, DateTime to) {
    final m = <String, double>{};
    for (final s in salesBetween(from, to)) {
      m[s.method] = (m[s.method] ?? 0) + s.total;
    }
    return m;
  }

  double get todaySales {
    final n = DateTime.now();
    return totalBetween(n, n);
  }

  double get todayChangePercent {
    final n = DateTime.now();
    final y = n.subtract(const Duration(days: 1));
    final yt = totalBetween(y, y);
    if (yt == 0) return 0;
    return (todaySales - yt) / yt * 100;
  }

  List<Sale> get recentSales {
    final l = [...sales]..sort((a, b) => b.date.compareTo(a.date));
    return l.take(3).toList();
  }

  double get stockValue => products.fold(0.0, (a, p) => a + p.price * p.stock);
  List<Product> get lowStock => products.where((p) => p.isLow).toList();
}
