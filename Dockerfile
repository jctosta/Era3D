FROM --platform=linux/amd64 nvidia/cuda:11.8.0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# Set Coordinated Universal Time
RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime
RUN apt update && apt install -y tzdata && apt clean && rm -rf /var/lib/apt/lists/*

# Install CONDA

## Install base utilities
RUN apt-get update \
    && apt-get install -y build-essential \
    && apt-get install -y wget \
    && apt-get install -y git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

## Install miniconda
ENV CONDA_DIR /opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda

## Put conda in path so we can use conda activate
ENV PATH=$CONDA_DIR/bin:$PATH

# Configure Conda Env
RUN conda init bash \
    && . ~/.bashrc \
    && conda create --name Era3D python=3.9 -y \
    && conda activate Era3D \
    && pip install -U pip \
    && conda install Ninja -y \
    && conda install cuda -c nvidia/label/cuda-11.8.0 -y \
    && pip install torch==2.1.2 torchvision==0.16.2 torchaudio==2.1.2 --index-url https://download.pytorch.org/whl/cu118 \
    && wget -c https://download.pytorch.org/whl/cu121/xformers-0.0.23.post1-cp39-cp39-manylinux2014_x86_64.whl#sha256=a117e4cc835d9a19c653d79b5c66e37c72f713241e2d85b6561a15006f84b6e6 \
    && pip install xformers-0.0.23.post1-cp39-cp39-manylinux2014_x86_64.whl \
    && pip install git+https://github.com/NVlabs/tiny-cuda-nn/#subdirectory=bindings/torch \
    && pip install git+https://github.com/NVlabs/nvdiffrast

# Set the working directory
WORKDIR /app


# Copy the assets
COPY ./assets /app/assets
COPY ./configs /app/configs
COPY ./examples /app/examples
COPY ./data_lists /app/data_lists
COPY ./blender /app/blender
COPY ./instant-nsr-pl /app/instant-nsr-pl
COPY ./mvdiffusion /app/mvdiffusion
COPY ./node_config /app/node_config
COPY ./utils /app/utils
COPY ./app.py /app/app.py
COPY ./test_mvdiffusion_unclip.py /app/test_mvdiffusion_unclip.py
COPY ./requirements.txt /app/requirements.txt
COPY ./download_model.py /app/download_model.py

# Install Requirements
RUN . ~/.bashrc \
    && conda activate Era3D \
    && pip install -r /app/requirements.txt

RUN apt-get update \
    && apt-get install \
    ffmpeg \
    libsm6 \
    git-lfs \
    libxext6 -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Make the script executable
RUN chmod +x /app/instant-nsr-pl/run.sh

# Download the model
# RUN conda run --no-capture-output -n Era3D /bin/bash -c '. /root/.bashrc && python /app/download_model.py'

RUN git lfs install \
    && git clone https://huggingface.co/pengHTYX/MacLab-Era3D-512-6view

# Navigate to the instant-nsr-pl directory
# WORKDIR /app/instant-nsr-pl

# Make RUN commands use the new environment:
SHELL ["conda", "run", "--no-capture-output", "-n", "Era3D", "/bin/bash", "-c"]

# Set the entry point to be bash and use CMD for the actual command
# ENTRYPOINT ["/bin/bash", "-c"]

# Default CMD to activate conda environment and run the script
CMD ["conda run --no-capture-output -n Era3D /bin/bash -c '. /root/.bashrc && /app/instant-nsr-pl/run.sh $GPU $CASE $OUTPUT_DIR'"]

# # Set the entry point to activate the conda environment and start the script
# ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "Era3D", "/bin/bash", "-c", ". /root/.bashrc && /app/instant-nsr-pl/run.sh $GPU $CASE $OUTPUT_DIR"]

# Default CMD to pass arguments if needed (can be overridden at runtime)
# CMD ["0 A_bulldog_with_a_black_pirate_hat_rgba /app/output"]

ENV DEBIAN_FRONTEND=