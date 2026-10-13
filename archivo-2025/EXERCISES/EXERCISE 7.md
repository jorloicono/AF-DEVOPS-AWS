This practical lab is divided into the following parts:

1. Launch EC2 instances with tags
2. Create AWS IAM identities
3. Test resource access
4. Assign the IAM role to the EC2 instance and test access

## Launch EC2 Instances with Tags

In this lab, we will launch two Amazon Linux 2 instances.
Suppose one is an EC2 instance used in a development environment and the other is used in a production environment. We will use tags to distinguish these two instances.

Enter the EC2 Console in the AWS Management Console.

Click on **EC2 Dashboard** near the top of the left menu. Then, click on **Launch instances**.

In **Name**, enter the value `prod-instance`. Click on **Add additional tags**.

Click on **Add tag**, then in **Key** enter `Env`, and in **Value** enter `prod`.

Check the default Amazon Machine Image settings and select `t2.micro` in **Instance Type**.

In **Key pair (login)**, select **Proceed without a key pair**. Then, click on **Launch instance**.

You have launched an EC2 instance for the production environment. Now you need to create another EC2 instance for the development environment.
Repeat the previous instructions (start from step 1 and follow through step 5), but with different **Name** and **Env** tags in steps 2 and 3 as follows:


| KEY | VALUE |
| :-- | :-- |
| Name | dev-instance |
| Env | dev |

After launching both instances, you can find them in the instances menu on the sidebar. Click the checkbox for `prod-instance` and click on the **Tags** tab at the bottom of the page. You can see details about the tag information for this EC2 instance.

---

## Create AWS IAM Identities

In this chapter, we will work on creating AWS IAM identities.
An AWS IAM entity includes IAM users, IAM user groups, and IAM roles. We will also work on creating an IAM policy, an object in AWS that, when attached to an identity or resource, defines its permissions.

This chapter consists of the following steps:

- Create an IAM policy to attach to the IAM user group.
- Create an IAM user group named `dev-group`.
- Create an IAM user named `dev-user` placed in `dev-group`.

Sign in to the IAM console. To generate a console login URL, click the **customize** button as shown below.

Enter the account alias. For this lab, type `aws-login-user_name` and click the **create alias** button.

Click on **Policies** on the left side of the IAM console, then click the **Create Policy** button at the top right corner.

When defining the policy for AWS permissions, you can create and edit in the visual or JSON editor. In this lab, we will use the JSON method.
Briefly describe the permission below: this policy allows all EC2 actions tagged as `Env-dev`. It also allows describing actions related to all EC2 instances. However, it denies the action of creating and deleting tags to prevent users from arbitrarily modifying them. Note that the **Deny** effect takes precedence over the **Allow** effect.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "ec2:*",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "ec2:ResourceTag/Env": "dev"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": "ec2:Describe*",
            "Resource": "*"
        },
        {
            "Effect": "Deny",
            "Action": [
                "ec2:DeleteTags",
                "ec2:CreateTags"
            ],
            "Resource": "*"
        }
    ]
}
```

Click on the **JSON** tab, paste the above policy, and click the **Next: Tags** button.

### JSON Policy Structure

- **Version**: Use the latest version from 10/17/2012.
- **Statement**: Can include more than one statement in a policy.
- **Sid (optional)**: An optional statement ID.
- **Effect**: Use `Allow` or `Deny` to indicate if the policy allows or denies access. `Deny` takes precedence.
- **Principal**: If you create a resource-based policy, specify the account, user, role, or federated user to allow or deny access. If creating an IAM permission policy to attach to a user or role, you cannot include this element. The principal is implicitly that user or role.
- **Action**: A list of actions the policy allows or denies.
- **Resource**: For IAM permission policies, specify a list of resources the actions apply to. For resource-based policies, this element is optional. If not included, the resource to which the policy is attached is applied.
- **Condition Block (optional)**: Specify the circumstances under which the policy grants permission.

Keep the default settings in the next step, click the **Next: Review** button.
Enter `DevPolicy` in the name section and write the description for this policy. Then, click the **Create policy** button.


| KEY | VALUE |
| :-- | :-- |
| Name | DevPolicy |
| Description | IAM Policy for Dev Group |

Click on **User groups** on the left side of the IAM console, then click the **Create group** button at the top right corner.

Enter `dev-group` in **User group name** and select `DevPolicy` in the **Attach permissions policies - Optional** section.


| KEY | VALUE |
| :-- | :-- |
| User group name | dev-group |

Click on **Users** on the left side of the page, then click the **Add users** button.

Type `dev-user` in **User name** and allow both programmatic access and AWS Management Console access. Then, select **Custom password** and enter the desired password. Finally, uncheck **Require password reset function** for quick action. In real-world scenarios, enabling password reset is recommended. Click the **Next: Permissions** button.

Select the `dev-group` we just created and click the **Next: Tags** button. Skip the **Add user** page and proceed to the next step.

Click the **Create user** button to add `dev-user`.

Download the `.csv` file to get the access key ID and secret access key. You can also send login instructions.
Click on **Sign-in URL** to log in as `dev-user`. Enter the IAM user name and password to log in to the AWS Management Console.

---

## Test Resource Access

Log in to the AWS console and check the account alias and IAM user. Also, check the AWS region where the EC2 instances were launched.

Go to the EC2 console and click on the **Instances** menu.
Select the instance called `prod-instance` and click on the **Instance state** button and then **Stop instance**. Click **Stop** in the pop-up window.

A warning appears that `dev-user` does not have permission to stop the EC2 instance. This is because the previous lab only allowed `dev-user` to stop EC2 instances with the resource tag `Env (key)-dev(value)`.

Select the instance called `dev-instance` and click on the **Instance State** button and then **Stop instance**. Click **Stop** in the pop-up window.

After a few seconds, you will see that the `dev-instance` has stopped.

In the real world, you may not want to shut down the EC2 instance to test the custom IAM policy. The policy simulator is a tool that allows you to examine and validate the permissions your policies set. In this step, we will test the permission of `dev-group` by simulating the `DeleteTags` and `StopInstances` actions using the IAM policy simulator. Skipping this step does not affect your next lab practices.

The `dev-user` you were using does not have access to the IAM Policy Simulator. Log in as Administrator.
Go to the IAM Policy Simulator.
Select `dev-group`.

Select the actions `DeleteTags` and `StopInstances` to test them.

You can see that both actions are denied, but for different reasons. `DeleteTags` was denied due to a **matching statement** (1 matching statement) and `StopInstances` was denied with the message **Implicitly denied (no matching statements)**.

Expand `DeleteTags` and click on **Show statement** in `DevPolicy (IAM Policy)`. It automatically highlights which statement exactly matches the simulated action.

Expand `StopInstances`. The action was denied because the simulation resource is `"*"`. Note that `dev-group` can only stop EC2 instances with the `dev` tags.

Now we will test the policy after adding the `dev` tag to properly validate the policy.

---

## Assign the IAM Role to the EC2 Instance and Test Access

Log in again to the AWS account with the administrator role at the beginning of the lab, not as `dev-user`, before continuing with this chapter.

To create an S3 bucket, go to the S3 console. Then, click the **Create bucket** button. For detailed information about Amazon S3, see the chapter **Storage on AWS**.

Enter a unique name in the **Bucket name** field. In this lab, type `iam-test-user_name`. All Amazon S3 bucket names must be unique and cannot be repeated. Click the **Create bucket** button and do not modify the remaining settings.

Upload any file to the S3 bucket.

Create another bucket named `iam-test-other-user_name`. Upload any file to this S3 bucket.

Go to the IAM console to create the IAM role for the EC2 instance. Click on **Roles** on the left side of the IAM console and click the **Create role** button. In step 1, choose EC2 for the trusted entity and click **Next: Permissions**. The IAM role can be applied to many AWS services, including EC2 and Lambda, as well as other AWS accounts, web identities, and SAML 2.0 federation.

In step 2, click **Create policy** to create a policy to associate with the EC2 instance role. In the **JSON** tab, paste the policy below and click **Next: Tags**.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": ["s3:ListAllMyBuckets", "s3:GetBucketLocation"],
            "Effect": "Allow",
            "Resource": ["arn:aws:s3:::*"]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
                "arn:aws:s3:::iam-test-user_name/*",
                "arn:aws:s3:::iam-test-user_name"
            ]
        }
    ]
}
```

In the above JSON file, make sure to change the **Resource** value to the name of the S3 bucket you created.

To skip the tagging operation, click **Next: Review** and enter `IAMBucketTestPolicy` in the **Name** input box. Click **Create policy** to associate it with the IAM role.

Return to the page where you were creating the IAM role, click the **Refresh** button in the top right corner, and type `IAMBucketTestPolicy`. If you see the policy you just created in the list below, select it and proceed to the next step.

In step 4, enter `IAMBucketTestRole` and create the role.

Go to the EC2 console to associate the IAM role with the EC2 instance. If you do not have EC2 instances created from the previous lab, check the top right to see if the AWS region is set correctly.
Select `prod-instance` and then click the **Connect** button.

Connect to the instance using the **EC2 Instance Connect** option and click the **Connect** button. Then, the terminal will appear as shown below. Type `aws s3 ls` and you will see that you cannot get S3 bucket lists.

Return to the **Instances** page and select `prod-instance`. Click the **Actions** button, select **Security**, and click **Modify IAM role**.

In the IAM role, select `IAMBucketTestRole` and click the **Save** button to associate the IAM role with the EC2 instance.

Connect again to the EC2 instance and type `aws s3 ls` again. Now you will be able to see the lists of S3 buckets. You will also be able to see the list of objects located in `iam-test-user_name`, but not in `iam-test-other-user_name`, because there is no IAM policy for this bucket.

```bash
aws s3 ls

aws s3 ls iam-test-user_name

aws s3 ls iam-test-other-user_name
```



