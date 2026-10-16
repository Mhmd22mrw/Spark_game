import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const VaultApp());

class VaultApp extends StatelessWidget {
  const VaultApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'خزنتي الشخصية',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.amberAccent,
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const Directionality(textDirection: TextDirection.rtl, child: LockPage()),
    );
  }
}

class PassItem {
  String id, title, user, pass, notes, cat;
  PassItem({required this.id, required this.title, required this.user, required this.pass, this.notes = '', this.cat = 'حسابات'});
  Map<String, dynamic> toJson() => {'id': id, 't': title, 'u': user, 'p': pass, 'n': notes, 'c': cat};
  factory PassItem.fromJson(Map<String, dynamic> j) => PassItem(
    id: j['id'] ?? '', title: j['t'] ?? '', user: j['u'] ?? '', pass: j['p'] ?? '', notes: j['n'] ?? '', cat: j['c'] ?? 'حسابات',
  );
}

class Storage {
  static File get _f {
    final d = Directory(Directory.systemTemp.path.replaceAll('/cache', '/files'));
    return File('${d.existsSync() ? d.path : Directory.systemTemp.path}/my_vault_v2.dat');
  }
  static String enc(String s) => base64Encode(utf8.encode(s).map((b) => b ^ 73).toList());
  static String dec(String s) {
    try { return utf8.decode(base64Decode(s.trim()).map((b) => b ^ 73).toList()); } catch (_) { return ''; }
  }
  static Future<Map<String, dynamic>> load() async {
    try {
      if (await _f.exists()) {
        final d = dec(await _f.readAsString());
        if (d.isNotEmpty) return jsonDecode(d);
      }
    } catch (_) {}
    return {'pin': '', 'email': '', 'items': []};
  }
  static Future<void> save(String pin, String email, List<PassItem> items) async {
    await _f.writeAsString(enc(jsonEncode({'pin': pin, 'email': email, 'items': items.map((e) => e.toJson()).toList()})));
  }
}

class LockPage extends StatefulWidget {
  const LockPage({super.key});
  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  String savedPin = '', email = '', pin = '', err = '';
  List<PassItem> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    Storage.load().then((d) {
      setState(() {
        savedPin = (d['pin'] ?? '').toString();
        email = (d['email'] ?? '').toString();
        items = ((d['items'] as List?) ?? []).map((e) => PassItem.fromJson(Map<String, dynamic>.from(e))).toList();
        loading = false;
      });
    });
  }

  void _press(String n) async {
    if (pin.length < 4) setState(() { pin += n; err = ''; });
    if (pin.length == 4) {
      if (savedPin.isEmpty) {
        savedPin = pin;
        items.add(PassItem(id: '1', title: 'إيميلي الشخصي الرئيسي', user: 'اضغط القلم ✏️ لكتابة إيميلك', pass: 'كلمة المرور', notes: 'الحساب الأساسي'));
        await Storage.save(savedPin, email, items);
        _go();
      } else if (pin == savedPin) {
        _go();
      } else {
        setState(() { pin = ''; err = 'الرقم السري غير صحيح!'; });
      }
    }
  }

  void _go() => Navigator.pushReplacement(context, MaterialPageRoute(
    builder: (_) => Directionality(textDirection: TextDirection.rtl, child: HomePage(pin: savedPin, initEmail: email, initItems: items)),
  ));

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_rounded, size: 70, color: Colors.tealAccent),
              const SizedBox(height: 12),
              Text(savedPin.isEmpty ? 'اختر 4 أرقام لقفل خزنتك' : 'أدخل الرقم السري للفتح', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8), width: 20, height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i < pin.length ? Colors.tealAccent : Colors.transparent, border: Border.all(color: Colors.tealAccent, width: 2)),
                )),
              ),
              if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err, style: const TextStyle(color: Colors.redAccent))),
              const SizedBox(height: 30),
              SizedBox(
                width: 260,
                child: GridView.count(
                  shrinkWrap: true, crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12,
                  children: [
                    for (var i = 1; i <= 9; i++) ElevatedButton(onPressed: () => _press('$i'), child: Text('$i', style: const TextStyle(fontSize: 22))),
                    const SizedBox.shrink(),
                    ElevatedButton(onPressed: () => _press('0'), child: const Text('0', style: TextStyle(fontSize: 22))),
                    IconButton(onPressed: () => setState(() { if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1); }), icon: const Icon(Icons.backspace_outlined)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final String pin, initEmail;
  final List<PassItem> initItems;
  const HomePage({super.key, required this.pin, required this.initEmail, required this.initItems});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late List<PassItem> items = List.from(widget.initItems);
  late String myEmail = widget.initEmail;
  String search = '';
  final Set<String> shown = {};

  void _save() => Storage.save(widget.pin, myEmail, items);

  void _copy(String txt, String msg) {
    Clipboard.setData(ClipboardData(text: txt));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم نسخ $msg'), duration: const Duration(seconds: 2)));
  }

  String _genPass() {
    const c = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%&*';
    final r = Random.secure();
    return List.generate(14, (_) => c[r.nextInt(c.length)]).join();
  }

  void _setEmailDialog() {
    final ctrl = TextEditingController(text: myEmail);
    showDialog(context: context, builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('📧 إيميلي الشخصي الموحّد'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'example@gmail.com', labelText: 'اكتب إيميلك للتعبئة السريعة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () { setState(() => myEmail = ctrl.text.trim()); _save(); Navigator.pop(ctx); }, child: const Text('حفظ')),
        ],
      ),
    ));
  }

  void _backupDialog() {
    final ctrl = TextEditingController();
    final code = Storage.enc(jsonEncode({'pin': widget.pin, 'email': myEmail, 'items': items.map((e) => e.toJson()).toList()}));
    showDialog(context: context, builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('🔄 نسخ احتياطي واستعادة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(onPressed: () { _copy(code, 'كود النسخة الاحتياطية'); Navigator.pop(ctx); }, icon: const Icon(Icons.copy), label: const Text('نسخ الكود الاحتياطي المشفر')),
            const Divider(height: 24),
            TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'الصق الكود المشفر هنا للاستعادة')),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () {
            try {
              final d = jsonDecode(Storage.dec(ctrl.text));
              setState(() {
                if ((d['email'] ?? '').toString().isNotEmpty) myEmail = d['email'];
                items = ((d['items'] as List?) ?? []).map((e) => PassItem.fromJson(Map<String, dynamic>.from(e))).toList();
              });
              _save(); Navigator.pop(ctx);
            } catch (_) {}
          }, child: const Text('استعادة الآن')),
        ],
      ),
    ));
  }

  void _editDialog({PassItem? item}) {
    final tCtrl = TextEditingController(text: item?.title ?? '');
    final uCtrl = TextEditingController(text: item?.user ?? myEmail);
    final pCtrl = TextEditingController(text: item?.pass ?? '');
    final nCtrl = TextEditingController(text: item?.notes ?? '');

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1E293B),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item == null ? '➕ إضافة حساب جديد' : '✏️ تعديل الحساب', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: tCtrl, decoration: const InputDecoration(labelText: 'اسم الموقع أو التطبيق (مثل: جيميل، فيسبوك)')),
                const SizedBox(height: 8),
                TextField(controller: uCtrl, decoration: const InputDecoration(labelText: 'الإيميل الشخصي أو اسم المستخدم')),
                if (myEmail.isNotEmpty) Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(onPressed: () => uCtrl.text = myEmail, icon: const Icon(Icons.bolt, size: 18), label: Text('وضع إيميلي: $myEmail')),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: pCtrl, decoration: const InputDecoration(labelText: 'كلمة المرور'))),
                  IconButton(tooltip: 'توليد كلمة مرور قوية', icon: const Icon(Icons.auto_fix_high, color: Colors.amberAccent), onPressed: () => pCtrl.text = _genPass()),
                ]),
                const SizedBox(height: 8),
                TextField(controller: nCtrl, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)')),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                  onPressed: () {
                    if (tCtrl.text.trim().isEmpty) return;
                    setState(() {
                      if (myEmail.isEmpty && uCtrl.text.contains('@')) myEmail = uCtrl.text.trim();
                      if (item == null) {
                        items.insert(0, PassItem(id: DateTime.now().millisecondsSinceEpoch.toString(), title: tCtrl.text.trim(), user: uCtrl.text.trim(), pass: pCtrl.text.trim(), notes: nCtrl.text.trim()));
                      } else {
                        item.title = tCtrl.text.trim(); item.user = uCtrl.text.trim(); item.pass = pCtrl.text.trim(); item.notes = nCtrl.text.trim();
                      }
                    });
                    _save(); Navigator.pop(ctx);
                  },
                  child: const Text('حفظ في الخزنة 🔒', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = items.where((e) => e.title.toLowerCase().contains(search.toLowerCase()) || e.user.toLowerCase().contains(search.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('خزنتي الشخصية 🔐'),
        actions: [
          IconButton(icon: const Icon(Icons.alternate_email, color: Colors.tealAccent), onPressed: _setEmailDialog),
          IconButton(icon: const Icon(Icons.cloud_sync_outlined), onPressed: _backupDialog),
          IconButton(icon: const Icon(Icons.lock_outline, color: Colors.amberAccent), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Directionality(textDirection: TextDirection.rtl, child: LockPage())))),
        ],
      ),
      body: Column(
        children: [
          InkWell(
            onTap: _setEmailDialog,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.teal.withOpacity(0.15),
              child: Row(children: [
                const Icon(Icons.email, size: 18, color: Colors.tealAccent), const SizedBox(width: 8),
                Expanded(child: Text(myEmail.isEmpty ? 'اضغط هنا لحفظ إيميلك الشخصي الرئيسي' : 'إيميلي الشخصي: $myEmail', style: const TextStyle(color: Colors.tealAccent, fontSize: 13))),
                if (myEmail.isNotEmpty) IconButton(constraints: const BoxConstraints(), padding: EdgeInsets.zero, icon: const Icon(Icons.copy, size: 18, color: Colors.tealAccent), onPressed: () => _copy(myEmail, 'إيميلك الشخصي')),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(onChanged: (v) => setState(() => search = v), decoration: InputDecoration(hintText: 'ابحث عن حساب أو إيميل...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final it = list[i];
                final vis = shown.contains(it.id);
                return Card(
                  color: const Color(0xFF1E293B), margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.vpn_key, color: Colors.tealAccent, size: 20), const SizedBox(width: 8),
                          Expanded(child: Text(it.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _editDialog(item: it)),
                          IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent), onPressed: () { setState(() => items.removeWhere((x) => x.id == it.id)); _save(); }),
                        ]),
                        if (it.user.isNotEmpty) Container(
                          margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            const Icon(Icons.person_outline, size: 16, color: Colors.cyanAccent), const SizedBox(width: 6),
                            Expanded(child: Text(it.user, style: const TextStyle(fontSize: 14))),
                            IconButton
