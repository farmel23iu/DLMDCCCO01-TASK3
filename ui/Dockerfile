# Copyright (c) 2023 Cisco Systems, Inc. and its affiliates All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

FROM --platform=linux/amd64 node:18-alpine AS build
WORKDIR /bankapp
COPY package.json package-lock.json ./
RUN npm ci --silent
COPY . ./
RUN npm run build

FROM --platform=linux/amd64 nginxinc/nginx-unprivileged:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /bankapp/dist /usr/share/nginx/html
COPY --from=build /bankapp/src/assets /usr/share/nginx/html/src/assets
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
