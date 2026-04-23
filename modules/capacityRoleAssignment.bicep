@description('Name of the existing Fabric capacity to assign the role on')
param capacityName string

@description('Principal ID of the Logic App managed identity')
param principalId string

@description('Full resource ID of the role definition to assign')
param roleDefinitionId string

@description('Unique suffix to make the role assignment name deterministic')
param logicAppResourceId string

resource fabricCapacity 'Microsoft.Fabric/capacities@2023-11-01' existing = {
  name: capacityName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(fabricCapacity.id, logicAppResourceId, roleDefinitionId)
  scope: fabricCapacity
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
