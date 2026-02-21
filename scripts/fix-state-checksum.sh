#!/bin/bash
# Script para resolver error de checksum entre S3 y DynamoDB
# Este error ocurre cuando el checksum en DynamoDB no coincide con el estado en S3

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración por defecto
ENVIRONMENT=${ENVIRONMENT:-dev}
BUCKET_NAME=${BUCKET_NAME:-foodoffice-terraform-state}
STATE_KEY="environments/${ENVIRONMENT}/terraform.tfstate"
BACKEND_REGION=${BACKEND_REGION:-us-east-2}
DYNAMODB_TABLE=${DYNAMODB_TABLE:-terraform-state-lock}
LOCK_ID="${BUCKET_NAME}/${STATE_KEY}"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Script de Reparación de Checksum de Estado            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Configuración:"
echo "  Ambiente: ${ENVIRONMENT}"
echo "  Bucket: ${BUCKET_NAME}"
echo "  State Key: ${STATE_KEY}"
echo "  Lock ID: ${LOCK_ID}"
echo "  Región: ${BACKEND_REGION}"
echo ""

# Verificar que AWS CLI esté disponible
if ! command -v aws &> /dev/null; then
  echo -e "${RED}❌ AWS CLI no está instalado${NC}"
  exit 1
fi

# Verificar credenciales de AWS
echo -e "${YELLOW}🔍 Verificando credenciales de AWS...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
  echo -e "${RED}❌ No se pudieron validar las credenciales de AWS${NC}"
  exit 1
fi
echo -e "${GREEN}✅ Credenciales de AWS válidas${NC}"
echo ""

# Paso 1: Verificar si existe el estado en S3
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}PASO 1: Verificar Estado en S3${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if aws s3 ls "s3://${BUCKET_NAME}/${STATE_KEY}" --region "${BACKEND_REGION}" &> /dev/null; then
  echo -e "${GREEN}✅ Estado encontrado en S3${NC}"
  
  # Descargar el estado para verificar
  TEMP_STATE="/tmp/terraform-state-${ENVIRONMENT}.tfstate"
  echo -e "${YELLOW}📥 Descargando estado desde S3...${NC}"
  aws s3 cp \
    "s3://${BUCKET_NAME}/${STATE_KEY}" \
    "${TEMP_STATE}" \
    --region "${BACKEND_REGION}"
  
  if [ -f "${TEMP_STATE}" ]; then
    STATE_SIZE=$(stat -f%z "${TEMP_STATE}" 2>/dev/null || stat -c%s "${TEMP_STATE}" 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✅ Estado descargado (tamaño: ${STATE_SIZE} bytes)${NC}"
  else
    echo -e "${RED}❌ Error al descargar el estado${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}⚠️  Estado no encontrado en S3${NC}"
  echo -e "${YELLOW}💡 Esto puede significar que el estado fue borrado o nunca existió${NC}"
  echo ""
  read -p "¿Deseas continuar eliminando el lock de DynamoDB de todas formas? (s/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}⚠️  Operación cancelada${NC}"
    exit 0
  fi
fi
echo ""

# Paso 2: Verificar lock en DynamoDB
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}PASO 2: Verificar Lock en DynamoDB${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}🔍 Buscando lock en DynamoDB...${NC}"
LOCK_ITEM=$(aws dynamodb get-item \
  --table-name "${DYNAMODB_TABLE}" \
  --key "{\"LockID\": {\"S\": \"${LOCK_ID}\"}}" \
  --region "${BACKEND_REGION}" \
  --output json 2>/dev/null || echo "{}")

if echo "$LOCK_ITEM" | grep -q '"Item"'; then
  echo -e "${GREEN}✅ Lock encontrado en DynamoDB${NC}"
  echo ""
  echo "Información del lock:"
  echo "$LOCK_ITEM" | grep -E "(LockID|Info|Digest)" | head -5 || echo "  (No se pudo parsear completamente)"
  echo ""
  
  # Extraer el Digest actual
  CURRENT_DIGEST=$(echo "$LOCK_ITEM" | grep -o '"Digest":\s*"[^"]*"' | cut -d'"' -f4 || echo "")
  if [ -n "$CURRENT_DIGEST" ]; then
    echo -e "${YELLOW}📋 Digest actual en DynamoDB: ${CURRENT_DIGEST}${NC}"
  fi
else
  echo -e "${YELLOW}⚠️  No se encontró lock en DynamoDB${NC}"
  echo -e "${GREEN}✅ No hay nada que limpiar${NC}"
  exit 0
fi
echo ""

# Paso 3: Opciones de reparación
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}PASO 3: Opciones de Reparación${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "Tienes dos opciones para resolver el error de checksum:"
echo ""
echo "1. ${GREEN}Eliminar solo el Digest${NC} (recomendado)"
echo "   - Mantiene el lock pero elimina el checksum"
echo "   - Terraform recalculará el checksum en la próxima operación"
echo ""
echo "2. ${YELLOW}Eliminar todo el lock${NC}"
echo "   - Elimina completamente el registro del lock"
echo "   - Útil si el estado está corrupto o no existe"
echo ""

read -p "Selecciona una opción (1/2): " -n 1 -r
echo ""

if [[ $REPLY == "1" ]]; then
  # Opción 1: Actualizar el lock eliminando solo el Digest
  echo ""
  echo -e "${YELLOW}🔧 Actualizando lock: eliminando Digest...${NC}"
  
  # Obtener el lock completo
  LOCK_DATA=$(aws dynamodb get-item \
    --table-name "${DYNAMODB_TABLE}" \
    --key "{\"LockID\": {\"S\": \"${LOCK_ID}\"}}" \
    --region "${BACKEND_REGION}" \
    --output json)
  
  # Eliminar el atributo Digest usando update-item
  aws dynamodb update-item \
    --table-name "${DYNAMODB_TABLE}" \
    --key "{\"LockID\": {\"S\": \"${LOCK_ID}\"}}" \
    --update-expression "REMOVE Digest" \
    --region "${BACKEND_REGION}" > /dev/null
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Digest eliminado del lock${NC}"
    echo -e "${GREEN}✅ Terraform recalculará el checksum en la próxima operación${NC}"
  else
    echo -e "${RED}❌ Error al actualizar el lock${NC}"
    exit 1
  fi
  
elif [[ $REPLY == "2" ]]; then
  # Opción 2: Eliminar todo el lock
  echo ""
  echo -e "${YELLOW}🗑️  Eliminando lock completo...${NC}"
  
  aws dynamodb delete-item \
    --table-name "${DYNAMODB_TABLE}" \
    --key "{\"LockID\": {\"S\": \"${LOCK_ID}\"}}" \
    --region "${BACKEND_REGION}"
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Lock eliminado completamente${NC}"
  else
    echo -e "${RED}❌ Error al eliminar el lock${NC}"
    exit 1
  fi
  
else
  echo -e "${YELLOW}⚠️  Opción inválida. Operación cancelada.${NC}"
  exit 0
fi
echo ""

# Limpiar archivo temporal
if [ -f "${TEMP_STATE}" ]; then
  rm -f "${TEMP_STATE}"
fi

# Resumen final
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    PROCESO COMPLETADO                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Problema de checksum resuelto${NC}"
echo ""
echo -e "${YELLOW}📝 Próximos pasos:${NC}"
echo "  1. Intenta ejecutar terraform init de nuevo:"
echo "     cd terraform"
echo "     terraform init \\"
echo "       -backend-config=\"bucket=${BUCKET_NAME}\" \\"
echo "       -backend-config=\"key=${STATE_KEY}\" \\"
echo "       -backend-config=\"region=${BACKEND_REGION}\" \\"
echo "       -backend-config=\"dynamodb_table=${DYNAMODB_TABLE}\" \\"
echo "       -backend-config=\"encrypt=true\""
echo ""
echo "  2. Si el problema persiste, verifica que el estado en S3 no esté corrupto"
echo "  3. Como último recurso, puedes restaurar desde un backup si tienes uno"
echo ""
