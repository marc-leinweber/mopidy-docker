# --- Build Node ---
FROM rust:slim-bullseye AS Builder

# Switch to the root user while we do our changes
USER root

# Install all libraries and needs
RUN apt update \
    && apt install -yq --no-install-recommends \
        git \
        patch \
        libgstreamer-plugins-base1.0-dev \
        libgstreamer1.0-dev \
        libcsound64-dev \
        libclang-11-dev \
        libpango1.0-dev  \
        libdav1d-dev \
        # libgtk-4-dev \ Only in bookworm
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/gst-plugins-rs

ARG GST_PLUGINS_RS_TAG=main
RUN git clone -c advice.detachedHead=false \
	--single-branch --depth 1 \
	--branch ${GST_PLUGINS_RS_TAG} \
	https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs.git ./

RUN sed -i 's/librespot = { version = "0.4", default-features = false }/librespot = { version = "0.4.2", default-features = false }/g' audio/spotify/Cargo.toml

ENV DEST_DIR /target/gst-plugins-rs
ENV CARGO_PROFILE_RELEASE_DEBUG false

RUN export CSOUND_LIB_DIR="/usr/lib/$(uname -m)-linux-gnu" \
    && export PLUGINS_DIR=$(pkg-config --variable=pluginsdir gstreamer-1.0) \
    && export SO_SUFFIX=so \
    && cargo build --release --no-default-features --config net.git-fetch-with-cli=true \
        # List of packages to build
        --package gst-plugin-spotify \
    # Use install command to create directory (-d), copy and print filenames (-v), and set attributes/permissions (-m)
    && install -v -d ${DEST_DIR}/${PLUGINS_DIR} \
    && install -v -m 755 target/release/*.${SO_SUFFIX} ${DEST_DIR}/${PLUGINS_DIR} \
    && cargo clean

# --- Release Node ---
FROM debian:bullseye-slim as Release

# Switch to the root user while we do our changes
USER root
WORKDIR /

# Install GStreamer and other required Debian packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        sudo \
        build-essential \
        curl \
        git \
        wget \
        gnupg2 \
        dumb-init \
        graphviz-dev \
        pulseaudio \
        libasound2-dev \
        libdbus-glib-1-dev \
        libgirepository1.0-dev \
        python3-dev \
        python3-gst-1.0 \
        python3-setuptools \
        python3-pip \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-libav \
        gstreamer1.0-pulseaudio \
    && rm -rf /var/lib/apt/lists/*
    
COPY --from=Builder /target/gst-plugins-rs/ /

RUN mkdir -p /etc/apt/keyrings \
    && wget -q -O /etc/apt/keyrings/mopidy-archive-keyring.gpg https://apt.mopidy.com/mopidy.gpg \
    && wget -q -O /etc/apt/sources.list.d/mopidy.list https://apt.mopidy.com/bullseye.list \
    && apt-get update \
    && apt-get install -y \ 
        mopidy \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --upgrade pip

RUN git clone --depth 1 --single-branch -b main https://github.com/mopidy/mopidy-spotify.git mopidy-spotify \
    && cd mopidy-spotify \
    && python3 setup.py install \
    && cd .. \
    && rm -rf mopidy-spotify
    
# Start helper script.
COPY entrypoint.sh /entrypoint.sh

# Copy the pulse-client configuratrion
COPY pulse-client.conf /etc/pulse/client.conf

EXPOSE 6680

ENTRYPOINT ["/usr/bin/dumb-init", "/entrypoint.sh"]
CMD ["mopidy"]
