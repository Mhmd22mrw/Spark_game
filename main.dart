import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const platform = MethodChannel('vault_native_channel');

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

class PasswordItem {
  String id, title, username, password, notes, category;

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
    return {'pin': '', 'useBio': false, 'items': []};
  }

  static Future<void> saveVault(String pin, bool useBio, List<PasswordItem> items) async {
    final data = {
      'pin': pin,
      'useBio': useBio,
      'items': items.map((e) => e.toJson()).toList(),
    };
    await _file.writeAsString(encryptData(jsonEncode(data)));
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String savedPin = '', enteredPin = '', errorMessage = '';
  bool useBio = false, isLoading = true;
  List<PasswordItem> items = [];

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
      useBio = data['useBio'] == true;
      items = rawItems.map((e) => PasswordItem.fromJson(Map<String, dynamic>.from(e))).toList();
      isLoading = false;
    });
    if (savedPin.isNotEmpty && useBio) {
      _authenticateWithBio();
    }
  }

  Future<void> _authenticateWithBio() async {
    try {
      final bool ok = await platform.invokeMethod('authenticate');
      if (ok) _openVault();
    } catch (_) {}
  }

  void _onNumberPress(String num) {
    if (enteredPin.length < 4) {
      setState(() {
        enteredPin += num;
        errorMessage = '';
      });
      if (enteredPin.length == 4) _verifyOrSetPin();
    }
  }

  void _onBackspace() {
    if (enteredPin.isNotEmpty) {
      setState(() => enteredPin = enteredPin.substring(0, enteredPin.length - 1));
    }
  }

  Future<void> _verifyOrSetPin() async {
    if (savedPin.isEmpty) {
      savedPin = enteredPin;
      await VaultStorage.saveVault(savedPin, useBio, items);
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
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: VaultHomeScreen(pin: savedPin, initialUseBio: useBio, initialItems: items),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isFirstTime = savedPin.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_rounded, size: 72, color: Colors.tealAccent),
              const SizedBox(height: 16),
              Text(
                isFirstTime ? 'إنشاء رقم سري لخزنتك' : 'أدخل الرقم السري للفتح',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isFirstTime ? 'اختر 4 أرقام لحماية كلمات مرورك' : 'جميع كلمات مرورك مشفرة ومحفوظة على هاتفك',
                style: const TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
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
                const SizedBox(height: 14),
                Text(errorMessage, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 32),
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
                    useBio && !isFirstTime
                        ? IconButton(
                            tooltip: 'الدخول بالبصمة',
                            onPressed: _authenticateWithBio,
                            icon: const Icon(Icons.fingerprint, size: 38, color: Colors.tealAccent),
                          )
                        : const SizedBox.shrink(),
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
      child: Text(num, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }
}

class VaultHomeScreen extends StatefulWidget {
  final String pin;
  final bool initialUseBio;
  final List<PasswordItem> initialItems;

  const VaultHomeScreen({
    super.key,
    required this.pin,
    required this.initialUseBio,
    required this.initialItems,
  });

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen> {
  late List<PasswordItem> items;
  late String currentPin;
  late bool useBio;
  String searchQuery = '', selectedCategory = 'الكل';
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
    currentPin = widget.pin;
    useBio = widget.initialUseBio;
  }

  Future<void> _saveChanges() async {
    await VaultStorage.saveVault(currentPin, useBio, items);
  }

  String _generateStrongPassword({int length = 14}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%&*';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ تم نسخ $label إلى الحافظة!'),
      backgroundColor: Colors.teal.shade700,
      duration: const Duration(seconds: 2),
    ));
  }

  // مشاركة ملف الـ APK مباشرة عبر واتساب أو أي تطبيق
  Future<void> _shareApkFile() async {
    try {
      await platform.invokeMethod('shareApk');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري تجهيز ملف الـ APK للمشاركة...')),
      );
    }
  }

  // تفعيل أو إيقاف البصمة
  Future<void> _toggleBiometrics() async {
    if (!useBio) {
      try {
        final bool ok = await platform.invokeMethod('authenticate');
        if (ok) {
          setState(() => useBio = true);
          await _saveChanges();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ تم ربط بصمة الهاتف بالتطبيق بنجاح!'), backgroundColor: Colors.teal),
            );
          }
        }
      } catch (_) {}
    } else {
      setState(() => useBio = false);
      await _saveChanges();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إيقاف الدخول بالبصمة')),
        );
      }
    }
  }

  // نافذة تعديل كلمة مرور الدخول (الرقم السري للخزنة)
  void _showChangePinDialog() {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.password, color: Colors.amberAccent),
              SizedBox(width: 8),
              Text('تغيير رمز الدخول', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: TextField(
            controller: pinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: InputDecoration(
              labelText: 'أدخل الرقم السري الجديد (4 أرقام)',
              prefixIcon: const Icon(Icons.lock_reset),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
              onPressed: () {
                final newPin = pinCtrl.text.trim();
                if (newPin.length == 4 && int.tryParse(newPin) != null) {
                  setState(() => currentPin = newPin);
                  _saveChanges();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ تم تغيير الرقم السري للدخول بنجاح!'), backgroundColor: Colors.teal),
                  );
                }
              },
              child: const Text('حفظ الرمز الجديد', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupDialog() {
    final importCtrl = TextEditingController();
    final exportCode = VaultStorage.encryptData(jsonEncode({
      'pin': currentPin,
      'useBio': useBio,
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
                const Text('1. تصدير كلمات مرورك (انسخ الكود المشفر واحتفظ به):', style: TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                  onPressed: () {
                    _copyToClipboard(exportCode, 'كود النسخة الاحتياطية المشفر');
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.copy_all),
                  label: const Text('نسخ الكود الاحتياطي المشفر'),
                ),
                const Divider(height: 28, color: Colors.white24),
                const Text('2. استعادة كلمات المرور (الصق الكود المشفر هنا):', style: TextStyle(fontSize: 13, color: Colors.white70)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                  onPressed: () {
                    final raw = VaultStorage.decryptData(importCtrl.text);
                    if (raw.isNotEmpty) {
                      try {
                        final decoded = jsonDecode(raw) as Map<String, dynamic>;
                        final rawList = (decoded['items'] as List?) ?? [];
                        setState(() {
                          items = rawList.map((e) => PasswordItem.fromJson(Map<String, dynamic>.from(e))).toList();
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

  void _showAddOrEditDialog({PasswordItem? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final userCtrl = TextEditingController(text: existing?.username ?? '');
    final passCtrl = TextEditingController(text: existing?.password ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String category = existing?.category ?? 'حسابات وإيميلات';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
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
                      labelText: 'اسم الحساب (مثل: جيميل، فيسبوك، GitHub)',
                      prefixIcon: const Icon(Icons.label_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: userCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'الإيميل أو اسم المستخدم أو الرقم',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
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
                        onPressed: () => setModalState(() => passCtrl.text = _generateStrongPassword()),
                        icon: const Icon(Icons.auto_fix_high, size: 20),
                        label: const Text('توليد', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'ملاحظات إضافية (اختياري)',
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
                    items: categories.where((c) => c != 'الكل').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => category = val);
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
                      if (titleCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) return;
                      setState(() {
                        if (existing == null) {
                          items.insert(0, PasswordItem(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            title: titleCtrl.text.trim(),
                            username: userCtrl.text.trim(),
                            password: passCtrl.text.trim(),
                            notes: notesCtrl.text.trim(),
                            category: category,
                          ));
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
                    child: const Text('حفظ الحساب في الخزنة 🔒', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'حسابات وإيميلات': return Icons.mark_email_read_outlined;
      case 'تواصل اجتماعي': return Icons.public;
      case 'بنوك ومحافظ': return Icons.account_balance_wallet_outlined;
      case 'شبكات Wi-Fi': return Icons.wifi;
      default: return Icons.vpn_key_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = items.where((item) {
      final matchesCat = selectedCategory == 'الكل' || item.category == selectedCategory;
      final q = searchQuery.toLowerCase();
      final matchesSearch = item.title.toLowerCase().contains(q) || item.username.toLowerCase().contains(q) || item.notes.toLowerCase().contains(q);
      return matchesCat && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.shield, color: Colors.tealAccent, size: 22),
            SizedBox(width: 6),
            Text('خزنتي الشخصية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'إرسال تطبيق APK للأصدقاء',
            icon: const Icon(Icons.share, color: Colors.cyanAccent),
            onPressed: _shareApkFile,
          ),
          IconButton(
            tooltip: useBio ? 'البصمة مفعلة (اضغط للإيقاف)' : 'ربط بصمة الهاتف بالتطبيق',
            icon: Icon(Icons.fingerprint, color: useBio ? Colors.tealAccent : Colors.white54),
            onPressed: _toggleBiometrics,
          ),
          IconButton(
            tooltip: 'تغيير كلمة مرور الدخول',
            icon: const Icon(Icons.password, color: Colors.amberAccent),
            onPressed: _showChangePinDialog,
          ),
          IconButton(
            tooltip: 'نسخ احتياطي واستعادة',
            icon: const Icon(Icons.cloud_sync_outlined, color: Colors.white),
            onPressed: _showBackupDialog,
          ),
          IconButton(
            tooltip: 'قفل الخزنة',
            icon: const Icon(Icons.lock_outline, color: Colors.redAccent),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const Directionality(textDirection: TextDirection.rtl, child: LockScreen())),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: 'ابحث باسم الحساب، الإيميل، أو الملاحظات...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
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
                    labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                    onSelected: (_) => setState(() => selectedCategory = cat),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
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
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isVisible = visiblePasswords.contains(item.id);

                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.tealAccent.withOpacity(0.15),
                                    child: Icon(_getCategoryIcon(item.category), color: Colors.tealAccent),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                        Text(item.category, style: const TextStyle(color: Colors.tealAccent, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.white70),
                                    onPressed: () => _showAddOrEditDialog(existing: item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                    onPressed: () {
                                      setState(() => items.removeWhere((e) => e.id == item.id));
                                      _saveChanges();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (item.username.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 18, color: Colors.cyanAccent),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(item.username, style: const TextStyle(fontSize: 14, color: Colors.white))),
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                        icon: const Icon(Icons.copy, size: 18, color: Colors.cyanAccent),
                                        onPressed: () => _copyToClipboard(item.username, 'الإيميل / اسم المستخدم'),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.key, size: 18, color: Colors.amberAccent),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isVisible ? item.password : '••••••••••••',
                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 1.5, color: Colors.amberAccent),
                                      ),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(6),
                                      icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility, size: 19, color: Colors.white70),
                                      onPressed: () => setState(() => isVisible ? visiblePasswords.remove(item.id) : visiblePasswords.add(item.id)),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(6),
                                      icon: const Icon(Icons.copy, size: 19, color: Colors.tealAccent),
                                      onPressed: () => _copyToClipboard(item.password, 'كلمة المرور'),
                                    ),
                                  ],
                                ),
                              ),
                              if (item.notes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.notes, size: 15, color: Colors.white54),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(item.notes, style: const TextStyle(color: Colors.white60, fontSize: 12))),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        onPressed: () => _showAddOrEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة حساب / كلمة مرور', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
// END_OF_CODE
