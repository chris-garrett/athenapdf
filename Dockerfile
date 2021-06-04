#########################################
# ./cli/Dockerfile.build
#########################################

FROM node:14.17.0-alpine3.13 as athena-cli-builder
MAINTAINER Arachnys <techteam@arachnys.com>

RUN mkdir -p /athenapdf/build/artifacts/
WORKDIR /athenapdf/

COPY cli/package.json /athenapdf/
RUN npm install

COPY cli/package.json /athenapdf/build/artifacts/
RUN cp -r /athenapdf/node_modules/ /athenapdf/build/artifacts/

COPY cli/src /athenapdf/build/artifacts/
RUN npm run build:linux

CMD ["/bin/sh"]

#########################################
# ./cli/Dockerfile
#########################################

FROM debian:buster-slim as athena-cli
LABEL maintainer="Arachnys <techteam@arachnys.com>"

RUN echo 'deb http://httpredir.debian.org/debian/ stable main contrib non-free' >> /etc/apt/sources.list

RUN apt-get -yq update && \
    apt-get -yq install \
        wget \
        xvfb \
        libasound2 \
        libgconf-2-4 \
        libgtk2.0-0 \
        libnotify4 \
        libnss3 \
        libxss1 \
        libxtst6 \
        culmus \
        fonts-beng \
        fonts-dejavu \
        fonts-hosny-amiri \
        fonts-lklug-sinhala \
        fonts-lohit-guru \
        fonts-lohit-knda \
        fonts-samyak-gujr \
        fonts-samyak-mlym \
        fonts-samyak-taml \
        fonts-sarai \
        fonts-sil-abyssinica \
        fonts-sil-padauk \
        fonts-telu \
        fonts-thai-tlwg \
        fonts-liberation \
        fonts-unfonts-core \
        fonts-wqy-zenhei \
        ttf-mscorefonts-installer \
    && fc-cache -f -v \
    && apt-get -yq autoremove \
    && apt-get -yq clean \
    && rm -rf /var/lib/apt/lists/* \
    && truncate -s 0 /var/log/*log

COPY cli/fonts.conf /etc/fonts/conf.d/100-athena.conf

COPY --from=athena-cli-builder /athenapdf/build/athenapdf-linux-x64/ /athenapdf/
WORKDIR /athenapdf/

ENV PATH /athenapdf/:$PATH

COPY cli/entrypoint.sh /athenapdf/entrypoint.sh

RUN mkdir -p /converted/
WORKDIR /converted/

CMD ["athenapdf"]

ENTRYPOINT ["/athenapdf/entrypoint.sh"]

#########################################
# ./weaver/Dockerfile.build
#########################################

FROM golang:1.15-alpine as athena-weaver-builder
WORKDIR /go/src/github.com/arachnys/athenapdf/weaver

RUN apk add --update git build-base
# RUN go get -u github.com/golang/dep/cmd/dep

# COPY Gopkg.lock Gopkg.toml ./
# RUN dep ensure --vendor-only -v

COPY weaver ./

RUN \
  CGO_ENABLED=0 go build -v -o weaver .

CMD ["/bin/sh"]

#########################################
# ./weaver/Dockerfile
#########################################

FROM athena-cli
LABEL maintainer="Arachnys <techteam@arachnys.com>"

ENV GIN_MODE release

RUN \
  wget https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_amd64.deb \
  && dpkg -i dumb-init_*.deb \
  && rm dumb-init_*.deb \
  && mkdir -p /athenapdf-service/tmp/

COPY --from=athena-weaver-builder /go/src/github.com/arachnys/athenapdf/weaver/weaver /athenapdf-service/
WORKDIR /athenapdf-service/

ENV PATH /athenapdf-service/:$PATH

COPY weaver/conf/ /athenapdf-service/conf/

EXPOSE 8080

CMD ["dumb-init", "weaver"]

ENTRYPOINT ["/athenapdf-service/conf/entrypoint.sh"]
