# 使用官方推荐的 CUDA 12 基础镜像
FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

# 安装编译依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 将当前目录（即克隆下来的 llama.cpp 源码）复制到容器内
COPY . .

# 编译 llama.cpp (开启 CUDA 并指定 sm_50 架构)
RUN cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=50 -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --config Release -j$(nproc)

# 设置启动入口（默认启动 API 服务器）
WORKDIR /app/build/bin
ENTRYPOINT ["./llama-server"]
