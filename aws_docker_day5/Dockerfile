# docker file to create an image for achieving below :
# 1. spin an nginx web server exposing port 80
# 2. fetch the application files from github url - https://github.com/sanjeevkpune/aws_docker_K8S_practice.git. copy files from https://github.com/sanjeevkpune/aws_docker_K8S_practice/tree/main/apps/Gym to nginx html content directory - /usr/share/nginx/html

# --- STAGE 1: BUILDER STAGE (For cloning files and cleaning up) ---
FROM ubuntu:22.04 AS builder

# 1. Install git and cleanup package lists in a single RUN layer
RUN apt-get update && \
    apt-get install -y git && \
    rm -rf /var/lib/apt/lists/*

# Define Environment Variables
ENV REPO_URL="https://github.com/sanjeevkpune/aws_docker_K8S_practice.git"
ENV APP_PATH="apps/Gym"

# Clone the repository and move the application content
WORKDIR /app-source
RUN git clone --depth 1 $REPO_URL .

# 2. OPTIONAL: To remove git from this *builder* stage, you can add this line.
# However, the key optimization is moving to the next stage.
# RUN apt-get remove --purge -y git && apt-get autoremove -y

# --- STAGE 2: PRODUCTION STAGE (Minimal Nginx image without git) ---
FROM nginx:latest

# 1. Copy the application files from the builder stage's specific subdirectory 
#    to the Nginx HTML root.
# This copies only the *final files* and ignores git, apt, and the temporary repository.
COPY --from=builder /app-source/${APP_PATH} /usr/share/nginx/html

# 2. Expose the Nginx default port
EXPOSE 80

# The base nginx:latest image already contains the CMD to run Nginx
