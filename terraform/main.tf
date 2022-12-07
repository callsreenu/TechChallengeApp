#Set up the provider for Azure
terraform {
 backend "azurerm" {}
}
provider "azurerm" {
 # Whilst version is optional, we /strongly recommend/ using it to pin the version of the Provider being used
 version         = "=2.18.0"
 subscription_id = var.acr_subscription_id
 features {}
 skip_provider_registration = "true"

}
provider "azuread" {
 version = "=0.7.0"
}

#Get user assign identity
data "azurerm_user_assigned_identity" "assigned_identity_acr_pull" {
 provider            = azurerm.acr_sub
 name                = "GoLang_Test"
 resource_group_name = "GOIAC"
}

#App service plan
resource "azurerm_app_service_plan" "Go_Asp01" {
 name                = "Go_Asp01"
 location            = "Australia East"
 resource_group_name = "GOIAC"
 kind                = "Linux"
 reserved            = true

 sku {
   tier     = "PremiumV2"
   size     = "P2v2"
   capacity = "3"
 }
}

#App service
resource "azurerm_app_service" "GoApp_container" {
 name                    = "GoApp_container"
 location                = "Australia East"
 resource_group_name     = "GOIAC"
 app_service_plan_id     = azurerm_app_service_plan.my_service_plan.id
 https_only              = true
 client_affinity_enabled = true
 site_config {
   scm_type  = "VSTSRM"
   always_on = "true"

   linux_fx_version  = "DOCKER|sreenu.terraform.io/Go:latest" #define the images to usecfor you application

   health_check_path = "/health" # health check required in order that internal app service plan loadbalancer do not loadbalance on instance down
 }

 identity {
   type         = "SystemAssigned, UserAssigned"
   identity_ids = [data.azurerm_user_assigned_identity.assigned_identity_acr_pull.id]
 }

 app_settings = local.env_variables 
}

#Staging slot
resource "azurerm_app_service_slot" "GoApp_container_staging" {
 name                    = "Go-staging"
 app_service_name        = azurerm_app_service.my_app_service_container.name
 location                = "Australia East"
 resource_group_name     = "GOIAC"
 app_service_plan_id     = azurerm_app_service_plan.my_service_plan.id
 https_only              = true
 client_affinity_enabled = true
 site_config {
   scm_type          = "VSTSRM"
   always_on         = "true"
   health_check_path = "/login"
 }

 identity {
   type         = "SystemAssigned, UserAssigned"
   identity_ids = [data.azurerm_user_assigned_identity.assigned_identity_acr_pull.id]
 }

 app_settings = local.env_variables
}

#Monitoring - App Insight
resource "azurerm_application_insights" "Go_app_insight" {
 name                = "Go_app_insight"
 location            = "Australia East"
 resource_group_name = "GOIAC"
 application_type    = "GO" # Depends on your application
 disable_ip_masking  = true
 retention_in_days   = 730
}

#App Container Registry
resource "azurerm_container_registry" "Go" {
  name                = "Go_containerRegistry"
  resource_group_name = GOIAC
  app_service_plan_id     = azurerm_app_service_plan.Go_Asp01.id
  location            = Australia East
  sku                 = "Standard"
  admin_enabled       = true
  georeplications {
    location                = "Australia South East"
    zone_redundancy_enabled = true
    tags                    = {}
  }

#App Key Vault
module "Go_az_kv" {
  source                        = "Sreenu.terraform.io/Sreenu/keyvault-cloud/azurerm"
  version                       = "0.2.0"
  keyvault_name                 = "Go_kv_AUE"
  location                      = "Australia East"
  rgname                        = "GOIAC"
  kv_soft_delete_retention_days = 70
  kv_sku                        = Standard
  external_ipaddresses          = [10.20.137.16,10.20.137.57]
  virtual_subnet_ids            = 172.315.23.01/16

}

#App Postgres sql server
resource "azurerm_postgresql_server" "Go_DB" {
  name                = "Go-DB-server"
  location            = "Australia East"
  resource_group_name = "GOIAC"

  administrator_login          = "admin"
  administrator_login_password = "admin"

  sku_name   = "GP_Gen5_4"
  version    = "11"
  storage_mb = 100000

  backup_retention_days        = 7
  geo_redundant_backup_enabled = true
  auto_grow_enabled            = true

  public_network_access_enabled    = false
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
}