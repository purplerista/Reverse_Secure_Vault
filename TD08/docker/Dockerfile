# Environnement du Secure Vault, inspire du docker du cours :
# meme base (ubuntu:24.04), memes outils (nasm, ld, Qiling),
# sans Ghidra ni les outils graphiques qui ne servent pas ici.
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# nasm + ld (binutils) pour compiler, gdb pour deboguer,
# build-essential + cmake pour construire keystone-engine (dependance de Qiling)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates git nasm binutils gdb \
    build-essential cmake python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Meme version de Qiling que dans le docker du cours (installee depuis GitHub,
# car PyPI s'arrete a la 1.4.6)
RUN python3 -m pip install --no-cache-dir --break-system-packages git+https://github.com/qilingframework/qiling.git@v1.4.11

# Utilisateur non root (uid 1000), comme dans le docker du cours
USER ubuntu
WORKDIR /opt/secure_vault

CMD ["/bin/bash"]
