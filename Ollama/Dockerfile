# Dockerfile
FROM ollama/ollama:latest


# Или если образ debian-based (но ollama alpine)

# Предотвращаем интерактивные запросы при установке
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_BREAK_SYSTEM_PACKAGES=1 

RUN <<'EOT' bash
    mkdir -p /mnt/host
    echo -e "\nPS1='\[\\\033[01;32m\][\$?] \d \\\t \${debian_chroot:+(\$debian_chroot)}\[\\\033[01;32m\]\u@\h\[\\\033[00m\]:\[\\\033[01;34m\]\w\[\\\033[00m\]\\\n\\$ '" | tee -a /root/.bashrc
    echo "export PIP_BREAK_SYSTEM_PACKAGES=1" >> /root/.bashrc
    echo "export LANG=ru_RU.UTF-8" >> /root/.bashrc
    echo "export LC_ALL=ru_RU.UTF-8" >> /root/.bashrc
    echo '[ -e /mnt/host/.bashrc ] && source /mnt/host/.bashrc' >> /root/.bashrc
    echo 'export HISTFILE="/mnt/host/.bash_history"'  >> /root/.bashrc
    echo "PROMPT_COMMAND='history -a; history -n'"  >> /root/.bashrc
source /root/.bashrc
    apt update
    apt install -y locales
    locale-gen ru_RU.UTF-8
    update-locale LANG=ru_RU.UTF-8
    apt install -y \
        curl \
        vim \
        iputils-ping \
        jq \
        tree \
        mc
    mkdir -p /etc/ollama/custom
    ln -s /etc/ollama/custom /mnt/host/ollama-configs
    apt-get clean
    rm -rf /var/lib/apt/lists/*
EOT

ENV LANG=ru_RU.UTF-8
ENV LANGUAGE=ru_RU:ru
ENV LC_ALL=ru_RU.UTF-8

# Создаем рабочую директорию
WORKDIR /mnt/host

# CMD ["tail", "-f", "/dev/null"]
# ENTRYPOINT ["/bin/sh", "-c", "/usr/bin/ollama serve"]
ENTRYPOINT ["ollama", "serve"]
