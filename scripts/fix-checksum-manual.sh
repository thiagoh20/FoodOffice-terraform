#!/bin/bash
# Script rápido para actualizar el checksum en DynamoDB manualmente

ENVIRONMENT=${ENVIRONMENT:-dev}
CALCULATED_CHECKSUM=${1:-"b03d18b747546ae910ee77ba738c6569"}  # Checksum del error

LOCK_ID="foodoffice-terraform-state/environments/${ENVIRONMENT}/terraform.tfstate"

echo "🔧 Actualizando Digest en DynamoDB con checksum: ${CALCULATED_CHECKSUM}"

aws dynamodb update-item \
  --table-name terraform-state-lock \
  --key "{\"LockID\": {\"S\": \"${LOCK_ID}\"}}" \
  --update-expression "SET Digest = :digest" \
  --expression-attribute-values "{\":digest\": {\"S\": \"${CALCULATED_CHECKSUM}\"}}" \
  --region us-east-2

if [ $? -eq 0 ]; then
  echo "✅ Digest actualizado exitosamente"
else
  echo "❌ Error al actualizar. Intentando eliminar Digest..."
  aws dynamodb update-item \
    --table-name terraform-state-lock \
    --key "{\"LockID\": {\"S\": \"${LOCK_ID}\"}}" \
    --update-expression "REMOVE Digest" \
    --region us-east-2
fi
