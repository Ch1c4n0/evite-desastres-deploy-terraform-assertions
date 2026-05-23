variables {
  vm_size = "Standard_B1s"
}

run "check_vm_sku" {
  command = apply
  assert {
    condition     = azurerm_linux_virtual_machine.vm.size == "Standard_B1s"
    error_message = "Erro: O tamanho da VM deve ser Standard_B1s."
  }
}

run "check_network_config" {
  command = apply
  assert {
    condition     = azurerm_public_ip.pip.allocation_method == "Static"
    error_message = "Erro: O IP Público precisa ser Estático."
  }
}

run "check_vnet_address_space" {
  command = apply
  assert {
    condition     = azurerm_virtual_network.vnet.address_space[0] == "10.0.0.0/16"
    error_message = "Erro: O range da VNet está incorreto."
  }
}
