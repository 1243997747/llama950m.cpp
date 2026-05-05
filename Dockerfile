FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

# 安装依赖
RUN apt update && apt install -y cmake build-essential git

# 克隆 llama.cpp (使用官方最新地址)
RUN git clone https://github.com/ggml-org/llama.cpp /llama

# 编译（GTX950M sm_50）
WORKDIR /llama
# 注意：下面每一行的反斜杠 \ 后面绝对不能有空格或注释！
RUN cmake -B build \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES=50 \
    -DCMAKE_BUILD_TYPE=Release

# 执行编译
RUN cmake --build build --config Release -j$(nproc)

# 启动
WORKDIR /llama/build/bin
ENTRYPOINT ["./llama-server"]
