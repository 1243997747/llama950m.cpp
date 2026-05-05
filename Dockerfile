FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

RUN apt update && apt install -y --no-install-recommends \
    git build-essential cmake nvidia-cuda-toolkit \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/ggerganov/llama.cpp /app && cd /app \
    && cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=50 \
    && make -C build -j4

WORKDIR /app/build/bin
ENTRYPOINT ["./llama-server"]
