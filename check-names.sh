#!/bin/bash
# check-names.sh — Vérification des ressources avant déploiement

set -u

echo "Vérification des ressources Azure..."
echo "=========================================="

# Vérifier la présence du fichier
if [ ! -f terraform.tfvars ]; then
    echo "Erreur : terraform.tfvars introuvable"
    exit 1
fi

# Lecture des variables
STORAGE=$(grep 'storage_account_name' terraform.tfvars | awk -F'"' '{print $2}')
FIREWALL=$(grep 'firewall_name' terraform.tfvars | awk -F'"' '{print $2}')
VNET=$(grep 'vnet_name' terraform.tfvars | awk -F'"' '{print $2}')
RG=$(grep 'resource_group_name' terraform.tfvars | awk -F'"' '{print $2}')

# Vérification des valeurs
for VAR in STORAGE FIREWALL VNET RG; do
    if [ -z "${!VAR}" ]; then
        echo "Erreur : variable $VAR vide ou absente dans terraform.tfvars"
        exit 1
    fi
done

#
# 1. Storage Account
#
echo ""
echo "Storage Account : $STORAGE"

SA_CHECK=$(az storage account check-name \
    --name "$STORAGE" \
    --output json)

SA_AVAILABLE=$(echo "$SA_CHECK" | jq -r '.nameAvailable')

if [ "$SA_AVAILABLE" = "true" ]; then
    echo "   Disponible"
else
    SA_MESSAGE=$(echo "$SA_CHECK" | jq -r '.message')
    echo "   Indisponible — $SA_MESSAGE"
fi

#
# 2. Resource Group
#
echo ""
echo "Resource Group : $RG"

RG_EXISTS=$(az group exists --name "$RG")

if [ "$RG_EXISTS" = "true" ]; then
    echo "   Existe déjà"
else
    echo "   Disponible"
fi

#
# 3. Virtual Network
#
echo ""
echo "Virtual Network : $VNET"

if [ "$RG_EXISTS" = "true" ]; then

    VNET_EXISTS=$(az network vnet show \
        --name "$VNET" \
        --resource-group "$RG" \
        --query name \
        -o tsv 2>/dev/null)

    if [ -n "$VNET_EXISTS" ]; then
        echo "   Existe déjà dans $RG"
    else
        echo "   Disponible"
    fi

else
    echo "   Disponible "
fi

#
# 4. Azure Firewall
#
echo ""
echo "Azure Firewall : $FIREWALL"

if [ "$RG_EXISTS" = "true" ]; then

    FW_EXISTS=$(az resource show \
        --resource-group "$RG" \
        --name "$FIREWALL" \
        --resource-type Microsoft.Network/azureFirewalls \
        --query name \
        -o tsv 2>/dev/null)

    if [ -n "$FW_EXISTS" ]; then
        echo "   Existe déjà dans $RG"
    else
        echo "   Disponible"
    fi

else
    echo "   Disponible (Resource Group inexistant)"
fi

echo ""
echo "=========================================="
echo "Vérification terminée."
