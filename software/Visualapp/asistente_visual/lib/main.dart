import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';

const Color irisYellow = Color(0xFFFFC928);
const Color irisBlack = Color(0xFF080808);
const Color irisPanel = Color(0xFF1B1B1B);

List<CameraDescription> availableDeviceCameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    availableDeviceCameras = await availableCameras();
  } catch (e) {
    debugPrint('Error al buscar cámaras: $e');
  }

  runApp(const IrisVisionApp());
}

class IrisVisionApp extends StatelessWidget {
  const IrisVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IRIS VISION',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: irisBlack,
        fontFamily: 'sans-serif',
        colorScheme: const ColorScheme.dark(
          primary: irisYellow,
          surface: irisPanel,
        ),
      ),
      home: const IrisHomePage(),
    );
  }
}

class IrisHomePage extends StatefulWidget {
  const IrisHomePage({super.key});

  @override
  State<IrisHomePage> createState() => _IrisHomePageState();
}

class _IrisHomePageState extends State<IrisHomePage>
    with WidgetsBindingObserver {
  // ==========================================
  // CONTROL DE LA CÁMARA
  // ==========================================

  CameraController? cameraController;

  String? cameraError;
  bool cameraReady = false;
  bool isCapturing = false;

  XFile? capturedPhoto;

  // ==========================================
  // CONTROL DE VOZ
  // ==========================================

  final SpeechToText speech = SpeechToText();
  final FlutterTts tts = FlutterTts();

  bool voiceReady = false;
  bool isListening = false;
  bool isSpeaking = false;
  bool processingVoiceCommand = false;
  bool commandHandledForSession = false;

  bool listeningEnabled = true;

  bool appInForeground = true;
  bool appHasFocus = true;

  bool restartPending = false;
  bool startingListening = false;

  // Última frase reconocida por Android.
  String pendingRecognizedWords = '';

  // Temporizador para procesar el último resultado parcial.
  Timer? pendingRecognitionTimer;

  String speechLocale = 'es_ES';

  // ==========================================
  // HISTORIAL DE CONVERSACIÓN
  // ==========================================

  final List<Map<String, String>> conversationHistory = [];

  // ==========================================
  // INICIALIZACIÓN
  // ==========================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    initializeCamera();
    initializeVoice();
  }

  // ==========================================
  // INICIALIZAR CÁMARA
  // ==========================================

  Future<void> initializeCamera() async {
    if (!appInForeground) return;

    if (cameraController != null && cameraController!.value.isInitialized) {
      return;
    }

    if (availableDeviceCameras.isEmpty) {
      if (!mounted) return;

      setState(() {
        cameraError = 'No se encontró una cámara disponible.';
      });

      return;
    }

    CameraController? controller;

    try {
      final selectedCamera = availableDeviceCameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => availableDeviceCameras.first,
      );

      controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      cameraController = controller;

      debugPrint('Inicializando cámara...');

      await controller.initialize();

      if (!mounted || !appInForeground || cameraController != controller) {
        await controller.dispose();
        return;
      }

      setState(() {
        cameraReady = true;
        cameraError = null;
      });

      debugPrint('Cámara inicializada correctamente.');
    } on CameraException catch (e) {
      if (!mounted || (controller != null && cameraController != controller)) {
        return;
      }

      if (cameraController == controller) {
        cameraController = null;
      }

      setState(() {
        cameraReady = false;
        cameraError =
            'No se pudo iniciar la cámara: ${e.description ?? e.code}';
      });

      debugPrint('Error de cámara: ${e.code}');
    } catch (e) {
      if (!mounted) return;

      if (cameraController == controller) {
        cameraController = null;
      }

      setState(() {
        cameraReady = false;
        cameraError = 'Error al iniciar la cámara.';
      });

      debugPrint('Error al inicializar cámara: $e');
    }
  }

  // ==========================================
  // CONFIGURAR VOZ ESPAÑOLA
  // ==========================================

  Future<void> configureSpanishVoice() async {
    await tts.setLanguage('es-US');
    await tts.setSpeechRate(0.45);
    await tts.setPitch(1.0);
    await tts.setVolume(1.0);
    await tts.awaitSpeakCompletion(true);

    try {
      final rawVoices = await tts.getVoices;

      final List<Map<String, dynamic>> spanishVoices = [];

      if (rawVoices is List) {
        for (final item in rawVoices) {
          if (item is! Map) continue;

          final voice = Map<String, dynamic>.from(item);

          final locale = (voice['locale'] ?? '')
              .toString()
              .replaceAll('_', '-')
              .toLowerCase();

          if (locale.startsWith('es-')) {
            spanishVoices.add(voice);
          }
        }
      }

      debugPrint('VOCES ESPAÑOLAS DISPONIBLES:');

      for (final voice in spanishVoices) {
        debugPrint(
          '${voice['name']} | ${voice['locale']} '
          '| Red: ${voice['network_required']}',
        );
      }

      // Buscar voces locales.
      final localVoices = spanishVoices.where((voice) {
        final name = (voice['name'] ?? '').toString().toLowerCase();

        final requiresNetwork =
            voice['network_required'] == true || name.contains('network');

        return !requiresNetwork && name.contains('local');
      }).toList();

      if (localVoices.isNotEmpty) {
        // Preferir una voz local latinoamericana.
        final selectedVoice = localVoices.firstWhere((voice) {
          final name = (voice['name'] ?? '').toString().toLowerCase();

          return name == 'es-us-x-esd-local';
        }, orElse: () => localVoices.first);

        final name = selectedVoice['name'].toString();
        final locale = selectedVoice['locale'].toString();

        await tts.setLanguage(locale);

        await tts.setVoice({'name': name, 'locale': locale});

        debugPrint('VOZ LOCAL SELECCIONADA: $name ($locale)');
      } else {
        debugPrint(
          'No se encontraron voces españolas locales. '
          'Se conserva la voz predeterminada.',
        );
      }

      await tts.setSpeechRate(0.45);
      await tts.setPitch(1.0);
      await tts.setVolume(1.0);
    } catch (e) {
      debugPrint('Error configurando la voz: $e');

      await tts.setLanguage('es-US');
      await tts.setSpeechRate(0.45);
      await tts.setPitch(1.0);
      await tts.setVolume(1.0);
    }
  }

  // ==========================================
  // INICIALIZAR SISTEMA DE VOZ
  // ==========================================

  Future<void> initializeVoice() async {
    try {
      await configureSpanishVoice();

      final initialized = await speech.initialize(
        onStatus: (status) {
          if (!mounted) return;

          debugPrint('Estado del reconocimiento: $status');

          setState(() {
            isListening = status == 'listening';
          });

          if (status == 'done') {
            processPendingRecognition();
            scheduleListeningRestart();
          }
        },
        onError: (error) {
          debugPrint('Error de reconocimiento: ${error.errorMsg}');

          processPendingRecognition();
          scheduleListeningRestart();
        },
      );

      if (!initialized) {
        debugPrint('No se pudo inicializar el reconocimiento de voz.');

        await speak(
          'No pude activar el reconocimiento de voz. '
          'Revisa el permiso del micrófono.',
        );

        return;
      }

      final locales = await speech.locales();

      final colombianLocale = locales.where(
        (locale) =>
            locale.localeId.toLowerCase().replaceAll('-', '_') == 'es_co',
      );

      final spanishLocale = locales.where(
        (locale) => locale.localeId.toLowerCase().startsWith('es'),
      );

      if (colombianLocale.isNotEmpty) {
        speechLocale = colombianLocale.first.localeId;
      } else if (spanishLocale.isNotEmpty) {
        speechLocale = spanishLocale.first.localeId;
      }

      if (!mounted) return;

      setState(() {
        voiceReady = true;
      });

      debugPrint('Idioma de reconocimiento: $speechLocale');

      await speak(
        'Bienvenido a IRIS VISION. '
        '¿Deseas que te describa qué estás viendo? '
        'Para confirmar, dime: ¿Qué ves?',
      );

      if (mounted && appInForeground && appHasFocus && listeningEnabled) {
        await startListening();
      }
    } catch (e) {
      debugPrint('Error al configurar la voz: $e');
    }
  }

  // ==========================================
  // PROGRAMAR REINICIO DEL MICRÓFONO
  // ==========================================

  void scheduleListeningRestart() {
    if (restartPending ||
        !mounted ||
        !appInForeground ||
        !appHasFocus ||
        !listeningEnabled ||
        !voiceReady ||
        isSpeaking ||
        isCapturing ||
        processingVoiceCommand ||
        startingListening) {
      return;
    }

    restartPending = true;

    debugPrint('Reinicio del micrófono programado.');

    Future.delayed(const Duration(milliseconds: 1000), () async {
      restartPending = false;

      if (!mounted ||
          !appInForeground ||
          !appHasFocus ||
          !listeningEnabled ||
          !voiceReady ||
          isSpeaking ||
          isCapturing ||
          processingVoiceCommand ||
          startingListening ||
          speech.isListening) {
        return;
      }

      debugPrint('Reactivando reconocimiento de voz.');

      await startListening();
    });
  }

  // ==========================================
  // PROCESAR FRASES PARCIALES
  // CUANDO TERMINA EL RECONOCIMIENTO
  // ==========================================

  void processPendingRecognition() {
    pendingRecognitionTimer?.cancel();

    pendingRecognitionTimer = Timer(const Duration(milliseconds: 350), () {
      pendingRecognitionTimer = null;

      if (!mounted ||
          !appInForeground ||
          !appHasFocus ||
          !listeningEnabled ||
          commandHandledForSession ||
          processingVoiceCommand ||
          isCapturing ||
          isSpeaking) {
        return;
      }

      final recognized = pendingRecognizedWords.trim();

      if (recognized.isEmpty) return;

      final normalized = normalizeCommand(recognized);

      final words = normalized
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();

      // Preguntas cortas que también son válidas.
      const shortQuestions = {
        'color',
        'que color',
        'de que color',
        'que es',
        'por que',
        'ayuda',
        'repite',
        'repetir',
      };

      // No enviar fragmentos demasiado cortos.
      if (words.length < 3 && !shortQuestions.contains(normalized)) {
        debugPrint('Fragmento demasiado corto, se ignora: $recognized');

        pendingRecognizedWords = '';
        return;
      }

      debugPrint(
        'Procesando frase parcial al terminar la escucha: '
        '$recognized',
      );

      dispatchRecognizedCommand(recognized);
    });
  }

  // ==========================================
  // ENVIAR COMANDO RECONOCIDO
  // ==========================================

  void dispatchRecognizedCommand(String recognized) {
    if (!mounted ||
        !appInForeground ||
        !appHasFocus ||
        !listeningEnabled ||
        commandHandledForSession ||
        processingVoiceCommand ||
        isCapturing) {
      return;
    }

    commandHandledForSession = true;

    pendingRecognizedWords = '';
    pendingRecognitionTimer?.cancel();
    pendingRecognitionTimer = null;

    debugPrint('Enviando comando reconocido: $recognized');

    unawaited(handleVoiceCommand(recognized));
  }

  // ==========================================
  // HACER QUE IRIS HABLE
  // ==========================================

  Future<void> speak(String message) async {
    try {
      if (!mounted || !appInForeground) return;

      if (speech.isListening) {
        await speech.stop();
      }

      await tts.stop();

      if (!mounted || !appInForeground) return;

      setState(() {
        isSpeaking = true;
        isListening = false;
      });

      debugPrint('IRIS hablando: $message');

      await tts.speak(message);

      if (!mounted) return;

      setState(() {
        isSpeaking = false;
      });
    } catch (e) {
      debugPrint('Error al reproducir la voz: $e');

      if (mounted) {
        setState(() {
          isSpeaking = false;
        });
      }
    }
  }

  // ==========================================
  // ESCUCHAR COMANDOS Y PREGUNTAS
  // ==========================================

  Future<void> startListening() async {
    if (!mounted ||
        !appInForeground ||
        !appHasFocus ||
        !voiceReady ||
        !listeningEnabled ||
        isSpeaking ||
        isCapturing ||
        processingVoiceCommand ||
        startingListening ||
        speech.isListening) {
      return;
    }

    startingListening = true;

    pendingRecognitionTimer?.cancel();
    pendingRecognitionTimer = null;
    pendingRecognizedWords = '';

    try {
      commandHandledForSession = false;

      debugPrint('Iniciando reconocimiento de voz...');

      await speech.listen(
        onResult: (result) {
          final recognized = result.recognizedWords.trim();

          if (recognized.isEmpty) return;

          pendingRecognizedWords = recognized;

          final normalized = normalizeCommand(recognized);

          debugPrint(
            'Voz detectada: $recognized '
            '| Final: ${result.finalResult}',
          );

          // --------------------------------------
          // COMANDOS INMEDIATOS
          // --------------------------------------

          final initialPhotoCommand =
              normalized == 'que ves' ||
              normalized.startsWith('que ves ') ||
              normalized == 'que puedes ver' ||
              normalized == 'que hay' ||
              normalized == 'describe';

          final anotherPhotoCommand =
              normalized == 'otra foto' ||
              normalized.contains('toma otra foto') ||
              normalized.contains('tomar otra foto') ||
              normalized.contains('nueva foto') ||
              normalized.contains('otra fotografia') ||
              normalized.contains('captura otra foto') ||
              normalized.contains('haz otra foto');

          final finishCommand =
              normalized.contains('eso es todo') ||
              normalized.contains('terminemos') ||
              normalized.contains('terminar conversacion') ||
              normalized.contains('finalizar conversacion') ||
              normalized.contains('ya terminamos') ||
              normalized == 'terminar';

          final immediateCommand =
              initialPhotoCommand || anotherPhotoCommand || finishCommand;

          if (immediateCommand &&
              !commandHandledForSession &&
              !processingVoiceCommand &&
              !isCapturing &&
              appInForeground &&
              appHasFocus) {
            debugPrint('Comando inmediato detectado.');

            dispatchRecognizedCommand(recognized);
            return;
          }

          // --------------------------------------
          // DEMÁS PREGUNTAS
          // --------------------------------------

          if (result.finalResult &&
              !commandHandledForSession &&
              !processingVoiceCommand &&
              !isCapturing &&
              appInForeground &&
              appHasFocus) {
            dispatchRecognizedCommand(recognized);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: speechLocale,
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
        ),
      );
    } catch (e) {
      debugPrint('Error al escuchar: $e');
    } finally {
      startingListening = false;
    }
  }

  // ==========================================
  // NORMALIZAR TEXTO
  // ==========================================

  String normalizeCommand(String command) {
    return command
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[¿?¡!.,;:]'), '')
        .trim();
  }

  // ==========================================
  // INTERPRETAR COMANDO DE VOZ
  // ==========================================

  Future<void> handleVoiceCommand(String command) async {
    if (!mounted ||
        !appInForeground ||
        !appHasFocus ||
        !listeningEnabled ||
        processingVoiceCommand ||
        isCapturing) {
      return;
    }

    processingVoiceCommand = true;
    commandHandledForSession = true;

    debugPrint('Comando reconocido: $command');

    final normalizedCommand = normalizeCommand(command);

    try {
      await speech.stop();

      // ------------------------------------------
      // 1. TERMINAR CONVERSACIÓN
      // ------------------------------------------

      final finishConversation =
          normalizedCommand.contains('eso es todo') ||
          normalizedCommand.contains('terminemos') ||
          normalizedCommand.contains('terminar conversacion') ||
          normalizedCommand.contains('finalizar conversacion') ||
          normalizedCommand.contains('terminar') ||
          normalizedCommand.contains('ya terminamos');

      if (finishConversation) {
        await endCurrentConversation();
        return;
      }

      // ------------------------------------------
      // 2. TOMAR OTRA FOTOGRAFÍA
      // ------------------------------------------

      final newPhotoCommand =
          normalizedCommand.contains('toma otra foto') ||
          normalizedCommand.contains('tomar otra foto') ||
          normalizedCommand.contains('nueva foto') ||
          normalizedCommand.contains('otra fotografia') ||
          normalizedCommand.contains('otra foto') ||
          normalizedCommand.contains('captura otra foto') ||
          normalizedCommand.contains('haz otra foto');

      if (newPhotoCommand) {
        await capturePhoto();
        return;
      }

      // ------------------------------------------
      // 3. PRIMERA FOTOGRAFÍA
      // ------------------------------------------

      final initialPhotoCommand =
          normalizedCommand.contains('que ves') ||
          normalizedCommand.contains('que puedes ver') ||
          normalizedCommand == 'que hay' ||
          normalizedCommand == 'describe' ||
          normalizedCommand.contains('toma una foto') ||
          normalizedCommand.contains('toma la foto') ||
          normalizedCommand.contains('captura una foto');

      if (initialPhotoCommand && capturedPhoto == null) {
        await capturePhoto();
        return;
      }

      // ------------------------------------------
      // 4. PREGUNTAS SOBRE LA FOTO ACTUAL
      // ------------------------------------------

      if (capturedPhoto != null) {
        await askQuestion(command);
        return;
      }

      // ------------------------------------------
      // 5. TODAVÍA NO HAY FOTOGRAFÍA
      // ------------------------------------------

      await speak(
        'Primero necesito tomar una fotografía. '
        'Dime: ¿Qué ves?',
      );
    } catch (e) {
      debugPrint('Error procesando el comando: $e');

      if (mounted && appInForeground) {
        await speak(
          'No pude procesar tu solicitud. '
          'Inténtalo nuevamente.',
        );
      }
    } finally {
      processingVoiceCommand = false;

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted &&
          appInForeground &&
          appHasFocus &&
          voiceReady &&
          listeningEnabled &&
          !isSpeaking &&
          !isCapturing) {
        await startListening();
      }
    }
  }

  // ==========================================
  // TERMINAR CONVERSACIÓN ACTUAL
  // ==========================================

  Future<void> endCurrentConversation() async {
    debugPrint('Terminando conversación actual.');

    if (!mounted) return;

    setState(() {
      capturedPhoto = null;
      conversationHistory.clear();
    });

    await speak(
      'Conversación terminada. '
      'Cuando quieras comenzar de nuevo, dime: ¿Qué ves?',
    );
  }

  // ==========================================
  // CAPTURAR Y ANALIZAR FOTOGRAFÍA
  // ==========================================

  Future<bool> capturePhoto() async {
    if (!appInForeground || isCapturing || !mounted) {
      debugPrint('No se puede capturar en este momento.');
      return false;
    }

    CameraController? controller = cameraController;

    // Esperar si la cámara todavía está inicializándose.
    if (controller == null || !controller.value.isInitialized) {
      debugPrint('Cámara no lista. Esperando inicialización...');

      await initializeCamera();

      for (int attempt = 0; attempt < 20; attempt++) {
        if (!mounted || !appInForeground) return false;

        controller = cameraController;

        if (controller != null && controller.value.isInitialized) {
          break;
        }

        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    if (!mounted ||
        !appInForeground ||
        controller == null ||
        !controller.value.isInitialized) {
      debugPrint('La cámara no está preparada.');

      if (mounted && appInForeground) {
        await speak(
          'La cámara todavía se está preparando. '
          'Inténtalo nuevamente.',
        );
      }

      return false;
    }

    try {
      setState(() {
        isCapturing = true;
        capturedPhoto = null;
        conversationHistory.clear();
      });

      debugPrint('Tomando fotografía...');

      final XFile photo = await controller.takePicture();

      debugPrint('Fotografía capturada: ${photo.path}');

      if (!mounted || !appInForeground) return false;

      setState(() {
        capturedPhoto = photo;
      });

      // Enviar fotografía al servidor.
      final description = await analyzePhoto(photo);

      debugPrint('Descripción de IRIS: $description');

      if (!mounted || !appInForeground) return false;

      // Guardar descripción inicial para futuras preguntas.
      conversationHistory.add({'role': 'model', 'text': description});

      await speak(description);

      return true;
    } catch (e) {
      debugPrint('Error al capturar o analizar: $e');

      if (mounted && appInForeground) {
        await speak(
          'No pude analizar la fotografía. '
          'Comprueba que el servidor y la conexión estén funcionando.',
        );
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          isCapturing = false;
        });
      }
    }
  }

  // ==========================================
  // ENVIAR FOTOGRAFÍA AL SERVIDOR
  // ==========================================

  Future<String> analyzePhoto(XFile photo) async {
    final uri = Uri.parse('http://10.0.2.2:3000/analyze');

    final imageBytes = await photo.readAsBytes();

    debugPrint('Enviando fotografía al servidor...');

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': getMimeType(photo.path),
            'Accept': 'application/json',
          },
          body: imageBytes,
        )
        .timeout(const Duration(seconds: 90));

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 &&
        data['success'] == true &&
        data['description'] is String &&
        (data['description'] as String).trim().isNotEmpty) {
      return (data['description'] as String).trim();
    }

    throw Exception(data['error'] ?? 'Error al recibir la descripción.');
  }

  // ==========================================
  // DETERMINAR FORMATO DE IMAGEN
  // ==========================================

  String getMimeType(String path) {
    final extension = path.toLowerCase().split('.').last;

    if (extension == 'png') {
      return 'image/png';
    }

    if (extension == 'webp') {
      return 'image/webp';
    }

    return 'image/jpeg';
  }

  // ==========================================
  // PREGUNTAR SOBRE LA FOTOGRAFÍA ACTUAL
  // ==========================================

  Future<void> askQuestion(String question) async {
    final photo = capturedPhoto;

    if (photo == null) {
      await speak('Todavía no tengo una fotografía para responder.');
      return;
    }

    try {
      debugPrint('Pregunta del usuario: $question');

      final imageBytes = await photo.readAsBytes();
      final imageBase64 = base64Encode(imageBytes);

      final uri = Uri.parse('http://10.0.2.2:3000/ask');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'imageBase64': imageBase64,
              'mimeType': getMimeType(photo.path),
              'question': question,
              'history': conversationHistory,
            }),
          )
          .timeout(const Duration(seconds: 90));

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 ||
          data['success'] != true ||
          data['answer'] is! String ||
          (data['answer'] as String).trim().isEmpty) {
        throw Exception(data['error'] ?? 'No pude obtener una respuesta.');
      }

      final answer = (data['answer'] as String).trim();

      debugPrint('Respuesta de IRIS: $answer');

      // Guardar pregunta y respuesta.
      conversationHistory.add({'role': 'user', 'text': question});

      conversationHistory.add({'role': 'model', 'text': answer});

      // Conservar los mensajes más recientes.
      if (conversationHistory.length > 12) {
        conversationHistory.removeRange(0, conversationHistory.length - 12);
      }

      await speak(answer);
    } catch (e) {
      debugPrint('Error al responder pregunta: $e');

      if (mounted && appInForeground) {
        await speak(
          'No pude responder esa pregunta. '
          'Inténtalo nuevamente.',
        );
      }
    }
  }

  // ==========================================
  // CICLO DE VIDA DE LA APLICACIÓN
  // ==========================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ------------------------------------------
    // LA APLICACIÓN PIERDE EL FOCO
    // ------------------------------------------

    if (state == AppLifecycleState.inactive) {
      debugPrint('IRIS VISION está inactiva.');

      appHasFocus = false;

      if (!processingVoiceCommand) {
        unawaited(speech.stop());
      }

      if (mounted) {
        setState(() {
          isListening = false;
        });
      }
    }
    // ------------------------------------------
    // LA APLICACIÓN SALE DE LA PANTALLA
    // ------------------------------------------
    else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      debugPrint('IRIS VISION pasó a segundo plano.');

      appInForeground = false;
      appHasFocus = false;
      restartPending = false;

      unawaited(speech.stop());
      unawaited(tts.stop());

      final oldController = cameraController;
      cameraController = null;

      if (oldController != null) {
        unawaited(oldController.dispose());
      }

      if (mounted) {
        setState(() {
          cameraReady = false;
          isListening = false;
          isSpeaking = false;
        });
      }
    }
    // ------------------------------------------
    // EL USUARIO REGRESA A IRIS
    // ------------------------------------------
    else if (state == AppLifecycleState.resumed) {
      debugPrint('IRIS VISION regresó al primer plano.');

      appInForeground = true;
      appHasFocus = true;

      unawaited(initializeCamera());

      if (voiceReady && listeningEnabled && !processingVoiceCommand) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted &&
              appInForeground &&
              appHasFocus &&
              listeningEnabled &&
              !isSpeaking &&
              !isCapturing &&
              !processingVoiceCommand) {
            unawaited(startListening());
          }
        });
      }
    }
  }

  // ==========================================
  // CERRAR RECURSOS
  // ==========================================

  @override
  void dispose() {
    appInForeground = false;
    appHasFocus = false;
    listeningEnabled = false;
    restartPending = false;

    pendingRecognitionTimer?.cancel();
    pendingRecognizedWords = '';

    WidgetsBinding.instance.removeObserver(this);

    unawaited(speech.stop());
    unawaited(tts.stop());

    final controller = cameraController;
    cameraController = null;

    if (controller != null) {
      unawaited(controller.dispose());
    }

    super.dispose();
  }

  // ==========================================
  // MENSAJES EN PANTALLA
  // ==========================================

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: irisPanel),
    );
  }

  // ==========================================
  // INTERFAZ PRINCIPAL
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: irisBlack,
        systemNavigationBarColor: irisBlack,
      ),
      child: Scaffold(
        backgroundColor: irisBlack,
        body: SafeArea(
          child: Column(
            children: [
              // ENCABEZADO
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/iris_eye_logo.jpg',
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IRIS VISION',
                          style: TextStyle(
                            color: irisYellow,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'La cámara que habla',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.accessibility_new,
                      color: Colors.white,
                      size: 28,
                    ),
                  ],
                ),
              ),

              // VISOR: CÁMARA O FOTOGRAFÍA
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(14, 5, 14, 12),
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF202020),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFF383838),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (capturedPhoto != null)
                        Image.file(
                          File(capturedPhoto!.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      else if (cameraReady &&
                          cameraController != null &&
                          cameraController!.value.isInitialized)
                        CameraPreview(cameraController!)
                      else
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.camera_alt_outlined,
                                color: irisYellow,
                                size: 75,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                cameraError != null
                                    ? 'CÁMARA NO DISPONIBLE'
                                    : 'INICIANDO CÁMARA',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  cameraError ??
                                      'Preparando asistencia visual...',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // INDICADOR DE FOTOGRAFÍA
                      if (capturedPhoto != null)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.photo_camera,
                                  color: irisYellow,
                                  size: 17,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'IMAGEN CAPTURADA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // INDICADOR DE CAPTURA / ANÁLISIS
                      if (isCapturing)
                        const Center(
                          child: CircularProgressIndicator(color: irisYellow),
                        ),

                      // ESQUINAS DEL VISOR
                      const Positioned(
                        top: 18,
                        left: 18,
                        child: CameraCorner(top: true, left: true),
                      ),
                      const Positioned(
                        top: 18,
                        right: 18,
                        child: CameraCorner(top: true, left: false),
                      ),
                      const Positioned(
                        bottom: 18,
                        left: 18,
                        child: CameraCorner(top: false, left: true),
                      ),
                      const Positioned(
                        bottom: 18,
                        right: 18,
                        child: CameraCorner(top: false, left: false),
                      ),
                    ],
                  ),
                ),
              ),

              // INDICADOR DE VOZ
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isListening ? Icons.mic : Icons.mic_off,
                      color: irisYellow,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const SoundWave(),
                  ],
                ),
              ),

              // BOTONES PRINCIPALES
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 10, 28, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ControlButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Galería',
                      onPressed: () {
                        showMessage(
                          'La galería estará disponible próximamente.',
                        );
                      },
                    ),

                    // BOTÓN CENTRAL DEL MICRÓFONO
                    Semantics(
                      button: true,
                      label: listeningEnabled
                          ? 'Detener reconocimiento de voz'
                          : 'Activar reconocimiento de voz',
                      child: GestureDetector(
                        onTap: () async {
                          if (listeningEnabled) {
                            listeningEnabled = false;
                            restartPending = false;

                            pendingRecognitionTimer?.cancel();
                            pendingRecognitionTimer = null;
                            pendingRecognizedWords = '';

                            await speech.stop();

                            if (mounted) {
                              setState(() {
                                isListening = false;
                              });
                            }
                          } else {
                            if (processingVoiceCommand ||
                                isCapturing ||
                                isSpeaking ||
                                !appInForeground ||
                                !appHasFocus) {
                              return;
                            }

                            listeningEnabled = true;

                            await startListening();
                          }
                        },
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: irisYellow,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: irisYellow.withValues(alpha: 0.25),
                                blurRadius: 22,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Center(
                            child: isCapturing
                                ? const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Icon(
                                    listeningEnabled
                                        ? Icons.mic
                                        : Icons.mic_off,
                                    color: Colors.black,
                                    size: 43,
                                  ),
                          ),
                        ),
                      ),
                    ),

                    ControlButton(
                      icon: Icons.more_horiz,
                      label: 'Opciones',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: irisPanel,
                          builder: (context) {
                            return const SafeArea(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'OPCIONES',
                                      style: TextStyle(
                                        color: irisYellow,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                    Text(
                                      'Aquí agregaremos las configuraciones de IRIS.',
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
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
}

// ==========================================
// BOTONES SECUNDARIOS
// ==========================================

class ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Column(
        children: [
          SizedBox(
            width: 66,
            height: 66,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: irisPanel,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              child: Icon(icon, size: 30),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ESQUINAS DE LA CÁMARA
// ==========================================

class CameraCorner extends StatelessWidget {
  final bool top;
  final bool left;

  const CameraCorner({super.key, required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ONDA DE SONIDO
// ==========================================

class SoundWave extends StatelessWidget {
  const SoundWave({super.key});

  @override
  Widget build(BuildContext context) {
    const heights = [
      9.0,
      16.0,
      11.0,
      23.0,
      14.0,
      29.0,
      18.0,
      24.0,
      12.0,
      20.0,
      8.0,
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: heights.map((height) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 4,
          height: height,
          decoration: BoxDecoration(
            color: irisYellow,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }).toList(),
    );
  }
}
