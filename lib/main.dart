import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = NotificationService();
  await notifications.initialize();
  final store = SupplementStore(await SharedPreferences.getInstance());
  runApp(KkolttakApp(store: store, notifications: notifications));
}

class KkolttakApp extends StatelessWidget {
  const KkolttakApp({
    required this.store,
    required this.notifications,
    super.key,
  });

  final SupplementStore store;
  final NotificationService notifications;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KKOLTTAK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F8A70)),
        scaffoldBackgroundColor: const Color(0xFFF7F4EE),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: HomeScreen(store: store, notifications: notifications),
    );
  }
}

enum DoseMoment { morning, lunch, evening, night }

extension DoseMomentInfo on DoseMoment {
  String get label {
    return switch (this) {
      DoseMoment.morning => '아침',
      DoseMoment.lunch => '점심',
      DoseMoment.evening => '저녁',
      DoseMoment.night => '잠들기 전',
    };
  }

  TimeOfDay get defaultTime {
    return switch (this) {
      DoseMoment.morning => const TimeOfDay(hour: 8, minute: 0),
      DoseMoment.lunch => const TimeOfDay(hour: 12, minute: 30),
      DoseMoment.evening => const TimeOfDay(hour: 19, minute: 0),
      DoseMoment.night => const TimeOfDay(hour: 22, minute: 30),
    };
  }

  IconData get icon {
    return switch (this) {
      DoseMoment.morning => Icons.wb_sunny_outlined,
      DoseMoment.lunch => Icons.restaurant_outlined,
      DoseMoment.evening => Icons.nightlight_round,
      DoseMoment.night => Icons.bedtime_outlined,
    };
  }
}

class Supplement {
  Supplement({
    required this.id,
    required this.name,
    required this.dose,
    required this.moment,
    required this.stock,
    required this.reorderAt,
    required this.memo,
    required this.reminderHour,
    required this.reminderMinute,
    required Set<int> activeWeekdays,
    Set<String>? takenDates,
    this.lastMood,
  }) : activeWeekdays = activeWeekdays.toSet(),
       takenDates = takenDates?.toSet() ?? {};

  final int id;
  String name;
  String dose;
  DoseMoment moment;
  int stock;
  int reorderAt;
  String memo;
  int reminderHour;
  int reminderMinute;
  Set<int> activeWeekdays;
  Set<String> takenDates;
  String? lastMood;

  bool get needsReorder => stock <= reorderAt;
  bool get isDaily => activeWeekdays.length == 7;

  TimeOfDay get reminderTime =>
      TimeOfDay(hour: reminderHour, minute: reminderMinute);

  bool isDueToday(DateTime now) => activeWeekdays.contains(now.weekday);
  bool takenOn(String dateKey) => takenDates.contains(dateKey);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dose': dose,
    'moment': moment.name,
    'stock': stock,
    'reorderAt': reorderAt,
    'memo': memo,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'activeWeekdays': activeWeekdays.toList()..sort(),
    'takenDates': takenDates.toList()..sort(),
    'lastMood': lastMood,
  };

  factory Supplement.fromJson(Map<String, dynamic> json) {
    final moment = DoseMoment.values.firstWhere(
      (value) => value.name == json['moment'],
      orElse: () => DoseMoment.morning,
    );
    final defaultTime = moment.defaultTime;

    return Supplement(
      id: json['id'] as int,
      name: json['name'] as String,
      dose: json['dose'] as String,
      moment: moment,
      stock: json['stock'] as int,
      reorderAt: json['reorderAt'] as int? ?? 7,
      memo: json['memo'] as String? ?? '',
      reminderHour: json['reminderHour'] as int? ?? defaultTime.hour,
      reminderMinute: json['reminderMinute'] as int? ?? defaultTime.minute,
      activeWeekdays: ((json['activeWeekdays'] as List?) ?? _allWeekdays)
          .cast<int>()
          .toSet(),
      takenDates: ((json['takenDates'] as List?) ?? []).cast<String>().toSet(),
      lastMood: json['lastMood'] as String?,
    );
  }
}

class SupplementStore {
  SupplementStore(this._prefs);

  static const _itemsKey = 'supplements';
  final SharedPreferences _prefs;

  List<Supplement> load() {
    final encoded = _prefs.getString(_itemsKey);
    if (encoded == null) {
      return _seedItems();
    }

    final decoded = jsonDecode(encoded) as List<dynamic>;
    return decoded
        .map((item) => Supplement.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<Supplement> items) async {
    final encoded = jsonEncode(items.map((item) => item.toJson()).toList());
    await _prefs.setString(_itemsKey, encoded);
  }

  List<Supplement> _seedItems() {
    return [
      Supplement(
        id: 1,
        name: '오메가3',
        dose: '1캡슐',
        moment: DoseMoment.morning,
        stock: 18,
        reorderAt: 7,
        memo: '식후에 먹기',
        reminderHour: 8,
        reminderMinute: 0,
        activeWeekdays: _allWeekdays.toSet(),
        lastMood: '속 편함',
      ),
      Supplement(
        id: 2,
        name: '마그네슘',
        dose: '2정',
        moment: DoseMoment.night,
        stock: 6,
        reorderAt: 7,
        memo: '커피 마신 날은 2시간 띄우기',
        reminderHour: 22,
        reminderMinute: 30,
        activeWeekdays: _allWeekdays.toSet(),
        lastMood: '잠 잘 옴',
      ),
      Supplement(
        id: 3,
        name: '비타민 D',
        dose: '1정',
        moment: DoseMoment.lunch,
        stock: 24,
        reorderAt: 5,
        memo: '점심 식사 후',
        reminderHour: 12,
        reminderMinute: 30,
        activeWeekdays: _allWeekdays.toSet(),
      ),
    ];
  }
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _enabled = false;

  Future<void> initialize() async {
    if (kIsWeb) {
      return;
    }

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final androidAllowed =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        true;
    final iosAllowed =
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;
    _enabled = androidAllowed && iosAllowed;
  }

  Future<void> schedule(Supplement item) async {
    if (!_enabled || kIsWeb) {
      return;
    }

    await cancel(item.id);
    for (final weekday in item.activeWeekdays) {
      await _plugin.zonedSchedule(
        item.id * 10 + weekday,
        '꼴딱할 시간이에요',
        '${item.name} ${item.dose} 챙길 차례입니다.',
        _nextWeekdayTime(
          weekday: weekday,
          hour: item.reminderHour,
          minute: item.reminderMinute,
        ),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_dose',
            '복용 알림',
            channelDescription: '약과 영양제 복용 시간을 알려줍니다.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancel(int itemId) async {
    if (kIsWeb) {
      return;
    }

    for (final weekday in _allWeekdays) {
      await _plugin.cancel(itemId * 10 + weekday);
    }
  }

  tz.TZDateTime _nextWeekdayTime({
    required int weekday,
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.store,
    required this.notifications,
    super.key,
  });

  final SupplementStore store;
  final NotificationService notifications;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<Supplement> _items;
  late int _nextId;
  int _selectedIndex = 0;
  final DateTime _today = DateTime.now();

  String get _todayKey => _dateKey(_today);
  List<Supplement> get _todayItems =>
      _items.where((item) => item.isDueToday(_today)).toList();
  int get _takenCount =>
      _todayItems.where((item) => item.takenOn(_todayKey)).length;
  int get _reorderCount => _items.where((item) => item.needsReorder).length;

  @override
  void initState() {
    super.initState();
    _items = widget.store.load();
    _nextId = _items.isEmpty
        ? 1
        : _items.map((item) => item.id).reduce((a, b) => a > b ? a : b) + 1;
    for (final item in _items) {
      widget.notifications.schedule(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _TodayView(
        items: _todayItems,
        takenCount: _takenCount,
        reorderCount: _reorderCount,
        todayKey: _todayKey,
        onToggleTaken: _toggleTaken,
        onCheckIn: _openCheckIn,
      ),
      _CabinetView(
        items: _items,
        onAdd: () => _openEditor(),
        onEdit: _openEditor,
        onDelete: _deleteItem,
      ),
      _InsightView(items: _items, todayItems: _todayItems, todayKey: _todayKey),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('KKOLTTAK'),
        centerTitle: false,
        backgroundColor: const Color(0xFFF7F4EE),
        actions: [
          IconButton(
            tooltip: '추가',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: '오늘',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_liquid_outlined),
            selectedIcon: Icon(Icons.medication_liquid),
            label: '약장',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_graph_outlined),
            selectedIcon: Icon(Icons.auto_graph),
            label: '반응',
          ),
        ],
      ),
    );
  }

  Future<void> _persist() => widget.store.save(_items);

  Future<void> _upsertItem(Supplement item) async {
    setState(() {
      final index = _items.indexWhere((value) => value.id == item.id);
      if (index == -1) {
        _items.add(item);
      } else {
        _items[index] = item;
      }
      _selectedIndex = 1;
    });
    await _persist();
    await widget.notifications.schedule(item);
  }

  Future<void> _deleteItem(Supplement item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item.name} 삭제'),
        content: const Text('복용 기록과 알림도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _items.removeWhere((value) => value.id == item.id));
    await _persist();
    await widget.notifications.cancel(item.id);
  }

  Future<void> _toggleTaken(Supplement item) async {
    setState(() {
      if (item.takenOn(_todayKey)) {
        item.takenDates.remove(_todayKey);
        item.stock += 1;
      } else {
        item.takenDates.add(_todayKey);
        if (item.stock > 0) {
          item.stock -= 1;
        }
      }
    });
    await _persist();
  }

  Future<void> _openCheckIn(Supplement item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final moods = ['속 편함', '졸림', '메스꺼움', '기운 남', '변화 없음'];

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.name} 먹고 어땠나요?',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '꼴딱 체크인은 약효보다 내 몸의 반응 패턴을 모으는 기능이에요.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mood in moods)
                    ChoiceChip(
                      label: Text(mood),
                      selected: item.lastMood == mood,
                      onSelected: (_) async {
                        setState(() => item.lastMood = mood);
                        await _persist();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditor([Supplement? item]) async {
    final saved = await showModalBottomSheet<Supplement>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SupplementEditor(initial: item, nextId: _nextId),
    );

    if (saved == null) {
      return;
    }

    if (item == null) {
      _nextId += 1;
    }
    await _upsertItem(saved);
  }
}

class _SupplementEditor extends StatefulWidget {
  const _SupplementEditor({required this.nextId, this.initial});

  final int nextId;
  final Supplement? initial;

  @override
  State<_SupplementEditor> createState() => _SupplementEditorState();
}

class _SupplementEditorState extends State<_SupplementEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _doseController;
  late final TextEditingController _stockController;
  late final TextEditingController _reorderController;
  late final TextEditingController _memoController;
  late DoseMoment _moment;
  late TimeOfDay _time;
  late Set<int> _weekdays;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _moment = initial?.moment ?? DoseMoment.morning;
    _time = initial?.reminderTime ?? _moment.defaultTime;
    _weekdays = initial?.activeWeekdays.toSet() ?? _allWeekdays.toSet();
    _nameController = TextEditingController(text: initial?.name ?? '');
    _doseController = TextEditingController(text: initial?.dose ?? '1정');
    _stockController = TextEditingController(text: '${initial?.stock ?? 30}');
    _reorderController = TextEditingController(
      text: '${initial?.reorderAt ?? 7}',
    );
    _memoController = TextEditingController(text: initial?.memo ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _stockController.dispose();
    _reorderController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? '새로 챙길 것' : '복용 정보 수정',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _doseController,
                    decoration: const InputDecoration(labelText: '복용량'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '남은 수'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reorderController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '재구매 알림 기준'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<DoseMoment>(
              segments: [
                for (final moment in DoseMoment.values)
                  ButtonSegment(
                    value: moment,
                    icon: Icon(moment.icon),
                    label: Text(moment.label),
                  ),
              ],
              selected: {_moment},
              onSelectionChanged: (value) {
                setState(() {
                  _moment = value.first;
                  _time = _moment.defaultTime;
                });
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.alarm),
              label: Text('알림 시간 ${_time.format(context)}'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final weekday in _allWeekdays)
                  FilterChip(
                    label: Text(_weekdayLabel(weekday)),
                    selected: _weekdays.contains(weekday),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _weekdays.add(weekday);
                        } else if (_weekdays.length > 1) {
                          _weekdays.remove(weekday);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '메모'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(widget.initial == null ? '추가하기' : '저장하기'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    final initial = widget.initial;
    Navigator.pop(
      context,
      Supplement(
        id: initial?.id ?? widget.nextId,
        name: name,
        dose: _doseController.text.trim().isEmpty
            ? '1정'
            : _doseController.text.trim(),
        moment: _moment,
        stock: int.tryParse(_stockController.text.trim()) ?? 0,
        reorderAt: int.tryParse(_reorderController.text.trim()) ?? 7,
        memo: _memoController.text.trim(),
        reminderHour: _time.hour,
        reminderMinute: _time.minute,
        activeWeekdays: _weekdays,
        takenDates: initial?.takenDates,
        lastMood: initial?.lastMood,
      ),
    );
  }
}

class _TodayView extends StatelessWidget {
  const _TodayView({
    required this.items,
    required this.takenCount,
    required this.reorderCount,
    required this.todayKey,
    required this.onToggleTaken,
    required this.onCheckIn,
  });

  final List<Supplement> items;
  final int takenCount;
  final int reorderCount;
  final String todayKey;
  final ValueChanged<Supplement> onToggleTaken;
  final ValueChanged<Supplement> onCheckIn;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _HeroPanel(
          takenCount: takenCount,
          totalCount: items.length,
          reorderCount: reorderCount,
        ),
        const SizedBox(height: 20),
        Text(
          '오늘 꼴딱할 것',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const _EmptyPanel(message: '오늘 예정된 복용이 없어요.')
        else
          for (final item in items)
            _DoseCard(
              item: item,
              todayKey: todayKey,
              onToggleTaken: () => onToggleTaken(item),
              onCheckIn: () => onCheckIn(item),
            ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.takenCount,
    required this.totalCount,
    required this.reorderCount,
  });

  final int takenCount;
  final int totalCount;
  final int reorderCount;

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0 ? 0.0 : takenCount / totalCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12372A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: Color(0xFFFFD166)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '오늘 $takenCount/$totalCount 완료',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: Colors.white24,
            color: const Color(0xFFFFD166),
          ),
          const SizedBox(height: 14),
          Text(
            reorderCount == 0
                ? '재구매 알림은 아직 조용해요.'
                : '$reorderCount개가 곧 떨어져요. 장바구니에 넣을 타이밍입니다.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({
    required this.item,
    required this.todayKey,
    required this.onToggleTaken,
    required this.onCheckIn,
  });

  final Supplement item;
  final String todayKey;
  final VoidCallback onToggleTaken;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final takenToday = item.takenOn(todayKey);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton.filledTonal(
              tooltip: takenToday ? '복용 취소' : '복용 완료',
              onPressed: onToggleTaken,
              icon: Icon(
                takenToday ? Icons.check_circle : Icons.radio_button_unchecked,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(item.moment.icon, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${item.moment.label} · ${item.dose} · ${_formatTime(item.reminderTime)}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (item.memo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(item.memo),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(
                        icon: Icons.inventory_2_outlined,
                        label: '${item.stock}개 남음',
                        warning: item.needsReorder,
                      ),
                      _StatusChip(
                        icon: Icons.event_repeat,
                        label: item.isDaily
                            ? '매일'
                            : item.activeWeekdays.map(_weekdayLabel).join(' '),
                      ),
                      if (item.lastMood != null)
                        _StatusChip(
                          icon: Icons.favorite_border,
                          label: item.lastMood!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: onCheckIn,
                    icon: const Icon(Icons.edit_note),
                    label: const Text('먹고 난 느낌 기록'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      padding: EdgeInsets.zero,
                    ),
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

class _CabinetView extends StatelessWidget {
  const _CabinetView({
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Supplement> items;
  final VoidCallback onAdd;
  final ValueChanged<Supplement> onEdit;
  final ValueChanged<Supplement> onDelete;

  @override
  Widget build(BuildContext context) {
    final reorderItems = items.where((item) => item.needsReorder).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '내 약장',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('추가'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (reorderItems.isNotEmpty) _ReorderPanel(items: reorderItems),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const _EmptyPanel(message: '아직 등록된 약이나 영양제가 없어요.')
        else
          for (final item in items)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFEAF3EF),
                  child: Icon(item.moment.icon, color: const Color(0xFF155C47)),
                ),
                title: Text(item.name),
                subtitle: Text(
                  '${item.moment.label} · ${item.dose} · ${item.stock}개 · ${_formatTime(item.reminderTime)}',
                ),
                onTap: () => onEdit(item),
                trailing: PopupMenuButton<String>(
                  tooltip: '더 보기',
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit(item);
                    } else if (value == 'delete') {
                      onDelete(item);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('수정')),
                    PopupMenuItem(value: 'delete', child: Text('삭제')),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _InsightView extends StatelessWidget {
  const _InsightView({
    required this.items,
    required this.todayItems,
    required this.todayKey,
  });

  final List<Supplement> items;
  final List<Supplement> todayItems;
  final String todayKey;

  @override
  Widget build(BuildContext context) {
    final checkedIn = items.where((item) => item.lastMood != null).toList();
    final missed = todayItems.where((item) => !item.takenOn(todayKey)).toList();
    final reorder = items.where((item) => item.needsReorder).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          '몸 반응 노트',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          '먹었는지만 보지 않고, 먹고 난 내 몸의 반응과 놓치는 순간까지 같이 모읍니다.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        _InsightCard(
          icon: Icons.psychology_alt_outlined,
          title: '나한테 맞는 타이밍 찾기',
          body: checkedIn.isEmpty
              ? '오늘 복용 후 느낌을 하나 남기면 여기에 패턴이 쌓여요.'
              : checkedIn
                    .map((item) => '${item.name}: ${item.lastMood}')
                    .join('\n'),
        ),
        _InsightCard(
          icon: Icons.schedule_outlined,
          title: '놓치기 쉬운 순간',
          body: missed.isEmpty
              ? '오늘은 모두 완료했어요.'
              : missed
                    .map((item) => '${item.moment.label} ${item.name}')
                    .join('\n'),
        ),
        _InsightCard(
          icon: Icons.shopping_cart_checkout,
          title: '곧 살 것',
          body: reorder.isEmpty
              ? '이번 주 재구매 후보는 없어요.'
              : reorder
                    .map((item) => '${item.name}: ${item.stock}개')
                    .join('\n'),
        ),
        const _InsightCard(
          icon: Icons.local_cafe_outlined,
          title: '섭취 간섭 메모',
          body: '커피, 유제품, 공복처럼 나에게 애매했던 조건을 메모에 남겨두면 다음 복용 카드에서 바로 보입니다.',
        ),
      ],
    );
  }
}

class _ReorderPanel extends StatelessWidget {
  const _ReorderPanel({required this.items});

  final List<Supplement> items;

  @override
  Widget build(BuildContext context) {
    final names = items.map((item) => item.name).join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3D7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: Color(0xFF9C2E00),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '재구매 알림',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF9C2E00),
                  ),
                ),
                const SizedBox(height: 4),
                Text('$names 재고가 기준 이하로 내려갔어요.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final background = warning
        ? const Color(0xFFFFE3D7)
        : const Color(0xFFEAF3EF);
    final foreground = warning
        ? const Color(0xFF9C2E00)
        : const Color(0xFF155C47);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

const List<int> _allWeekdays = [1, 2, 3, 4, 5, 6, 7];

String _weekdayLabel(int weekday) {
  return const {
    1: '월',
    2: '화',
    3: '수',
    4: '목',
    5: '금',
    6: '토',
    7: '일',
  }[weekday]!;
}

String _formatTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
