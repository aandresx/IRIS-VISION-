
const express = require("express");

const app = express();
const PORT = 3000;

const MODEL = "gemini-3.5-flash-lite";

const GEMINI_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

const ALLOWED_MIME_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp"
];

// ==========================================
// FUNCIONES AUXILIARES
// ==========================================

function getApiKey() {
  return process.env.GEMINI_API_KEY;
}

function getImageMimeType(value) {
  return ALLOWED_MIME_TYPES.includes(value) ? value : null;
}

function extractGeminiText(result) {
  return (
    result.candidates?.[0]?.content?.parts || []
  )
    .map(part => part.text || "")
    .join("\n")
    .trim();
}

async function sendToGemini(contents, maxOutputTokens = 220) {
  const apiKey = getApiKey();

  if (!apiKey) {
    throw new Error("Falta configurar la clave API de Gemini.");
  }

  const response = await fetch(GEMINI_URL, {
    method: "POST",

    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey
    },

    body: JSON.stringify({
      contents,

      generationConfig: {
        temperature: 0.3,
        maxOutputTokens
      }
    }),

    signal: AbortSignal.timeout(60000)
  });

  const result = await response.json();

  if (!response.ok) {
    const detail =
      result.error?.message || "Error desconocido de Gemini.";

    console.error("Error HTTP de Gemini:", response.status);
    console.error("Detalle:", detail);

    const error = new Error(detail);
    error.status = 502;
    throw error;
  }

  const text = extractGeminiText(result);

  if (!text) {
    console.error(
      "Gemini no devolvió texto.",
      result.promptFeedback?.blockReason ||
      result.candidates?.[0]?.finishReason ||
      "Sin detalle"
    );

    const error = new Error("Gemini no pudo generar una respuesta.");
    error.status = 502;
    throw error;
  }

  return text;
}

function sendError(res, error, defaultMessage) {
  console.error("Error:", error.message);

  if (error.name === "TimeoutError" ||
      error.name === "AbortError") {
    return res.status(504).json({
      success: false,
      error: "Gemini tardó demasiado en responder."
    });
  }

  return res.status(error.status || 500).json({
    success: false,
    error: error.status
      ? error.message
      : defaultMessage
  });
}

// ==========================================
// COMPROBAR ESTADO DEL SERVIDOR
// ==========================================

app.get("/health", (req, res) => {
  res.json({
    estado: "correcto",
    mensaje: "Servidor de IRIS VISION funcionando",
    motor: "Gemini",
    modelo: MODEL
  });
});

// ==========================================
// ANALIZAR UNA FOTOGRAFÍA NUEVA
// ==========================================

app.post(
  "/analyze",

  express.raw({
    type: ALLOWED_MIME_TYPES,
    limit: "12mb"
  }),

  async (req, res) => {
    const startedAt = Date.now();

    try {
      if (!getApiKey()) {
        return res.status(500).json({
          success: false,
          error: "Falta configurar la clave API de Gemini."
        });
      }

      if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
        return res.status(400).json({
          success: false,
          error: "No se recibió ninguna fotografía."
        });
      }

      const mimeType = getImageMimeType(
        (req.headers["content-type"] || "")
          .split(";")[0]
          .trim()
      );

      if (!mimeType) {
        return res.status(400).json({
          success: false,
          error: "El formato de la fotografía no es compatible."
        });
      }

      const imageBase64 = req.body.toString("base64");

      console.log("------------------------------------");
      console.log("Nueva fotografía recibida.");
      console.log("Tamaño:", req.body.length, "bytes");
      console.log("Enviando fotografía a Gemini...");

      const description = await sendToGemini([
        {
          role: "user",
          parts: [
            {
              text: `
Eres el asistente visual de IRIS VISION,
diseñado para ayudar a personas ciegas
o con baja visión.

Describe esta fotografía en español,
de manera clara, natural y breve.

Menciona los objetos principales, sus colores,
su ubicación relativa y los detalles importantes.

Utiliza frases sencillas y naturales,
apropiadas para escucharse mediante voz.

No inventes objetos, distancias ni información
que no puedas confirmar visualmente.

Si algo no se distingue, dilo con honestidad.

No incluyas introducciones innecesarias.
Comienza directamente con la descripción.
              `
            },
            {
              inline_data: {
                mime_type: mimeType,
                data: imageBase64
              }
            }
          ]
        }
      ], 220);

      const elapsed = ((Date.now() - startedAt) / 1000).toFixed(1);

      console.log("Descripción generada correctamente.");
      console.log("Tiempo:", elapsed, "segundos");
      console.log("Descripción:", description);
      console.log("------------------------------------");

      return res.json({
        success: true,
        description
      });

    } catch (error) {
      return sendError(
        res,
        error,
        "No fue posible analizar la fotografía."
      );
    }
  }
);

// ==========================================
// PREGUNTAS SOBRE LA FOTOGRAFÍA ACTUAL
// ==========================================

app.post(
  "/ask",
  express.json({ limit: "16mb" }),

  async (req, res) => {
    const startedAt = Date.now();

    try {
      if (!getApiKey()) {
        return res.status(500).json({
          success: false,
          error: "Falta configurar la clave API de Gemini."
        });
      }

      const {
        imageBase64,
        mimeType: requestedMimeType,
        question,
        history
      } = req.body || {};

      if (
        typeof imageBase64 !== "string" ||
        imageBase64.length === 0
      ) {
        return res.status(400).json({
          success: false,
          error: "No se recibió la fotografía de referencia."
        });
      }

      const mimeType = getImageMimeType(requestedMimeType);

      if (!mimeType) {
        return res.status(400).json({
          success: false,
          error: "El formato de la fotografía no es compatible."
        });
      }

      if (
        typeof question !== "string" ||
        question.trim().length === 0
      ) {
        return res.status(400).json({
          success: false,
          error: "No se recibió ninguna pregunta."
        });
      }

      if (question.length > 2000) {
        return res.status(400).json({
          success: false,
          error: "La pregunta es demasiado larga."
        });
      }

      // Solo aceptamos mensajes de usuario y del modelo.
      // Limitamos el historial para evitar conversaciones excesivas.
      const safeHistory = Array.isArray(history)
        ? history
            .filter(message =>
              message &&
              ["user", "model"].includes(message.role) &&
              typeof message.text === "string" &&
              message.text.trim().length > 0
            )
            .slice(-12)
            .map(message => ({
              role: message.role,
              parts: [
                {
                  text: message.text.slice(0, 2000)
                }
              ]
            }))
        : [];

      console.log("------------------------------------");
      console.log("Pregunta sobre la fotografía actual.");
      console.log("Pregunta:", question.trim());
      console.log("Mensajes de contexto:", safeHistory.length);
      console.log("Enviando pregunta e imagen a Gemini...");

      // La imagen original se incluye en cada consulta.
      // Así Gemini puede volver a observarla para responder.
      const contents = [
        {
          role: "user",
          parts: [
            {
              text: `
Esta es la fotografía que debes utilizar como referencia
durante toda esta conversación.

Eres IRIS VISION, un asistente visual para personas
ciegas o con baja visión.

Responde las preguntas del usuario en español,
con lenguaje natural, claro y apropiado para escucharse
mediante voz.

Basa tus respuestas exclusivamente en lo que se pueda
observar en la fotografía.

No inventes colores, objetos, características,
identidades, distancias ni detalles que no sean visibles.

Si algo no se puede distinguir o confirmar,
explícalo con honestidad.

Cuando el usuario haga una pregunta de seguimiento,
ten en cuenta los mensajes anteriores y la fotografía.

Responde directamente, sin saludos ni introducciones
innecesarias.
              `
            },
            {
              inline_data: {
                mime_type: mimeType,
                data: imageBase64
              }
            }
          ]
        },

        ...safeHistory,

        {
          role: "user",
          parts: [
            {
              text: question.trim()
            }
          ]
        }
      ];

      const answer = await sendToGemini(contents, 220);

      const elapsed = ((Date.now() - startedAt) / 1000).toFixed(1);

      console.log("Respuesta generada correctamente.");
      console.log("Tiempo:", elapsed, "segundos");
      console.log("Respuesta:", answer);
      console.log("------------------------------------");

      return res.json({
        success: true,
        answer
      });

    } catch (error) {
      return sendError(
        res,
        error,
        "No fue posible responder la pregunta sobre la fotografía."
      );
    }
  }
);

// ==========================================
// INICIAR SERVIDOR
// ==========================================

app.listen(PORT, "0.0.0.0", () => {
  console.log("------------------------------------");
  console.log(" IRIS VISION - SERVIDOR INICIADO");
  console.log("------------------------------------");
  console.log("Puerto:", PORT);
  console.log("Motor de inteligencia artificial: Gemini");
  console.log("Modelo:", MODEL);
  console.log(`Estado: http://localhost:${PORT}/health`);
  console.log("Ruta de fotografías: POST /analyze");
  console.log("Ruta de preguntas: POST /ask");
  console.log("------------------------------------");
});
