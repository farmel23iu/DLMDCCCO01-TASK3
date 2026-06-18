# Copyright (c) 2023 Cisco Systems, Inc. and its affiliates All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

FROM node:22-bookworm-slim
WORKDIR /usr/src/app
COPY ./package*.json /usr/src/app/
RUN npm ci --omit=dev
COPY . ./
EXPOSE 8001
CMD ["npm", "start"]
