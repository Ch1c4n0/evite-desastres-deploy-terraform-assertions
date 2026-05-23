output "vm_infrastructure_summary" {
  value = {
    "Resource_Group" = azurerm_resource_group.rg.name
    "VM_Name"        = azurerm_linux_virtual_machine.vm.name
    "VM_Size"        = azurerm_linux_virtual_machine.vm.size
    "Public_IP"      = azurerm_public_ip.pip.ip_address
    "VNet_Range"     = azurerm_virtual_network.vnet.address_space[0]
    "Location"       = var.location
  }
  description = "Resumo da infraestrutura provisionada no Azure."
}
