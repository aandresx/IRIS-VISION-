

import torch
import numpy as np
from PIL import Image
from transformers import AutoImageProcessor, AutoModelForDepthEstimation
import torch.nn.functional as F

MODELO = "depth-anything/Depth-Anything-V2-Metric-Indoor-Small-hf"

print("Cargando modelo...")
procesador = AutoImageProcessor.from_pretrained(MODELO)

modelo = AutoModelForDepthEstimation.from_pretrained(
    MODELO,
    dtype=torch.float16
).to("cuda")

modelo.eval()

ruta = input("\nEscribe la ruta de tu fotografía: ").strip().strip('"')

imagen = Image.open(ruta).convert("RGB")
ancho, alto = imagen.size

print("\nFotografía:", ancho, "x", alto)
print("Calculando profundidad...")

entradas = procesador(images=imagen, return_tensors="pt")
entradas = {
    clave: valor.to("cuda", dtype=torch.float16)
    if valor.is_floating_point()
    else valor.to("cuda")
    for clave, valor in entradas.items()
}

with torch.inference_mode():
    salida = modelo(**entradas)

profundidad = F.interpolate(
    salida.predicted_depth.unsqueeze(1),
    size=(alto, ancho),
    mode="bicubic",
    align_corners=False
).squeeze().float().cpu().numpy()

# Guardar valores numéricos de profundidad
np.save("profundidad_metros.npy", profundidad)

# Crear imagen visual normalizada
limite_min = np.percentile(profundidad, 2)
limite_max = np.percentile(profundidad, 98)

normalizada = np.clip(
    (profundidad - limite_min) /
    max(limite_max - limite_min, 1e-6),
    0, 1
)

mapa = (normalizada * 255).astype(np.uint8)
Image.fromarray(mapa).save("mapa_profundidad.png")

print("\n================================")
print("RESULTADOS")
print("================================")
print("Profundidad mínima:", round(float(np.min(profundidad)), 2), "m")
print("Profundidad media:", round(float(np.mean(profundidad)), 2), "m")
print("Profundidad máxima:", round(float(np.max(profundidad)), 2), "m")
print("\nArchivos generados:")
print("- mapa_profundidad.png")
print("- profundidad_metros.npy")
print("\nPRUEBA TERMINADA")

