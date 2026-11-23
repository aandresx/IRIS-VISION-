# MEMORIA.md — Memoria Técnica y Convenciones Duraderas del Proyecto

Este documento preserva las decisiones técnicas arquitectónicas, configuraciones de entorno, parámetros de calibración y convenciones de desarrollo acordadas. Es de lectura obligatoria al iniciar cualquier sesión de trabajo y se actualiza cada vez que una decisión duradera se consolida.

---

## 1. Identificación del Proyecto
- **Nombre:** Sistema de Asistencia Multimodal en Tiempo Real Basado en Visión Computacional en Dispositivos Edge AI para la Autonomía y Orientación de Personas con Discapacidad Visual (`asistencia_edge_ai`).
- **Destino Científico:** Revista indexada internacional JCR Q1/Q2 (candidata principal: *IEEE Access* / alternativa: *MDPI Sensors*).
- **Idioma del Artículo:** Inglés.
- **Horizonte Temporal:** 5 a 6 meses.

---

## 2. Decisiones de Arquitectura y Stack Tecnológico
- **Plataforma Objetivo:** Android Nativo (API Level 30+, Android 11.0 en adelante).
- **Lenguajes:**
  - **Kotlin 1.9+:** Lógica de aplicación, gestión del ciclo de vida, Foreground Services y máquina de estados.
  - **C++17:** Procesamiento matemático intensivo, visión por computadora, álgebra lineal y filtrado digital vía Android NDK (r25c+).
- **Visión por Computadora (Edge AI):**
  - **Modelo:** YOLOv5s cuantizado con Post-Training Quantization (PTQ INT8 / FP16) en formato TensorFlow Lite (`.tflite`).
  - **Resolución de Entrada:** $320 \times 320$ o $416 \times 416$ píxeles (compromiso velocidad vs. mAP).
  - **Aceleración:** GPU Delegate (OpenCL/Vulkan) o NNAPI Delegate, con fallback automático a CPU multihilo (4 hilos).
- **Filtro Cinemático y Estabilización:**
  - **Egomoción:** Flujo óptico piramidal Lucas-Kanade (`calcOpticalFlowPyrLK`) sobre puntos de interés y estimación de homografía con RANSAC en OpenCV C++.
  - **Filtro Digital:** Filtro de Kalman Lineal discreto en C++ (usando Eigen 3.4) acoplado a la aceleración y velocidad angular de la IMU para atenuar oscilaciones cíclicas de marcha humana (1 a 2 Hz).
- **Módulo Voice-First (STT/TTS):**
  - **STT Offline:** Vosk Android SDK con modelo acústico ligero en español (`vosk-model-small-es-0.42`, < 50 MB) o Sherpa-ONNX.
  - **TTS Offline:** Motor `TextToSpeech` nativo de Android con datos de voz descargados localmente.
- **Actuación Multimodal:**
  - **Háptica:** Modulación por ancho de pulsos (PWM virtual) ejecutada en el motor de vibración interno del smartphone (LRA) a través de `VibratorManager` y `VibrationEffect.Composition`.
  - **Audio 3D:** Renderizado binaural con Head-Related Transfer Functions (HRTF) a través de Google Resonance Audio SDK o biblioteca Oboe C++.

---

## 3. Convenciones de Coordenadas y Metrología
- **Sistema de Coordenadas de la Cámara (Convención OpenCV/Derecha):**
  - Eje $+X$: Hacia la derecha del campo visual.
  - Eje $+Y$: Hacia abajo en el plano de la imagen.
  - Eje $+Z$: Hacia el frente (profundidad perpendicular al sensor).
- **Sistema de Coordenadas de la IMU (Convención Android Sensor):**
  - Eje $+X$: Horizontal apuntando a la derecha de la pantalla.
  - Eje $+Y$: Vertical apuntando a la parte superior de la pantalla.
  - Eje $+Z$: Apuntando hacia afuera de la pantalla frontal.
- **Unidades:**
  - Distancias en metros ($\text{m}$).
  - Ángulos en grados sexagesimales ($^\circ$) o radianes ($\text{rad}$) con conversión explícita.
  - Tasa de refresco en fotogramas por segundo ($\text{FPS}$) y frecuencia en Hertz ($\text{Hz}$).

---

## 4. Parámetros de Calibración Base
- **Altura de Montaje Predeterminada ($H_c$):** $1.30\text{ m}$ (altura típica del pecho en bipedestación; ajustable por calibración inicial).
- **Umbrales Hápticos:**
  - Zona Segura: $D > 2.50\text{ m}$ (0% vibración).
  - Zona de Precaución: $1.20\text{ m} < D \le 2.50\text{ m}$ (tren de pulsos, frecuencia proporcional inversa a la distancia).
  - Zona de Peligro: $D \le 1.20\text{ m}$ (vibración continua máxima al 100%).
- **Calibración de Marcha para Búsqueda:** Tamaño medio de zancada estimado: $0.65\text{ m/paso}$.

---

## 5. Convenciones de Control de Versiones (Git)
- **Ramas:** Una rama por hito con el formato `hito/H<NN>-<nombre_corto>` (ej. `hito/H01-captura-sensores`).
- **Commits:** Mensajes con prefijo obligatorio `[H<NN>]`:
  - `[H01] Configurar servicio foreground de cámara con CameraX y buffer circular`
  - `[H03] Implementar modelo proyectivo de distancia monocular en C++`
- **Merge:** Solo se realiza merge a `main` tras la verificación satisfactoria de todos los criterios de aceptación del hito.
