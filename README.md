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
🔧 Configuration
Deploy the Logic App in Azure
Configure authentication (Managed Identity or Service Principal)
Provide required parameters:
Fabric Capacity ID
Define scheduling triggers:
Pause schedule
Resume schedule
🔑 Permissions Required
Capacity Admin access on the Fabric capacity
API permissions to manage Fabric resources
📉 Benefits
Significant cost savings by eliminating idle runtime
Reduced manual intervention
Better operational discipline (forced, but still counts)
⚠️ Notes
Ensure no critical workloads are running before pausing
Add alerting/notifications for pause/resume actions if needed
Monitor execution logs for failures or throttling
