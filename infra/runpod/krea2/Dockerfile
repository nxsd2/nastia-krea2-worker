# Образ фото-воркера Krea 2 (полигон фото, съёмка владельца и — по «боевой как полигон»,
# выкат 2 «персонаж целиком» — генерации людей).
#
# Сборка — GitHub Actions `.github/workflows/krea2-worker-image.yml` →
# ghcr.io/nexsidee/nastia-krea2-worker:<sha>. Контекст сборки — `infra/runpod/krea2/`.
# Шаблон RunPod на этот образ переключается отдельно, руками (сборка ничего не выкатывает).
#
# ❗️Образ ПУБЛИЧНЫЙ: в нём только открытый код (ComfyUI, пакеты узлов, наш старт-скрипт)
# и публичные веса поиска лица MediaPipe (Comfy-Org/mediapipe, Apache-2.0, 5,4 МБ). Ни
# секретов, ни моделей владельца, ни LoRA: модели — из кэша моделей RunPod на старте
# (`worker_start.sh`, HF-репо моделей).
#
# База — тот же образ, что у шаблонов полигона и боевого (RunPod API 15 ноя: оба
# `runpod/worker-comfyui:5.10.0-base-cuda12.8.1`, ComfyUI 0.34.0), закреплённая по digest.
# Отличия:
# * ComfyUI — тег v0.43.0 В ОБРАЗЕ (полигон поднимал его на каждом холодном старте
#   переменной COMFYUI_REF: git fetch + pip — секунды к старту и риск сети);
# * пакеты узлов полигона по закреплённым коммитам — те, чьи class_type перечислены в
#   `backend/src/infra/runpod/krea_workflow.py: PLAYGROUND_WORKER_CLASS_TYPES`:
#   - comfyui-krea2edit (lbouaraba) — Krea2EditGroundedEncode, Krea2EditModelPatch;
#   - ComfyUI-Inpaint-CropAndStitch (lquesada) — InpaintCropImproved, InpaintStitchImproved;
#   - узлы ядра 0.43 (MediaPipe-маска лица, ComfyMathExpression, ColorTransfer,
#     MaskComposite) — с ComfyUI; веса MediaPipe — models/detection/ (sha256 сверяется).
#   Список пакетов и список class_type сверяет `build_check.sh` и тест
#   `backend/tests/test_krea2_worker_image.py`;
# * обработчик — стоковый (картинки как раньше); старт — `worker_start.sh` (модели из
#   кэша моделей RunPod → папки ComfyUI), без обновления ComfyUI на старте.
ARG BASE_IMAGE=runpod/worker-comfyui:5.10.0-base-cuda12.8.1@sha256:45a1abd8796dbbcbc631f3d7d0db942946ce2f82ff24a070e3e6c527eeff9c47
FROM ${BASE_IMAGE}

ARG COMFYUI_REF=v0.43.0
ARG KREA2EDIT_SHA=13ef60f20828949becada815d3cbc371eb5ccaab
ARG CROP_STITCH_SHA=6005efc02f7745649118edd89cdd084c2b9bd3ae
# Веса поиска лица (узлы ядра MediaPipe) — с ревизией и sha256.
ARG MEDIAPIPE_URL=https://huggingface.co/Comfy-Org/mediapipe/resolve/f787efc1ad99492ec7d5b6564c0dd6c48d84ee49/detection/mediapipe_face_fp32.safetensors
ARG MEDIAPIPE_SHA256=a98c4806081d40eba35102a0f6dc0000c2e1388b72cf24e691703d0605bd888a

ENV NASTIA_COMFYUI_BAKED_REF=${COMFYUI_REF}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ComfyUI → тег. Пины transformers/huggingface-hub — как у стокового образа (5.x/1.x
# ломают старт ComfyUI); torch cu128 уже стоит и требованием `torch` не меняется.
RUN cd /comfyui \
    && git fetch -q --depth 1 origin "refs/tags/${COMFYUI_REF}:refs/tags/${COMFYUI_REF}" \
    && git -c advice.detachedHead=false checkout -q "${COMFYUI_REF}" \
    && uv pip install --python /opt/venv/bin/python -r requirements.txt \
         "transformers>=4.50.3,<5" "huggingface-hub<1.0" \
    && rm -rf /root/.cache/uv

# Пакеты узлов по коммитам (своих зависимостей сверх ComfyUI у них нет; есть
# requirements.txt — ставится).
RUN set -eux; \
    fetch() { git init -q "$1"; git -C "$1" remote add origin "$2"; \
              git -C "$1" fetch -q --depth 1 origin "$3"; git -C "$1" -c advice.detachedHead=false checkout -q FETCH_HEAD; \
              rm -rf "$1/.git"; \
              if [ -f "$1/requirements.txt" ]; then uv pip install --python /opt/venv/bin/python -r "$1/requirements.txt"; fi; }; \
    cd /comfyui/custom_nodes; \
    fetch comfyui-krea2edit https://github.com/lbouaraba/comfyui-krea2edit "${KREA2EDIT_SHA}"; \
    fetch ComfyUI-Inpaint-CropAndStitch https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch "${CROP_STITCH_SHA}"; \
    rm -rf /root/.cache/uv; \
    mkdir -p /comfyui/models/detection; \
    wget -q -O /comfyui/models/detection/mediapipe_face_fp32.safetensors "${MEDIAPIPE_URL}"; \
    echo "${MEDIAPIPE_SHA256}  /comfyui/models/detection/mediapipe_face_fp32.safetensors" | sha256sum -c -

COPY worker_start.sh build_check.sh /nastia/

# Проверка сборки: ComfyUI стартует на CPU и грузит пакеты узлов; нет пакета, узла из
# списка полигона или весов — сборка падает. SKIP_BUILD_CHECK=1 — только для сборки под
# эмуляцией (Mac: torch на qemu/Rosetta падает «Illegal instruction»); в GitHub Actions
# проверка идёт всегда.
ARG SKIP_BUILD_CHECK=0
RUN if [ "${SKIP_BUILD_CHECK}" = "1" ]; then echo "build_check пропущен (эмуляция)"; else bash /nastia/build_check.sh; fi

# Шаблон RunPod с этим образом: Container Start Command — пусто (или `bash /nastia/worker_start.sh`),
# переменную COMFYUI_REF можно убрать — ComfyUI уже на нужном теге.
CMD ["bash", "/nastia/worker_start.sh"]
