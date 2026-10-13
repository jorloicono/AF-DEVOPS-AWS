This tutorial guides you through using AWS CodeBuild to build a simple .NET C# application, run tests, and produce an output artifact (a DLL).

## Step 1: Create the Source Code

In this step, you'll create the source code that CodeBuild will use as input. This source code will consist of two C# class files, two .NET project files (`.csproj`), and a .NET solution file (`.sln`).

1. In an empty directory on your local computer or instance, create this directory structure.

   ```
   (root directory name)
   |-- src
   |   |-- MessageUtil       // Main library project
   |       |-- MessageUtil.cs
   |       |-- MessageUtil.csproj
   |-- test
   |   |-- MessageUtil.Tests // Test project
   |       |-- TestMessageUtil.cs
   |       |-- MessageUtil.Tests.csproj
   |-- MessageUtilSolution.sln // Solution file at the root
   ```

2. Create this file, name it `MessageUtil.cs`, and save it in the `src/MessageUtil/` directory.

   ```csharp
   // src/MessageUtil/MessageUtil.cs
   using System;

   public class MessageUtil
   {
       private string message;

       public MessageUtil(string message)
       {
           this.message = message;
       }

       public string PrintMessage()
       {
           Console.WriteLine(message);
           return message;
       }

       public string SalutationMessage()
       {
           message = "Hi! " + message;
           Console.WriteLine(message);
           return message;
       }
   }
   ```

3. Create this file, name it `TestMessageUtil.cs`, and save it in the `test/MessageUtil.Tests/` directory.

   ```csharp
   // test/MessageUtil.Tests/TestMessageUtil.cs
   using Microsoft.VisualStudio.TestTools.UnitTesting;

   [TestClass]
   public class TestMessageUtil
   {
       string message = "Robert";
       MessageUtil messageUtil;

       [TestInitialize]
       public void TestSetup()
       {
           messageUtil = new MessageUtil(message);
       }

       [TestMethod]
       public void TestPrintMessage()
       {
           Console.WriteLine("Inside TestPrintMessage()");
           Assert.AreEqual(message, messageUtil.PrintMessage());
       }

       [TestMethod]
       public void TestSalutationMessage()
       {
           Console.WriteLine("Inside TestSalutationMessage()");
           string expectedMessage = "Hi! " + "Robert";
           Assert.AreEqual(expectedMessage, messageUtil.SalutationMessage());
       }
   }
   ```

4. Create the library project file `MessageUtil.csproj` in `src/MessageUtil/`.

   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
     <PropertyGroup>
       <TargetFramework>net8.0</TargetFramework>
       <AssemblyName>MessageUtil</AssemblyName>
       <Version>1.0.0</Version>
       <ImplicitUsings>enable</ImplicitUsings>
       <Nullable>enable</Nullable>
     </PropertyGroup>
   </Project>
   ```

5. Create the test project file `MessageUtil.Tests.csproj` in `test/MessageUtil.Tests/`.

   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
     <PropertyGroup>
       <TargetFramework>net8.0</TargetFramework>
       <IsPackable>false</IsPackable>
       <ImplicitUsings>enable</ImplicitUsings>
       <Nullable>enable</Nullable>
     </PropertyGroup>
     <ItemGroup>
       <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.9.0" />
       <PackageReference Include="MSTest.TestAdapter" Version="3.2.2" />
       <PackageReference Include="MSTest.TestFramework" Version="3.2.2" />
     </ItemGroup>
     <ItemGroup>
       <ProjectReference Include="..\..\src\MessageUtil\MessageUtil.csproj" />
     </ItemGroup>
   </Project>
   ```

6. Create the solution file using the .NET CLI:

   ```bash
   dotnet new sln -n MessageUtilSolution
   dotnet sln MessageUtilSolution.sln add src/MessageUtil/MessageUtil.csproj
   dotnet sln MessageUtilSolution.sln add test/MessageUtil.Tests/MessageUtil.Tests.csproj
   ```

7. At this point, your directory structure should look like this:

   ```
   (root directory name)
   |-- MessageUtilSolution.sln
   |-- src
   |   |-- MessageUtil
   |   |   |-- MessageUtil.cs
   |   |   |-- MessageUtil.csproj
   |-- test
   |   |-- MessageUtil.Tests
   |       |-- TestMessageUtil.cs
   |       |-- MessageUtil.Tests.csproj
   ```

## Step 2: Create the Build Specification File

Create a build specification file named `buildspec.yml` in the root directory.

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      dotnet: 8.0
    commands:
      - echo "Installing .NET SDK specified in runtime-versions"
  pre_build:
    commands:
      - echo "Nothing to do in the pre_build phase..."
  build:
    commands:
      - echo Build started on `date`
      - dotnet build MessageUtilSolution.sln --configuration Release
      - dotnet test MessageUtilSolution.sln --configuration Release --no-build
  post_build:
    commands:
      - echo Build completed on `date`
artifacts:
  files:
    - src/MessageUtil/bin/Release/net8.0/MessageUtil.dll
    - src/MessageUtil/bin/Release/net8.0/MessageUtil.pdb
```

Your updated structure:

```
(root directory name)
|-- MessageUtilSolution.sln
|-- buildspec.yml
|-- src
|   |-- MessageUtil
|   |   |-- MessageUtil.cs
|   |   |-- MessageUtil.csproj
|-- test
|   |-- MessageUtil.Tests
|       |-- TestMessageUtil.cs
|       |-- MessageUtil.Tests.csproj
```

## Step 3: Create Two S3 Buckets

Create two S3 buckets:

* **Input bucket** to store the source code: `codebuild-region-ID-account-ID-input-bucket`
* **Output bucket** to store build artifacts: `codebuild-region-ID-account-ID-output-bucket`

Make sure both buckets are in the same AWS Region as your CodeBuild project.

## Step 4: Upload the Source Code and Buildspec File

Zip your source code and `buildspec.yml`:

```
MessageUtilNet.zip
|-- MessageUtilSolution.sln
|-- buildspec.yml
|-- src
|   |-- MessageUtil
|   |   |-- MessageUtil.cs
|   |   |-- MessageUtil.csproj
|-- test
|   |-- MessageUtil.Tests
|       |-- TestMessageUtil.cs
|       |-- MessageUtil.Tests.csproj
```

Upload `MessageUtilNet.zip` to the **input S3 bucket**.

## Step 5: Create the Build Project

1. Go to [AWS CodeBuild Console](https://console.aws.amazon.com/codesuite/codebuild/home)
2. Choose a region.
3. Click **Create build project**.
4. Enter **Project name** (e.g., `codebuild-demo-dotnet-project`).
5. Under **Source**, choose **Amazon S3**, select your input bucket, and enter `MessageUtilNet.zip`.
6. Under **Environment**:

   * Choose **Managed image**
   * OS: **Amazon Linux 2**
   * Runtime: **Standard**
   * Image: Use one with .NET 8 support (e.g., `aws/codebuild/standard:7.0`)
7. Choose **New service role** for permissions.
8. Leave **Use a buildspec file** selected.
9. Under **Artifacts**, choose **Amazon S3**, then select your output bucket.
10. Click **Create build project**.


Let me know if you'd like this exported as a Markdown file or have it tailored for a different CI/CD platform like GitHub Actions or Azure DevOps.
