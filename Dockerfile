ARG NGINX_TAG=release-1.30.0

FROM alpine:3.23 AS builder

ARG NGINX_TAG

RUN apk add --no-cache \
    build-base \
    ca-certificates \
    git \
    libmaxminddb-dev \
    linux-headers \
    openssl-dev \
    pcre-dev \
    zlib-dev

RUN git clone --branch ${NGINX_TAG} --depth 1 https://github.com/nginx/nginx.git /src/nginx
RUN git clone --depth 1 https://github.com/leev/ngx_http_geoip2_module.git /src/ngx_http_geoip2_module
RUN git clone --depth 1 https://github.com/openresty/headers-more-nginx-module.git /src/headers_more_nginx_module
RUN git clone --depth 1 https://github.com/openresty/xss-nginx-module.git /src/xss_nginx_module
RUN git clone --depth 1 https://github.com/fdintino/nginx-upload-module.git /src/nginx_upload_module

WORKDIR /src/nginx

RUN ./auto/configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --with-compat \
    --with-file-aio \
    --with-threads \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --add-dynamic-module=/src/ngx_http_geoip2_module \
    --add-dynamic-module=/src/headers_more_nginx_module \
    --add-dynamic-module=/src/xss_nginx_module \
    --add-dynamic-module=/src/nginx_upload_module \
    && make -j$(nproc) \
    && make install

FROM alpine:3.23

RUN apk add --no-cache \
    ca-certificates \
    libmaxminddb \
    openssl \
    pcre \
    zlib \
    && addgroup -S nginx \
    && adduser -S -G nginx -H -s /sbin/nologin nginx

COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/lib/nginx/modules /usr/lib/nginx/modules

RUN mkdir -p /var/log/nginx /var/cache/nginx \
    && chown -R nginx:nginx /var/log/nginx /var/cache/nginx \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 443

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]
