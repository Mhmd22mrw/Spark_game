import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Directionality(textDirection: TextDirection.rtl, child: VaultApp()),
));

class VaultApp extends StatefulWidget {
  const VaultApp({super.key});
  @override
  State<VaultApp> createState() => _VaultAppState();
}

class _VaultAppState extends State<VaultApp> {
  String savedPin = '', myEmail = '', pin = '', search = '';
  List<Map<String, dynamic>> items = [];
  final Set<int> shown = {};
  bool unlocked = false, loading = true;

  File get _file {
    final d = Directory(Directory.systemTemp.path.replaceAll('/cache', '/files'));
    return File('${d.existsSync() ? d.path : Directory.systemTemp.path}/v_data.json');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (await _file.exists()) {
        final d = jsonDecode(utf8.decode(base64Decode(await _file.readAsString())));
        savedPin = d['pin'] ?? '';
        myEmail = d['email'] ?? '';
        items = List<Map<String, dynamic>>.from(d['items'] ?? []);
      }
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _save() async {
    final s = base64Encode(utf8.encode(jsonEncode({'pin': savedPin, 'email': myEmail, 'items': items})));
    await _file.writeAsString(s);
  }

  void _copy(String t, String label) {
    Clipboard.setData(ClipboardData(text: t));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم نسخ $label'), duration: const Duration(seconds: 1)));
  }

  String _gen() {
    const c = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%&*';
    final r = Random();
    return List.generate(12, (_) => c[r.nextInt(c.length)]).join();
  }

  void _edit({int? idx}) {
    final it = idx != null ? items[idx] : null;
    final tC = TextEditingController(text: it?['t'] ?? '');
    final uC = TextEditingController(text: it?['u'] ?? myEmail);
    final pC = TextEditingController(text: it?['p'] ?? '');
    showDialog(context: context, builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(it == null ? '➕ إضافة حساب جديد' : '✏️ تعديل الحساب', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: tC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'اسم الحساب (جيميل، فيسبوك...)')),
            TextField(controller: uC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'الإيميل أو اسم المستخدم')),
            Row(children: [
              Expanded(child: TextField(controller: pC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'كلمة المرور'))),
              IconButton(icon: const Icon(Icons.auto_fix_high, color: Colors.amber), onPressed: () => pC.text = _gen()),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () {
            if (tC.text.isEmpty) return;
            setState(() {
              if (uC.text.contains('@') && myEmail.isEmpty) myEmail = uC.text.trim();
              final m = {'t': tC.text.trim(), 'u': uC.text.trim(), 'p': pC.text.trim()};
              idx == null ? items.insert(0, m) : items[idx] = m;
            });
            _save(); Navigator.pop(ctx);
          }, child: const Text('حفظ 🔒')),
        ],
      ),
    ));
  }

  void _setEmail() {
    final c = TextEditingController(text: myEmail);
    showDialog(context: context, builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('📧 إيميلي الشخصي الموحد', style: TextStyle(color: Colors.white)),
        content: TextField(controller: c, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'example@gmail.com')),
        actions: [
          ElevatedButton(onPressed: () { setState(() => myEmail = c.text.trim()); _save(); Navigator.pop(ctx); }, child: const Text('حفظ')),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator()));
    if (!unlocked) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_person, size: 70, color: Colors.tealAccent),
            const SizedBox(height: 12),
            Text(savedPin.isEmpty ? 'اختر 4 أرقام لقفل خزنتك' : 'أدخل الرقم السري: $pin', style: const TextStyle(color: Colors.white, fontSize: 22)),
            const SizedBox(height: 24),
            Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
              for (var i = 1; i <= 9; i++) _btn('$i'),
              _btn('0'),
              ElevatedButton(onPressed: () => setState(() => pin = ''), child: const Text('مسح')),
            ]),
          ]),
        ),
      );
    }
    final list = items.where((e) => e['t'].toString().contains(search) || e['u'].toString().contains(search)).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('خزنتي الشخصية 🔐', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.email, color: Colors.tealAccent), onPressed: _setEmail),
          IconButton(icon: const Icon(Icons.lock, color: Colors.amber), onPressed: () => setState(() { unlocked = false; pin = ''; })),
        ],
      ),
      body: Column(children: [
        ListTile(
          tileColor: Colors.teal.withOpacity(0.2),
          title: Text(myEmail.isEmpty ? 'اضغط هنا لحفظ إيميلك الشخصي الرئيسي' : 'إيميلي: $myEmail', style: const TextStyle(color: Colors.tealAccent, fontSize: 14)),
          trailing: myEmail.isEmpty ? null : IconButton(icon: const Icon(Icons.copy, color: Colors.tealAccent), onPressed: () => _copy(myEmail, 'الإيميل')),
          onTap: _setEmail,
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(onChanged: (v) => setState(() => search = v), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'ابحث عن حساب...', hintStyle: TextStyle(color: Colors.white54), prefixIcon: Icon(Icons.search, color: Colors.white54))),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (c, i) {
              final it = list[i];
              final vis = shown.contains(i);
              return Card(
                color: const Color(0xFF1E293B), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(it['t'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('👤 ${it['u']}', style: const TextStyle(color: Colors.cyanAccent))),
                      IconButton(icon: const Icon(Icons.copy, size: 18, color: Colors.cyanAccent), onPressed: () => _copy(it['u'], 'الإيميل')),
                    ]),
                    Row(children: [
                      Expanded(child: Text('🔑 ${vis ? it['p'] : "••••••••"}', style: const TextStyle(color: Colors.amberAccent))),
                      IconButton(icon: Icon(vis ? Icons.visibility_off : Icons.visibility, size: 18, color: Colors.white70), onPressed: () => setState(() => vis ? shown.remove(i) : shown.add(i))),
                      IconButton(icon: const Icon(Icons.copy, size: 18, color: Colors.tealAccent), onPressed: () => _copy(it['p'], 'كلمة المرور')),
                    ]),
                  ]),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () { setState(() => items.remove(it)); _save(); }),
                  onTap: () => _edit(idx: items.indexOf(it)),
                ),
              );
            },
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.tealAccent,
        onPressed: () => _edit(),
        label: const Text('إضافة حساب +', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _btn(String n) => ElevatedButton(
    onPressed: () {
      setState(() => pin += n);
      if (pin.length == 4) {
        if (savedPin.isEmpty) {
          savedPin = pin;
          items.add({'t': 'إيميلي الشخصي الرئيسي', 'u': 'اضغط هنا لتعديل إيميلك', 'p': '123456'});
          _save();
          setState(() => unlocked = true);
        } else if (pin == savedPin) {
          setState(() => unlocked = true);
        } else {
          setState(() => pin = '');
        }
      }
    },
    child: Text(n, style: const TextStyle(fontSize: 20)),
  );
}
// END_OF_CODE
 
