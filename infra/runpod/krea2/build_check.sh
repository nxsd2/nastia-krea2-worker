#!/bin/bash
# Проверка образа фото-воркера на сборке (RUN в Dockerfile): ComfyUI стартует на CPU и
# грузит пакеты узлов; каждый class_type воркера полигона
# (`krea_workflow.PLAYGROUND_WORKER_CLASS_TYPES` — список ниже сверяет тест
# backend/tests/test_krea2_worker_image.py) есть в коде ComfyUI или пакета; веса
# MediaPipe на месте. Не так — сборка падает.
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
PACKS="comfyui-krea2edit ComfyUI-Inpaint-CropAndStitch"
for pack in $PACKS; do
  if ! grep -qE "seconds: /comfyui/custom_nodes/$pack\$" "$log"; then
    echo "build_check: пакет $pack не загрузился"
    failed=1
  fi
done
# class_type воркера полигона: где-то в коде ядра (comfy_extras) или пакетов.
CLASS_TYPES="Krea2EditGroundedEncode Krea2EditModelPatch InpaintCropImproved InpaintStitchImproved LoadMediaPipeFaceLandmarker MediaPipeFaceLandmarker MediaPipeFaceMask ComfyMathExpression ColorTransfer MaskComposite"
for class_type in $CLASS_TYPES; do
  if ! grep -rqsF --include='*.py' "$class_type" /comfyui/comfy_extras /comfyui/nodes.py /comfyui/custom_nodes; then
    echo "build_check: узла $class_type нет ни в ядре, ни в пакетах"
    failed=1
  fi
done
[ -s /comfyui/models/detection/mediapipe_face_fp32.safetensors ] || { echo "build_check: нет весов MediaPipe"; failed=1; }
if [ $failed -ne 0 ]; then
  grep -iE "error|traceback|cannot import|No module" "$log" | head -40
  exit 1
fi
[ -f /nastia/worker_start.sh ] || { echo "build_check: нет старт-скрипта"; exit 1; }
cd /comfyui && echo "build_check: ок, ComfyUI $(git describe --tags 2>/dev/null)"
rm -f "$log"
