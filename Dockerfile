FROM ubuntu:22.04

WORKDIR /app

# 安装依赖
RUN apt update && apt install -y --no-install-recommends \
    git cmake build-essential \
    && rm -rf /var/lib/apt/lists/*

# 下载源码
RUN git clone https://github.com/ggerganov/llama.cpp .

# 【关键】关闭CUDA编译！用官方编译方式，不报错！
RUN cmake -B build -DGGML_CUDA=OFF
RUN make -C build -j4

WORKDIR /app/build/bin
ENTRYPOINT ["./llama-server"]
