#!/bin/bash
# Script para crear un estado inicial de Terraform en S3
# Útil cuando el bucket está vacío y necesitas un estado base

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

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Crear Estado Inicial de Terraform en S3                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
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
echo -e "${YELLOW}🔍 Verificando credenciales de AWS...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
  echo -e "${RED}❌ No se pudieron validar las credenciales de AWS${NC}"
  exit 1
fi
echo -e "${GREEN}✅ Credenciales de AWS válidas${NC}"
echo ""

# Verificar si el estado ya existe
echo -e "${YELLOW}🔍 Verificando si el estado ya existe en S3...${NC}"
if aws s3 ls "s3://${BUCKET_NAME}/${STATE_KEY}" --region "${BACKEND_REGION}" &> /dev/null; then
  echo -e "${YELLOW}⚠️  El estado ya existe en S3${NC}"
  echo ""
  read -p "¿Deseas sobrescribirlo con un estado vacío? (s/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}⚠️  Operación cancelada${NC}"
    exit 0
  fi
else
  echo -e "${GREEN}✅ No existe estado previo. Creando estado nuevo...${NC}"
fi
echo ""

# Crear estado inicial vacío (formato JSON válido de Terraform)
echo -e "${YELLOW}📝 Creando estado inicial vacío...${NC}"

# Estado inicial de Terraform (formato mínimo válido)
INITIAL_STATE=$(cat <<EOF
{
  "version": 4,
  "terraform_version": "1.13.4",
  "serial": 1,
  "lineage": "$(openssl rand -hex 16)",
  "outputs": {},
  "resources": []
}
EOF
)

# Crear archivo temporal
TEMP_STATE="/tmp/terraform-state-init.json"
echo "$INITIAL_STATE" > "$TEMP_STATE"

# Subir a S3
echo -e "${YELLOW}📤 Subiendo estado inicial a S3...${NC}"
aws s3 cp \
  "$TEMP_STATE" \
  "s3://${BUCKET_NAME}/${STATE_KEY}" \
  --region "${BACKEND_REGION}" \
  --content-type "application/json" \
  --metadata "terraform-state=initial"

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Estado inicial creado exitosamente en S3${NC}"
else
  echo -e "${RED}❌ Error al crear el estado en S3${NC}"
  rm -f "$TEMP_STATE"
  exit 1
fi

# Limpiar archivo temporal
rm -f "$TEMP_STATE"

# Verificar que se creó correctamente
echo ""
echo -e "${YELLOW}🔍 Verificando que el estado fue creado...${NC}"
if aws s3 ls "s3://${BUCKET_NAME}/${STATE_KEY}" --region "${BACKEND_REGION}" &> /dev/null; then
  STATE_SIZE=$(aws s3 ls "s3://${BUCKET_NAME}/${STATE_KEY}" --region "${BACKEND_REGION}" | awk '{print $3}')
  echo -e "${GREEN}✅ Estado verificado (tamaño: ${STATE_SIZE} bytes)${NC}"
else
  echo -e "${RED}❌ El estado no se encontró después de crearlo${NC}"
  exit 1
fi

# Limpiar cualquier lock en DynamoDB
echo ""
echo -e "${YELLOW}🧹 Limpiando locks en DynamoDB...${NC}"
LOCK_ID="${BUCKET_NAME}/${STATE_KEY}"
DYNAMODB_TABLE=${DYNAMODB_TABLE:-terraform-state-lock}

aws dynamodb delete-item \
  --table-name "${DYNAMODB_TABLE}" \
  --key "{\"LockID\": {\"S\": \"${LOCK_ID}\"}}" \
  --region "${BACKEND_REGION}" 2>&1 || echo "ℹ️  No hay lock para eliminar (esto es normal)"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    PROCESO COMPLETADO                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Estado inicial creado exitosamente${NC}"
echo ""
echo -e "${YELLOW}📝 Próximos pasos:${NC}"
echo "  1. Ejecuta terraform init:"
echo "     cd terraform"
echo "     terraform init \\"
echo "       -backend-config=\"bucket=${BUCKET_NAME}\" \\"
echo "       -backend-config=\"key=${STATE_KEY}\" \\"
echo "       -backend-config=\"region=${BACKEND_REGION}\" \\"
echo "       -backend-config=\"dynamodb_table=${DYNAMODB_TABLE}\" \\"
echo "       -backend-config=\"encrypt=true\""
echo ""
echo "  2. Luego puedes ejecutar terraform plan o terraform apply"
echo ""
