FROM debian:bookworm-slim
LABEL repo="https://github.com/ZakKemble/avr-gcc-build"

WORKDIR /avr-gcc-build

RUN apt update && \
	apt -y install wget make mingw-w64 gcc g++ bzip2 xz-utils autoconf texinfo libgmp-dev libmpfr-dev

COPY avr-gcc-build.sh .
RUN chmod +x avr-gcc-build.sh


# Bind mounts from Windows are very slow and seriously impacts build time.
# So instead of directly mounting the directory that the toolchains are
# built into (/avr-gcc-build/build/), we mount to a different directory (/output/)
# and move the toolchains across only once building has completed.

ENV BASE=/avr-gcc-build/build/

CMD ./avr-gcc-build.sh \
	; echo "Moving toolchains to /output/..." \
	; mv ${BASE}* /output/ \
	; mv ./avr-gcc-build.log /output/ \
	; echo "Done"
