import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const SoundboardApp());
}

class SoundboardApp extends StatelessWidget {
  const SoundboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Soundboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const SoundboardPage(),
    );
  }
}

class SoundItem {
  final String id;
  String title;
  String filePath;
  int colorValue;
  bool loop;
  double volume;

  SoundItem({
    required this.id,
    required this.title,
    required this.filePath,
    required this.colorValue,
    this.loop = false,
    this.volume = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'colorValue': colorValue,
        'loop': loop,
        'volume': volume,
      };

  factory SoundItem.fromJson(Map<String, dynamic> json) => SoundItem(
        id: json['id'],
        title: json['title'],
        filePath: json['filePath'],
        colorValue: json['colorValue'],
        loop: json['loop'] ?? false,
        volume: (json['volume'] ?? 1.0).toDouble(),
      );
}

class SoundboardPage extends StatefulWidget {
  const SoundboardPage({super.key});

  @override
  State<SoundboardPage> createState() => _SoundboardPageState();
}

class _SoundboardPageState extends State<SoundboardPage> {
  static const storageKey = 'sound_items_v1';
  final uuid = const Uuid();

  List<SoundItem> sounds = [];
  final List<AudioPlayer> activePlayers = [];

  @override
  void initState() {
    super.initState();
    loadBoard();
  }

  @override
  void dispose() {
    for (final player in activePlayers) {
      player.dispose();
    }
    super.dispose();
  }

  Future<void> loadBoard() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return;

    final decoded = jsonDecode(raw) as List;
    setState(() {
      sounds = decoded.map((e) => SoundItem.fromJson(e)).toList();
    });
  }

  Future<void> saveBoard() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(sounds.map((e) => e.toJson()).toList());
    await prefs.setString(storageKey, raw);
  }

  Future<void> addSound() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;

    final pickedFile = File(result.files.single.path!);
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '${uuid.v4()}_${result.files.single.name}';
    final savedFile = await pickedFile.copy('${appDir.path}/$fileName');

    final item = SoundItem(
      id: uuid.v4(),
      title: result.files.single.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
      filePath: savedFile.path,
      colorValue: Colors.blue.value,
    );

    setState(() => sounds.add(item));
    await saveBoard();
  }

  Future<void> playSound(SoundItem item) async {
    final file = File(item.filePath);
    if (!await file.exists()) {
      showError('Audiodatei nicht gefunden.');
      return;
    }

    final player = AudioPlayer();
    activePlayers.add(player);

    try {
      await player.setFilePath(item.filePath);
      await player.setVolume(item.volume);
      await player.setLoopMode(item.loop ? LoopMode.one : LoopMode.off);
      await player.play();

      player.playerStateStream.listen((state) async {
        if (state.processingState == ProcessingState.completed && !item.loop) {
          await player.dispose();
          activePlayers.remove(player);
        }
      });
    } catch (_) {
      await player.dispose();
      activePlayers.remove(player);
      showError('Sound konnte nicht abgespielt werden.');
    }
  }

  Future<void> stopAll() async {
    for (final player in List<AudioPlayer>.from(activePlayers)) {
      await player.stop();
      await player.dispose();
    }
    activePlayers.clear();
  }

  Future<void> deleteSound(SoundItem item) async {
    final file = File(item.filePath);
    if (await file.exists()) {
      await file.delete();
    }

    setState(() => sounds.removeWhere((s) => s.id == item.id));
    await saveBoard();
  }

  void showError(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> editSound(SoundItem item) async {
    final titleController = TextEditingController(text: item.title);
    double volume = item.volume;
    bool loop = item.loop;
    Color selectedColor = Color(item.colorValue);

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
      Colors.grey,
      Colors.black,
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Sound bearbeiten'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Loop'),
                        const Spacer(),
                        Switch(
                          value: loop,
                          onChanged: (value) {
                            setDialogState(() => loop = value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Lautstärke: ${(volume * 100).round()} %'),
                    Slider(
                      value: volume,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      onChanged: (value) {
                        setDialogState(() => volume = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: colors.map((color) {
                        final isSelected = color.value == selectedColor.value;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() => selectedColor = color);
                          },
                          child: CircleAvatar(
                            backgroundColor: color,
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () async {
                    item.title = titleController.text.trim().isEmpty
                        ? 'Sound'
                        : titleController.text.trim();
                    item.volume = volume;
                    item.loop = loop;
                    item.colorValue = selectedColor.value;

                    setState(() {});
                    await saveBoard();

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSounds = sounds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Soundboard'),
        actions: [
          IconButton(
            tooltip: 'Alle stoppen',
            onPressed: stopAll,
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addSound,
        icon: const Icon(Icons.add),
        label: const Text('Sound hinzufügen'),
      ),
      body: hasSounds
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                itemCount: sounds.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (context, index) {
                  final item = sounds[index];

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => playSound(item),
                    onLongPress: () => editSound(item),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(item.colorValue),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.loop ? Icons.repeat : Icons.play_arrow,
                            color: Colors.white,
                            size: 36,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(item.volume * 100).round()} %',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Löschen',
                            onPressed: () => deleteSound(item),
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.graphic_eq, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Noch keine Sounds vorhanden.',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Füge MP3, WAV, M4A oder andere Audiodateien hinzu.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: addSound,
                      icon: const Icon(Icons.add),
                      label: const Text('Ersten Sound hinzufügen'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
