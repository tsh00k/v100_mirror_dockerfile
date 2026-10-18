ARG CUDA_IMAGE=nvcr.io/nvidia/cuda:11.8.0-devel-ubuntu22.04
FROM ${CUDA_IMAGE}

ARG APT_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/ubuntu
ARG MINICONDA_URL=https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-py312_25.1.1-2-Linux-x86_64.sh
ARG MINICONDA_SHA256=4766d85b5f7d235ce250e998ebb5a8a8210cbd4f2b0fea4d2177b3ed9ea87884
ARG PYTORCH_WHEEL_ROOT=https://mirror.sjtu.edu.cn/pytorch-wheels/cu118

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

RUN sed -Ei \
      "s#https?://archive.ubuntu.com/ubuntu/?#${APT_MIRROR}/#g; \
       s#https?://security.ubuntu.com/ubuntu/?#${APT_MIRROR}/#g" \
      /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      bash-completion \
      build-essential \
      bzip2 \
      ca-certificates \
      cmake \
      curl \
      dnsutils \
      fd-find \
      ffmpeg \
      git \
      git-lfs \
      gnupg \
      htop \
      iproute2 \
      iputils-ping \
      jq \
      less \
      libgl1 \
      libglib2.0-0 \
      libsndfile1 \
      locales \
      lsof \
      nano \
      net-tools \
      netcat-openbsd \
      ninja-build \
      openssh-client \
      openssh-server \
      pciutils \
      pkg-config \
      procps \
      psmisc \
      ripgrep \
      rsync \
      strace \
      sudo \
      tar \
      tini \
      tmux \
      tree \
      tzdata \
      unzip \
      usbutils \
      vim \
      wget \
      xz-utils \
      zip \
    && git lfs install --system \
    && rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "${MINICONDA_URL}" -o /tmp/miniconda.sh \
    && echo "${MINICONDA_SHA256}  /tmp/miniconda.sh" | sha256sum -c - \
    && bash /tmp/miniconda.sh -b -p /opt/conda \
    && rm -f /tmp/miniconda.sh

COPY condarc /etc/conda/.condarc
COPY pip.conf /etc/pip.conf

ENV PATH=/opt/conda/bin:${PATH}

RUN conda create -y --override-channels -c conda-forge \
      -n lerobot python=3.12 pip 'setuptools<82' wheel \
    && conda clean -afy

ENV PATH=/opt/conda/envs/lerobot/bin:/opt/conda/bin:${PATH} \
    CONDA_DEFAULT_ENV=lerobot \
    CONDA_PREFIX=/opt/conda/envs/lerobot

COPY requirements-lerobot.txt /tmp/requirements-lerobot.txt

RUN python -m pip install --no-cache-dir \
      "${PYTORCH_WHEEL_ROOT}/torch-2.7.1%2Bcu118-cp312-cp312-manylinux_2_28_x86_64.whl#sha256=91454dcfdb81f181fdf216d6d6d9912fbd8795578b90384b3b8b8132737072bb" \
      "${PYTORCH_WHEEL_ROOT}/torchvision-0.22.1%2Bcu118-cp312-cp312-manylinux_2_28_x86_64.whl#sha256=e4a8696261b8c64297a2683656f4ee64418d7ee391627702fe5c06b72ce81123" \
      "${PYTORCH_WHEEL_ROOT}/torchaudio-2.7.1%2Bcu118-cp312-cp312-manylinux_2_28_x86_64.whl#sha256=6b64a313866b2a5bb43d4c6906e8820d3dc844f89a97c00dc5c8b92e6b70fe17" \
    && python -m pip check

RUN python -m pip install --no-cache-dir -r /tmp/requirements-lerobot.txt \
    && python -m pip check \
    && rm -f /tmp/requirements-lerobot.txt

COPY assets/vla-v100.pub /root/.ssh/authorized_keys
COPY config/sshd_config /etc/ssh/sshd_config_v100
COPY scripts/entrypoint.sh /usr/local/bin/v100-entrypoint
COPY scripts/check_environment.py /usr/local/share/v100-image/check_environment.py
COPY scripts/enable-public-mirrors.sh /usr/local/share/v100-image/enable-public-mirrors.sh

RUN chmod 0700 /root/.ssh \
    && chmod 0600 /root/.ssh/authorized_keys \
    && chmod 0755 /usr/local/bin/v100-entrypoint \
    && chmod 0644 /usr/local/share/v100-image/check_environment.py \
    && chmod 0644 /usr/local/share/v100-image/enable-public-mirrors.sh \
    && printf '\nsource /opt/conda/etc/profile.d/conda.sh\nconda activate lerobot\n' >> /root/.bashrc \
    && python /usr/local/share/v100-image/check_environment.py --imports-only

WORKDIR /root

EXPOSE 22

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/v100-entrypoint"]
CMD ["/usr/sbin/sshd", "-D", "-e", "-f", "/etc/ssh/sshd_config_v100"]

