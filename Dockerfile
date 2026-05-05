FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

WORKDIR /app

RUN apt update && apt install -y git cmake build-essential

RUN git clone https://github.com/ggerganov/llama.cpp .

# 关键：必须用 devel 镜像 + 正确算力
RUN cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=50
RUN make -C build -j4

WORKDIR /app/build/bin
ENTRYPOINT ["./llama-server"]
