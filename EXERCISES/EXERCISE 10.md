# Terraform with AWS Guide

## Introduction
Terraform is an open-source Infrastructure as Code (IaC) tool that allows you to define and manage your cloud infrastructure declaratively. This guide will walk you through using Terraform to provision resources on AWS.

---

## Prerequisites

- AWS Account
- AWS CLI installed and configured with credentials (`aws configure`)
- Terraform installed ([Terraform installation guide](https://learn.hashicorp.com/tutorials/terraform/install-cli))

---

## Step 1: Configure AWS Credentials

Terraform needs AWS credentials to create resources.

You can provide credentials via:

- Environment variables:
  ```bash
  export AWS_ACCESS_KEY_ID="your_access_key"
  export AWS_SECRET_ACCESS_KEY="your_secret_key"
  export AWS_DEFAULT_REGION="us-east-1"
````

* Or ensure the AWS CLI is configured with `aws configure`.

---

## Step 2: Create Terraform Configuration

Create a directory for your project and a file `main.tf`:

```hcl
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "example" {
  bucket = "my-unique-terraform-bucket-12345"
  acl    = "private"
}
```

---

## Step 3: Initialize Terraform

Run the following command inside your project directory:

```bash
terraform init
```

This will download the AWS provider plugin.

---

## Step 4: Plan Your Infrastructure

Check what Terraform will create or change:

```bash
terraform plan
```

---

## Step 5: Apply Your Configuration

Create the AWS resources:

```bash
terraform apply
```

Confirm with `yes` when prompted.

---

## Step 6: Verify Resources

Check your AWS console to see the S3 bucket created.

---

## Step 7: Clean Up

To remove resources created by Terraform:

```bash
terraform destroy
```

Confirm with `yes`.

---

## Additional Tips

* Use `terraform fmt` to format your code.
* Use `terraform validate` to validate the syntax.
* Manage state files carefully, especially for teams.
* Use Terraform modules to organize complex infrastructure.


