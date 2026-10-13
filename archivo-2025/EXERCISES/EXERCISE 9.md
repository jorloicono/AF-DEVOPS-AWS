## Deploy a .NET Project to AWS using GitHub Actions

This guide explains how to automate the deployment of a .NET application to AWS using GitHub Actions. We’ll use **AWS Elastic Beanstalk** as the deployment target.

---

## Prerequisites

* A .NET project (e.g., ASP.NET Core Web API)
* AWS account
* Elastic Beanstalk environment set up (e.g., `my-dotnet-env`)
* IAM user with programmatic access & necessary permissions
* GitHub repository for your project

---

## Step 1: Configure AWS Credentials in GitHub

1. In your AWS Console:

   * Go to **IAM > Users** > your user.
   * Under **Security credentials**, create **Access keys**.
   * Copy the **Access Key ID** and **Secret Access Key**.

2. In your GitHub repo:

   * Go to **Settings > Secrets and variables > Actions > Secrets**
   * Add the following secrets:

     * `AWS_ACCESS_KEY_ID`
     * `AWS_SECRET_ACCESS_KEY`

---

## Step 2: Project Structure Example

```bash
/MyDotNetApp
├── Controllers/
│   └── WeatherForecastController.cs
├── Program.cs
├── MyDotNetApp.csproj
├── .github/
│   └── workflows/
│       └── deploy.yml

```

---

## Step 3: Create the GitHub Actions Workflow

Create this file in your project repository:

```bash
.github/workflows/deploy.yml
```

### `deploy.yml`

```yaml
name: Deploy to AWS Elastic Beanstalk

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout source code
        uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x' # Adjust if needed

      - name: Restore dependencies
        run: dotnet restore

      - name: Build
        run: dotnet build --configuration Release

      - name: Publish
        run: dotnet publish -c Release -o publish

      - name: Generate deployment package
        run: zip -r deploy-package.zip publish

      - name: Deploy to Elastic Beanstalk
        uses: einaregilsson/beanstalk-deploy@v21
        with:
          aws_access_key: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws_secret_key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          application_name: MyDotNetApp           # Your EB Application name
          environment_name: MyDotNetApp-env       # Your EB Environment name
          version_label: v-${{ github.run_number }}
          region: us-east-1                       # Your AWS region
          deployment_package: deploy-package.zip
```

---

## Step 4: Create and Configure Elastic Beanstalk

1. Package your app locally to test:

   ```bash
   dotnet publish -c Release -o publish
   zip -r deploy-package.zip publish
   ```

2. In AWS Console:

   * Go to **Elastic Beanstalk**
   * Create an **Application**
   * Choose **.NET on Linux** platform (or Windows if needed)
   * Deploy any placeholder zip to initialize

---

## Step 5: Push Code to Trigger Workflow

```bash
git add .
git commit -m "Set up GitHub Actions deployment to AWS"
git push origin main
```

The GitHub Action will:

* Build your .NET app
* Publish it
* Zip it
* Deploy to Elastic Beanstalk

---

## Logs and Monitoring

* Go to **GitHub > Actions** tab to see job logs
* Go to **AWS EB Console** to view:

  * Deployment status
  * Logs
  * Health checks

Here’s **all the necessary code** for deploying.

## 1. `Program.cs`

```csharp
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Hosting;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
var app = builder.Build();

app.MapControllers();
app.Run();
```

---

## 2. `MyDotNetApp.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

</Project>
```

---

## 3. `Controllers/WeatherForecastController.cs`

```csharp
using Microsoft.AspNetCore.Mvc;

[ApiController]
[Route("[controller]")]
public class WeatherForecastController : ControllerBase
{
    [HttpGet]
    public IEnumerable<string> Get()
    {
        return new[] { "Sunny", "Cloudy", "Rainy" };
    }
}
```



