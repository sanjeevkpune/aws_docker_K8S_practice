#!/bin/bash
set -e

# Step 1: Create user "my-user" and add to sudoers
useradd -m my-user
echo "my-user ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/my-user
usermod -aG sudo my-user

# Step 2 & 3: Install and Enable Docker
# Using the recommended setup for Ubuntu
apt-get update -y
apt install -y unzip
apt-get install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
usermod -aG docker my-user

# Step 4: Install and enable SSM Agent
# On most modern Ubuntu AMIs, SSM is pre-installed. The snap command is a robust fallback.
if ! systemctl status amazon-ssm-agent > /dev/null; then
    snap install amazon-ssm-agent --classic
    systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
fi

# Step 5: Install AWS CLI (needed for s3 copy)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
aws --version

# Step 6: Copy from S3, unzip, and move contents
mkdir -p /home/my-user/apps/gym/
chown -R my-user:my-user /home/my-user/

# Use the my-user context to ensure file ownership is correct
# The IAM role provides access for the EC2 instance profile
sudo -H -u my-user bash -c '
  aws s3 cp s3://my-bucket-docker-site/gym-app/Gym.zip /tmp/Gym.zip
  unzip /tmp/Gym.zip -d /home/my-user/apps/gym/
  rm /tmp/Gym.zip
'

# Step 7: Install and run Nginx container
docker container run -d \
-v /home/my-user/apps/gym/Gym:/usr/share/nginx/html:ro \
--name=nginx-container1 \
--hostname=nginx-server \
-p80:80 nginx