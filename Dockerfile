FROM ubuntu:20.04

MAINTAINER tukiyo3 <tukiyo3@gmail.com>

# パッケージインストール用 (コンテナサイズを小さく保つ)
RUN { \
	echo " apt update \\"; \
	# 容量を抑えるための --no-install-recommends オプション
	echo " && DEBIAN_FRONTEND=noninteractive apt install --no-install-recommends -y \$@ \\"; \
	echo " && apt clean \\"; \
	echo " && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*"; \
    } > /usr/local/bin/pkgadd.sh \
  && chmod +x /usr/local/bin/pkgadd.sh

# 必須
RUN pkgadd.sh \
        # 一般ユーザー用
        sudo \
        # 64bit版wine
        wine64 \
        # 音
	pulseaudio \
        # winetricks
        winetricks \
        ca-certificates \
        xz-utils \
        # 日本語フォント
        fonts-vlgothic

# あると便利
RUN pkgadd.sh \
        wget \
        nkf \
        unzip \
        lhasa

RUN \
	# 日本語入力のためにlocaleパッケージが必要
	pkgadd.sh locales \
	# 言語: ja_JP.UTF-8
	&& locale-gen ja_JP.UTF-8 \
	&& echo "LC_ALL=ja_JP.UTF-8\nLANG=ja_JP.UTF-8" > /etc/default/locale \
	# timezone
	&& cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
	&& echo "Asia/Tokyo" > /etc/timezone \
	\
	# sudoグループはパスワードを不要に
	&& echo "%sudo ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/group_sudo \
	# sudo時のエラー対策 -> "sudo: setrlimit(RLIMIT_CORE): Operation not permitted"
	&& echo "Set disable_coredump false" >> /etc/sudo.conf

# wine を動かす一般ユーザー作成
RUN adduser --disabled-password --gecos sudo wine \
 && ln -s /home/wine/.wine/drive_c /c \
 && mkdir -p /run/user/1000 \
 && chown -R 1000:1000 /run/user/1000

USER wine
ENV USER wine
ENV LC_ALL=ja_JP.UTF-8 LANG=ja_JP.UTF-8
ENV DISPLAY :0.0
ENV WINEARCH=win64
# pulseaudio
ENV PULSE_SERVER unix:/run/user/1000/pulse/native
# fcitx
ENV XMODIFIERS="@im=fcitx"
ENV GTK_IM_MODULE=fcitx
ENV QT_IM_MODULE=fcitx
ENV XIMPROGRAM=fcitx

RUN wineboot -i
RUN winetricks fonts fakejapanese_vlgothic


# video
VOLUME ["/tmp/.X11-unix"]
# audio
#VOLUME ["/run/user/1000/pulse/native"]
# data
VOLUME ["/c/host"]

WORKDIR /c/host

CMD echo '\
docker run -it \
 --rm \
 --name=wine64 \
 \
 -e DISPLAY=$DISPLAY \
 -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
 -v $HOME/.Xauthority:/home/wine/.Xauthority \
 \
 -v /run/user/$(id -u)/pulse/native:/run/user/1000/pulse/native \
 -v /dev/snd:/dev/snd --privileged \
 \
 -v $PWD:/c/host/ \
 tukiyo3/wine64 /bin/bash \
'
