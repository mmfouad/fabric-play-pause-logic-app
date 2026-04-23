@description('Name prefix for the Logic App resources')
param namePrefix string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the existing Fabric capacity to manage')
param fabricCapacityName string

@description('Your UTC offset in whole hours (e.g. -5 for Eastern, 0 for UTC, 1 for Central Europe, 8 for Singapore). Half-hour zones: use the nearest whole hour.')
@minValue(-12)
@maxValue(14)
param utcOffsetHours int = 0

@description('Name of the resource group that contains the Fabric capacity (may differ from the deployment resource group)')
param fabricCapacityResourceGroupName string = resourceGroup().name

@description('Hour to resume the capacity (24-hour format)')
param resumeHour int = 8

@description('Hour to suspend the capacity (24-hour format)')
param suspendHour int = 17

@description('Run schedule on Monday')
param runOnMonday bool = true

@description('Run schedule on Tuesday')
param runOnTuesday bool = true

@description('Run schedule on Wednesday')
param runOnWednesday bool = true

@description('Run schedule on Thursday')
param runOnThursday bool = true

@description('Run schedule on Friday')
param runOnFriday bool = true

@description('Run schedule on Saturday')
param runOnSaturday bool = false

@description('Run schedule on Sunday')
param runOnSunday bool = false

// Built-in Contributor role definition ID
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

// Convert local hours to UTC by subtracting the offset.
// +48 ensures the result is always positive before the modulo.
var resumeHourUtc = (resumeHour - utcOffsetHours + 48) % 24
var suspendHourUtc = (suspendHour - utcOffsetHours + 48) % 24

var selectedWeekDays = concat(
  runOnMonday ? [
    'Monday'
  ] : [],
  runOnTuesday ? [
    'Tuesday'
  ] : [],
  runOnWednesday ? [
    'Wednesday'
  ] : [],
  runOnThursday ? [
    'Thursday'
  ] : [],
  runOnFriday ? [
    'Friday'
  ] : [],
  runOnSaturday ? [
    'Saturday'
  ] : [],
  runOnSunday ? [
    'Sunday'
  ] : []
)

// Reference the existing Fabric capacity – supports cross-resource-group deployments
resource fabricCapacity 'Microsoft.Fabric/capacities@2023-11-01' existing = {
  name: fabricCapacityName
  scope: resourceGroup(fabricCapacityResourceGroupName)
}

// ---------------------------------------------------------------------------
// Resume Logic App – fires Mon-Fri at the configured resumeHour
// ---------------------------------------------------------------------------
resource resumeApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: '${namePrefix}-resume'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        Recurrence: {
          type: 'Recurrence'
          recurrence: {
            frequency: 'Week'
            interval: 1
            schedule: {
              weekDays: selectedWeekDays
              hours: [
                resumeHourUtc
              ]
              minutes: [
                0
              ]
            }
            timeZone: 'UTC'
          }
        }
      }
      actions: {
        // Read the capacity first – this captures the full resource including
        // the administration.members list and all other properties so they are
        // visible in the run history for auditing purposes.
        // Suspend / Resume are state-only operations and never modify
        // properties, SKU, or administrators.
        Get_Current_Capacity_State: {
          type: 'Http'
          inputs: {
            method: 'GET'
            uri: 'https://management.azure.com${fabricCapacity.id}?api-version=2023-11-01'
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: 'https://management.azure.com'
            }
          }
          runAfter: {}
        }
        Check_If_Paused: {
          type: 'If'
          expression: {
            and: [
              {
                equals: [
                  '@body(\'Get_Current_Capacity_State\')?[\'properties\']?[\'state\']'
                  'Paused'
                ]
              }
            ]
          }
          actions: {
            Resume_Capacity: {
              type: 'Http'
              inputs: {
                method: 'POST'
                uri: 'https://management.azure.com${fabricCapacity.id}/resume?api-version=2023-11-01'
                authentication: {
                  type: 'ManagedServiceIdentity'
                  audience: 'https://management.azure.com'
                }
              }
              runAfter: {}
            }
          }
          else: {
            actions: {}
          }
          runAfter: {
            Get_Current_Capacity_State: [
              'Succeeded'
            ]
          }
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Suspend Logic App – fires Mon-Fri at the configured suspendHour
// ---------------------------------------------------------------------------
resource suspendApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: '${namePrefix}-suspend'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        Recurrence: {
          type: 'Recurrence'
          recurrence: {
            frequency: 'Week'
            interval: 1
            schedule: {
              weekDays: selectedWeekDays
              hours: [
                suspendHourUtc
              ]
              minutes: [
                0
              ]
            }
            timeZone: 'UTC'
          }
        }
      }
      actions: {
        Get_Current_Capacity_State: {
          type: 'Http'
          inputs: {
            method: 'GET'
            uri: 'https://management.azure.com${fabricCapacity.id}?api-version=2023-11-01'
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: 'https://management.azure.com'
            }
          }
          runAfter: {}
        }
        Check_If_Active: {
          type: 'If'
          expression: {
            and: [
              {
                equals: [
                  '@body(\'Get_Current_Capacity_State\')?[\'properties\']?[\'state\']'
                  'Active'
                ]
              }
            ]
          }
          actions: {
            Suspend_Capacity: {
              type: 'Http'
              inputs: {
                method: 'POST'
                uri: 'https://management.azure.com${fabricCapacity.id}/suspend?api-version=2023-11-01'
                authentication: {
                  type: 'ManagedServiceIdentity'
                  audience: 'https://management.azure.com'
                }
              }
              runAfter: {}
            }
          }
          else: {
            actions: {}
          }
          runAfter: {
            Get_Current_Capacity_State: [
              'Succeeded'
            ]
          }
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Role assignments – scoped to the resource group that owns the Fabric
// capacity so they work even when the Logic Apps live in a different RG.
// ---------------------------------------------------------------------------
module resumeRoleAssignment './modules/capacityRoleAssignment.bicep' = {
  name: 'resumeRoleAssignment'
  scope: resourceGroup(fabricCapacityResourceGroupName)
  params: {
    capacityName: fabricCapacityName
    principalId: resumeApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    logicAppResourceId: resumeApp.id
  }
}

module suspendRoleAssignment './modules/capacityRoleAssignment.bicep' = {
  name: 'suspendRoleAssignment'
  scope: resourceGroup(fabricCapacityResourceGroupName)
  params: {
    capacityName: fabricCapacityName
    principalId: suspendApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    logicAppResourceId: suspendApp.id
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output resumeLogicAppName string = resumeApp.name
output suspendLogicAppName string = suspendApp.name
output resumePrincipalId string = resumeApp.identity.principalId
output suspendPrincipalId string = suspendApp.identity.principalId
