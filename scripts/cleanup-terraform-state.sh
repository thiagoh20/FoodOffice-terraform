#!/bin/bash
# Script para limpiar el estado de Terraform en S3
# IMPORTANTE: Este script hace backup antes de borrar

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración por defecto
ENVIRONMENT=${ENVIRONMENT:-dev}
BUCKET_NAME=${BUCKET_NAME:-foodoffice-terraform-state}
STATE_KEY="environments/${ENVIRONMENT}/terraform.tfstate"
BACKEND_REGION=${BACKEND_REGION:-us-east-2}
DYNAMODB_TABLE=${DYNAMODB_TABLE:-terraform-state-lock}
BACKUP_DIR="./backups/terraform-state"

echo "🔧 Script de Limpieza de Estado de Terraform"
echo "=============================================="
echo ""
echo "Configuración:"
echo "  Ambiente: ${ENVIRONMENT}"
echo "  Bucket: ${BUCKET_NAME}"
echo "  State Key: ${STATE_KEY}"
echo "  Región: ${BACKEND_REGION}"
echo ""

# Verificar que AWS CLI esté disponible
if ! command -v aws &> /dev/null; then
  echo -e "${RED}❌ AWS CLI no está instalado${NC}"
  exit 1
fi

# Verificar credenciales de AWS
echo "🔍 Verificando credenciales de AWS..."
if ! aws sts get-caller-identity &> /dev/null; then
  echo -e "${RED}❌ No se pudieron validar las credenciales de AWS${NC}"
  exit 1
fi
echo -e "${GREEN}✅ Credenciales de AWS válidas${NC}"
echo ""

# Verificar si el estado existe
echo "🔍 Verificando si el estado existe en S3..."
if aws s3 ls "s3://${BUCKET_NAME}/${STATE_KEY}" --region "${BACKEND_REGION}" &> /dev/null; then
  echo -e "${GREEN}✅ Estado encontrado en S3${NC}"
  STATE_EXISTS=true
else
  echo -e "${YELLOW}⚠️  Estado no encontrado en S3 (puede que ya esté limpio)${NC}"
  STATE_EXISTS=false
fi
echo ""

# Verificar locks en DynamoDB
echo "🔍 Verificando locks en DynamoDB..."
LOCK_ID="${BUCKET_NAME}/${STATE_KEY}"
LOCK_EXISTS=$(aws dynamodb get-item \
  --table-name "${DYNAMODB_TABLE}" \
  --key "{\"LockID\": {\"S\": \"${LOCK_ID}\"}}" \
  --region "${BACKEND_REGION}" \
  --query 'Item' \
  --output text 2>/dev/null || echo "None")

if [ "$LOCK_EXISTS" != "None" ] && [ -n "$LOCK_EXISTS" ]; then
  echo -e "${RED}❌ Hay un lock activo en DynamoDB${NC}"
  echo ""
  echo "Información del lock:"
  aws dynamodb get-item \
    --table-name "${DYNAMODB_TABLE}" \
    --key "{\"LockID\": {\"S\": \"${LOCK_ID}\"}}" \
    --region "${BACKEND_REGION}" \
    --output json | jq -r '.Item | "  LockID: \(.LockID.S)\n  Info: \(.Info.S)"' 2>/dev/null || echo "  (No se pudo parsear)"
  echo ""
  echo -e "${YELLOW}⚠️  Debes eliminar el lock antes de continuar${NC}"
  echo ""
  read -p "¿Deseas eliminar el lock ahora? (s/N): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "🗑️  Eliminando lock..."
    aws dynamodb delete-item \
      --table-name "${DYNAMODB_TABLE}" \
      --key "{\"LockID\": {\"S\": \"${LOCK_ID}\"}}" \
      --region "${BACKEND_REGION}" && echo -e "${GREEN}✅ Lock eliminado${NC}" || echo -e "${RED}❌ Error al eliminar lock${NC}"
  else
    echo -e "${YELLOW}⚠️  Operación cancelada. Elimina el lock manualmente y vuelve a ejecutar el script.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}✅ No hay locks activos${NC}"
fi
echo ""

# Si no existe el estado, salir
if [ "$STATE_EXISTS" = false ]; then
  echo -e "${GREEN}✅ El estado ya está limpio. No hay nada que hacer.${NC}"
  exit 0
fi

# Crear directorio de backup
mkdir -p "${BACKUP_DIR}"

# Backup del estado actual
echo "💾 Creando backup del estado actual..."
BACKUP_FILE="${BACKUP_DIR}/terraform.tfstate.${ENVIRONMENT}.$(date +%Y%m%d-%H%M%S)"
aws s3 cp \
  "s3://${BUCKET_NAME}/${STATE_KEY}" \
  "${BACKUP_FILE}" \
  --region "${BACKEND_REGION}"

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Backup creado: ${BACKUP_FILE}${NC}"
else
  echo -e "${RED}❌ Error al crear backup${NC}"
  exit 1
fi
echo ""

# Confirmación final
echo -e "${RED}⚠️  ADVERTENCIA: Estás a punto de borrar el estado de Terraform${NC}"
echo ""
echo "Esto significa que:"
echo "  - Terraform perderá el registro de todos los recursos desplegados"
echo "  - Necesitarás importar los recursos existentes o recrearlos"
echo "  - Si haces 'terraform apply' sin importar, intentará crear recursos duplicados"
echo ""
echo "Opciones después de borrar:"
echo "  1. Importar recursos existentes usando el script: scripts/import-existing-resources.sh"
echo "  2. O hacer 'terraform apply' y manejar los conflictos manualmente"
echo ""
read -p "¿Estás seguro de que quieres borrar el estado? (escribe 'BORRAR' para confirmar): " -r
echo ""

if [ "$REPLY" != "BORRAR" ]; then
  echo -e "${YELLOW}⚠️  Operación cancelada${NC}"
  echo "El backup está guardado en: ${BACKUP_FILE}"
  exit 0
fi

# Borrar el estado
echo "🗑️  Borrando estado de Terraform en S3..."
aws s3 rm \
  "s3://${BUCKET_NAME}/${STATE_KEY}" \
  --region "${BACKEND_REGION}"

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Estado borrado exitosamente${NC}"
else
  echo -e "${RED}❌ Error al borrar el estado${NC}"
  exit 1
fi
echo ""

# Verificar que se borró
echo "🔍 Verificando que el estado fue borrado..."
if aws s3 ls "s3://${BUCKET_NAME}/${STATE_KEY}" --region "${BACKEND_REGION}" &> /dev/null; then
  echo -e "${RED}❌ El estado aún existe. Algo salió mal.${NC}"
  exit 1
else
  echo -e "${GREEN}✅ Confirmado: el estado ha sido borrado${NC}"
fi
echo ""

# Resumen final
echo "=============================================="
echo -e "${GREEN}✅ Proceso completado${NC}"
echo ""
echo "Resumen:"
echo "  ✅ Backup creado: ${BACKUP_FILE}"
echo "  ✅ Estado borrado de S3"
echo "  ✅ No hay locks activos"
echo ""
echo "Próximos pasos:"
echo "  1. Inicializar Terraform de nuevo:"
echo "     cd terraform"
echo "     terraform init \\"
echo "       -backend-config=\"bucket=${BUCKET_NAME}\" \\"
echo "       -backend-config=\"key=${STATE_KEY}\" \\"
echo "       -backend-config=\"region=${BACKEND_REGION}\" \\"
echo "       -backend-config=\"dynamodb_table=${DYNAMODB_TABLE}\" \\"
echo "       -backend-config=\"encrypt=true\""
echo ""
echo "  2. Importar recursos existentes (recomendado):"
echo "     ./scripts/import-existing-resources.sh"
echo ""
echo "  3. O hacer terraform plan para ver qué recursos se crearían"
echo ""
