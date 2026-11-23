# Sistema de Asistencia Multimodal en Tiempo Real Basado en Visión Computacional en Dispositivos Edge AI para Personas con Discapacidad Visual

> Sistema móvil de asistencia en lazo cerrado para smartphones comerciales que combina visión monocular (YOLOv5s) y sensores inerciales mediante un Filtro de Kalman cinemático, ofreciendo navegación segura, descripción visual del entorno y búsqueda guiada de objetos cotidianos mediante una interfaz *Voice-First* no invasiva (vibración PWM virtual y audio 3D binaural).

---

## Estado Actual
- **Fase del Proyecto:** Planificación completa finalizada. Listo para iniciar la fase de desarrollo.
- **Hito en Curso:** Ninguno (próximo a iniciar: `H01_captura_sensores`).
- **Estado de Manuscrito:** Borrador inicial y esquema estructurado disponible en `articulo/borrador_esquema.docx`.
- **Última Actualización:** 2026-11-06.

---

## Mapa de Carpetas del Proyecto

| Carpeta | Descripción | Responsable de Escritura |
|---|---|---|
| `/` (raíz) | Puerta de entrada, coordinación general, memoria técnica y guías de uso. | Planificador / Todos |
| `articulos/` | PDFs de los 10 trabajos científicos de referencia del estado del arte. | Usuario |
| `insumos/` | Anteproyecto, especificaciones iniciales y materiales aportados por el usuario. | Usuario |
| `preguntas/` | Rondas de preguntas y respuestas (.docx) para planificación, desarrollo y artículo. | Planificador / Dev / Artículo |
| `planificacion/` | Matriz del estado del arte, brecha, desafío, argumento central y bitácora de registro. | Planificador |
| `articulo/` | Guía de redacción, esquema borrador (.docx) y versiones sucesivas del artículo (`borrador_vN.docx`). | Planificador / Agente Artículo |
| `hitos/` | Índice de hitos (`HITOS.md`), diagrama de dependencias en Mermaid y especificaciones `H01` a `H08`. | Planificador |
| `desarrollo/` | Bitácora de desviaciones técnicas (`bitacora.md`) y código fuente modular (`codigo/`). | Agente Desarrollo (Programador) |
| `resultados/` | Mediciones empíricas, datos CSV, figuras gráficas y tablas por cada hito (`H01/` a `H08/`). | Agente Desarrollo (Programador) |

---

## Documentos Clave de Consulta Rápida

- [PROYECTO.md](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/PROYECTO.md): Explicación integral del proyecto, problema, objetivos, brecha, argumento central y arquitectura general.
- [GUIA_USO.md](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/GUIA_USO.md): Manual paso a paso de cómo iniciar las sesiones de desarrollo y de redacción del artículo.
- [hitos/HITOS.md](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/hitos/HITOS.md): Tabla de hitos, diagrama de dependencias sin ciclos, ruta crítica y stack técnico.
- [CLAUDE_desarrollo.md](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/CLAUDE_desarrollo.md): Guía de coordinación para el agente programador que ejecutará los hitos.
- [CLAUDE_articulo.md](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/CLAUDE_articulo.md): Guía de coordinación para el agente que redactará el manuscrito para revista Q1/Q2.
- [planificacion/estado_del_arte.docx](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/planificacion/estado_del_arte.docx): Matriz comparativa de 10 artículos, brecha, desafío, argumento y guía de análisis.
- [articulo/guia_escritura.docx](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/articulo/guia_escritura.docx): Normas de publicación IEEE Access, mensajes clave por sección y plan de figuras/tablas.
- [articulo/borrador_esquema.docx](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/articulo/borrador_esquema.docx): Borrador estructurado en inglés con secciones teóricas redactadas y huecos de resultados.
- [MEMORIA.md](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/MEMORIA.md): Decisiones técnicas duraderas, versiones de software, parámetros de calibración y convenciones git.
