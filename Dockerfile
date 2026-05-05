# 基础镜像：CUDA 12.1 是支持老显卡比较稳妥的版本
FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

# 1. 安装系统依赖
RUN apt update && apt install -y \
    cmake \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# 2. 拉取官方最新源码（注意这里修正了 URL）
# 截至 2026 年 5 月，主仓库在 ggml-org
RUN git clone https://github.com/ggml-org/llama.cpp /llama

# 3. 编译配置 (关键步骤：开启 CUDA 并锁定 sm_50 架构)
WORKDIR /llama
RUN cmake -B build \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES=50 \  # 这一行是 GTX950M 的命门
    -DCMAKE_BUILD_TYPE=Release \

# 4. 编译 llama-server
RUN cmake --build build --config Release -j$(nproc)

# 5. 启动设置
WORKDIR /llama/build/bin
ENTRYPOINT ["./llama-server"]
