FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

# 安装依赖
RUN apt update && apt install -y cmake build-essential git

# 克隆 llama.cpp (使用官方最新地址)
RUN git clone https://github.com/ggml-org/llama.cpp /llama

# 编译（GTX950M sm_50）
WORKDIR /llama
# 配置阶段：生成构建文件到 build 目录
RUN cmake -B build \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES=50 \
    -DCMAKE_BUILD_TYPE=Release

# 执行编译阶段
# 1. 先切到 build 目录
WORKDIR /llama/build
# 2. 执行编译。CMake 官方推荐的并行编译参数是 --parallel，完美替代 -j$(nproc)
RUN cmake --build . --config Release --parallel

# 启动
# 编译好的可执行文件就在当前目录(bin)下
WORKDIR
