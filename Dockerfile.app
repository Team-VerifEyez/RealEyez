FROM python:3.12

# Set environment variables to prevent Python from writing .pyc files and buffering stdout/stderr
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Install system dependencies required for h5py and other packages
RUN apt-get update && apt-get install -y \
    build-essential \
    libhdf5-dev \
    zlib1g-dev \
    libjpeg-dev \
    libssl-dev \
    libffi-dev \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements.txt
COPY requirements.txt /app/

# Upgrade pip and install Python dependencies
RUN pip install --upgrade pip setuptools wheel \
    && pip install -r requirements.txt

COPY ./detection/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Copy application files
COPY . /app/

EXPOSE 8000

ENTRYPOINT ["./entrypoint.sh"]

