#!/bin/bash
# check-names.sh — Vérification des noms uniques avant déploiement

echo "Vérification des noms Azure uniques..."
echo "=========================================="

# Lire les valeurs du tfvars
STORAGE=$(grep 'storage_account_name' terraform.tfvars | awk -F'"' '{print $2}')
FIREWALL=$(grep 'firewall_name' terraform.tfvars | awk -F'"' '{print $2}')
VNET=$(grep 'vnet_name' terraform.tfvars | awk -F'"' '{print $2}')
RG=$(grep 'resource_group_name' terraform.tfvars | awk -F'"' '{print $2}')

# 1. Storage Account 
echo ""
echo "Storage Account : $STORAGE"
RESULT=$(az storage account check-name --name "$STORAGE" --query nameAvailable -o tsv)
if [ "$RESULT" = "true" ]; then
  echo "   Disponible"
else
  REASON=$(az storage account check-name --name "$STORAGE" --query message -o tsv)
  echo "   Indisponible — $REASON"
fi

# 2. Resource Group 
echo ""
echo "Resource Group : $RG"
RG_EXISTS=$(az group exists --name "$RG")
if [ "$RG_EXISTS" = "false" ]; then
  echo "   Disponible"
else
  echo "   Existe déjà (sera réutilisé ou écrasé)"
fi

# 3. VNet 
echo ""
echo "Virtual Network : $VNET"
VNET_EXISTS=$(az network vnet show --name "$VNET" --resource-group "$RG" 2>/dev/null)
if [ -z "$VNET_EXISTS" ]; then
  echo "   Disponible"
else
  echo "   Existe déjà dans $RG"
fi

# 4. Firewall 
echo ""
echo "Azure Firewall : $FIREWALL"
FW_EXISTS=$(az network firewall show --name "$FIREWALL" --resource-group "$RG" 2>/dev/null)
if [ -z "$FW_EXISTS" ]; then
  echo "   Disponible"
else
  echo "   Existe déjà dans $RG"
fi

echo ""
echo "=========================================="
echo "Vérification terminée. Corrige les avant de lancer terraform apply."