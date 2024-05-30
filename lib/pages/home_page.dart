import 'dart:io';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AudioRecorder audioRecorder = AudioRecorder();
  final AudioPlayer audioPlayer = AudioPlayer();

  List<FileSystemEntity> recordings = [];
  bool isRecording = false;
  String? playingPath; // Variable to track the currently playing file
  String? loopingPath; // Variable to track the currently looping file
  late String recordingPath;

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    final String directoryPath = appDocumentsDir.path;
    setState(() {
      recordings = Directory(directoryPath)
          .listSync()
          .where((item) => item.path.endsWith('.wav'))
          .toList();
    });
  }

  Future<void> _setupAudioPlayer(String recordingPath) async {
    audioPlayer.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stacktrace) {
      // print("A stream error occurred: $e");
    });
    try {
      await audioPlayer
          .setAudioSource(AudioSource.uri(Uri.file(recordingPath)));
    } catch (e) {
      // print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Melody'),
        backgroundColor: const Color.fromARGB(255, 30, 198, 64),
      ),
      floatingActionButton: _recordingButton(),
      body: _buildUI(),
      backgroundColor: Colors.grey[200],
    );
  }

  Widget _buildUI() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: recordings.isEmpty
          ? Center(
              child: Text(
                'No Recordings Found',
                style: TextStyle(color: Colors.grey[600], fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: recordings.length,
              itemBuilder: (context, index) {
                final recording = recordings[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    title: Text(p.basename(recording.path)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            playingPath == recording.path
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.green,
                          ),
                          onPressed: () async {
                            setState(() {
                              recordingPath = recording.path;
                            });
                            _setupAudioPlayer(recording.path);
                            showAudioPopup(context);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _progessBar() {
    return StreamBuilder<Duration?>(
      stream: audioPlayer.positionStream,
      builder: (context, snapshot) {
        return ProgressBar(
          progress: snapshot.data ?? Duration.zero,
          buffered: audioPlayer.bufferedPosition,
          total: audioPlayer.duration ?? Duration.zero,
          onSeek: (duration) {
            audioPlayer.seek(duration);
          },
        );
      },
    );
  }

  Future<void> _toggleLoopMode() async {
    if (audioPlayer.loopMode == LoopMode.one && loopingPath == recordingPath) {
      await audioPlayer.setLoopMode(LoopMode.off);
      setState(() {
        loopingPath = null; // Reset looping path
      });
    } else {
      await audioPlayer.setFilePath(recordingPath);
      await audioPlayer.setLoopMode(LoopMode.one);
      setState(() {
        loopingPath = recordingPath; // Set the new looping path
      });
    }
  }

  Widget _recordingButton() {
    return FloatingActionButton(
      onPressed: () async {
        if (isRecording) {
          String? filePath = await audioRecorder.stop();
          if (filePath != null) {
            setState(() {
              isRecording = false;
            });
            _loadRecordings(); // Refresh the list of recordings
          }
        } else {
          if (await audioRecorder.hasPermission()) {
            final Directory appDocumentsDir =
                await getApplicationDocumentsDirectory();
            final String timestamp =
                DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
            final String filePath =
                p.join(appDocumentsDir.path, "recording_$timestamp.wav");
            await audioRecorder.start(
              const RecordConfig(),
              path: filePath,
            );
            setState(() {
              isRecording = true;
            });
          }
        }
      },
      backgroundColor: isRecording ? Colors.red : Colors.deepPurple,
      child: Icon(
        isRecording ? Icons.stop : Icons.mic,
        color: Colors.white,
      ),
    );
  }

  Widget _playbackControlButton() {
    return StreamBuilder<PlayerState>(
        stream: audioPlayer.playerStateStream,
        builder: (context, snapshot) {
          final processingState = snapshot.data?.processingState;
          final playing = snapshot.data?.playing;
          if (processingState == ProcessingState.loading ||
              processingState == ProcessingState.buffering) {
            return Container(
              margin: const EdgeInsets.all(8.0),
              width: 64,
              height: 64,
              child: const CircularProgressIndicator(),
            );
          } else if (playing != true) {
            return IconButton(
              icon: const Icon(Icons.play_arrow),
              iconSize: 64,
              onPressed: audioPlayer.play,
            );
          } else if (processingState != ProcessingState.completed) {
            return IconButton(
              icon: const Icon(Icons.pause),
              iconSize: 64,
              onPressed: audioPlayer.pause,
            );
          } else {
            return IconButton(
                icon: const Icon(Icons.replay),
                iconSize: 64,
                onPressed: () => audioPlayer.seek(Duration.zero));
          }
        });
  }

  showAudioPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "Player",
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20.0),
                // _sourceSelect(),
                _progessBar(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // _controlButtons(),
                    IconButton(
                      icon: const Icon(
                        Icons.loop,
                      ),
                      onPressed: () => _toggleLoopMode(),
                    ),
                    const SizedBox(width: 10.0),
                    _playbackControlButton(),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
