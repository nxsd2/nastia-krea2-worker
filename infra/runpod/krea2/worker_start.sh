# Старт воркера Krea 2 (шаблон RunPod «nastia-krea2-worker», dockerStartCmd):
# модели из кэша моделей RunPod (HF-репо nexside/nastia-krea2) → папки ComfyUI.
#
# До 27 окт жил вне репо (tools/krea2/worker_start.sh). Отличия от той копии:
# + папка checkpoints — для CheckpointLoaderSimple (полигон: «Добавить файл»
#   кладёт чекпоинты в checkpoints/ репо моделей);
# + снимок репо — самый свежий: после «Edit Endpoint → Save» в кэше может
#   остаться и прежний снимок, а `ls | head -1` брал первый по алфавиту;
# + пустая папка не даёт битой ссылки «*»;
# − имена файлов в журнал воркера не печатаются (LoRA и модели — содержимое
#   владельца, правило 27 окт): только число файлов в каждой папке.
REPO_CACHE=/runpod-volume/huggingface-cache/hub/models--nexside--nastia-krea2
SNAP=$(ls -dt "$REPO_CACHE"/snapshots/*/ 2>/dev/null | head -1)
echo "krea2: snapshot=$(basename "${SNAP:-НЕТ}")"
if [ -z "$SNAP" ]; then ls -la /runpod-volume /runpod-volume/huggingface-cache/hub 2>&1 | head -20; fi
for d in diffusion_models checkpoints loras text_encoders vae; do
  mkdir -p /comfyui/models/$d
  n=0
  if [ -n "$SNAP" ] && [ -d "$SNAP$d" ]; then
    for f in "$SNAP$d"/*; do
      [ -e "$f" ] || continue
      ln -sf "$f" /comfyui/models/$d/ && n=$((n + 1))
    done
  fi
  echo "krea2: $d — файлов: $n"
done
exec /start.sh
