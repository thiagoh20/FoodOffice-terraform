#!/bin/bash
# Script para importar recursos existentes en AWS al estado de Terraform
# Este script resuelve errores de "already exists" durante terraform apply

set +e  # No fallar si algún comando falla, queremos intentar importar todos los recursos posibles

# Configuración
AWS_REGION=${AWS_REGION:-us-east-1}
ENVIRONMENT=${ENVIRONMENT:-dev}
PROJECT_NAME=${PROJECT_NAME:-foodoffice}
TERRAFORM_DIR=${TERRAFORM_DIR:-terraform}

echo "🔄 Importando recursos existentes al estado de Terraform..."
echo "   Ambiente: $ENVIRONMENT"
echo "   Región: $AWS_REGION"
echo ""

cd "$TERRAFORM_DIR" || exit 1

# Función auxiliar para importar recursos
import_resource() {
  local RESOURCE_PATH=$1
  local RESOURCE_ID=$2
  local DESCRIPTION=$3
  
  echo "📌 Importando: $DESCRIPTION"
  echo "   Recurso: $RESOURCE_PATH"
  echo "   ID: $RESOURCE_ID"
  
  # Verificar si ya está en el state
  if terraform state show "$RESOURCE_PATH" &>/dev/null; then
    echo "   ✅ Ya está en el Terraform state"
    return 0
  fi
  
  # Intentar importar
  if terraform import \
    -var="environment=$ENVIRONMENT" \
    -var="bucket_name=${TF_VAR_bucket_name:-foodoffice-frontend}" \
    -var="github_repository=${TF_VAR_github_repository:-}" \
    -var="oidc_provider_arn=${TF_VAR_oidc_provider_arn:-}" \
    -var="db_password=${TF_VAR_db_password:-dummy}" \
    "$RESOURCE_PATH" "$RESOURCE_ID" 2>/dev/null; then
    echo "   ✅ Importado exitosamente"
    return 0
  else
    echo "   ⚠️  No se pudo importar (puede que ya esté en el state o el ID sea incorrecto)"
    return 1
  fi
}

# 1. Manejar CloudFront Origin Access Control
# Nota: CloudFront OAC no se puede importar fácilmente, pero podemos verificar si existe
echo "🔍 Verificando CloudFront Origin Access Control..."
OAC_NAME="${PROJECT_NAME}-frontend-${ENVIRONMENT}-oac"
OAC_ID=$(aws cloudfront list-origin-access-controls \
  --query "OriginAccessControlList.Items[?Name=='$OAC_NAME'].Id" \
  --output text 2>/dev/null || echo "")

if [ -n "$OAC_ID" ] && [ "$OAC_ID" != "None" ]; then
  echo "   📌 OAC encontrado: $OAC_ID"
  echo "   ⚠️  CloudFront OAC ya existe. Si falla el apply, considera:"
  echo "      1. Eliminar el OAC existente manualmente desde la consola de AWS"
  echo "      2. O usar 'terraform import' manualmente con el ID: $OAC_ID"
  echo "      3. O modificar el código para usar un data source en lugar de resource"
  
  # Intentar importar de todas formas
  if terraform state show "module.foodoffice_frontend_cloudfront.aws_cloudfront_origin_access_control.s3_oac" &>/dev/null; then
    echo "   ✅ Ya está en el Terraform state"
  else
    echo "   🔄 Intentando importar..."
    if terraform import \
      -var="environment=$ENVIRONMENT" \
      "module.foodoffice_frontend_cloudfront.aws_cloudfront_origin_access_control.s3_oac" \
      "$OAC_ID" 2>/dev/null; then
      echo "   ✅ Importado exitosamente"
    else
      echo "   ⚠️  No se pudo importar automáticamente"
      echo "   💡 Puedes importarlo manualmente con:"
      echo "      terraform import module.foodoffice_frontend_cloudfront.aws_cloudfront_origin_access_control.s3_oac $OAC_ID"
    fi
  fi
else
  echo "   ℹ️  No se encontró OAC con nombre: $OAC_NAME"
fi

# 2. Importar Security Groups
echo ""
echo "🔍 Buscando Security Groups..."

# Security Group RDS
RDS_SG_NAME="${PROJECT_NAME}-${ENVIRONMENT}-rds-sg"
RDS_SG_ID=$(aws ec2 describe-security-groups \
  --region "$AWS_REGION" \
  --filters "Name=group-name,Values=$RDS_SG_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text 2>/dev/null || echo "")

if [ -n "$RDS_SG_ID" ] && [ "$RDS_SG_ID" != "None" ]; then
  import_resource \
    "module.rds_security_groups.aws_security_group.rds" \
    "$RDS_SG_ID" \
    "RDS Security Group"
fi

# Security Group NAT Instance
NAT_SG_NAME="${PROJECT_NAME}-${ENVIRONMENT}-nat-instance-sg"
NAT_SG_ID=$(aws ec2 describe-security-groups \
  --region "$AWS_REGION" \
  --filters "Name=group-name,Values=$NAT_SG_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text 2>/dev/null || echo "")

if [ -n "$NAT_SG_ID" ] && [ "$NAT_SG_ID" != "None" ]; then
  import_resource \
    "module.vpc.aws_security_group.nat_instance[0]" \
    "$NAT_SG_ID" \
    "NAT Instance Security Group"
fi

# 3. Importar Internet Gateway
echo ""
echo "🔍 Buscando Internet Gateway..."

# Obtener VPC ID primero
VPC_ID=$(aws ec2 describe-vpcs \
  --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENVIRONMENT}-vpc" \
  --query 'Vpcs[0].VpcId' \
  --output text 2>/dev/null || echo "")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --region "$AWS_REGION" \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text 2>/dev/null || echo "")
  
  if [ -n "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
    # Para Internet Gateway, el ID de importación es solo el IGW ID
    # Terraform manejará el attachment automáticamente
    import_resource \
      "module.vpc.aws_internet_gateway.main" \
      "$IGW_ID" \
      "Internet Gateway"
  fi
fi

# 4. Importar Subnets
echo ""
echo "🔍 Buscando Subnets..."

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
  # Obtener todas las subnets de la VPC
  SUBNETS=$(aws ec2 describe-subnets \
    --region "$AWS_REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[*].[SubnetId,Tags[?Key==`Type`].Value|[0],CidrBlock]' \
    --output text 2>/dev/null || echo "")
  
  if [ -n "$SUBNETS" ]; then
    echo "$SUBNETS" | while read -r SUBNET_ID SUBNET_TYPE CIDR; do
      if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" = "None" ]; then
        continue
      fi
      
      # Determinar el path del recurso según el tipo
      RESOURCE_PATH=""
      if [ "$SUBNET_TYPE" = "public" ]; then
        # Intentar con diferentes índices
        for INDEX in 0 1; do
          RESOURCE_PATH="module.vpc.aws_subnet.public[$INDEX]"
          if terraform state show "$RESOURCE_PATH" &>/dev/null; then
            continue
          fi
          if terraform import \
            -var="environment=$ENVIRONMENT" \
            "$RESOURCE_PATH" "$SUBNET_ID" 2>/dev/null; then
            echo "   ✅ Subnet pública importada: $SUBNET_ID (índice $INDEX)"
            break
          fi
        done
      elif [ "$SUBNET_TYPE" = "private-app" ]; then
        for INDEX in 0 1; do
          RESOURCE_PATH="module.vpc.aws_subnet.private_app[$INDEX]"
          if terraform state show "$RESOURCE_PATH" &>/dev/null; then
            continue
          fi
          if terraform import \
            -var="environment=$ENVIRONMENT" \
            "$RESOURCE_PATH" "$SUBNET_ID" 2>/dev/null; then
            echo "   ✅ Subnet privada-app importada: $SUBNET_ID (índice $INDEX)"
            break
          fi
        done
      elif [ "$SUBNET_TYPE" = "private-data" ]; then
        for INDEX in 0 1; do
          RESOURCE_PATH="module.vpc.aws_subnet.private_data[$INDEX]"
          if terraform state show "$RESOURCE_PATH" &>/dev/null; then
            continue
          fi
          if terraform import \
            -var="environment=$ENVIRONMENT" \
            "$RESOURCE_PATH" "$SUBNET_ID" 2>/dev/null; then
            echo "   ✅ Subnet privada-data importada: $SUBNET_ID (índice $INDEX)"
            break
          fi
        done
      fi
    done
  fi
fi

echo ""
echo "✅ Proceso de importación completado"
echo ""
echo "💡 Ahora puedes ejecutar 'terraform plan' para verificar que todo esté correcto"
echo "   y luego 'terraform apply' para aplicar los cambios restantes"
