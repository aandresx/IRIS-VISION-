# Bitácora de Desarrollo — Decisiones y Desviaciones del Plan

Este documento es mantenido exclusivamente por el **agente programador** (coordinado por `CLAUDE_desarrollo.md`) para registrar formalmente cada cambio, decisión de arquitectura, optimización o desviación respecto a las especificaciones originales de los hitos.

---

## Estructura de Entradas
Cada entrada debe registrarse con la siguiente plantilla:

```markdown
### [AAAA-MM-DD] — H<NN>: <Título Breve del Cambio o Decisión>
- **Hito afectado:** H<NN>_<nombre>
- **Tipo:** Decisión técnica | Desviación de alcance | Optimización | Corrección de bug
- **Descripción:** <Explicación concisa de lo que se decidió o modificó>
- **Motivo / Justificación:** <Por qué fue necesario el cambio y qué impacto tiene>
- **Impacto en entregables:** <Archivos o resultados afectados>
```

---

## Historial de Entradas

### [2026-11-06] — H00: Cierre de Planificación y Definición del Paradigma Voice-First
- **Hito afectado:** H01 a H08 (Marco General del Proyecto)
- **Tipo:** Decisión técnica de arquitectura
- **Descripción:** Se integró formalmente la interacción 100% por voz (*Voice-First*) sin botones táctiles en pantalla para los 3 modos de operación (Navegación, Descripción de Escena y Búsqueda de Objetos Caídos), tras la retroalimentación del usuario en la Ronda 1.
- **Motivo / Justificación:** Las personas con ceguera total enfrentan serias dificultades ergonómicas para acertar a botones táctiles en la pantalla del smartphone mientras caminan. La voz local embebida (sin datos móviles) garantiza autonomía y accesibilidad universal.
- **Impacto en entregables:** Se creó el hito H04 dedicado a STT/TTS offline y se reestructuró H06 para coordinar los tres modos funcionales.
