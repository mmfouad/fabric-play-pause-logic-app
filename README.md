# ⏯️ Fabric Capacity Auto Pause/Resume Logic App

Running a Microsoft Fabric capacity 24/7 is a great way to impress your cloud bill — and nobody else. This project deploys two Azure Logic Apps that automatically **resume** your capacity every weekday morning and **suspend** it every evening, so you only pay for what you actually use.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmmfouad%2Ffabric-play-pause-logic-app%2Fmain%2Fazuredeploy.json)

---

## 📌 What It Does

| Logic App | Schedule | Action |
|-----------|----------|--------|
| `<prefix>-resume` | Mon – Fri at **8:00 AM** | Resumes the capacity if it is paused |
| `<prefix>-suspend` | Mon – Fri at **5:00 PM** | Suspends the capacity if it is active |

Both Logic Apps read the current capacity state before acting, so duplicate calls are safe. The suspend/resume APIs are **state-only operations** — they never modify administrators, SKU, or any other capacity properties.

---

## ⚙️ Features

- ⏱️ Scheduled pause and resume on a weekday-only cadence
- 🔄 Fully automated — no manual intervention required
- 🔐 Secured with system-assigned managed identities (no secrets to manage)
- 💸 Significant cost savings by eliminating idle runtime
- 🧩 Easily customizable schedule, time zone, and naming prefix
- 🛡️ Preserves capacity administrators and all resource properties

---

## 🏗️ Architecture

```
┌──────────────┐  8 AM Mon-Fri   ┌────────────────────────┐
│  Recurrence  │────────────────▶│  GET capacity state    │
│  Trigger     │                 │  ↓                     │
└──────────────┘                 │  If Paused → POST      │
                                 │  /resume               │
                                 └────────────────────────┘

┌──────────────┐  5 PM Mon-Fri   ┌────────────────────────┐
│  Recurrence  │────────────────▶│  GET capacity state    │
│  Trigger     │                 │  ↓                     │
└──────────────┘                 │  If Active → POST      │
                                 │  /suspend              │
                                 └────────────────────────┘
```

- **Azure Logic Apps** for orchestration
- **Fabric REST API** (`Microsoft.Fabric/capacities`) for pause/resume
- **System-assigned Managed Identities** for authentication against Azure Resource Manager

---

## 📂 Repository Structure

```
├── main.bicep          # Bicep template (Logic Apps + role assignments)
├── main.bicepparam     # Parameter file — edit this before deploying
├── README.md
└── LICENSE
```

---

## 🚀 Step-by-Step Deployment

### Prerequisites

| Requirement | Details |
|-------------|---------|
| **Azure CLI** | `>= 2.50` — [Install](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| **Bicep CLI** | Bundled with Azure CLI or install separately |
| **Azure subscription** | With an existing Fabric capacity |
| **Permissions** | **Owner** or **User Access Administrator** on the Fabric capacity resource group (needed to create role assignments) |

### Step 1 — Clone the repository

```bash
git clone https://github.com/<your-org>/fabric-play-pause-logic-app.git
cd fabric-play-pause-logic-app
```

### Step 2 — Sign in to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### Step 3 — Edit the parameters file

Open `main.bicepparam` and replace the placeholder values:

```bicep
using './main.bicep'

param namePrefix         = 'my-fabric'           // prefix for Logic App names
param fabricCapacityName = 'my-capacity'          // name of your existing Fabric capacity
param timeZone           = 'Eastern Standard Time'
param resumeHour         = 8                      // 8 AM
param suspendHour        = 17                     // 5 PM
```

> **Tip:** For a full list of valid Windows time zone names run `[System.TimeZoneInfo]::GetSystemTimeZones()` in PowerShell.

### Step 4 — Deploy to Azure

```bash
az deployment group create \
  --resource-group <resource-group-with-fabric-capacity> \
  --template-file main.bicep \
  --parameters main.bicepparam
```

The template automatically:

1. Creates two Logic Apps (`<prefix>-resume` and `<prefix>-suspend`)
2. Assigns a **system-assigned managed identity** to each
3. Grants **Contributor** on the Fabric capacity to both identities

### Step 5 — Verify the deployment

```bash
az logic workflow list \
  --resource-group <resource-group-with-fabric-capacity> \
  --query "[?contains(name,'resume') || contains(name,'suspend')].{Name:name, State:state}" \
  --output table
```

You should see two workflows in the **Enabled** state.

### Step 6 — (Optional) Trigger a test run

```bash
az logic workflow run trigger \
  --resource-group <resource-group-with-fabric-capacity> \
  --name <prefix>-resume \
  --trigger-name Recurrence
```

Check the run history in the Azure Portal under **Logic App → Run history** to confirm the run succeeded.

---

## 🔑 Permissions

| Who | Role | Scope | Purpose |
|-----|------|-------|---------|
| **You** (deployer) | Owner *or* User Access Administrator | Resource group | Create role assignments during deployment |
| **Logic App managed identities** | Contributor | Fabric capacity | Call resume / suspend REST APIs |

The Contributor role assignments are created automatically by the Bicep template — no manual steps needed.

---

## 📉 Cost Impact

A Fabric capacity left running overnight and on weekends accrues **~128 hours of idle time per week**. Pausing during those hours can reduce your Fabric compute bill by up to **76%**.

---

## ⚠️ Important Notes

- Make sure no long-running jobs (Spark, pipelines, dataflows) are still executing at suspend time. Consider adding a buffer or checking job status before suspending.
- Add an **Action Group** or **Logic App alert rule** if you want email/Teams notifications on failures.
- Monitor **Logic App run history** in the Azure Portal for throttling or transient errors.
- The suspend/resume operations are idempotent — resuming an already-active capacity (or suspending an already-paused one) is a safe no-op.

---

## 📄 License

See [LICENSE](LICENSE) for details.
# ⏯️ Fabric Capacity Auto Pause/Resume Logic App

This project provides an automated solution to pause and resume a Microsoft Fabric capacity based on a defined schedule or trigger conditions using Azure Logic Apps.

📌 Overview

Running Fabric capacity 24/7 is a great way to impress your cloud bill and nobody else. This Logic App automates pausing and resuming the capacity so it only runs when it’s actually needed.

⚙️ Features
⏱️ Scheduled pause/resume (e.g., pause after hours, resume before business starts)
🔄 Fully automated using Azure Logic Apps
🔐 Secure authentication via Azure AD / Managed Identity
💸 Cost optimization by avoiding idle runtime
🧩 Easily customizable schedules and triggers
🏗️ Architecture

The solution uses:

Azure Logic Apps for orchestration
Microsoft Fabric REST APIs for pause and resume operations
Azure AD for authentication and authorization
🧪 Use Cases
Pause capacity during nights or weekends
Resume capacity before business or reporting hours
Reduce cost in non-production or dev/test environments
� Deployment

1. Edit `main.bicepparam` with your values:

```bicep
param namePrefix = 'my-fabric'           // prefix for Logic App resource names
param fabricCapacityName = 'my-capacity'  // existing Fabric capacity name
param timeZone = 'Eastern Standard Time' // IANA or Windows time zone
param resumeHour = 8                     // 8 AM resume
param suspendHour = 17                   // 5 PM suspend
```

2. Deploy with the Azure CLI:

```bash
az deployment group create \
  --resource-group <your-rg> \
  --template-file main.bicep \
  --parameters main.bicepparam
```

The template automatically:
- Creates two Logic Apps (`<prefix>-resume` and `<prefix>-suspend`)
- Assigns a **system-assigned managed identity** to each
- Grants **Contributor** on the Fabric capacity to both identities

🔑 Permissions Required
The deploying principal needs **Owner** or **User Access Administrator** on the Fabric capacity resource (to create the role assignments).
The managed identities receive **Contributor** automatically via the template.
📉 Benefits
Significant cost savings by eliminating idle runtime
Reduced manual intervention
Better operational discipline (forced, but still counts)
⚠️ Notes
Ensure no critical workloads are running before pausing
Add alerting/notifications for pause/resume actions if needed
Monitor execution logs for failures or throttling
