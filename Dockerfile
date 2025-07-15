# https://catalog.ngc.nvidia.com/orgs/nvidia/containers/cuda
#  - see: "LATEST CUDA XXXX"
# Use devel image for CUDA development tools needed to compile hashcat
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04

LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.description="Up-to-date CUDA container built to be a one-click runnable Hashtopolis agent to use on Vast.ai with interruptible instance support."
LABEL org.opencontainers.image.source=https://github.com/bcherb2/vast-hashtopolis-runner
LABEL org.opencontainers.image.version="0.4.0"
LABEL vast.ai.compatible="true"
LABEL vast.ai.cuda.version="12.2.2"

ENV DEBIAN_FRONTEND=NONINTERACTIVE

# Update package lists and install dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        git \
        build-essential \
        make \
        cmake \
        && \
    apt-get install -y --no-install-recommends \
        zip \
        p7zip-full \
        python3 \
        python3-psutil \
        python3-pip \
        python3-requests \
        pciutils \
        autossh \
        jq \
        rsync \
        screen \
        tmux \
        htop \
        opencl-headers \
        ocl-icd-libopencl1 \
        ocl-icd-opencl-dev \
        && \
    rm -rf /var/lib/apt/lists/*

# Build hashcat from source with CUDA support
RUN git clone https://github.com/hashcat/hashcat.git /tmp/hashcat && \
    cd /tmp/hashcat && \
    git checkout v6.2.6 && \
    make clean && \
    make ENABLE_CUDA=1 && \
    make install && \
    cd / && \
    rm -rf /tmp/hashcat && \
    mv /usr/local/bin/hashcat /usr/local/bin/hashcat-cuda

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
