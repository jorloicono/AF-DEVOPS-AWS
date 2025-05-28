This lab will guide you through the creation and use of a serverless AWS service called AWS Lambda. In this lab, we will create a sample Lambda function that will be triggered by an S3 object upload event. The Lambda function will make a copy of that object and place it in a different S3 bucket.

## Task Details

1. Log in to the AWS Management Console.
2. Create two S3 buckets. One for the source and another for the destination.
3. Create a Lambda function to copy the object from one bucket to another.
4. Test the Lambda function.

## Create Amazon S3 Bucket (Source Bucket)

Click on **Create bucket**.

- **Bucket name:** `your_source_bucket_name`
- **Region:** `US East (N. Virginia)`

> Note: Each S3 bucket name is globally unique, so create the bucket with a name that is not currently in use.

Leave other settings as default and click the **Create** button.

Once the bucket has been successfully created, select your S3 bucket (click the checkbox).
Click **Copy Bucket ARN** to copy the ARN.

- **ARN:** `arn:aws:s3:::zacks-source-bucket`

Save the source bucket ARN in a text file for later use.

## Create Amazon S3 Bucket (Destination Bucket)

Click on **Create bucket**.

- **Bucket name:** `your_destination_bucket_name`
- **Region:** `US East (N. Virginia)`

> Note: Each S3 bucket name is globally unique, so create the bucket with a name that is not currently in use.

Leave other settings as default and click the **Create** button.

Once the bucket has been successfully created, select your S3 bucket (click the checkbox).
Click **Copy Bucket ARN** to copy the ARN.

- **ARN:** `arn:aws:s3:::zacks-destination-bucket`

Save the source bucket ARN in a text file for later use.

Now we have two S3 buckets (source and destination).
We will use our AWS Lambda function to copy the content from the source bucket to the destination bucket.

## Create an IAM Policy

As a prerequisite for creating the Lambda function, we must create a user role with a custom policy.

Click on **Create policy**.

Click on the **JSON** tab and copy and paste the following policy statement into the editor:

```json
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect":"Allow",
         "Action":[
            "s3:GetObject"
         ],
         "Resource":[
            "arn:aws:s3:::your_source_bucket_name/*"
         ]
      },
      {
         "Effect":"Allow",
         "Action":[
            "s3:PutObject"
         ],
         "Resource":[
            "arn:aws:s3:::your_destination_bucket_name/*"
         ]
      }
   ]
}
```

Make sure to have `/*` after the ARN name.

Click **Review policy**.

On the Create Policy page:

- **Policy name:** `mypolicy`

Click the **Create policy** button.

A policy named `mypolicy` has been created.

## Create an IAM Role

In the left-hand menu, click **Roles**.
Click the **Create role** button.

Select **Lambda** from the list of AWS services.
Click **Next: Permissions**.

Filter policies: you can now see a list of policies. Search for your policy by name (`mypolicy`).
Select your policy and click **Next: Tags**.

Add tags: provide a key-value pair for the role:

- **Key:** `Name`
- **Value:** `myrole`

Click **Next: Review**.

**Role name:**

- **Role name:** `myrole`

Click the **Create role** button.

You have successfully created an IAM role named `myrole`.

## Create a Lambda Function

Click the **Create function** button.

Choose **Author from scratch**.

- **Function name:** `mylambdafunction`
- **Runtime:** Select `Node.js 12.x`
- **Permissions:** In the permissions section, select **use an existing role**.
    - **Existing role:** Select `myrole`

Click **Create function**.

On the configuration page, we need to configure our Lambda function.
If you scroll down, you will see the **Function code** section. Here we need to write a Node.js function that copies the object from the source bucket and pastes it into the destination bucket.

Delete the existing code in the AWS Lambda `index.js`.
Copy the following code and paste it into your Lambda `index.js`:

```javascript
var AWS = require("aws-sdk");
exports.handler = (event, context, callback) => {
    var s3 = new AWS.S3();

    var sourceBucket = "your_source_bucket_name";
    var destinationBucket = "your_destination_bucket_name";
    var objectKey = event.Records[^0].s3.object.key;
    var copySource = encodeURI(sourceBucket + "/" + objectKey);
    var copyParams = { Bucket: destinationBucket, CopySource: copySource, Key: objectKey };
    s3.copyObject(copyParams, function(err, data) {
        if (err) {
            console.log(err, err.stack);
        } else {
            console.log("S3 object copy successful.");
        }
    });
};
```

You need to change the **source and destination bucket names** (not ARN!) in the `index.js` file according to your bucket names.

Save the function by clicking **Deploy** in the top right corner.

## Add Triggers to the Lambda Function

Go to the top and left-hand page, click **+ Add trigger** in the Designer.

Scroll down in the list and select **S3** from the list of triggers.
Once you select S3, a form will appear.
Enter these details:

- **Bucket:** select your source bucket – `your_source_bucket_name`
- **Event type:** `All object create events`

Leave other fields as default.

Check the recursive invocation option to avoid failures in case you upload multiple files at once.

Click **Add**.

## Validation Test

Prepare an image on your local machine.

Go to the bucket list and click on the source bucket – `your_source_bucket_name`.
Upload the image to the source S3 bucket. To do this:

- Click the **Upload** button.
- Click **Add files** to add the files.
- Select the image and click the **Upload** button to upload the image.

Now return to the S3 list and open your destination bucket: `your_destination_bucket_name`.

To open the object, scroll down and change **ACL – Everyone – Read**.

You can see a copy of the image from the source bucket uploaded to the destination bucket.


