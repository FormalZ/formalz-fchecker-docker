FROM ubuntu:18.04 as build
ENV GAMESERVER_GIT_REPO_URL=https://github.com/e-ucm/formalz-fchecker.git
ENV GAMESERVER_GIT_REF=1.0.0
ENV PATH="/root/formalz/.local/bin:${PATH}"
RUN set -ex; \
  apt-get update && apt-get install -y --no-install-recommends \
    git \
    z3 \
    libz3-dev \
    zlib1g-dev \
    curl \
    netbase \
    build-essential \
    haskell-stack \
  ; \
  rm -rf /var/lib/apt/lists/; \
  mkdir /app; \
  git clone --depth 1 --branch ${GAMESERVER_GIT_REF} ${GAMESERVER_GIT_REPO_URL} /app; \
  stack upgrade --binary-only; \
  cd /app; \
  stack setup; \
  stack build; \
  stack install

FROM ubuntu:18.04
# grab tini for signal processing and zombie killing
ENV TINI_VERSION v0.18.0
RUN apt-get update && apt-get install -y --no-install-recommends \
	curl gpg dirmngr \
	&& curl -k -fSL "https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini" -o /usr/local/bin/tini \
	&& curl -k -fSL "https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini.asc" -o /usr/local/bin/tini.asc \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& for server in $(shuf -e ha.pool.sks-keyservers.net \
                            hkp://p80.pool.sks-keyservers.net:80 \
                            keyserver.ubuntu.com \
                            hkp://keyserver.ubuntu.com:80 \
                            pgp.mit.edu) ; do \
        gpg --keyserver "$server" --recv-keys  595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 && break || : ; \
    done \
	&& gpg --batch --verify /usr/local/bin/tini.asc /usr/local/bin/tini \
	&& rm -r "$GNUPGHOME" /usr/local/bin/tini.asc && unset GNUPGHOME \
	&& chmod +x /usr/local/bin/tini \
	# installation cleanup
	&& apt-get remove --purge -y curl \
  && apt-get clean \
  && rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*
ENTRYPOINT ["/usr/local/bin/tini", "--"]
RUN set -ex; \
  apt-get update; apt-get install -y --no-install-recommends \
    libz3-4 \
  ; \
  rm -rf /var/lib/apt/lists/ /tmp/* /var/tmp/*
COPY --from=build /root/.local/bin/javawlp /usr/local/bin
RUN useradd -ms /bin/bash formalz
USER formalz
CMD ["/usr/local/bin/javawlp"]
