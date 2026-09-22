# llama.cpp Docker 版编译与使用指南（GTX 950M 4GB / i3-7350K / 20GB DDR4）

## 硬件与方案要点

| 项目 | 参数 | 影响 |
|---|---|---|
| GPU | GTX 950M 4GB（Maxwell，计算能力 5.0） | llama.cpp CUDA 后端仍支持（要求 CC ≥ 5.0），但**必须用 CUDA 12.x 或 11.8**，CUDA 13 已放弃 Maxwell |
| CPU | i3-7350K（Kaby Lake） | 支持 AVX2，CPU 推理路径没问题 |
| 内存 | 20GB DDR4 | 足够把 7B Q4 模型放内存，部分层卸载到 GPU |

4GB 显存的实际定位：
- **3B 级模型（Q4_K_M，约 2GB）**：全部层放 GPU（`-ngl 99`），速度最好
- **7B 级模型（Q4_K_M，约 4.3GB）**：放不进 4GB 显存，只能卸载一部分层（`-ngl` 从 10 起试），其余走 CPU
- Maxwell 没有 Tensor Core、不支持 FlashAttention，别指望跑大上下文高频吞吐

## 一、准备环境（宿主机）

需要：NVIDIA 驱动 + Docker + nvidia-container-toolkit（Linux 原生环境）。

```bash
# 1. 确认驱动支持的 CUDA 版本
nvidia-smi   # 右上角 "CUDA Version" 字样
#   >= 12.2  -> 按默认 Dockerfile 编译即可
#   < 12.2   -> 加 --build-arg CUDA_VERSION=11.8.0
#   GTX 950M 的最终驱动约在 546.x 分支 (支持到 CUDA 12.3)，一般没问题

# 2. 安装 nvidia-container-toolkit（Debian/Ubuntu）
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -sL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# 3. 验证容器内能看到 GPU
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

> Windows 用户注意：如果想在 Windows + Docker Desktop (WSL2) 上跑，WSL 的 GPU 直通对 Maxwell 老卡支持很差，很可能容器里 `nvidia-smi` 看不到卡。GTX 950M 这套配置**强烈建议装原生 Linux**（Ubuntu 22.04/24.04）跑 Docker。

## 二、编译

### 方式 A：云端编译（推荐，本机编译慢时用）

CUDA 编译不需要 GPU 在场，GitHub Actions 免费 runner（4 核）约 10 分钟编完，产物自动推到 GHCR：

1. 在 GitHub 新建**公开**仓库（公开仓库 GHCR 存储/流量免费无限制）
2. 把本目录内容推上去（包含 `.github/workflows/docker.yml`）
3. Actions 自动触发构建，完成后目标机器直接拉取：

```bash
docker pull ghcr.io/<你的用户名>/<仓库名>:latest

# 之后运行（同方式 B 的 docker run，只是镜像名换成上面的）
```

手动触发可换参数（Actions 页面 → Run workflow）：CUDA 版本（驱动旧选 11.8.0）、llama.cpp 版本 tag。

### 方式 B：本机编译

```bash
cd llama-docker
docker build -t llama-cuda-950m .

# 驱动较旧时（nvidia-smi 显示 CUDA < 12.2）:
docker build --build-arg CUDA_VERSION=11.8.0 -t llama-cuda-950m .

# 想固定 llama.cpp 版本（推荐，避免 master 突变）:
# docker build --build-arg LLAMA_TAG=b4750 -t llama-cuda-950m .
```

只编译 sm_50 一个架构：云端 runner 约 10 分钟；本机 i3-7350K 双核四线程约 20~40 分钟。

## 三、下载模型（示例）

```bash
mkdir -p ~/models && cd ~/models
# 3B 级：显存放得下，推荐
wget https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf
# 或 7B 级：需部分卸载
# wget https://huggingface.co/bartowski/Llama-3.1-8B-Instruct-GGUF/...
```

## 四、运行

```bash
# 3B 模型：全部层进 GPU
docker run --gpus all --rm -it \
  -v ~/models:/models -p 8080:8080 \
  llama-cuda-950m \
  -m /models/qwen2.5-3b-instruct-q4_k_m.gguf \
  -ngl 99 -c 2048 --host 0.0.0.0 --port 8080

# 7B 模型：部分卸载（-ngl 从 10 开始往上加，直到显存接近用满）
docker run --gpus all --rm -it \
  -v ~/models:/models -p 8080:8080 \
  llama-cuda-950m \
  -m /models/llama-3.1-8b-q4_k_m.gguf \
  -ngl 14 -c 2048 --no-mmap --host 0.0.0.0 --port 8080
```

启动后浏览器打开 `http://localhost:8080` 即是内置 WebUI。

## 五、调优建议

- `-ngl`：最大可设到显存接近 4GB 上限；OOM 就往回降
- `-c` 上下文：4GB 显存别开太大，2048~4096 合理
- `--no-mmap`：旧驱动下 mmap 偶尔有问题，加上更稳
- 7B 模型在 950M + i3-7350K 上预计 3~6 token/s；3B 模型约 8~15 token/s
- 如果容器启动报 `no kernel image available for execution on the device`，说明编译时架构没对上——确认 `CMAKE_CUDA_ARCHITECTURES=50`（950M 是 5.0，不是 5.2）
