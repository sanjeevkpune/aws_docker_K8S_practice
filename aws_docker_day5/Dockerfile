# docker file to create an image for achieving below :
# 1. spin an nginx web server exposing port 80
# 2. fetch the application files from github url - https://github.com/sanjeevkpune/aws_docker_K8S_practice.git. copy files from https://github.com/sanjeevkpune/aws_docker_K8S_practice/tree/main/apps/Gym to nginx html content directory - /usr/share/nginx/html

# --- STAGE 1: BUILDER STAGE (For cloning files and cleaning up) ---
FROM ubuntu:22.04 AS builder

# Define a static path variable for use in this stage
ENV APP_PATH="apps/Gym"
ENV REPO_URL="https://github.com/sanjeevkpune/aws_docker_K8S_practice.git"

# Install git and cleanup package lists in a single RUN layer
RUN apt-get update && \
    apt-get install -y git && \
    rm -rf /var/lib/apt/lists/*

# Clone the repository
WORKDIR /app-source
RUN git clone --depth 1 ${REPO_URL} .

# --- STAGE 2: PRODUCTION STAGE (Minimal Nginx image without git) ---
FROM nginx:latest

# The FIX:
# In the COPY instruction, you must hardcode the path *relative to the builder's WORKDIR*, 
# or use the path that was effectively created in the builder stage.
# The path created in the builder is: /app-source/apps/Gym
COPY --from=builder /app-source/apps/Gym /usr/share/nginx/html

# Expose the Nginx default port
EXPOSE 80

# Nginx starts automatically via the base image CMD