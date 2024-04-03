FROM debian:latest

RUN apt-get update && apt-get install -y \
    hugo \
    git

WORKDIR /

RUN git clone https://github.com/sneakyHulk/heyn.dev.git

WORKDIR /heyn.dev

EXPOSE 1313

HEALTHCHECK --interval=3600s --timeout=20s --retries=3 \
    CMD git pull

CMD hugo server --bind="0.0.0.0" --watch --environment="production"