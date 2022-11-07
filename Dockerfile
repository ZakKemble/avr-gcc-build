FROM debian:bullseye

WORKDIR /avr-gcc-build

# ENV JOBCOUNT=

COPY avr-gcc-build.sh ./
RUN chmod +x ./avr-gcc-build.sh

RUN apt update
RUN apt -y install wget make mingw-w64 gcc g++ bzip2 xz-utils git autoconf texinfo libgmp-dev

CMD ["./avr-gcc-build.sh"]
