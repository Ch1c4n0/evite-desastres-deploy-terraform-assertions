<div align="center">

<img src="https://img.shields.io/badge/HashiCorp-000000?style=for-the-badge&logo=hashicorp&logoColor=white" alt="HashiCorp" />&nbsp;
<img src="https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white" alt="Terraform" />&nbsp;
<img src="https://img.shields.io/badge/IBM_Champion_2026-052FAD?style=for-the-badge&logo=ibm&logoColor=white" alt="IBM Champion 2026" />

<br/><br/>

# 🚀 Evite Desastres no Deploy
### Usando Assertions e Blocos `run` no Terraform

<br/>

<a href="#-versão-em-português">
  <img src="https://img.shields.io/badge/🇧🇷_Versão_em_Português-009c3b?style=for-the-badge&labelColor=FEDD00&color=009c3b" alt="Versão em Português" />
</a>
&nbsp;&nbsp;
<a href="#-english-version">
  <img src="https://img.shields.io/badge/🇺🇸_English_Version-B22234?style=for-the-badge&labelColor=3c3b6e&color=B22234" alt="English Version" />
</a>

</div>

---

## 🇧🇷 Versão em Português

### 📌 Introdução

O Terraform evoluiu demais nos últimos tempos. Antigamente, testar uma infraestrutura como código significava executar o `terraform apply` em um ambiente de homologação e ficar torcendo para que nada desse errado. Outra forma era recorrer a ferramentas externas complexas como o famoso **Terratest**, que exige conhecimento em **Go**.

Mas agora temos uma saída nativa: o comando **`terraform test`** e os arquivos de configuração `.tftest.hcl`. Neste repositório exploramos como esse recurso funciona, por que alguns analistas ainda resistem a adotá-lo, e demonstramos casos reais de uso com uma infraestrutura Azure completa.

---

### 🧪 O que é o `terraform test` e o arquivo `main.tftest.hcl`?

Introduzido de forma nativa a partir do **Terraform 1.6**, o arquivo `.tftest.hcl` permite criar **testes unitários e de integração** diretamente na linguagem HCL — sem dependências externas, sem Go, sem frameworks de terceiros. Você pode:

- Definir **cenários de teste** completos com contexto isolado
- **Injetar variáveis** específicas para o contexto de teste, sobrepondo os valores padrão
- **Validar outputs** e o estado real dos recursos após o apply
- Garantir que os recursos atendam **critérios obrigatórios** antes de chegar à produção

O comando para executar os testes é:

```bash
terraform test
```

Ele busca automaticamente por arquivos `.tftest.hcl` dentro da pasta `tests/` ou na raiz do módulo.

> 💡 **Versão mínima obrigatória:** Terraform >= 1.6.0. Verifique com `terraform version`.

---

### ❓ Por que os testes de infraestrutura são necessários?

Escrever código reutilizável é uma excelente prática, mas traz riscos inerentes. Uma alteração em um módulo compartilhado pode quebrar silenciosamente múltiplos projetos. Os testes garantem que:

- ✅ As mudanças no código sejam **seguras e previsíveis** antes de qualquer deploy
- ✅ **Políticas de conformidade** sejam respeitadas automaticamente (SKU obrigatório, IP Estático, tags)
- ✅ A lógica de condicionais (`count` e `for_each`) **funcione corretamente**
- ✅ Nenhuma mudança provoque **destruição acidental** de recursos críticos em produção

---

### 🤔 Por que alguns analistas ainda relutam em usar?

| Motivo | Explicação |
|--------|------------|
| **"O `plan` já testa"** | Falsa sensação de que o `terraform plan` cumpre o papel de teste. O plan valida apenas sintaxe e aceite da API do provedor — **não valida lógica de negócio, valores de propriedades ou comportamento de módulos** |
| **Falta de cultura de testes** | Escrever testes é uma cultura enraizada no desenvolvimento de software, mas muito recente no mundo de IaC |
| **Medo dos custos temporários** | O `terraform test` pode criar e destruir recursos reais. Na prática, os custos são mínimos e compensados pela primeira falha evitada |

> 💡 **Reflexão:** Superar essa resistência paga os custos temporários já na **primeira falha catastrófica evitada em produção**.

---

### 📁 Estrutura do Projeto

```
📦 Terraform Test
 ├── 📄 main.tf           → Configuração do Provider Azure (azurerm)
 ├── 📄 variables.tf      → Declaração de variáveis reutilizáveis
 ├── 📄 rg.tf             → Resource Group (container lógico Azure)
 ├── 📄 vnet.tf           → VNet, Subnet e IP Público Estático
 ├── 📄 vm.tf             → Network Interface e Máquina Virtual Linux
 ├── 📄 nsg.tf            → Network Security Group (firewall)
 ├── 📄 output.tf         → Outputs consolidados da infraestrutura
 └── 📁 tests/
      └── 📄 main.tftest.hcl  → Arquivo de testes com assertions
```

---

### 📘 Explicação Detalhada de Cada Arquivo

#### `main.tf` — Configuração do Provider

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.50.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "Your_Subscription"
}
```

Este é o **arquivo de entrada do Terraform**. Ele estabelece dois contratos fundamentais:

**Bloco `terraform {}` — Declaração de dependências:**
- `required_providers` instrui o Terraform sobre quais plugins baixar durante `terraform init`
- `source = "hashicorp/azurerm"` aponta para o registro oficial da HashiCorp
- `version = "~> 3.50.0"` usa o **pessimistic constraint operator (`~>`)**, que significa `>= 3.50.0` AND `< 3.51.0`. Essa notação protege contra breaking changes em versões minor inesperadas, garantindo reprodutibilidade entre ambientes

**Bloco `provider "azurerm" {}` — Configuração do cliente Azure:**
- `features {}` é obrigatório no AzureRM e permite customizações de comportamento
- `subscription_id` define qual assinatura Azure receberá os recursos provisionados

> ⚠️ **Segurança:** Em produção, nunca coloque `subscription_id` diretamente no código. Use variáveis de ambiente (`ARM_SUBSCRIPTION_ID`) ou injeção segura via pipeline CI/CD.

---

#### `variables.tf` — Declaração de Variáveis

```hcl
variable "resource_group_name" { default = "rg-terraform-test" }
variable "location"            { default = "East US" }
variable "vm_name"             { default = "vm-test-01" }
variable "vm_size"             { default = "Standard_B1s" }
```

Variáveis tornam o código **reutilizável, testável e parametrizável**:

| Variável | Valor Padrão | Papel |
|----------|-------------|-------|
| `resource_group_name` | `rg-terraform-test` | Container lógico Azure onde todos os recursos vivem |
| `location` | `East US` | Região Azure — afeta latência, disponibilidade e conformidade |
| `vm_name` | `vm-test-01` | Identificador da VM no portal Azure |
| `vm_size` | `Standard_B1s` | **SKU da VM — diretamente validado pelo teste `check_vm_sku`** |

> 🔬 **Conexão com os testes:** O arquivo de testes injeta `vm_size = "Standard_B1s"` explicitamente. Se alguém alterar o default para `Standard_D4s_v5` por engano, o teste **falha imediatamente antes de qualquer deploy**.

---

#### `rg.tf` — Resource Group

```hcl
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}
```

O **Resource Group** é o container lógico fundamental do Azure. Todos os controles de acesso (RBAC) e operações de ciclo de vida podem ser aplicados nesse nível. O identificador local `rg` é usado em todos os outros arquivos para criar **dependências implícitas** — o Terraform constrói automaticamente o grafo de dependências e garante que o RG exista antes de qualquer outro recurso.

---

#### `vnet.tf` — Rede Virtual, Subnet e IP Público

```hcl
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-terraform-test"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "snet-internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "pip-vm-test"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}
```

Define a **topologia completa de rede** com três recursos interdependentes:

**`azurerm_virtual_network` — A VNet:**
- `address_space = ["10.0.0.0/16"]` define o range CIDR. É uma lista — por isso o teste usa `address_space[0]`
- 🔴 **Target do teste `check_vnet_address_space`:** Alterar o range da VNet em ambientes com VNet Peering ou ExpressRoute **força destruição e recriação completa** da VNet, derrubando todas as subnets, VMs e conexões

**`azurerm_subnet` — A Subnet:**
- Subdivide o `/16` em uma subnet `/24` com capacidade para 251 hosts
- Cria dependência explícita na VNet via `virtual_network_name`

**`azurerm_public_ip` — O IP Público:**
- `allocation_method = "Static"` garante que o endereço IP **não muda** entre reinicializações
- `sku = "Standard"` é obrigatório para Load Balancers, zonas de disponibilidade e Azure Firewall
- 🔴 **Target do teste `check_network_config`:** Um IP `Dynamic` quebra registros DNS, regras de firewall e certificados TLS vinculados ao IP

---

#### `vm.tf` — Interface de Rede e Máquina Virtual Linux

```hcl
resource "azurerm_network_interface" "nic" {
  name                = "nic-vm-test"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = var.vm_name
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = var.vm_size
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}
```

O **coração da infraestrutura** — a camada de computação:

**`azurerm_network_interface` — A NIC:**
- Conecta a VM à subnet, associando o IP Público via `public_ip_address_id`
- `private_ip_address_allocation = "Dynamic"` é aceitável para o IP privado interno

**`azurerm_linux_virtual_machine` — A VM:**
- `size = var.vm_size` — SKU controlado pela variável e **validado pelo teste `check_vm_sku`**
- Imagem Ubuntu Server 18.04 LTS da Canonical
- OS Disk com `Standard_LRS` — HDD gerenciado econômico para laboratório
- `disable_password_authentication = false` — aceitável apenas em lab

> ⚠️ **Alerta crítico de segurança:** Em produção, **NUNCA** use senhas hardcoded no código Terraform. Use SSH keys com `disable_password_authentication = true` e armazene credenciais no Azure Key Vault. Senhas no código ficam expostas no histórico do Git e nos logs de pipeline.

---

#### `nsg.tf` — Network Security Group

```hcl
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-test"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
```

O NSG funciona como um **firewall stateful de camada 4** gerenciado pelo Azure. Regras com menor número de prioridade têm precedência.

A regra `SSH` permite conexão na **porta 22** de qualquer origem (`*`). Em produção, restrinja `source_address_prefix` ao CIDR corporativo.

> 🔒 **Extensão natural dos testes:** Uma assertion futura poderia validar que SSH não está exposto publicamente:
> ```hcl
> assert {
>   condition     = tolist(azurerm_network_security_group.nsg.security_rule)[0].source_address_prefix != "*"
>   error_message = "Erro: SSH não pode ser exposto para a internet pública."
> }
> ```

---

#### `output.tf` — Saídas da Infraestrutura

```hcl
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
```

O bloco `output` tem dois papéis:

1. **Exibição após apply:** Consolida as informações mais relevantes no terminal
2. **Dados para outros módulos:** Consumível via `terraform_remote_state`

> 🔬 **Uso em testes:** Outputs também podem ser validados em assertions para verificar valores calculados pelo Terraform.

---

### 🧪 Análise Completa: `tests/main.tftest.hcl`

#### Bloco `variables {}` — Injeção de Contexto de Teste

```hcl
variables {
  vm_size = "Standard_B1s"
}
```

**O que faz:** Injeta variáveis que se aplicam a **todos os blocos `run`** do arquivo, sobrepondo os valores padrão de `variables.tf`. Cria um **contexto de teste isolado e determinístico** — o teste sempre executa com os mesmos valores, independente do ambiente.

**Por que importa:** Permite testar cenários específicos sem alterar os arquivos de configuração principal. Em CI/CD, diferentes arquivos `.tftest.hcl` podem testar o mesmo módulo com diferentes conjuntos de variáveis.

---

#### Bloco `run "check_vm_sku"` — Validação do SKU da VM

```hcl
run "check_vm_sku" {
  command = apply
  assert {
    condition     = azurerm_linux_virtual_machine.vm.size == "Standard_B1s"
    error_message = "Erro: O tamanho da VM deve ser Standard_B1s."
  }
}
```

| Elemento | Significado |
|----------|-------------|
| `run "check_vm_sku"` | Nome descritivo do cenário — aparece no output do `terraform test` |
| `command = apply` | Executa `terraform apply` real, criando recursos na nuvem para validação |
| `condition` | Expressão HCL booleana acessando o **estado real** do recurso após o apply |
| `error_message` | Mensagem exibida quando `condition` é `false` — essencial para diagnóstico em pipelines |

**Caso de uso real:** Desenvolvedor muda `variables.tf` para `Standard_D4s_v5` pensando em "melhorar a performance". O custo mensal salta de ~$8 para ~$140. O teste **detecta a divergência e falha imediatamente**, bloqueando o merge.

---

#### Bloco `run "check_network_config"` — Validação do IP Estático

```hcl
run "check_network_config" {
  command = apply
  assert {
    condition     = azurerm_public_ip.pip.allocation_method == "Static"
    error_message = "Erro: O IP Público precisa ser Estático."
  }
}
```

**O que valida:** Garante que `allocation_method` permanece `"Static"` após o apply.

**Caso de uso real:** Analista muda para `Dynamic` pensando economizar. O impacto real seria:
- ❌ Registros DNS apontando para o IP antigo param de funcionar
- ❌ Regras de firewall on-premises (whitelist de IP) bloqueiam a VM
- ❌ Certificados TLS vinculados ao IP ficam inválidos
- ❌ Políticas de acesso condicional da organização são violadas

O teste **captura a mudança antes do deploy**, protegendo todos os sistemas dependentes.

---

#### Bloco `run "check_vnet_address_space"` — Validação do Range de Rede

```hcl
run "check_vnet_address_space" {
  command = apply
  assert {
    condition     = azurerm_virtual_network.vnet.address_space[0] == "10.0.0.0/16"
    error_message = "Erro: O range da VNet está incorreto."
  }
}
```

**Por que `address_space[0]`?** O atributo `address_space` é uma **lista** no schema do AzureRM (VNets podem ter múltiplos ranges). O índice `[0]` acessa o range primário.

**O teste mais crítico do conjunto.** Em ambientes corporativos:
- VNet Peering exige ranges não sobrepostos — alterar o range força reconfiguração de TODOS os peerings
- ExpressRoute e VPN Gateway têm tabelas de rota baseadas nos ranges das VNets
- **Alterar `address_space` em VNet existente força DESTRUIÇÃO E RECRIAÇÃO COMPLETA** — derrubando todas as subnets, VMs, App Services e qualquer recurso dentro dela

Uma falha aqui evita uma **indisponibilidade total do ambiente**.

---

### 🚀 Como Executar os Testes

**Pré-requisitos:**
- Terraform >= 1.6.0
- Azure CLI autenticado (`az login`) ou variáveis ARM configuradas
- `subscription_id` atualizado em `main.tf`

```bash
# 1. Inicializar os providers
terraform init

# 2. Executar todos os testes
terraform test

# 3. Executar um arquivo específico
terraform test -filter="tests/main.tftest.hcl"

# 4. Modo verbose — ver detalhes de cada assertion
terraform test -verbose
```

**Output esperado (sucesso):**
```
Tests passed! 3/3
  - check_vm_sku ... ok
  - check_network_config ... ok
  - check_vnet_address_space ... ok
```

> 💡 **Dica de custo:** Use `command = plan` em vez de `command = apply` para testes que não precisam validar o estado real — testes de plan são gratuitos e muito mais rápidos.

---

### 🎯 Conclusão

O `terraform test` com assertions transforma o modelo de deploy baseado na **esperança** para um modelo baseado na **engenharia previsível**:

| Teste | Protege contra |
|-------|----------------|
| `check_vm_sku` | Aumento acidental de custos por mudança de SKU |
| `check_network_config` | Quebra de DNS, firewall e certificados por IP dinâmico |
| `check_vnet_address_space` | Destruição catastrófica de rede por mudança de range CIDR |

Superar a resistência cultural ao uso do `main.tftest.hcl` paga os custos temporários já na **primeira falha catastrófica evitada**. Este é o caminho da infraestrutura madura.

---

<div align="center">
<a href="#-english-version">
  <img src="https://img.shields.io/badge/🇺🇸_Switch_to_English-B22234?style=for-the-badge&labelColor=3c3b6e" alt="Switch to English" />
</a>
</div>

---

## 🇺🇸 English Version

### 📌 Introduction

Terraform has evolved enormously over the years. In the past, testing infrastructure as code meant running `terraform apply` on a staging environment and hoping nothing would go wrong. The alternative was using complex external tools like the famous **Terratest**, which requires knowledge of **Go**.

But now we have a native solution: the **`terraform test`** command and `.tftest.hcl` configuration files. This repository explores how this feature works, why some analysts still resist adopting it, and demonstrates real-world use cases with a complete Azure infrastructure.

---

### 🧪 What is `terraform test` and `main.tftest.hcl`?

Introduced natively in **Terraform 1.6**, the `.tftest.hcl` file allows you to create **unit and integration tests** directly in HCL — no external dependencies, no Go, no third-party frameworks. You can:

- Define complete **test scenarios** with isolated context
- **Inject variables** specific to the test context, overriding default values
- **Validate outputs** and the real state of resources after apply
- Ensure resources meet **mandatory criteria** before reaching production

```bash
terraform test
```

It automatically finds `.tftest.hcl` files inside the `tests/` folder or at the module root.

> 💡 **Minimum required version:** Terraform >= 1.6.0. Check with `terraform version`.

---

### ❓ Why is infrastructure testing necessary?

Writing reusable code is excellent practice, but it carries inherent risks. A change to a shared module can silently break multiple projects. Tests ensure that:

- ✅ Code changes are **safe and predictable** before any deployment
- ✅ **Compliance policies** are automatically respected (required SKU, Static IP, tags)
- ✅ Conditional logic (`count` and `for_each`) **works correctly** for all scenarios
- ✅ No change causes **accidental destruction** of critical production resources

---

### 🤔 Why do some analysts still resist?

| Reason | Explanation |
|--------|-------------|
| **"Plan already tests"** | False sense that `terraform plan` fulfills the testing role. Plan only validates syntax and provider API acceptance — **it does not validate business logic, property values, or module behavior** |
| **Lack of testing culture** | Writing tests is ingrained in software development culture, but still very new in the IaC world |
| **Cost concerns** | `terraform test` can create and destroy real cloud resources. In practice, costs are minimal and offset by the first failure avoided |

> 💡 **Insight:** Overcoming this resistance pays for temporary costs at the **very first catastrophic production failure avoided**.

---

### 📁 Project Structure

```
📦 Terraform Test
 ├── 📄 main.tf           → Azure Provider Configuration (azurerm)
 ├── 📄 variables.tf      → Reusable variable declarations
 ├── 📄 rg.tf             → Resource Group (Azure logical container)
 ├── 📄 vnet.tf           → VNet, Subnet and Static Public IP
 ├── 📄 vm.tf             → Network Interface and Linux VM
 ├── 📄 nsg.tf            → Network Security Group (firewall rules)
 ├── 📄 output.tf         → Consolidated infrastructure outputs
 └── 📁 tests/
      └── 📄 main.tftest.hcl  → Test file with assertions
```

---

### 📘 Detailed File Explanations

#### `main.tf` — Provider Configuration

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.50.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "Your_Subscription"
}
```

The **Terraform entry point**, establishing two fundamental contracts:

**`terraform {}` block — Dependency declaration:**
- `required_providers` tells Terraform which plugins to download during `terraform init`
- `source = "hashicorp/azurerm"` points to the official HashiCorp registry
- `version = "~> 3.50.0"` uses the **pessimistic constraint operator (`~>`)** — meaning `>= 3.50.0` AND `< 3.51.0`, protecting against unexpected breaking changes

**`provider "azurerm" {}` block — Azure client configuration:**
- `features {}` is mandatory in the AzureRM provider
- `subscription_id` defines which Azure subscription receives the provisioned resources

> ⚠️ **Security:** In production, never hardcode `subscription_id`. Use environment variables (`ARM_SUBSCRIPTION_ID`) or secure CI/CD pipeline injection.

---

#### `variables.tf` — Variable Declarations

```hcl
variable "resource_group_name" { default = "rg-terraform-test" }
variable "location"            { default = "East US" }
variable "vm_name"             { default = "vm-test-01" }
variable "vm_size"             { default = "Standard_B1s" }
```

| Variable | Default | Role |
|----------|---------|------|
| `resource_group_name` | `rg-terraform-test` | Azure container where all resources live |
| `location` | `East US` | Azure region — affects latency, availability, data compliance |
| `vm_name` | `vm-test-01` | VM identifier in Azure portal |
| `vm_size` | `Standard_B1s` | **VM SKU — directly validated by `check_vm_sku` test** |

> 🔬 **Test connection:** The test file explicitly injects `vm_size = "Standard_B1s"`. If someone changes the default to `Standard_D4s_v5` accidentally, the test **fails immediately before any production deployment**.

---

#### `rg.tf` — Resource Group

The fundamental Azure logical container. The local identifier `rg` creates **implicit dependency chains** — Terraform ensures the Resource Group exists before any other resource is created.

---

#### `vnet.tf` — Virtual Network, Subnet and Public IP

Three interdependent networking resources:

- **`azurerm_virtual_network`:** VNet with `10.0.0.0/16` address space — 🔴 **target of `check_vnet_address_space` test**. Changing this range in corporate environments with VNet Peering forces **complete network destruction**
- **`azurerm_subnet`:** Internal subnet with `/24` prefix (251 hosts)
- **`azurerm_public_ip`:** Static Standard IP — 🔴 **target of `check_network_config` test**. A Dynamic IP breaks DNS records, firewall whitelists, and TLS certificates

---

#### `vm.tf` — Network Interface and Linux VM

The heart of the infrastructure:

- **NIC:** Connects the VM to the subnet and associates the Public IP
- **VM:** Ubuntu 18.04 LTS with `size = var.vm_size` — **the primary test target**

> ⚠️ **Security alert:** In production, **NEVER** use hardcoded passwords. Use SSH keys with `disable_password_authentication = true` and store credentials in Azure Key Vault.

---

#### `nsg.tf` — Network Security Group

Layer 4 stateful firewall allowing SSH (port 22) inbound. Restrict `source_address_prefix` to known CIDRs in production environments.

---

#### `output.tf` — Infrastructure Outputs

Exposes a consolidated summary object after `apply`. Outputs can also be validated in test assertions to verify values computed by Terraform.

---

### 🧪 Full Analysis: `tests/main.tftest.hcl`

#### `variables {}` block — Test Context Injection

```hcl
variables {
  vm_size = "Standard_B1s"
}
```

Injects variable values applying to **all `run` blocks**, overriding `variables.tf` defaults. Creates a **deterministic, isolated test context** — the test always executes with the same values regardless of environment.

---

#### `run "check_vm_sku"` — VM SKU Validation

```hcl
run "check_vm_sku" {
  command = apply
  assert {
    condition     = azurerm_linux_virtual_machine.vm.size == "Standard_B1s"
    error_message = "Erro: O tamanho da VM deve ser Standard_B1s."
  }
}
```

| Element | Meaning |
|---------|---------|
| `run "check_vm_sku"` | Descriptive scenario name — appears in `terraform test` output |
| `command = apply` | Executes real `terraform apply`, creating cloud resources for validation |
| `condition` | Boolean HCL expression accessing **real resource state** after apply |
| `error_message` | Message displayed when `condition` is `false` — critical for pipeline diagnostics |

**Real scenario:** Developer changes `variables.tf` to `Standard_D4s_v5` for "better performance." Monthly cost jumps from ~$8 to ~$140. The test **detects the divergence and fails immediately**, blocking the merge.

---

#### `run "check_network_config"` — Static IP Validation

```hcl
run "check_network_config" {
  command = apply
  assert {
    condition     = azurerm_public_ip.pip.allocation_method == "Static"
    error_message = "Erro: O IP Público precisa ser Estático."
  }
}
```

**What it prevents:** Analyst changes to `Dynamic` IP to "reduce costs." Real impact:
- ❌ DNS records pointing to old IP stop working
- ❌ On-premises firewall rules (IP whitelist) block the VM
- ❌ TLS certificates bound to the IP become invalid
- ❌ Organization's conditional access policies are violated

---

#### `run "check_vnet_address_space"` — Network Range Validation

```hcl
run "check_vnet_address_space" {
  command = apply
  assert {
    condition     = azurerm_virtual_network.vnet.address_space[0] == "10.0.0.0/16"
    error_message = "Erro: O range da VNet está incorreto."
  }
}
```

**Why `address_space[0]`?** The attribute is a **list** in AzureRM schema. Index `[0]` accesses the primary range.

**The most critical test.** In corporate environments:
- VNet Peering requires non-overlapping ranges — changing forces reconfiguration of ALL peerings
- **Changing `address_space` on an existing VNet forces COMPLETE DESTRUCTION AND RECREATION** — taking down all subnets, VMs, App Services, and every resource inside

A test failure here prevents a **total environment outage**.

---

### 🚀 How to Run the Tests

```bash
# Initialize providers
terraform init

# Run all tests
terraform test

# Run a specific file
terraform test -filter="tests/main.tftest.hcl"

# Verbose mode
terraform test -verbose
```

> 💡 **Cost tip:** Use `command = plan` instead of `command = apply` for tests that don't need to validate real state — plan tests are free and much faster.

---

### 🎯 Conclusion

`terraform test` with assertions transforms the deployment model from **hope-based** to **predictable engineering**:

| Test | Protects Against |
|------|-----------------|
| `check_vm_sku` | Accidental cost increase from SKU change |
| `check_network_config` | DNS, firewall, and certificate breakage from dynamic IP |
| `check_vnet_address_space` | Catastrophic network destruction from CIDR range change |

Overcoming cultural resistance to `main.tftest.hcl` pays for temporary costs at the **very first catastrophic failure avoided**. This is the path to mature infrastructure engineering.

---

<div align="center">
<a href="#-versão-em-português">
  <img src="https://img.shields.io/badge/🇧🇷_Mudar_para_Português-009c3b?style=for-the-badge&labelColor=FEDD00" alt="Mudar para Português" />
</a>
&nbsp;
<a href="#-english-version">
  <img src="https://img.shields.io/badge/⬆️_Back_to_Top-grey?style=for-the-badge" alt="Back to top" />
</a>
</div>
