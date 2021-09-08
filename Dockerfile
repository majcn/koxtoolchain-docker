# kindle, kindle5, kindlepw2, kobo, nickel, remarkable, cervantes, pocketbook, bookeen
ARG TARGET=kobo

# Base image
FROM debian:buster-slim AS base

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        git unzip build-essential gperf help2man bison texinfo flex \
        gawk autoconf automake wget curl file libncurses-dev libtool-bin && \
    rm -rf /var/lib/apt/lists/*


# Build image
FROM base AS build_toolchain

ARG TARGET

RUN useradd -m tc
USER tc
WORKDIR /home/tc

RUN git clone https://github.com/koreader/koxtoolchain && \
    cd koxtoolchain && \
    ./gen-tc.sh ${TARGET} && \
    rm -rf build


# Go image
FROM base AS install_go

RUN curl https://dl.google.com/go/go1.17.linux-amd64.tar.gz -o /tmp/go.tar.gz && \
    rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz


# Final image
FROM base AS final

ARG TARGET

WORKDIR /project

COPY --from=build_toolchain /home/tc/x-tools/ /home/tc/x-tools/
COPY --from=build_toolchain /home/tc/koxtoolchain/refs/x-compile.sh /home/tc/bin/x-compile.sh
COPY --from=install_go /usr/local/go/ /usr/local/go/

# CMD script
RUN echo '#!/bin/bash\n\
\n\
set -a\n\
HOME=/home/tc source /home/tc/bin/x-compile.sh ${TARGET} env bare\n\
set +a\n\
\n\
export CC=$CROSS_TC-gcc\n\
export CXX=$CROSS_TC-g++\n\
export STRIP=$CROSS_TC-strip\n\
export AR=$CROSS_TC-gcc-ar\n\
export RANLIB=$CROSS_TC-gcc-ranlib\n\
\n\
export GOOS="linux"\n\
export GOARCH="arm"\n\
export CGO_ENABLED="1"\n\
\n\
/usr/local/go/bin/go build -ldflags "-s -w" $1' > /home/tc/bin/exec && chmod +x /home/tc/bin/exec

CMD ["/home/tc/bin/exec"]