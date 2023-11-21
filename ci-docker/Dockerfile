ARG PERL_VERSION="5.38"
ARG THREADS=""

FROM quay.io/simcop2387/perl-debug-containers:${PERL_VERSION}-main${THREADS}-bookworm-backports

RUN apt update && apt install -y libssl-dev git
COPY ./ /install/
WORKDIR /install/ci-docker/
RUN cpanm Dist::Zilla
RUN cpanm --notest --from file://$PWD/vendor/cache --installdeps . || cpanm --from file://$PWD/vendor/cache --notest IO::Async
RUN cpanm --notest --from file://$PWD/vendor/cache --installdeps . || cpanm --notest --installdeps .

WORKDIR /install/
#carton install --cpanfile cpanfile.ci --cached || cpanm --notest --force IO::Async || carton install --cpanfile cpanfile.ci --cached
RUN dzil authordeps --missing | xargs cpanm
RUN dzil listdeps --missing | xargs cpanm
RUN dzil test
