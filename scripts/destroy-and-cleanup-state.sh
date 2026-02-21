#!/bin/bash
# Script para destruir infraestructura y limpiar estado de Terraform
# Este script:
# 1. Hace backup del estado actual
# 2. Importa recursos huérfanos (opcional)
# 3. Limpia ENIs de Lambda
# 4. Ejecuta terraform destroy
# 5. Limpia el estado de S3

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
AWS_REGION=${AWS_REGION:-us-east-1}
TERRAFORM_DIR=${TERRAFORM_DIR:-terraform}
PROJECT_NAME=${PROJECT_NAME:-foodoffice}
BACKUP_DIR="./backups/terraform-state"

# Variables de Terraform (deben estar configuradas)
TF_VAR_environment=${TF_VAR_environment:-${ENVIRONMENT}}
TF_VAR_bucket_name=${TF_VAR_bucket_name:-""}
TF_VAR_github_repository=${TF_VAR_github_repository:-""}
TF_VAR_oidc_provider_arn=${TF_VAR_oidc_provider_arn:-""}
TF_VAR_db_password=${TF_VAR_db_password:-""}

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Script de Destroy y Limpieza de Estado de Terraform      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Configuración:"
echo "  Ambiente: ${ENVIRONMENT}"
echo "  Bucket State: ${BUCKET_NAME}"
echo "  State Key: ${STATE_KEY}"
echo "  Región Backend: ${BACKEND_REGION}"
echo "  Región AWS: ${AWS_REGION}"
echo "  Directorio Terraform: ${TERRAFORM_DIR}"
echo ""

# Verificar que AWS CLI esté disponible
if ! command -v aws &> /dev/null; then
  echo -e "${RED}❌ AWS CLI no está instalado${NC}"
  exit 1
fi

# Verificar que Terraform esté disponible
if ! command -v terraform &> /dev/null; then
  echo -e "${RED}❌ Terraform no está instalado${NC}"
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

# Verificar variables de Terraform requeridas
if [ -z "$TF_VAR_bucket_name" ] || [ -z "$TF_VAR_github_repository" ]; then
  echo -e "${YELLOW}⚠️  Advertencia: Algunas variables de Terraform no están configuradas${NC}"
  echo "   TF_VAR_bucket_name: ${TF_VAR_bucket_name:-NO CONFIGURADO}"
  echo "   TF_VAR_github_repository: ${TF_VAR_github_repository:-NO CONFIGURADO}"
  echo ""
  read -p "¿Deseas continuar de todas formas? (s/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}⚠️  Operación cancelada${NC}"
    exit 0
  fi
fi

# Crear directorio de backup
mkdir -p "${BACKUP_DIR}"

# Paso 1: Backup del estado actual
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}PASO 1: Backup del Estado Actual${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if aws s3 ls "s3://${BUCKET_NAME}/${STATE_KEY}" --region "${BACKEND_REGION}" &> /dev/null; then
  echo -e "${YELLOW}💾 Creando backup del estado actual...${NC}"
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
else
  echo -e "${YELLOW}⚠️  No se encontró estado en S3 (puede que ya esté limpio)${NC}"
fi
echo ""

# Paso 2: Verificar y eliminar locks
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}PASO 2: Verificación de Locks${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

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
    --output json 2>/dev/null | grep -E "(LockID|Info)" || echo "  (No se pudo parsear)"
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

# Paso 3: Inicializar Terraform
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}PASO 3: Inicialización de Terraform${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

cd "${TERRAFORM_DIR}" || exit 1

echo -e "${YELLOW}🔄 Inicializando Terraform...${NC}"
terraform init \
  -backend-config="bucket=${BUCKET_NAME}" \
  -backend-config="key=${STATE_KEY}" \
  -backend-config="region=${BACKEND_REGION}" \
  -backend-config="dynamodb_table=${DYNAMODB_TABLE}" \
  -backend-config="encrypt=true" \
  -reconfigure

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Terraform inicializado${NC}"
else
  echo -e "${RED}❌ Error al inicializar Terraform${NC}"
  exit 1
fi
echo ""

# Paso 4: Importar recursos huérfanos (opcional)
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}PASO 4: Importar Recursos Huérfanos (Opcional)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

read -p "¿Deseas importar recursos huérfanos antes de destroy? (S/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  echo -e "${YELLOW}🔍 Buscando e importando recursos huérfanos...${NC}"
  cd ..
  if [ -f "./scripts/cleanup-orphaned-resources.sh" ]; then
    chmod +x ./scripts/cleanup-orphaned-resources.sh
    ./scripts/cleanup-orphaned-resources.sh || echo -e "${YELLOW}⚠️  Algunos recursos no se pudieron importar${NC}"
  else
    echo -e "${YELLOW}⚠️  Script de importación no encontrado, continuando...${NC}"
  fi
  cd "${TERRAFORM_DIR}" || exit 1
else
  echo -e "${YELLOW}⏭️  Saltando importación de recursos huérfanos${NC}"
fi
echo ""

# Paso 5: Limpiar ENIs de Lambda
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}PASO 5: Limpieza de ENIs de Lambda${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

read -p "¿Deseas limpiar ENIs de Lambda antes de destroy? (S/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  echo -e "${YELLOW}🧹 Limpiando ENIs de Lambda...${NC}"
  cd ..
  if [ -f "./scripts/cleanup-lambda-enis.sh" ]; then
    chmod +x ./scripts/cleanup-lambda-enis.sh
    AWS_REGION="${AWS_REGION}" ./scripts/cleanup-lambda-enis.sh || echo -e "${YELLOW}⚠️  Algunas ENIs no se pudieron limpiar${NC}"
  else
    echo -e "${YELLOW}⚠️  Script de limpieza de ENIs no encontrado, continuando...${NC}"
  fi
  cd "${TERRAFORM_DIR}" || exit 1
else
  echo -e "${YELLOW}⏭️  Saltando limpieza de ENIs${NC}"
fi
echo ""

# Paso 6: Terraform Destroy
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PASO 6: DESTRUIR INFRAESTRUCTURA${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${RED}⚠️  ADVERTENCIA CRÍTICA:${NC}"
echo ""
echo "Estás a punto de DESTRUIR toda la infraestructura en AWS:"
echo "  - VPC y subnets"
echo "  - RDS (base de datos)"
echo "  - S3 buckets"
echo "  - CloudFront distributions"
echo "  - Security Groups"
echo "  - IAM roles"
echo ""
echo -e "${RED}Esta operación NO se puede deshacer fácilmente.${NC}"
echo ""
read -p "¿Estás SEGURO de que quieres continuar? (escribe 'DESTRUIR' para confirmar): " -r
echo ""

if [ "$REPLY" != "DESTRUIR" ]; then
  echo -e "${YELLOW}⚠️  Operación cancelada${NC}"
  echo "El backup está guardado en: ${BACKUP_FILE:-N/A}"
  exit 0
fi

echo -e "${YELLOW}💥 Ejecutando terraform destroy...${NC}"
echo ""

# Exportar variables de entorno para Terraform
export TF_VAR_environment
export TF_VAR_bucket_name
export TF_VAR_github_repository
export TF_VAR_oidc_provider_arn
export TF_VAR_db_password

terraform destroy -auto-approve

DESTROY_EXIT_CODE=$?

if [ $DESTROY_EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}✅ Terraform destroy completado exitosamente${NC}"
else
  echo -e "${RED}❌ Error durante terraform destroy (código: ${DESTROY_EXIT_CODE})${NC}"
  echo -e "${YELLOW}⚠️  Algunos recursos pueden no haberse destruido completamente${NC}"
  echo ""
  read -p "¿Deseas continuar con la limpieza del estado de todas formas? (s/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}⚠️  Operación cancelada. Revisa los errores antes de continuar.${NC}"
    exit $DESTROY_EXIT_CODE
  fi
fi
echo ""

# Paso 7: Limpiar estado de S3
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}PASO 7: Limpieza del Estado en S3${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

cd ..

echo -e "${YELLOW}🗑️  Borrando estado de Terraform en S3...${NC}"

if aws s3 ls "s3://${BUCKET_NAME}/${STATE_KEY}" --region "${BACKEND_REGION}" &> /dev/null; then
  aws s3 rm \
    "s3://${BUCKET_NAME}/${STATE_KEY}" \
    --region "${BACKEND_REGION}"
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Estado borrado exitosamente de S3${NC}"
  else
    echo -e "${RED}❌ Error al borrar el estado${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}⚠️  El estado ya no existe en S3${NC}"
fi
echo ""

# Verificar que se borró
echo -e "${YELLOW}🔍 Verificando que el estado fue borrado...${NC}"
if aws s3 ls "s3://${BUCKET_NAME}/${STATE_KEY}" --region "${BACKEND_REGION}" &> /dev/null; then
  echo -e "${RED}❌ El estado aún existe. Algo salió mal.${NC}"
  exit 1
else
  echo -e "${GREEN}✅ Confirmado: el estado ha sido borrado${NC}"
fi
echo ""

# Resumen final
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    PROCESO COMPLETADO                   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Resumen:${NC}"
echo "  ✅ Backup creado: ${BACKUP_FILE:-N/A}"
echo "  ✅ Infraestructura destruida"
echo "  ✅ Estado borrado de S3"
echo "  ✅ No hay locks activos"
echo ""
echo -e "${YELLOW}📝 Próximos pasos:${NC}"
echo "  1. Verificar en AWS Console que todos los recursos fueron eliminados"
echo "  2. Si necesitas restaurar, usa el backup: ${BACKUP_FILE:-N/A}"
echo "  3. Para crear nueva infraestructura, ejecuta terraform apply"
echo ""
