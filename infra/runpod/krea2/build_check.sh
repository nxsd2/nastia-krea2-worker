#!/bin/bash
# Проверка образа фото-воркера на сборке (RUN в Dockerfile): ComfyUI стартует на CPU и
# грузит пакеты узлов; каждый class_type воркера полигона
# (`krea_workflow.PLAYGROUND_WORKER_CLASS_TYPES` — список ниже сверяет тест
# backend/tests/test_krea2_worker_image.py) есть в коде ComfyUI или пакета; веса
# MediaPipe на месте; узлы Ostris-Edit (выкат 4, как на полигоне) и LoRA проб лиц —
# не меньше, чем строк в списке (секрет сборки; число — /nastia/face_loras.count) (имена не печатаются: содержимое владельца).
# Не так — сборка падает.
set -uo pipefail
cd /comfyui
log=$(mktemp)
timeout 600 python main.py --quick-test-for-ci --cpu >"$log" 2>&1
status=$?
grep -E "seconds( \(IMPORT FAILED\))?: /comfyui/custom_nodes/" "$log" || true
if [ $status -ne 0 ]; then
  tail -60 "$log"
  echo "build_check: ComfyUI не стартовал (код $status)"
  exit 1
fi
failed=0
# Пакеты узлов полигона.
PACKS="comfyui-krea2edit ComfyUI-Inpaint-CropAndStitch ComfyUI-Krea2-Ostris-Edit"
for pack in $PACKS; do
  if ! grep -qE "seconds: /comfyui/custom_nodes/$pack\$" "$log"; then
    echo "build_check: пакет $pack не загрузился"
    failed=1
  fi
done
# class_type воркера полигона: где-то в коде ядра (comfy_extras) или пакетов.
CLASS_TYPES="Krea2EditGroundedEncode Krea2EditModelPatch TextEncodeKrea2OstrisEdit Krea2OstrisEditModelPatch InpaintCropImproved InpaintStitchImproved LoadMediaPipeFaceLandmarker MediaPipeFaceLandmarker MediaPipeFaceMask ComfyMathExpression ColorTransfer MaskComposite"
for class_type in $CLASS_TYPES; do
  if ! grep -rqsF --include='*.py' "$class_type" /comfyui/comfy_extras /comfyui/nodes.py /comfyui/custom_nodes; then
    echo "build_check: узла $class_type нет ни в ядре, ни в пакетах"
    failed=1
  fi
done
# Узлы Ostris-Edit (полигон, пробы лиц) — именно в своём пакете.
OSTRIS_CLASS_TYPES="TextEncodeKrea2OstrisEdit Krea2OstrisEditModelPatch"
for class_type in $OSTRIS_CLASS_TYPES; do
  if ! grep -qsF --include='*.py' -r "\"$class_type\"" /comfyui/custom_nodes/ComfyUI-Krea2-Ostris-Edit; then
    echo "build_check: узла $class_type нет в ComfyUI-Krea2-Ostris-Edit"
    failed=1
  fi
done
[ -s /comfyui/models/detection/mediapipe_face_fp32.safetensors ] || { echo "build_check: нет весов MediaPipe"; failed=1; }
# LoRA проб лиц: файлов (непустых) не меньше, чем строк в списке (число пишет шаг LoRA).
want=$(cat /nastia/face_loras.count 2>/dev/null || true); want=${want:-0}
have=$(find /comfyui/models/loras/identity -maxdepth 1 -type f -name '*.safetensors' -size +0 2>/dev/null | wc -l)
if [ "$want" -lt 1 ] || [ "$have" -lt "$want" ]; then
  echo "build_check: LoRA проб лиц — файлов $have из $want"
  failed=1
else
  echo "build_check: LoRA проб лиц — $have из $want"
fi
if [ $failed -ne 0 ]; then
  grep -iE "error|traceback|cannot import|No module" "$log" | head -40
  exit 1
fi
[ -f /nastia/worker_start.sh ] || { echo "build_check: нет старт-скрипта"; exit 1; }
cd /comfyui && echo "build_check: ок, ComfyUI $(git describe --tags 2>/dev/null)"
rm -f "$log"
