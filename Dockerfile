# https://catalog.ngc.nvidia.com/orgs/nvidia/containers/cuda
#  - see: "LATEST CUDA XXXX"
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.description="Up-to-date CUDA container built to be a one-click runnable Hashtopolis agent to use on Vast.ai with interruptible instance support."
LABEL org.opencontainers.image.source=https://github.com/bcherb2/vast-hashtopolis-runner
LABEL org.opencontainers.image.version="0.4.0"
LABEL vast.ai.compatible="true"
LABEL vast.ai.cuda.version="12.8.0"

ENV DEBIAN_FRONTEND=NONINTERACTIVE

RUN apt update && apt-get upgrade -y && apt install -y --no-install-recommends \
  zip \
  git \
  python3 \
  python3-psutil \
  python3-pip \
  python3-requests \
  pciutils \
  autossh \
  jq \
  curl \
  rsync \
  screen \
  tmux \
  htop \
  wget \
  p7zip-full && \
  rm -rf /var/lib/apt/lists/*

# Download and install the latest hashcat binary from GitHub
RUN HASHCAT_VERSION=6.2.6 && \
    cd /tmp && \
    wget -O hashcat.7z https://github.com/hashcat/hashcat/releases/download/v${HASHCAT_VERSION}/hashcat-${HASHCAT_VERSION}.7z && \
    7z x hashcat.7z && \
    rm hashcat.7z && \
    mv hashcat-${HASHCAT_VERSION} /opt/hashcat && \
    ln -s /opt/hashcat/hashcat.bin /usr/local/bin/hashcat

ENV VAST_AI_OPTIMIZED=true
ENV SUPPORTS_INTERRUPTION=true
ENV AUTO_RESTART=true


RUN groupadd -g 1001 hashtopolis-user && \
    useradd -g 1001 -u 1001 -m hashtopolis-user -s /bin/bash && \
    echo 'hashtopolis-user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers && \
    mkdir -p /home/hashtopolis-user/.ssh && \
    chown -R hashtopolis-user:hashtopolis-user /home/hashtopolis-user/

COPY scripts/vast-startup.sh /usr/local/bin/vast-startup.sh
COPY scripts/setup-wizard.sh /usr/local/bin/setup-wizard.sh
RUN chmod +x /usr/local/bin/vast-startup.sh /usr/local/bin/setup-wizard.sh

USER hashtopolis-user
WORKDIR /home/hashtopolis-user

RUN mkdir -p htpclient

#RUN git clone https://github.com/hashtopolis/agent-python.git && \
#  cd agent-python && \
#  ./build.sh && \
#  mv hashtopolis.zip ../ && \
#  cd ../ && rm -R agent-python

CMD ["/usr/local/bin/vast-startup.sh"]
