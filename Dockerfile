FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    iverilog \
    verilator \
    python3 \
    python3-pip \
    python3-venv \
    make \
    gcc \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install cocotb pyuvm

WORKDIR /sim
