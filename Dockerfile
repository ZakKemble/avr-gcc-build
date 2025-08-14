FROM debian:bookworm-slim
LABEL repo="https://github.com/ZakKemble/avr-gcc-build"

WORKDIR /avr-gcc-build

RUN apt update \
	&& apt -y install \
		wget \
		make \
		mingw-w64 \
		gcc \
		g++ \
		bzip2 \
		xz-utils \
		autoconf \
		texinfo \
		libgmp-dev \
		libmpfr-dev \
		libexpat1-dev \
	&& apt clean \
	&& rm -rf /var/lib/apt/lists/*

COPY --chmod=755 avr-gcc-build.sh entrypoint.sh .


# Bind mounts from Windows are very slow and seriously impacts build time.
# So instead of directly mounting the directory that the toolchains are
# built into (/avr-gcc-build/build/), we mount to a different directory (/output/)
# and move the toolchains across only once building has completed.

ENV BASE=/avr-gcc-build/build/

ENTRYPOINT ["./entrypoint.sh"]
