# speedtest-cdn — Docker 镜像
#
# 构建:
#   docker build -t speedtest-cdn -f docker/Dockerfile .
#
# 运行(完整流程):
#   docker run --rm -v ./data:/app/data -v ./reports:/app/reports speedtest-cdn
#
# 运行(快速模式):
#   docker run --rm -v ./data:/app/data -v ./reports:/app/reports speedtest-cdn --quick
#
# 或用 docker compose:
#   cd docker && docker compose up --build

FROM node:20-slim

LABEL org.opencontainers.image.title="speedtest-cdn"
LABEL org.opencontainers.image.description="CDN speedtest node discover / update / verify pipeline"

WORKDIR /app

# 仅需 Node 内置模块, 无 npm 依赖
COPY lib/ ./lib/
COPY scripts/ ./scripts/
COPY package.json ./

RUN mkdir -p data reports

# 默认执行完整流程; 可通过 docker run ... --quick 等参数覆盖
ENTRYPOINT ["node", "scripts/pipeline.mjs"]
CMD []
