# syntax=docker/dockerfile:1

# 不指定 --platform=$BUILDPLATFORM：
# Buildx 会让此阶段使用 --platform 指定的目标架构
FROM alpine:3.22 AS builder

ARG TENGINE_VERSION=3.1.0
ARG TONGSUO_VERSION=8.4.0

RUN apk add --no-cache \
    build-base \
    cmake \
    perl \
    perl-dev \
    curl \
    ca-certificates \
    linux-headers \
    openssl-dev \
    pcre2-dev \
    zlib-dev

WORKDIR /tmp/build

RUN curl -fsSL "https://github.com/alibaba/tengine/archive/refs/tags/${TENGINE_VERSION}.tar.gz" \
        -o tengine.tar.gz \
    && curl -fsSL "https://github.com/Tongsuo-Project/Tongsuo/archive/refs/tags/${TONGSUO_VERSION}.tar.gz" \
        -o tongsuo.tar.gz \
    && tar xzf tengine.tar.gz \
    && tar xzf tongsuo.tar.gz

WORKDIR /tmp/build/tengine-${TENGINE_VERSION}

RUN ./configure \
    --prefix=/usr/local/nginx \
    --add-module=modules/ngx_tongsuo_ntls \
    --with-openssl=/tmp/build/Tongsuo-${TONGSUO_VERSION} \
    --with-openssl-opt='--api=1.1.1 enable-ntls enable-sm2 enable-sm3 enable-sm4' \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_sni \
    --with-cc-opt="-Wno-error" \
    && make -j"$(nproc)" \
    && make install

# 运行阶段跟随目标平台
FROM alpine:3.22 AS runtime

RUN apk add --no-cache \
    pcre2 \
    zlib

COPY --from=builder /usr/local/nginx /usr/local/nginx

RUN mkdir -p /usr/local/nginx/conf/certs

ENV PATH="/usr/local/nginx/sbin:${PATH}"

EXPOSE 80 443
STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]

