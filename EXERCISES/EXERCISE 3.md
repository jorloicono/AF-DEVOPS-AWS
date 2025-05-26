# Step-by-Step Guide to Create a .NET Project and CI Workflow Directly on GitHub

This guide explains **step-by-step** how to create a simple .NET project **directly on GitHub**, then set up a GitHub Actions workflow to build, test, and optionally publish your project automatically.

---

## Step 1: Create a New GitHub Repository

1. Go to [github.com](https://github.com) and log in.
2. Click the **+** icon in the top-right corner, then select **New repository**.
3. Enter a repository name (e.g., `MyDotnetApp`).
4. Optionally, add a description.
5. Choose **Public** or **Private**.
6. Do **not** initialize with a README, `.gitignore`, or license.
7. Click **Create repository**.

---

## Step 2: Create Project Folder Structure and Files on GitHub

You will create folders and files **directly on GitHub** using the web interface:

- `src/MyDotnetApp/MyDotnetApp.csproj`
- `src/MyDotnetApp/Program.cs`
- `tests/MyDotnetApp.Tests/MyDotnetApp.Tests.csproj`
- `tests/MyDotnetApp.Tests/UnitTest1.cs`
- `.github/workflows/dotnet.yml`

### How to create folders and files:

1. Go to your repository main page.
2. Click **Add file** > **Create new file**.
3. To create folders, type the folder name followed by a slash `/` before the filename.  
   Example:  
   - For `src/MyDotnetApp/MyDotnetApp.csproj`, type `src/MyDotnetApp/MyDotnetApp.csproj` as the filename.
4. Paste the contents (see next step).
5. Scroll down, add a commit message like "Add MyDotnetApp project file".
6. Commit directly to `main` branch.
7. Repeat for each file.

---

## Step 3: Add the Project Files

### 1. `src/MyDotnetApp/MyDotnetApp.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net6.0</TargetFramework>
    <Nullable>enable</Nullable>
  </PropertyGroup>

</Project>
````

---

### 2. `src/MyDotnetApp/Program.cs`

```csharp
using System;

namespace MyDotnetApp
{
    public class Program
    {
        public static int Main(string[] args)
        {
            Console.WriteLine("Hello from MyDotnetApp!");
            return 0;
        }
    }
}
```

---

### 3. `tests/MyDotnetApp.Tests/MyDotnetApp.Tests.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net6.0</TargetFramework>
    <IsPackable>false</IsPackable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.4.1" />
    <PackageReference Include="xunit" Version="2.4.1" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.4.3" />
    <PackageReference Include="coverlet.collector" Version="3.1.2" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\src\MyDotnetApp\MyDotnetApp.csproj" />
  </ItemGroup>

</Project>
```

---

### 4. `tests/MyDotnetApp.Tests/UnitTest1.cs`

```csharp
using Xunit;
using MyDotnetApp;

namespace MyDotnetApp.Tests
{
    public class UnitTest1
    {
        [Fact]
        public void Test1()
        {
            // Simple test example, replace with real tests
            Assert.True(true);
        }
    }
}
```

---

## Step 4: Add GitHub Actions Workflow for Build and Test

### `.github/workflows/dotnet.yml`

```yaml
name: .NET Build and Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        dotnet-version: [ '6.0.x' ]

    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET SDK
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ matrix.dotnet-version }}
          cache: true

      - name: Restore dependencies
        run: dotnet restore src/MyDotnetApp/MyDotnetApp.csproj

      - name: Build project
        run: dotnet build src/MyDotnetApp/MyDotnetApp.csproj --no-restore --configuration Release

      - name: Run tests
        run: dotnet test tests/MyDotnetApp.Tests/MyDotnetApp.Tests.csproj --no-build --verbosity normal --logger "trx;LogFileName=test-results.trx"

      - name: Upload test results
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: '**/test-results.trx'
        if: ${{ always() }}
```

---

## Step 5: Commit and Test

* Once all files are added and committed to your repo, **GitHub Actions** will automatically run the workflow on every push or pull request to the `main` branch.
* You can check the progress and results under the **Actions** tab in your GitHub repository.

---

## Optional Next Steps

* Add publishing to NuGet or GitHub Packages.
* Add more tests and projects.
* Customize the workflow for multiple .NET versions or environments.

---

If you want, I can help you with those next steps too!

---

**That's it! You now have a .NET project built and tested automatically with GitHub Actions — all created without leaving GitHub's website.**

```

---

If you want, I can help you with any part of this or generate the full repo structure as a downloadable zip. Just say the word!
```
