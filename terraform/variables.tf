locals {
 env_variables = {
   DOCKER_REGISTRY_SERVER_URL            = "https://arc01.azurecr.io"
   DOCKER_REGISTRY_SERVER_USERNAME       = "GoLangTest01"
   DOCKER_REGISTRY_SERVER_PASSWORD       = "**************"
   AZURE_MONITOR_INSTRUMENTATION_KEY = azurerm_application_insights.my_app_insight.instrumentation_key

 }
}