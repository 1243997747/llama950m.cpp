# =============================================================================
# llama.cpp Docker 编译镜像 —— 专为 GTX 950M (Maxwell, 计算能力 5.0) 定制
#
# 用法（在装有 NVIDIA 驱动 + nvidia-container-toolkit 的 Linux 上）:
#   docker build -t llama-cuda-950m .
#
# 注意:
#   - CUDA 13.x 已放弃 Maxwell 架构, 因此这里用 CUDA 12.2
#   - 如果宿主机驱动较旧 (nvidia-smi 显示 CUDA Version < 12.2),
#     改用 11.8: docker build --build-arg CUDA_VERSION=11.8.0 -t llama-cuda-950m .
#   - 只编译 sm_50 一个架构, 编译时间大幅缩短
# =============================================================================

ARG CUDA_VERSION=12.2.0
ARG UBUNTU_VERSION=22.04

# ---------- 构建阶段 ----------
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        cmake \
        build-essential \
        libgomp1 \
        libopenblas-dev \
    && rm -rf /var/lib/apt/lists/*

# 可通过 --build-arg LLAMA_TAG=b1234 固定到某个 release tag
ARG LLAMA_TAG=master
WORKDIR /opt
RUN git clone --depth 1 --branch ${LLAMA_TAG} https://github.com/ggml-org/llama.cpp

WORKDIR /opt/llama.cpp
RUN cmake -B build \
        -DGGML_CUDA=ON \
        -DCMAKE_CUDA_ARCHITECTURES=50 \
        -DGGML_BLAS=ON \
        -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --config Release -j"$(nproc)" \
        --target llama-server llama-cli

# ---------- 运行阶段 ----------
FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgomp1 \
        libopenblas0 \
    && rm -rf /var/lib/apt/lists/*

# 从构建阶段拷贝 cuBLAS（runtime 基础镜像默认不含）
COPY --from=builder /usr/local/cuda/lib64/libcublas.so* /usr/local/cuda/lib64/
COPY --from=builder /usr/local/cuda/lib64/libcublasLt.so* /usr/local/cuda/lib64/

# 拷贝可执行文件
COPY --from=builder /opt/llama.cpp/build/bin/ /app/bin/

WORKDIR /app
ENV PATH="/app/bin:${PATH}"
EXPOSE 8080

# 默认启动 llama-server, 参数在 docker run 时追加
ENTRYPOINT ["llama-server"]
