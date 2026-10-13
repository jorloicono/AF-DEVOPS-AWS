# Laboratory Details

This lab practice will guide you through the Amazon Simple Storage Service. Amazon S3 has a simple web interface that you can use to store and retrieve any amount of data (at any time) from anywhere on the web. In this lab, we will demonstrate AWS S3 by creating a sample S3 bucket, uploading an object to the S3 bucket, and configuring the bucket policy and permissions.

## Tasks

1. **Log in to the AWS Management Console.**
2. **Create an S3 Bucket.**
3. **Upload an object to the S3 Bucket.**
4. **Access the object in your browser.**
5. **Change the permissions of the S3 objects.**
6. **Configure the bucket policy and permissions and test the object’s accessibility.**

---

## Step-by-step Instructions

1. **Click on Create Bucket**
2. **Configure the bucket name.**
S3 bucket names are globally unique; choose a name that is available.
3. **Click Next**
4. **Leave other settings as default and click Next**
5. **Leave other settings as default and click Next**
6. **Leave other settings as default and click Create Bucket**
7. **Click on your bucket name**
8. **Click Upload**
9. **Click Add files and choose a file from your computer**
10. **After selecting your file, click Next**
11. **Click Next**
12. **Click Next**
13. **Click Upload**

You can see the upload progress below.
Now you have a private S3 bucket with a private object uploaded, which means it cannot be accessed via the Internet.

---

## Change Bucket Permissions

**Change the bucket permission so that the image is publicly available.**

1. **Click on your object in the bucket.**
You will see the object details such as owner, size, link, etc.
2. **A URL will appear under Object URL:**
`https://mys3bucketwhizlabs.s3.amazonaws.com/smiley.jpg`
3. **Open the image link in a new tab.**
You will see an `AccessDenied` message, which means the object is not publicly accessible.
4. **Go back to your bucket and click on Permissions**
5. **Under Public Access, click Everyone and then click Read object on the right side of the pop-up window. Then click Save.**
6. **Now your status changes to Read Object – Yes**
7. **Click on Overview and click your Object URL again**
8. **Observe the URL in your browser**

---

## Create a Bucket Policy

In the previous step, you granted read access to only a specific object. If you want all objects within a bucket to be publicly available, you can achieve this by creating a bucket policy file.

1. **Go to the bucket list and click on your bucket name.**
2. **Click on the Permissions tab, then configure the following:**
3. **Click on Bucket Policy**
4. **A blank bucket policy editor is displayed.**
5. **Copy your bucket’s ARN to the clipboard.**
    - Example: `arn:aws:s3:::s3bucket180`
6. **Replace your bucket ARN with the ARN shown in the JSON below and then copy the complete policy:**
```json
{
  "Id": "Policy1",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1",
      "Action": ["s3:GetObject"],
      "Effect": "Allow",
      "Resource": "replace-this-string-from-your-bucket-arn/*",
      "Principal": "*"
    }
  ]
}
```

7. **Click Save**
8. **Test public access**
    - Go back to your bucket list and click on your bucket.
    - Upload another file. Leave all settings as default.
    - Click on your new object and click the Object URL

---

## How to Enable Amazon S3 Versioning

**Laboratory Details**

1. This lab practice will guide you through the steps on how to enable versioning in an AWS S3 Bucket. Versioning allows you to keep multiple versions of an object in a bucket.

**Task Details**

1. **Log in to the AWS Management Console.**
2. **Create an S3 Bucket.**
3. **Enable object versioning in the bucket.**
4. **Upload a text file to the S3 Bucket.**
5. **Test object versioning by changing the text file and uploading it again.**

### Architecture Diagram


---

## Step-by-step Instructions

1. **In the S3 panel, click Create Bucket and fill in the bucket details.**
    - **Bucket name:** Enter yourBucketName
*Note: S3 bucket names are globally unique; choose a name that is available.*
    - **Region:** Select US East (N. Virginia)
    - **Leave other settings as default.**
2. **Click Create**
3. **Close the pop-up window if it is still open.**
4. **Enable versioning in the S3 bucket**
    - Go to the bucket list and click on your bucket name (e.g., whizlabs234)
    - Click on Properties
    - Choose Versioning
    - Choose Enable versioning and click Save
    - Now versioning in the S3 bucket is enabled.
5. **Upload an object**
    - Upload any file from your local machine.
    - On the S3 Bucket list page, click yourBucketName
    - Click on the Overview tab
    - Click on the Upload button
    - Click on the Add files button
    - Browse for the file you want to upload
    - Click Next and grant public read access to this object(s)
    - Click the Upload button
    - You can see the upload progress from the transfer panel at the bottom of the screen. If it is a small file, you may not see the transfer. Once your file is uploaded, it will appear in the bucket.
6. **Make the bucket public with a bucket policy**
    - Go to the bucket list and click on your bucket name.
    - Click on the Permissions tab to configure your bucket:
        - On the Permissions tab, click Bucket Policy
        - A blank bucket policy editor is displayed.
        - Before creating the policy, you need to copy your bucket’s ARN (Amazon Resource Name).
        - Copy your bucket’s ARN to the clipboard. It is shown at the top of the policy editor. It looks like: `arn:aws:s3:::your-bucket-name`
        - In the following policy, update your bucket ARN in the resource value and copy the policy code.
        - Paste the bucket policy into the bucket policy editor.
```json
{
  "Id":"Policy1",
  "Version":"2012-10-17",
  "Statement":[
    {
      "Sid":"Stmt1",
      "Action":["s3:GetObject"],
      "Effect":"Allow",
      "Resource":"replace-this-string-from-your-bucket-arn/*",
      "Principal":"*"
    }
  ]
}
```

- Click Save
- Click Overview
- Now open the text file link in your browser and you should see the text in the file.

7. **Upload the same object with different content**
    - Upload the same file with different content from your local machine.
    - On the S3 Bucket list page, click yourBucketName
    - Click on the Overview tab
    - Click on the Upload button
    - Click on the Add files button
    - Browse for the file you want to upload
    - Click Next and grant public read access to this object(s)
    - Click the Upload button
    - You should see the latest version of the file you uploaded.
8. **Test a previous version of the file**
    - To enable the previous version of the file, we must delete the latest version of the file.
    - Click on the object URL
    - Click on the file name.
    - In the top section (next to the object name) you can find a dropdown menu of all file versions called Latest version
    - Click on the dropdown menu and delete the latest version of your file.
    - Now refresh your S3 object URL. You should see the previous version of the file you uploaded.

---

## Creating an S3 Lifecycle Policy

**Laboratory Details**

1. This lab practice will guide you through the steps on how to create a lifecycle rule for an object in an S3 bucket.

**Lab Tasks**

1. **Log in to the AWS Management Console.**
2. **Create an S3 Bucket and upload an object to the bucket.**
3. **Create a lifecycle rule on the object.**
4. **Create transition types.**
5. **Create expiration transition.**
6. **Test the lifecycle rule on the uploaded object.**

### Architecture Diagram


---

## Step-by-step Instructions

1. **Create an S3 Bucket**
    - In the S3 panel, click Create Bucket and fill in the bucket details.
        - **Bucket name:** Enter inputYourBucketName
*Note: S3 bucket names are globally unique; choose a name that is available.*
        - **Region:** Select US East (N. Virginia)
        - **Leave other settings as default.**
    - Click Create
    - Close the pop-up window if it is still open.
2. **Upload an object**
    - Upload any file from your local machine.
    - On the S3 Bucket list page, click yourBucketName
    - Click on the Overview tab
    - Click on the Upload button
    - Click on the Add files button
    - Browse for the file you want to upload
    - Click Next and grant public read access to this object(s)
    - Click the Upload button
    - You can see the upload progress from the transfer panel at the bottom of the screen. If it is a small file, you may not see the transfer. Once your file is uploaded, it will appear in the bucket.
3. **Create a lifecycle rule**
    - Click on the Management tab
    - Click Add lifecycle rule to create a lifecycle rule for the uploaded object
    - Enter the rule name: tmpLifecycle
    - Add a filter to limit the scope to prefixes/tags: tmp
    - Choose the tmp prefix from the dropdown and click Next.
    - **Storage class transition:** Select Current version
    - For current versions of objects: click Add transition
        - *Note: Currently, versioning is disabled, so we cannot access previous versions of the object.*
    - **Creation objects:** Select Transition to One Zone-IA from the dropdown.
        - **Days after creation:** Enter 35
    - Click Add transition.
    - Select Transition to Glacier after in the dropdown.
        - When prompted for the number of days before moving to Glacier, enter 90.
    - Click the checkbox that says I acknowledge that this lifecycle rule will increase the one-time lifecycle request cost if transitioning small objects.
    - Click Next.
    - *Note:*
        - Initially, when the object is uploaded, it will be in the standard storage class.
        - When we create a Lifecycle Policy, the object uploaded using the lifecycle rule will migrate to One Zone-IA after 35 days. This means the object will be available in only one availability zone after 35 days.
        - After 90 days, our object will migrate to Glacier. This means our object will be in archived status.
        - You would need to retrieve the object from Glacier before accessing it.
4. **Create expiration: Select Current version**
    - **Expire current version of an object:** Enter 120
    - Select the Clean up incomplete multipart uploads checkbox.
        - *Note: Leave the number of days at 7 (default value). This means that objects that have not been uploaded correctly will be deleted after 7 days.*
5. **Before saving, check the settings (you can go back and edit later if you need to change something). Click Edit.**
6. **Click Save.**
    - The lifecycle rule for our object will now be created and enabled.
