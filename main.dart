import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const PasswordVaultApp());
}

class PasswordVaultApp extends StatelessWidget {
  const PasswordVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'خزنتي الشخصية',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: Colors.tealAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.amberAccent,
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: LockScreen(),
      ),
    );
  }
}

// نموذج بيانات الحساب الشخصي
class PasswordItem {
  String id;
  String title;
  String username;
  String password;
  String notes;
  String category;

  PasswordItem({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.notes = '',
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'username': username,
        'password': password,
        'notes': notes,
        'category': category,
      };

  factory PasswordItem.fromJson(Map<String, dynamic> json) => PasswordItem(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        username: json['username'] ?? '',
        password: json['password'] ?? '',
        notes: json['notes'] ?? '',
        category: json['category'] ?? 'حسابات وإيميلات',
      );
}

// خدمة الحفظ المحلي والتشفير داخل الهاتف
class VaultStorage {
  static File get _file {
    final dir = Directory.systemTemp.path.replaceAll('/cache', '/files');
    final targetDir = Directory(dir);
    if (!targetDir.existsSync()) {
      return File('${Directory.systemTemp.path}/my_personal_vault.dat');
    }
    return File('${targetDir.path}/my_personal_vault.dat');
  }

  static String encryptData(String input) {
    final bytes = utf8.encode(input);
    final shifted = bytes.map((b) => b ^ 73).toList();
    return base64Encode(shifted);
  }

  static String decryptData(String input) {
    try {
      final shifted = base64Decode(input.trim());
      final bytes = shifted.map((b) => b ^ 73).toList();
      return utf8.decode(bytes);
    } catch (_) {
      return '';
    }
  }

  static Future<Map<String, dynamic>> loadVault() async {
    try {
      if (await _file.exists()) {
        final raw = await _file.readAsString();
        final decoded = decryptData(raw);
        if (decoded.isNotEmpty) {
          return jsonDecode(decoded) as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return {'pin': '', 'defaultEmail': '', 'items': []};
  }

  static Future<void> saveVault(
      String pin, String defaultEmail, List<PasswordItem> items) async {
    final data = {
      'pin': pin,
      'defaultEmail': defaultEmail,
      'items': items.map((e) => e.toJson()).toList(),
    };
    final encoded = encryptData(jsonEncode(data));
    await _file.writeAsString(encoded);
  }
}

// شاشة القفل بالرقم السري
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String savedPin = '';
  String defaultEmail = '';
  String enteredPin = '';
  List<PasswordItem> items = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final data = await VaultStorage.loadVault();
    final rawItems = (data['items'] as List?) ?? [];
    setState(() {
      savedPin = (data['pin'] ?? '').toString();
      defaultEmail = (data['defaultEmail'] ?? '').toString();
      items = rawItems
          .map((e) => PasswordItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      isLoading = false;
    });
  }

  void _onNumberPress(String num) {
    if (enteredPin.length < 4) {
      setState(() {
        enteredPin += num;
        errorMessage = '';
      });
      if (enteredPin.length == 4) {
        _verifyOrSetPin();
      }
    }
  }

  void _onBackspace() {
    if (enteredPin.isNotEmpty) {
      setState(() {
        enteredPin = enteredPin.substring(0, enteredPin.length - 1);
      });
    }
  }

  Future<void> _verifyOrSetPin() async {
    if (savedPin.isEmpty) {
      savedPin = enteredPin;
      // إضافة بطاقة ترحيبية جاهزة للإيميل الشخصي عند أول تشغيل
      items.add(
        PasswordItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'إيميلي الشخصي الرئيسي (Gmail)',
          username: 'اضغط على القلم ✏️ لكتابة إيميلك',
          password: 'اكتب كلمة المرور هنا',
          notes: 'الحساب الأساسي المرتبط بكل حساباتي',
          category: 'حسابات وإيميلات',
        ),
      );
      await VaultStorage.saveVault(savedPin, defaultEmail, items);
      _openVault();
    } else if (enteredPin == savedPin) {
      _openVault();
    } else {
      setState(() {
        enteredPin = '';
        errorMessage = 'الرقم السري غير صحيح!';
      });
    }
  }

  void _openVault() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: VaultHomeScreen(
            pin: savedPin,
            initialDefaultEmail: defaultEmail,
            initialItems: items,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isFirstTime = savedPin.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_rounded, size: 76, color: Colors.tealAccent),
              const SizedBox(height: 16),
              Text(
                isFirstTime ? 'إنشاء رقم سري لخزنتك' : 'أدخل الرقم السري للفتح',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isFirstTime
                    ? 'اختر 4 أرقام لحماية إيميلك وكلمات مرورك'
                    : 'جميع كلمات مرورك مشفرة ومحفوظة على هاتفك',
                style: const TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? Colors.tealAccent : Colors.transparent,
                      border: Border.all(color: Colors.tealAccent, width: 2),
                    ),
                  );
                }),
              ),
              if (errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: 280,
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 1; i <= 9; i++) _buildKeyButton('$i'),
                    const SizedBox.shrink(),
                    _buildKeyButton('0'),
                    IconButton(
                      onPressed: _onBackspace,
                      icon: const Icon(Icons.backspace_outlined, size: 28, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyButton(String num) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(16),
      ),
      onPressed: () => _onNumberPress(num),
      child: Text(
        num,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// الشاشة الرئيسية لإدارة الإيميلات وكلمات المرور
class VaultHomeScreen extends StatefulWidget {
  final String pin;
  final String initialDefaultEmail;
  final List<PasswordItem> initialItems;

  const VaultHomeScreen({
    super.key,
    required this.pin,
    required this.initialDefaultEmail,
    required this.initialItems,
  });

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen> {
  late List<PasswordItem> items;
  late String defaultEmail;
  String searchQuery = '';
  String selectedCategory = 'الكل';
  final Set<String> visiblePasswords = {};

  final List<String> categories = [
    'الكل',
    'حسابات وإيميلات',
    'تواصل اجتماعي',
    'بنوك ومحافظ',
    'شبكات Wi-Fi',
    'أخرى'
  ];

  @override
  void initState() {
    super.initState();
    items = List.from(widget.initialItems);
    defaultEmail = widget.initialDefaultEmail;
  }

  Future<void> _saveChanges() async {
    await VaultStorage.saveVault(widget.pin, defaultEmail, items);
  }

  String _generateStrongPassword({int length = 14}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%&*';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تم نسخ $label إلى الحافظة!'),
        backgroundColor: Colors.teal.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // نافذة تعيين الإيميل الشخصي الافتراضي للتعبئة السريعة
  void _showSetDefaultEmailDialog() {
    final emailCtrl = TextEditingController(text: defaultEmail);
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('📧 إيميلي الشخصي الموحّد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اكتب إيميلك الشخصي هنا لكي تتمكن من إدراجه بضغطة زر واحدة عند إضافة أي حساب جديد:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'example@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                setState(() {
                  defaultEmail = emailCtrl.text.trim();
                });
                _saveChanges();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ تم حفظ إيميلك الشخصي للتعبئة السريعة!')),
                );
              },
              child: const Text('حفظ الإيميل'),
            ),
          ],
        ),
      ),
    );
  }

  // نافذة النسخ الاحتياطي والاستعادة
  void _showBackupDialog() {
    final importCtrl = TextEditingController();
    final exportCode = VaultStorage.encryptData(jsonEncode({
      'pin': widget.pin,
      'defaultEmail': defaultEmail,
      'items': items.map((e) => e.toJson()).toList(),
    }));

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('🔄 نسخ احتياطي واستعادة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '1. تصدير كلمات مرورك (انسخ هذا الكود المشفر واحتفظ به في مكان آمن):',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    _copyToClipboard(exportCode, 'كود النسخة الاحتياطية المشفر');
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.copy_all),
                  label: const Text('نسخ الكود الاحتياطي المشفر'),
                ),
                const Divider(height: 28, color: Colors.white24),
                const Text(
                  '2. استعادة كلمات المرور (الصق الكود المشفر هنا لاسترجاع حساباتك):',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: importCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'الصق الكود المشفر هنا...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final raw = VaultStorage.decryptData(importCtrl.text);
                    if (raw.isNotEmpty) {
                      try {
                        final decoded = jsonDecode(raw) as Map<String, dynamic>;
                        final rawList = (decoded['items'] as List?) ?? [];
                        setState(() {
                          if ((decoded['defaultEmail'] ?? '').toString().isNotEmpty) {
                            defaultEmail = decoded['defaultEmail'].toString();
                          }
                          items = rawList
                              .map((e) => PasswordItem.fromJson(Map<String, dynamic>.from(e)))
                              .toList();
                        });
                        _saveChanges();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ تمت استعادة جميع كلمات المرور بنجاح!')),
                        );
                      } catch (_) {}
                    }
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('استعادة الحسابات الآن'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // نافذة إضافة أو تعديل حساب
  void _showAddOrEditDialog({PasswordItem? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final userCtrl = TextEditingController(
      text: existing?.username ?? (defaultEmail.isNotEmpty ? defaultEmail : ''),
    );
    final passCtrl = TextEditingController(text: existing?.password ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String category = existing?.category ?? 'حسابات وإيميلات';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existing == null ? '➕ إضافة حساب أو كلمة مرور جديدة' : '✏️ تعديل بيانات الحساب',
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'اسم الحساب (مثل: إيميلي الجيميل، فيسبوك، GitHub)',
                          prefixIcon: const Icon(Icons.label_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: userCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'الإيميل الشخصي أو اسم المستخدم أو الرقم',
                          prefixIcon: const Icon(Icons.alternate_email),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      if (defaultEmail.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ActionChip(
                            backgroundColor: Colors.teal.shade900,
                            avatar: const Icon(Icons.bolt, color: Colors.amberAccent, size: 18),
                            label: Text(
                              'إدراج إيميلي: $defaultEmail',
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                            ),
                            onPressed: () {
                              setModalState(() {
                                userCtrl.text = defaultEmail;
                              });
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: passCtrl,
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور الخاصة بالحساب',
                                prefixIcon: const Icon(Icons.key),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setModalState(() {
                                passCtrl.text = _generateStrongPassword();
                              });
                            },
                            icon: const Icon(Icons.auto_fix_high, size: 20),
                            label: const Text('توليد', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        decoration: InputDecoration(
                          labelText: 'ملاحظات إضافية (رقم مرتبط، رمز احتياطي - اختياري)',
                          prefixIcon: const Icon(Icons.notes),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: InputDecoration(
                          labelText: 'التصنيف',
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: categories
                            .where((c) => c != 'الكل')
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => category = val);
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (titleCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
                            return;
                          }
                          setState(() {
                            // إذا لم يكن هناك إيميل افتراضي محفوظ وكان المدخل يحتوي على @ نحفظه تلقائياً
                            if (defaultEmail.isEmpty && userCtrl.text.contains('@')) {
                              defaultEmail = userCtrl.text.trim();
                            }
                            if (existing == null) {
                              items.insert(
                                0,
                                PasswordItem(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  title: titleCtrl.text.trim(),
                                  username: userCtrl.text.trim(),
                                  password: passCtrl.text.trim(),
                                  notes: notesCtrl.text.trim(),
                                  category: category,
                                ),
                              );
                            } else {
                              existing.title = titleCtrl.text.trim();
                              existing.username = userCtrl.text.trim();
                              existing.password = passCtrl.text.trim();
                              existing.notes = notesCtrl.text.trim();
                              existing.category = category;
                            }
                          });
                          _saveChanges();
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'حفظ الحساب في الخزنة 🔒',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'حسابات وإيميلات':
        return Icons.mark_email_read_outlined;
      case 'تواصل اجتماعي':
        return Icons.public;
      case 'بنوك ومحافظ':
        return Icons.account_balance_wallet_outlined;
      case 'شبكات Wi-Fi':
        return Icons.wifi;
      default:
        return Icons.vpn_key_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = items.where((item) {
      final matchesCat = selectedCategory == 'الكل' || item.category == selectedCategory;
      final matchesSearch = item.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          item.username.toLowerCase().contains(searchQuery.toLowerCase()) ||
          item.notes.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.shield, color: Colors.tealAccent),
            SizedBox(width: 8),
            Text('خزنتي الشخصية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تعيين إيميلي الشخصي السريع',
            icon: const Icon(Icons.alternate_email, color: Colors.tealAccent),
            onPressed: _showSetDefaultEmailDialog,
          ),
          IconButton(
            tooltip: 'نسخ احتياطي واستعادة',
            icon: const Icon(Icons.cloud_sync_outlined, color: Colors.white),
            onPressed: _showBackupDialog,
          ),
          IconButton(
            tooltip: 'قفل الخزنة',
            icon: const Icon(Icons.lock_outline, color: Colors.amberAccent),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const Directionality(
                    textDirection: TextDirection.rtl,
                    child: LockScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط الإيميل الشخصي السريع في الأعلى
          InkWell(
            onTap: _showSetDefaultEmailDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.teal.withOpacity(0.15),
              child: Row(
                children: [
                  const Icon(Icons.email, size: 18, color: Colors.tealAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      defaultEmail.isEmpty
                          ? 'اضغط هنا لحفظ إيميلك الشخصي الرئيسي للتعبئة السريعة'
                          : 'إيميلي الشخصي: $defaultEmail',
                      style: const TextStyle(fontSize: 13, color: Colors.tealAccent),
                    ),
                  ),
                  if (defaultEmail.isNotEmpty)
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.copy, size: 18, color: Colors.tealAccent),
                      onPressed: () => _copyToClipboard(defaultEmail, 'إيميلك الشخصي'),
                    ),
                ],
              ),
            ),
          ),

          // شريط البحث
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: 'ابحث باسم الحساب، الإيميل، أو الملاحظات...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // شريط التصنيفات
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = cat == selectedCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: Colors.tealAccent,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) => setState(() => selectedCategory = cat),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // قائمة الحسابات وكلمات المرور
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_clock_outlined, size: 64, color: Colors.white30),
                        SizedBox(height: 12),
                        Text(
                          'لا توجد حسابات هنا بعد.\nاضغط على زر (إضافة حساب) بالأسفل لحفظ كلمات مرورك!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 85),
                    itemCount: filtered.length,
                    itemBuilder: (
