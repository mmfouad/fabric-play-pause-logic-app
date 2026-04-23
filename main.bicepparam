using './main.bicep'

param namePrefix = '<your-prefix>'
param fabricCapacityName = '<your-fabric-capacity-name>'
param fabricCapacityResourceGroupName = '<resource-group-containing-fabric-capacity>'
param utcOffsetHours = 0       // e.g. -5 for Eastern, 0 for UTC, 1 for CET, 8 for SGT
param resumeHour = 8
param suspendHour = 17
param runOnMonday = true
param runOnTuesday = true
param runOnWednesday = true
param runOnThursday = true
param runOnFriday = true
param runOnSaturday = false
param runOnSunday = false
