## Step 1: Create the Network Stack (VPC)

**Goal:** Deploy a VPC, public/private subnets, and an Internet Gateway.

**Template (`network.yml`):**

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: "Advanced CloudFormation Lab - Network Stack"

Parameters:
  VpcCidr:
    Type: String
    Default: "10.0.0.0/16"

Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCidr
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags:
        - Key: Name
          Value: AdvancedLab-VPC

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Tags:
      - Key: Name
        Value: AdvancedLab-IGW

  GatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  PublicSubnet:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: "10.0.0.0/24"
      AvailabilityZone: !Select [0, !GetAZs ""]
      Tags:
        - Key: Name
          Value: Public-Subnet

Outputs:
  VPCId:
    Description: "VPC ID"
    Value: !Ref VPC
    Export:
      Name: AdvancedLab-VPCId

  PublicSubnetId:
    Description: "Public Subnet ID"
    Value: !Ref PublicSubnet
    Export:
      Name: AdvancedLab-PublicSubnetId
```

**Deploy Stack:**

```bash
aws cloudformation deploy --template-file network.yml --stack-name NetworkStack
```


---

## Step 2: Create the Application Stack (Cross-Stack Reference)

**Goal:** Deploy an EC2 instance in the public subnet and use a custom resource to log deployment info.

**Template (`app.yml`):**

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: "Advanced CloudFormation Lab - Application Stack"

Parameters:
  KeyName:
    Type: AWS::EC2::KeyPair::KeyName
    Description: "Name of an existing EC2 KeyPair"

Resources:
  WebServerSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: "Allow HTTP and SSH"
      VpcId: !ImportValue AdvancedLab-VPCId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0

  WebServer:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t3.micro
      ImageId: ami-0abcdef1234567890 # Replace with a valid AMI ID
      KeyName: !Ref KeyName
      SubnetId: !ImportValue AdvancedLab-PublicSubnetId
      SecurityGroupIds:
        - !Ref WebServerSecurityGroup

  CustomResourceLambdaRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

  CustomResourceLambda:
    Type: AWS::Lambda::Function
    Properties:
      Handler: index.handler
      Runtime: python3.9
      Role: !GetAtt CustomResourceLambdaRole.Arn
      Code:
        ZipFile: |
          import json
          import cfnresponse

          def handler(event, context):
            print("Event: " + json.dumps(event))
            cfnresponse.send(event, context, cfnresponse.SUCCESS, { "Message": "Custom resource invoked" })

  CustomResource:
    Type: Custom::LogDeployment
    Properties:
      ServiceToken: !GetAtt CustomResourceLambda.Arn
```

**Deploy Stack:**

```bash
aws cloudformation deploy --template-file app.yml --stack-name AppStack --parameter-overrides KeyName=your-key-name
```


---

## Step 3: Verify and Test

- **Check Stacks:** Use the AWS Console or CLI to verify both stacks are created.
- **Test EC2:** Try to SSH into the EC2 instance using your key pair.
- **Check Custom Resource:** Look at the CloudWatch Logs for the Lambda function to see the custom resource invocation.



## Clean Up

To avoid ongoing charges, delete both stacks from the AWS Console or CLI:

```bash
aws cloudformation delete-stack --stack-name AppStack
aws cloudformation delete-stack --stack-name NetworkStack
```