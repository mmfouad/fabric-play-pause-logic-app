@description('Name prefix for the Logic App resources')
param namePrefix string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the existing Fabric capacity to manage')
param fabricCapacityName string

@description('Time zone for the schedule')
param timeZone string = 'Eastern Standard Time'

@description('Hour to resume the capacity (24-hour format)')
param resumeHour int = 8

@description('Hour to suspend the capacity (24-hour format)')
param suspendHour int = 17

// Built-in Contributor role definition ID
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

// Reference the existing Fabric capacity in the same resource group
resource fabricCapacity 'Microsoft.Fabric/capacities@2023-11-01' existing = {
  name: fabricCapacityName
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
              weekDays: [
                'Monday'
                'Tuesday'
                'Wednesday'
                'Thursday'
                'Friday'
              ]
              hours: [
                resumeHour
              ]
              minutes: [
                0
              ]
            }
            timeZone: timeZone
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
              weekDays: [
                'Monday'
                'Tuesday'
                'Wednesday'
                'Thursday'
                'Friday'
              ]
              hours: [
                suspendHour
              ]
              minutes: [
                0
              ]
            }
            timeZone: timeZone
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
// Role assignments – grant each Logic App's managed identity Contributor on
// the Fabric capacity so it can call resume / suspend.
// ---------------------------------------------------------------------------
resource resumeRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(fabricCapacity.id, resumeApp.id, contributorRoleId)
  scope: fabricCapacity
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: resumeApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource suspendRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(fabricCapacity.id, suspendApp.id, contributorRoleId)
  scope: fabricCapacity
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: suspendApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output resumeLogicAppName string = resumeApp.name
output suspendLogicAppName string = suspendApp.name
output resumePrincipalId string = resumeApp.identity.principalId
output suspendPrincipalId string = suspendApp.identity.principalId
