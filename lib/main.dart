
import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

const Color purple = Color(0xFF6C3CE8);
const Color darkPurple = Color(0xFF4820A8);
const String appName = 'سوق ال حمادي';
const String developerPhone = '9647880254887';

final FirebaseAuth auth = FirebaseAuth.instance;
final FirebaseFirestore db = FirebaseFirestore.instance;

const List<String> adCategories = [
  'سيارات',
  'قطع غيار',
  'عقارات',
  'موبايلات',
  'أجهزة إلكترونية',
  'أثاث',
  'ملابس',
  'أكلات',
  'سوق الجمعة',
  'أدوات ومعدات',
  'خدمات',
  'أخرى',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();
  runApp(const SouqApp());
}

class SouqApp extends StatelessWidget {
  const SouqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: appName,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          primary: purple,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F5FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE7E1F2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: purple, width: 1.5),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingPage();
        }
        if (snapshot.data == null) return const AuthPage();
        return const HomePage();
      },
    );
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: purple),
      ),
    );
  }
}

void message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text, textAlign: TextAlign.center),
      backgroundColor: darkPurple,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<void> openWhatsApp(String phone, String text) async {
  String number = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (number.startsWith('0')) {
    number = '964${number.substring(1)}';
  }
  if (!number.startsWith('964') && number.length == 10) {
    number = '964$number';
  }
  final uri = Uri.parse(
    'https://wa.me/$number?text=${Uri.encodeComponent(text)}',
  );
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool isLogin = true;
  bool loading = false;
  bool hidePassword = true;

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      message(context, 'أدخل البريد الإلكتروني وكلمة المرور');
      return;
    }
    if (!isLogin && name.text.trim().isEmpty) {
      message(context, 'أدخل اسمك');
      return;
    }

    setState(() => loading = true);
    try {
      if (isLogin) {
        await auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        final result = await auth.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
        await db.collection('users').doc(result.user!.uid).set({
          'name': name.text.trim(),
          'email': email.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'favorites': [],
        });
      }
    } on FirebaseAuthException catch (e) {
      message(context, e.message ?? 'تعذر إكمال العملية');
    } catch (e) {
      message(context, 'حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    if (email.text.trim().isEmpty) {
      message(context, 'اكتب بريدك الإلكتروني أولاً');
      return;
    }
    try {
      await auth.sendPasswordResetEmail(email: email.text.trim());
      if (mounted) message(context, 'تم إرسال رابط استعادة كلمة المرور');
    } catch (e) {
      if (mounted) message(context, 'تعذر إرسال رابط الاستعادة');
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [purple, darkPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 42,
                      backgroundColor: purple,
                      child: Icon(
                        Icons.storefront,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      appName,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: purple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(isLogin ? 'أهلاً بعودتك' : 'أنشئ حسابك الجديد'),
                    const SizedBox(height: 22),
                    if (!isLogin) ...[
                      TextField(
                        controller: name,
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => hidePassword = !hidePassword,
                          ),
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    if (isLogin)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: resetPassword,
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purple,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: loading ? null : submit,
                        child: loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(isLogin ? 'تسجيل الدخول' : 'إنشاء الحساب'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => isLogin = !isLogin),
                      child: Text(
                        isLogin
                            ? 'ليس لديك حساب؟ أنشئ حساباً'
                            : 'لديك حساب؟ سجل الدخول',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  String category = 'الكل';
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void openAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAdPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildMarket(),
      const MyAdsPage(),
      const FavoritesPage(),
      const AccountPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsPage(),
                ),
              );
            },
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: pages[tab],
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              onPressed: openAdd,
              icon: const Icon(Icons.add),
              label: const Text('أضف إعلان'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'السوق',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            label: 'إعلاناتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            label: 'المفضلة',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }

  Widget buildMarket() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'ابحث عن سلعة أو إعلان...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              'الكل',
              ...adCategories,
            ].map((item) {
              final selected = category == item;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(item),
                  selected: selected,
                  selectedColor: purple.withOpacity(.18),
                  onSelected: (_) => setState(() => category = item),
                ),
              );
            }).toList(),
          ),
        ),
        const HomeBannerAd(),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db
                .collection('ads')
                .where('status', isEqualTo: 'active')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('حدث خطأ بتحميل الإعلانات'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var docs = snapshot.data!.docs.toList();
              docs.sort((a, b) {
                final ad = a.data()['createdAt'] as Timestamp?;
                final bd = b.data()['createdAt'] as Timestamp?;
                return (bd?.millisecondsSinceEpoch ?? 0)
                    .compareTo(ad?.millisecondsSinceEpoch ?? 0);
              });

              final term = search.text.trim().toLowerCase();
              docs = docs.where((doc) {
                final data = doc.data();
                final matchesCategory =
                    category == 'الكل' || data['category'] == category;
                final title = (data['title'] ?? '').toString().toLowerCase();
                final desc =
                    (data['description'] ?? '').toString().toLowerCase();
                return matchesCategory &&
                    (term.isEmpty ||
                        title.contains(term) ||
                        desc.contains(term));
              }).toList();

              if (docs.isEmpty) {
                return const Center(child: Text('لا توجد إعلانات حالياً'));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: .68,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  return AdCard(
                    id: docs[index].id,
                    data: docs[index].data(),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class HomeBannerAd extends StatefulWidget {
  const HomeBannerAd({super.key});

  @override
  State<HomeBannerAd> createState() => _HomeBannerAdState();
}

class _HomeBannerAdState extends State<HomeBannerAd> {
  BannerAd? banner;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    banner = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => ready = true);
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() {
    banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ready || banner == null) return const SizedBox(height: 4);
    return SizedBox(
      height: banner!.size.height.toDouble(),
      width: banner!.size.width.toDouble(),
      child: AdWidget(ad: banner!),
    );
  }
}

class AdCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;

  const AdCard({super.key, required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final image = (data['imageUrl'] ?? '').toString();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdDetailsPage(id: id, data: data),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFECE7F5),
                          child: Icon(
                            Icons.image,
                            size: 55,
                            color: purple,
                          ),
                        )
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFFECE7F5),
                            child: Icon(Icons.broken_image, color: purple),
                          ),
                        ),
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: purple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${data['category'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data['title'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${data['price'] ?? ''} د.ع',
                    style: const TextStyle(
                      color: purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data['sellerName'] ?? 'بائع'}',
                    maxLines: 1,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddAdPage extends StatefulWidget {
  const AddAdPage({super.key});

  @override
  State<AddAdPage> createState() => _AddAdPageState();
}

class _AddAdPageState extends State<AddAdPage> {
  final title = TextEditingController();
  final price = TextEditingController();
  final description = TextEditingController();
  final phone = TextEditingController();
  final picker = ImagePicker();

  String category = adCategories.first;
  File? image;
  bool loading = false;

  Future<void> chooseImage() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1400,
    );
    if (picked != null) setState(() => image = File(picked.path));
  }

  Future<String> uploadImage() async {
    if (image == null) return '';

    final user = auth.currentUser;
    if (user == null) {
      throw Exception('سجّل الدخول مرة ثانية قبل رفع الصورة');
    }

    const workerUrl =
        'https://souq-alhamadi-image-auth.zzailaz17.workers.dev';
    const imageKitUploadUrl = 'https://upload.imagekit.io/api/v1/files/upload';

    // 1) نطلب توقيع رفع مؤقت من Cloudflare Worker بعد التحقق من Firebase.
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('تعذر الحصول على رمز تسجيل الدخول');
    }

    final authResponse = await http
        .post(
          Uri.parse(workerUrl),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 30));

    Map<String, dynamic> authData;
    try {
      final decoded = jsonDecode(authResponse.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid response');
      }
      authData = decoded;
    } catch (_) {
      throw Exception(
        'رد Cloudflare غير مفهوم (${authResponse.statusCode}): ${authResponse.body}',
      );
    }

    if (authResponse.statusCode < 200 || authResponse.statusCode >= 300) {
      throw Exception(
        authData['error']?.toString() ??
            'فشل التحقق من صلاحية رفع الصورة (${authResponse.statusCode})',
      );
    }

    final token = authData['token']?.toString();
    final expire = authData['expire']?.toString();
    final signature = authData['signature']?.toString();
    final publicKey = authData['publicKey']?.toString() ??
        authData['public_key']?.toString();

    if ([token, expire, signature, publicKey]
        .any((value) => value == null || value.isEmpty)) {
      throw Exception('بيانات توقيع ImageKit ناقصة من Cloudflare Worker');
    }

    // 2) نرفع الصورة مباشرة إلى ImageKit باستخدام التوقيع المؤقت.
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg';
    final uploadRequest = http.MultipartRequest(
      'POST',
      Uri.parse(imageKitUploadUrl),
    );
    uploadRequest.fields.addAll({
      'fileName': fileName,
      'token': token!,
      'expire': expire!,
      'signature': signature!,
      'publicKey': publicKey!,
      'useUniqueFileName': 'true',
    });
    uploadRequest.files.add(
      await http.MultipartFile.fromPath('file', image!.path),
    );

    final streamedResponse = await uploadRequest
        .send()
        .timeout(const Duration(seconds: 90));
    final uploadResponse = await http.Response.fromStream(streamedResponse);

    Map<String, dynamic> uploadData;
    try {
      final decoded = jsonDecode(uploadResponse.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid response');
      }
      uploadData = decoded;
    } catch (_) {
      throw Exception(
        'رد ImageKit غير مفهوم (${uploadResponse.statusCode}): ${uploadResponse.body}',
      );
    }

    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw Exception(
        uploadData['message']?.toString() ??
            uploadData['error']?.toString() ??
            'فشل رفع الصورة إلى ImageKit (${uploadResponse.statusCode})',
      );
    }

    final imageUrl = uploadData['url']?.toString();
    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('ImageKit لم يرجع رابط الصورة');
    }

    return imageUrl;
  }

  Future<void> publishAd() async {
    if (title.text.trim().isEmpty ||
        price.text.trim().isEmpty ||
        phone.text.trim().isEmpty) {
      message(context, 'أكمل العنوان والسعر ورقم واتساب');
      return;
    }
    if (image == null) {
      message(context, 'اختَر صورة للإعلان');
      return;
    }

    setState(() => loading = true);
    try {
      final user = auth.currentUser!;
      final userDoc = await db.collection('users').doc(user.uid).get();
      final sellerName =
          userDoc.data()?['name'] ?? user.email ?? 'مستخدم';

      final imageUrl = await uploadImage();

      await db.collection('ads').add({
        'title': title.text.trim(),
        'price': price.text.trim(),
        'description': description.text.trim(),
        'category': category,
        'phone': phone.text.trim(),
        'imageUrl': imageUrl,
        'sellerId': user.uid,
        'sellerName': sellerName,
        'sellerEmail': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'views': 0,
      });

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 36,
                backgroundColor: purple,
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'تم بنجاح!',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: purple,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'تم نشر إعلانك في سوق ال حمادي',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('تم'),
                ),
              ),
            ],
          ),
        ),
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) message(context, 'فشل نشر الإعلان: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    title.dispose();
    price.dispose();
    description.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة إعلان جديد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: chooseImage,
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                color: const Color(0xFFECE7F5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: purple.withOpacity(.3)),
              ),
              child: image == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 45, color: purple),
                        SizedBox(height: 8),
                        Text('اضغط لاختيار صورة الإعلان'),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(image!, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'عنوان الإعلان'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'السعر بالدينار'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: category,
            decoration: const InputDecoration(labelText: 'القسم'),
            items: adCategories
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => category = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: description,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'تفاصيل الإعلان'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم واتساب البائع',
              hintText: '07xxxxxxxxx',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
              ),
              onPressed: loading ? null : publishAd,
              icon: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.publish),
              label: Text(loading ? 'جاري النشر...' : 'نشر الإعلان'),
            ),
          ),
        ],
      ),
    );
  }
}

class AdDetailsPage extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;

  const AdDetailsPage({
    super.key,
    required this.id,
    required this.data,
  });

  @override
  State<AdDetailsPage> createState() => _AdDetailsPageState();
}

class _AdDetailsPageState extends State<AdDetailsPage> {
  bool favorite = false;
  bool checkedFavorite = false;

  @override
  void initState() {
    super.initState();
    checkFavorite();
    addView();
  }

  Future<void> checkFavorite() async {
    final user = auth.currentUser;
    if (user == null) return;
    final doc = await db
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(widget.id)
        .get();
    if (mounted) {
      setState(() {
        favorite = doc.exists;
        checkedFavorite = true;
      });
    }
  }

  Future<void> addView() async {
    try {
      await db.collection('ads').doc(widget.id).update({
        'views': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  Future<void> toggleFavorite() async {
    final user = auth.currentUser!;
    final ref = db
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(widget.id);

    if (favorite) {
      await ref.delete();
    } else {
      await ref.set({
        'adId': widget.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (mounted) setState(() => favorite = !favorite);
  }

  Future<void> deleteAd() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الإعلان'),
        content: const Text('هل تريد حذف هذا الإعلان نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await db.collection('ads').doc(widget.id).delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) message(context, 'تعذر حذف الإعلان: $e');
    }
  }

  Future<void> changeStatus(String status) async {
    try {
      await db.collection('ads').doc(widget.id).update({'status': status});
      if (mounted) {
        message(context, status == 'sold' ? 'تم تحديد الإعلان كمباع' : 'تم تفعيل الإعلان');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) message(context, 'تعذر تحديث الإعلان');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final owner = auth.currentUser?.uid == data['sellerId'];
    final image = (data['imageUrl'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الإعلان'),
        actions: [
          if (!owner)
            IconButton(
              onPressed: checkedFavorite ? toggleFavorite : null,
              icon: Icon(
                favorite ? Icons.favorite : Icons.favorite_border,
                color: favorite ? Colors.redAccent : Colors.white,
              ),
            ),
          if (owner)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') deleteAd();
                if (value == 'sold') changeStatus('sold');
                if (value == 'active') changeStatus('active');
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'sold', child: Text('تحديد كمباع')),
                PopupMenuItem(value: 'active', child: Text('إعادة تفعيل الإعلان')),
                PopupMenuItem(value: 'delete', child: Text('حذف الإعلان')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: image.isEmpty
                ? Container(
                    height: 250,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image, size: 70),
                  )
                : Image.network(
                    image,
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(height: 18),
          Text(
            '${data['title'] ?? ''}',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${data['price'] ?? ''} د.ع',
            style: const TextStyle(
              color: purple,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 28),
          infoRow(Icons.category, 'القسم', '${data['category'] ?? ''}'),
          infoRow(Icons.person, 'البائع', '${data['sellerName'] ?? ''}'),
          infoRow(Icons.visibility, 'المشاهدات', '${data['views'] ?? 0}'),
          const SizedBox(height: 14),
          const Text(
            'وصف الإعلان',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            (data['description'] ?? 'لا يوجد وصف').toString(),
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 24),
          if (!owner)
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20B85A),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => openWhatsApp(
                  '${data['phone'] ?? ''}',
                  'السلام عليكم، أتواصل معك بخصوص إعلانك: ${data['title'] ?? ''}',
                ),
                icon: const Icon(Icons.chat),
                label: const Text('تواصل مع البائع عبر واتساب'),
              ),
            ),
        ],
      ),
    );
  }

  Widget infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: purple),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class MyAdsPage extends StatelessWidget {
  const MyAdsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser!.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('ads').where('sellerId', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('لم تنشر أي إعلان بعد'));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return Card(
              child: ListTile(
                leading: data['imageUrl'] == null
                    ? const Icon(Icons.image)
                    : Image.network(
                        data['imageUrl'],
                        width: 55,
                        height: 55,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image),
                      ),
                title: Text('${data['title'] ?? ''}'),
                subtitle: Text(
                  '${data['price'] ?? ''} د.ع • ${data['status'] == 'sold' ? 'مباع' : 'نشط'}',
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdDetailsPage(id: doc.id, data: data),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser!.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('قائمة المفضلة فارغة'));
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final id = docs[index].id;
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: db.collection('ads').doc(id).get(),
              builder: (context, adSnapshot) {
                if (!adSnapshot.hasData || !adSnapshot.data!.exists) {
                  return const SizedBox.shrink();
                }
                final data = adSnapshot.data!.data()!;
                return AdCard(id: id, data: data);
              },
            );
          },
        );
      },
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser!;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SizedBox(height: 20),
        const CircleAvatar(
          radius: 48,
          backgroundColor: purple,
          child: Icon(Icons.person, size: 55, color: Colors.white),
        ),
        const SizedBox(height: 15),
        Text(
          user.email ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const SizedBox(height: 25),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.support_agent, color: purple),
                title: const Text('الدعم والشكاوى'),
                subtitle: const Text('تواصل مع إدارة سوق ال حمادي'),
                onTap: () => openWhatsApp(
                  developerPhone,
                  'السلام عليكم، أحتاج مساعدة في تطبيق سوق ال حمادي',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline, color: purple),
                title: const Text('عن التطبيق'),
                subtitle: const Text('سوق ال حمادي'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('تسجيل الخروج'),
                onTap: () async {
                  await auth.signOut();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'تطوير وإدارة: علاوي ال حمادي',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 65, color: purple),
            SizedBox(height: 12),
            Text('لا توجد إشعارات حالياً'),
          ],
        ),
      ),
    );
  }
}