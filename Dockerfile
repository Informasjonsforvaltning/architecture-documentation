FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y wget libgtk-3-0 libxss1 libasound2t64 xvfb

RUN wget https://github.com/jgraph/drawio-desktop/releases/download/v26.0.4/drawio-amd64-26.0.4.deb \
    && dpkg -i drawio-amd64-26.0.4.deb || apt-get install -f -y \
    && rm drawio-amd64-26.0.4.deb \
    && command -v drawio || (echo "Draw.io installation failed" && exit 1)

RUN rm -f drawio-amd64-26.0.4.deb

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]