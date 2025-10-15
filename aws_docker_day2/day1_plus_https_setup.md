### Here we will build on top of day1. The Goal is to enable our weservers to serve https requests using 3rd party certificates
-------------------------------

The most effective way to enable HTTPS on your existing AWS Application Load Balancer (ALB) architecture is to utilize **AWS Certificate Manager (ACM)** for certificate management. Although ACM can issue certificates for free, since you specifically requested using a **free external certificate generator** and importing it, the process involves using a service like **Let's Encrypt** or **ZeroSSL** and then importing the certificate components into ACM.

The key security principle here is **SSL Termination at the ALB**. The ALB will handle the secure HTTPS connection (Port 443) from the internet, and then communicate with your EC2 instances using the existing insecure **HTTP (Port 80)** protocol on the internal network. This is the AWS best practice and requires no changes to your Nginx Docker setup on the EC2 instances.

---

## Step 1: Generate a Free External SSL/TLS Certificate

You will use a free Certificate Authority (CA) like **Let's Encrypt** or **ZeroSSL** to generate your certificate files. You'll need access to your domain's DNS records (Route 53 in your case) for verification.

1.  **Choose a Generator:** Use an ACME client like **Certbot** (installed on a temporary machine) or an online interface like **SSL For Free** (powered by ZeroSSL).
2.  **Generate Key Pair:** Generate a **Private Key** and a **Certificate Signing Request (CSR)** for your domain (`devops-practice.click`). Most online generators handle the private key creation.
3.  **Domain Validation:** Complete the **DNS Validation** method. The generator will provide a **CNAME record** (a Name and Value) that you must add to your domain's Hosted Zone in AWS Route 53.
4.  **Confirm and Download:** Once the CNAME record is propagated and verified, the CA will issue the certificate. Download the resulting files. You will typically get three files in **PEM format**:
    * **Certificate Body** (`certificate.crt` or similar)
    * **Private Key** (`private.key` or similar)
    * **Certificate Chain/Intermediate** (`ca_bundle.crt` or similar)

---

## Step 2: Import Certificate into AWS Certificate Manager (ACM)

AWS services like ALB prefer to use certificates managed within **ACM**. You must import the external certificate files you generated in Step 1.

1.  **Navigate to ACM:** Go to the AWS Management Console and navigate to **Certificate Manager**. Ensure you are in the **Mumbai Region (`ap-south-1`)**.
2.  **Start Import:** Click **"Import a certificate"**.
3.  **Paste PEM Content:** Copy and paste the contents of the files into the respective fields:
    * **Certificate body:** Paste the content of your `certificate.crt` file (starts with `-----BEGIN CERTIFICATE-----`).
    * **Certificate private key:** Paste the content of your `private.key` file (starts with `-----BEGIN PRIVATE KEY-----` or `-----BEGIN RSA PRIVATE KEY-----`). **Note:** This key must be unencrypted.
    * **Certificate chain (optional):** Paste the content of your `ca_bundle.crt` file (the intermediates/chain). This is **highly recommended** for browser trust.
4.  **Tag and Import:** Add tags (optional) and click **"Review and Import"**.
5.  **Verify:** The certificate should now show a status of **"Issued"** in ACM. Note its **ARN (Amazon Resource Name)**.

---

## Step 3: Configure the Existing Application Load Balancer (ALB)

The final step is to add an HTTPS listener to your existing ALB and associate the imported certificate.

### 3.1. Update the ALB Security Group (ALB-SG)

You must open Port **443** (HTTPS) on your ALB-SG to allow secure traffic from the internet.

1.  Navigate to the EC2 service and go to **Security Groups**.
2.  Select the **ALB-SG** (The security group associated with your ALB).
3.  Go to the **Inbound Rules** tab.
4.  Click **"Edit inbound rules"** and add a new rule:
    * **Type:** HTTPS
    * **Protocol:** TCP
    * **Port range:** 443
    * **Source:** Anywhere - IPv4 (`0.0.0.0/0`)
    * Click **"Save rules"**.

### 3.2. Add an HTTPS Listener to the ALB

1.  Navigate to the EC2 service and go to **Load Balancers**.
2.  Select your **ALB**.
3.  Go to the **Listeners** tab.
4.  Click **"Add listener"**.
    * **Protocol:Port:** HTTPS:443
    * **Default Action:** Forward to the existing **ALB Target Group (ALB-TG)**. (This is the group forwarding to your EC2 instances on Port 80/HTTP).
    * **Security policy:** Select the recommended or a suitable policy (e.g., `ELBSecurityPolicy-2016-08`).
    * **Default SSL/TLS certificate:** Select the certificate you **imported to ACM** in Step 2 from the dropdown list.
    * Click **"Add listener"**.

### 3.3. (Optional but Recommended) Configure HTTP to HTTPS Redirection

To ensure all users access the secure site, you should redirect all HTTP (Port 80) traffic to HTTPS (Port 443).

1.  On the **Listeners** tab of your ALB, select the existing **HTTP:80** listener.
2.  Click **"View/edit rules"**.
3.  Edit the default rule (the one currently forwarding to ALB-TG).
4.  Change the action from "Forward to..." to **"Redirect to..."**.
    * **Protocol:** HTTPS
    * **Port:** 443
    * **Status Code:** Permanent (HTTP 301)
    * Click **"Update"** or **"Save"**.

Your AWS setup is now serving HTTPS traffic by terminating the SSL connection at the ALB and routing plain HTTP traffic to your backend EC2 instances, while also redirecting old HTTP requests to the new secure HTTPS listener.

***

You can review a video on [How to Import SSL Certificate to AWS Certificate Manager (ACM)](https://www.youtube.com/watch?v=6Nz0RFfBqVE) to understand the practical steps of bringing your external certificate into the AWS ecosystem.


http://googleusercontent.com/youtube_content/7
