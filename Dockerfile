FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

WORKDIR /app

# 安装依赖
RUN apt update && apt install -y --no-install-recommends \
    git cmake build-essential \
    && rm -rf /var/lib/apt/lists/*

# 下载源码
RUN git clone https://github.com/ggerganov/llama.cpp .

# 编译（sm_50 = GTX950M）
RUN cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=50
RUN make -C build -j4

WORKDIR /app/build/bin
ENTRYPOINT ["./llama-server"]
