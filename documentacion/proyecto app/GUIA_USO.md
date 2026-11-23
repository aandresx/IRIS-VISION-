# GUÍA DE USO — Cómo Continuar y Ejecutar el Proyecto

Esta guía explica detalladamente cómo continuar el proyecto en sesiones de trabajo independientes, qué archivos de coordinación utilizar, cómo ejecutar los hitos de ingeniería y cómo proceder con la redacción del artículo científico.

---

## 1. Sesión de Desarrollo e Implementación (Agente Programador)

Para comenzar a programar e implementar los hitos técnicos:
1. Abre una **nueva sesión de trabajo** en la carpeta raíz del proyecto (`c:\Users\jefer\OneDrive\Desktop\proyecto app`).
2. Indícale al asistente de IA en su primer mensaje:
   > *"Actúa como el agente desarrollador del proyecto siguiendo las instrucciones de [CLAUDE_desarrollo.md](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/CLAUDE_desarrollo.md). Vamos a comenzar con el hito H01."*
   *(Opcionalmente, puedes renombrar o copiar `CLAUDE_desarrollo.md` como `CLAUDE.md` en esa carpeta de trabajo).*
3. El agente programador consultará obligatoriamente [MEMORIA.md](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/MEMORIA.md) y [HITOS.md](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/hitos/HITOS.md) y comenzará por el primer hito de la ruta crítica: `H01_captura_sensores`.
4. El agente creará una rama git por hito (`hito/H01-captura-sensores`), escribirá el código en `desarrollo/codigo/`, ejecutará las pruebas y guardará los artefactos en `resultados/H01/`.

---

## 2. Sesión de Redacción Científica (Agente Editor)

Una vez que se hayan generado resultados experimentales en las carpetas `resultados/H<NN>/` (a partir de H02/H03 y H07/H08):
1. Abre una **nueva sesión de trabajo** independiente en esta misma carpeta.
2. Indícale al asistente de IA:
   > *"Actúa como el agente redactor del artículo científico siguiendo las instrucciones de [CLAUDE_articulo.md](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/CLAUDE_articulo.md). Revisa los resultados disponibles y actualiza el borrador del artículo."*
3. El agente consultará [guia_escritura.docx](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/articulo/guia_escritura.docx), [estado_del_arte.docx](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/planificacion/estado_del_arte.docx) y los datos reales en `resultados/` para reemplazar los marcadores de posición en [borrador_esquema.docx](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/articulo/borrador_esquema.docx), generando versiones incrementales `articulo/borrador_v1.docx`, `borrador_v2.docx`, etc.

---

## 3. Dinámica de Preguntas y Respuestas Durante la Ejecución

Si cualquiera de los agentes requiere consultar decisiones de diseño o afinamientos:
1. El agente generará un archivo `.docx` en `preguntas/desarrollo/` o `preguntas/articulo/`.
2. El agente notificará en el chat: *"Dejé la ronda en preguntas/. Marca [x] y escribe 'listo'."* y se detendrá.
3. Abre el archivo `.docx`, marca con `[x]` tus opciones elegidas (o escribe en "Otro" o en "Comentarios"), guarda el archivo y escribe simplemente:
   > `listo`

---

## 4. Dónde Monitorear el Avance del Proyecto

- **Estado de los Hitos:** Consulta la tabla resumen y diagrama de dependencias en [hitos/HITOS.md](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/hitos/HITOS.md).
- **Decisiones Técnicas y Desviaciones:** Lee la bitácora cronológica en [desarrollo/bitacora.md](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/desarrollo/bitacora.md).
- **Parámetros y Convenciones Duraderas:** Consulta [MEMORIA.md](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/MEMORIA.md).
- **Datos y Figuras Generadas:** Explora la carpeta [resultados/](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/resultados/).
- **Vista Rápida Global:** Consulta la sección *"Estado Actual"* en [README.md](file:///c:/Users/jefer/OneDrive/Desktop/proyecto%20app/README.md).

---

## 5. Cómo Replanificar si Cambia el Alcance

Si los requisitos del proyecto cambian, se añade hardware o se modifica la orientación de la publicación:
1. Abre una sesión con el agente planificador original (usando el planificador actual).
2. Escribe el comando rápido:
   > `regenerar hitos`
3. El planificador recalculará exclusivamente la carpeta `hitos/`, el diagrama de dependencias y `CLAUDE_desarrollo.md` para reflejar el nuevo alcance sin alterar el historial previo ni los insumos del usuario.
