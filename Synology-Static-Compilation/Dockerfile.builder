# cat /proc/cpuinfo | grep "model name" | uniq && uname -m
# проверить версию GLIBC:
# /lib/libc.so.6 
# Версия в контейнере не должна быть выше версии на хосте, иначе хост не сможет
# запустить собранную версию Питона. На NAS GLIBC 2.36
# Используем либо Ubuntu 22.04 LTS (Jammy) - GLIBC 2.35
# либо fedora:37 - GLIBC 2.36

# syntax=docker/dockerfile:1.4

# --- STAGE 1: Базовый образ (builder_base) ---
FROM fedora:37 AS builder_base

RUN <<'EOT'
GLIBC=$(/lib64/libc.so.6 | sed -n '/GNU C Library/ s/[^0-9]*\([0-9].*\)\./\1/p')
if [ "$GLIBC" != "2.36" ]; then
    echo "Ошибка: Неверная версия GLIBC=$GLIBC"
    exit 1
fi
EOT

WORKDIR /app

# Установка пакетов, необходимых для сборки
RUN <<'EOT' bash
# удаляем старый вид приглашения bash, и устанавливаем свой
#/bin/sed -i '/# set fallback PS1; only if currently set to upstream bash default/,/^$/d' /etc/bash.bashrc
#echo -e "\\\nPS1='\[\\\\\033[01;32m\][\$?] \d \\\\\t \\\${debian_chroot:+(\\\$debian_chroot)}\[\\\\\033[01;32m\]\u@\h\[\\\\\033[00m\]:\[\\\\\033[01;34m\]\w\[\\\\\033[00m\]\\\\\n\\$ '" | tee -a /root/.bashrc
echo -e "\nPS1='\[\\\033[01;32m\][\$?] \d \\\t \${debian_chroot:+(\$debian_chroot)}\[\\\033[01;32m\]\u@\h\[\\\033[00m\]:\[\\\033[01;34m\]\w\[\\\033[00m\]\\\n\\$ '" | tee -a /root/.bashrc
echo -e "export LANG=ru_RU.UTF-8\nexport LC_ALL=ru_RU.UTF-8\nexport LANGUAGE=ru:en_US\nexport TZ=Europe/Moscow" | tee -a /root/.bashrc
export LANG=ru_RU.UTF-8
export LC_ALL=ru_RU.UTF-8
export LANGUAGE=ru:en_US
export TZ=Europe/Moscow
dnf update -y
dnf install -y gcc make perl patch zlib-static zlib-devel bzip2-static bzip2-devel readline-static readline-devel sqlite sqlite-devel glibc-static glibc-devel libffi-devel xz-devel libstdc++-static wget
dnf install -y vim glibc-langpack-ru bash-completion git
# зависимости для сборки x11
sudo dnf install 'dnf-command(download)' rpm-build autoconf automake libtool pkgconfig git  libuuid-devel -y
# --- Ключ для проверки OpenSSL ---
gpg --keyserver hkps://keys.openpgp.org --recv-keys BA5473A2B0587B07FB27CF2D216094DFD0CB81EF
echo "BA5473A2B0587B07FB27CF2D216094DFD0CB81EF:6:" | gpg --import-ownertrust
# Установка средств проверки подписей для python
LATEST_VERSION=$(curl https://api.github.com/repos/sigstore/cosign/releases/latest | grep tag_name | cut -d : -f2 | tr -d "v\", ")
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-${LATEST_VERSION}-1.x86_64.rpm"
sudo rpm -ivh cosign-${LATEST_VERSION}-1.x86_64.rpm
mkdir -p /root/.local/bin/
ln -s /opt/host/make.sh  /root/.local/bin/make.sh
EOT

# --- STAGE 2: Образ для сборки Xauth (TARGET: builder_xauth) ---
# Используется как "чистая" среда, определенная в builder_base
FROM builder_base AS builder_xauth
CMD ["tail", "-f", "/dev/null"]

# --- STAGE 3: Образ для сборки X11 (TARGET: builder_x11) ---
# Используется ИЗ builder_base и ДОУСТАНАВЛИВАЕТ X11-devel пакеты
FROM builder_base AS builder_x11_env
# Устанавливаем ТОЛЬКО X11-специфичные пакеты. Этот слой кэшируется!
RUN <<'EOT' bash
sudo dnf groupinstall "Development Tools" -y >/dev/null
sudo dnf install -y tk-devel xorg-x11-util-macros libXdmcp-devel xorg-x11-xtrans-devel libX11-devel libXmu-devel libXext-devel libXau libXau-devel xmlto >/dev/null
EOT
CMD ["tail", "-f", "/dev/null"]

#dnf repoquery --requires --resolve @development-tools | grep -Ei 'xorg|x11|mesa|gtk|qt'
