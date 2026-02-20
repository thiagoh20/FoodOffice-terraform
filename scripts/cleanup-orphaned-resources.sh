#!/bin/bash
# Script para encontrar recursos huérfanos, importarlos al Terraform state y destruirlos

set +e

# Configurar región de AWS
AWS_REGION=${AWS_REGION:-us-east-1}
export AWS_DEFAULT_REGION=$AWS_REGION

# Variables del proyecto (ajustar según tu configuración)
PROJECT_NAME=${PROJECT_NAME:-foodoffice}
ENVIRONMENT=${ENVIRONMENT:-dev}
TERRAFORM_DIR=${TERRAFORM_DIR:-terraform}

echo "🔍 Buscando recursos huérfanos del proyecto $PROJECT_NAME en ambiente $ENVIRONMENT..."

# Verificar que AWS CLI esté disponible
if ! command -v aws &> /dev/null; then
  echo "❌ AWS CLI no está instalado"
  exit 1
fi

# Verificar credenciales de AWS
if ! aws sts get-caller-identity &> /dev/null; then
  echo "❌ No se pudieron validar las credenciales de AWS"
  exit 1
fi

# Verificar que terraform esté disponible
if ! command -v terraform &> /dev/null; then
  echo "❌ Terraform no está instalado"
  exit 1
fi

# Cambiar al directorio de Terraform
if [ ! -d "$TERRAFORM_DIR" ]; then
  echo "❌ Directorio $TERRAFORM_DIR no encontrado"
  exit 1
fi

cd "$TERRAFORM_DIR" || exit 1

# Configuración del backend (ajustar según tu configuración)
BACKEND_BUCKET=${BACKEND_BUCKET:-foodoffice-terraform-state}
BACKEND_KEY=${BACKEND_KEY:-environments/dev/terraform.tfstate}
BACKEND_REGION=${BACKEND_REGION:-us-east-2}
BACKEND_DYNAMODB=${BACKEND_DYNAMODB:-terraform-state-lock}

# Inicializar Terraform con backend
echo "🔧 Inicializando Terraform con backend..."
terraform init \
  -backend-config="bucket=$BACKEND_BUCKET" \
  -backend-config="key=$BACKEND_KEY" \
  -backend-config="region=$BACKEND_REGION" \
  -backend-config="dynamodb_table=$BACKEND_DYNAMODB" \
  -backend-config="encrypt=true" \
  -reconfigure > /dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "⚠️  No se pudo inicializar Terraform con backend, intentando sin backend..."
  terraform init -backend=false > /dev/null 2>&1 || {
    echo "❌ No se pudo inicializar Terraform"
    exit 1
  }
fi

echo ""
echo "📋 Buscando recursos huérfanos por tags..."

# Función para buscar y limpiar recursos por tipo
cleanup_resource_type() {
  local RESOURCE_TYPE=$1
  local AWS_QUERY=$2
  local TERRAFORM_TYPE=$3
  local IMPORT_ID_FUNC=$4
  
  echo ""
  echo "🔍 Buscando $RESOURCE_TYPE huérfanos..."
  
  # Obtener recursos de AWS con tags del proyecto
  RESOURCES=$(aws $AWS_QUERY \
    --region "$AWS_REGION" \
    --query "$RESOURCE_TYPE[?Tags[?Key=='Project' && Value=='$PROJECT_NAME'] && Tags[?Key=='Environment' && Value=='$ENVIRONMENT']].[$RESOURCE_TYPE[0].Id || $RESOURCE_TYPE[0].ResourceId || $RESOURCE_TYPE[0].$RESOURCE_TYPE[0]Id]" \
    --output text 2>/dev/null || echo "")
  
  if [ -z "$RESOURCES" ]; then
    echo "  ✅ No se encontraron $RESOURCE_TYPE huérfanos"
    return 0
  fi
  
  echo "$RESOURCES" | while read -r RESOURCE_ID; do
    if [ -n "$RESOURCE_ID" ] && [ "$RESOURCE_ID" != "None" ]; then
      echo "  📌 Encontrado: $RESOURCE_ID"
      
      # Generar ID para import
      IMPORT_ID=$($IMPORT_ID_FUNC "$RESOURCE_ID")
      
      if [ -n "$IMPORT_ID" ]; then
        echo "  🔄 Importando a Terraform state: $TERRAFORM_TYPE.$RESOURCE_ID -> $IMPORT_ID"
        
        terraform import \
          -var="environment=$ENVIRONMENT" \
          "$TERRAFORM_TYPE.$RESOURCE_ID" "$IMPORT_ID" 2>/dev/null
        
        if [ $? -eq 0 ]; then
          echo "  ✅ Importado exitosamente"
        else
          echo "  ⚠️  No se pudo importar (puede que ya esté en el state o el recurso no existe)"
        fi
      fi
    fi
  done
}

# Limpiar Security Groups huérfanos
echo ""
echo "🔍 Buscando Security Groups huérfanos..."
SG_IDS=$(aws ec2 describe-security-groups \
  --region "$AWS_REGION" \
  --filters "Name=tag:Project,Values=$PROJECT_NAME" "Name=tag:Environment,Values=$ENVIRONMENT" \
  --query 'SecurityGroups[*].GroupId' \
  --output text 2>/dev/null || echo "")

if [ -n "$SG_IDS" ]; then
  echo "$SG_IDS" | tr '\t' '\n' | while read -r SG_ID; do
    if [ -n "$SG_ID" ]; then
      echo "  📌 Security Group encontrado: $SG_ID"
      
      # Verificar si ya está en el state
      STATE_LIST=$(terraform state list 2>/dev/null || echo "")
      if echo "$STATE_LIST" | grep -q "$SG_ID"; then
        echo "  ✅ Ya está en el Terraform state"
        continue
      fi
      
      echo "  🔄 Intentando importar..."
      
      # Obtener nombre del SG para identificar el tipo
      SG_NAME=$(aws ec2 describe-security-groups \
        --region "$AWS_REGION" \
        --group-ids "$SG_ID" \
        --query 'SecurityGroups[0].GroupName' \
        --output text 2>/dev/null || echo "")
      
      echo "  📝 Nombre del SG: $SG_NAME"
      
      # Intentar importar según el nombre
      IMPORTED=false
      if echo "$SG_NAME" | grep -qi "lambda"; then
        echo "  🔄 Intentando importar como Lambda Security Group..."
        timeout 30 terraform import \
          -var="environment=$ENVIRONMENT" \
          -var="project_name=$PROJECT_NAME" \
          "module.rds_security_groups.aws_security_group.lambda" "$SG_ID" > /tmp/import-output.log 2>&1
        
        if [ $? -eq 0 ]; then
          echo "  ✅ Security Group Lambda importado"
          IMPORTED=true
        else
          echo "  ⚠️  No se pudo importar como Lambda SG"
          cat /tmp/import-output.log | grep -v "Warning" | tail -3
        fi
      fi
      
      if [ "$IMPORTED" = false ] && echo "$SG_NAME" | grep -qi "rds"; then
        echo "  🔄 Intentando importar como RDS Security Group..."
        timeout 30 terraform import \
          -var="environment=$ENVIRONMENT" \
          -var="project_name=$PROJECT_NAME" \
          "module.rds_security_groups.aws_security_group.rds" "$SG_ID" > /tmp/import-output.log 2>&1
        
        if [ $? -eq 0 ]; then
          echo "  ✅ Security Group RDS importado"
          IMPORTED=true
        else
          echo "  ⚠️  No se pudo importar como RDS SG"
          cat /tmp/import-output.log | grep -v "Warning" | tail -3
        fi
      fi
      
      if [ "$IMPORTED" = false ]; then
        echo "  ⚠️  No se pudo importar $SG_ID (puede requerir configuración manual o el recurso no existe en la configuración)"
      fi
    fi
  done
fi

# Limpiar ENIs huérfanas de Lambda
echo ""
echo "🔍 Buscando ENIs huérfanas de Lambda..."
ENI_IDS=$(aws ec2 describe-network-interfaces \
  --region "$AWS_REGION" \
  --filters "Name=description,Values=*Lambda*" "Name=status,Values=in-use,available" \
  --query 'NetworkInterfaces[*].NetworkInterfaceId' \
  --output text 2>/dev/null || echo "")

if [ -n "$ENI_IDS" ]; then
  echo "$ENI_IDS" | tr '\t' '\n' | while read -r ENI_ID; do
    if [ -n "$ENI_ID" ]; then
      echo "  📌 ENI encontrada: $ENI_ID"
      echo "  🗑️  Eliminando ENI huérfana directamente (no se puede importar a Terraform)..."
      
      # Intentar detach y eliminar
      aws ec2 detach-network-interface \
        --region "$AWS_REGION" \
        --network-interface-id "$ENI_ID" \
        --force \
        --no-cli-pager 2>/dev/null
      
      sleep 5
      
      aws ec2 delete-network-interface \
        --region "$AWS_REGION" \
        --network-interface-id "$ENI_ID" \
        --no-cli-pager 2>/dev/null && {
        echo "  ✅ ENI $ENI_ID eliminada"
      } || {
        echo "  ⚠️  No se pudo eliminar $ENI_ID"
      }
    fi
  done
fi

# Limpiar Subnets huérfanas
echo ""
echo "🔍 Buscando Subnets huérfanas..."
SUBNET_IDS=$(aws ec2 describe-subnets \
  --region "$AWS_REGION" \
  --filters "Name=tag:Project,Values=$PROJECT_NAME" "Name=tag:Environment,Values=$ENVIRONMENT" \
  --query 'Subnets[*].SubnetId' \
  --output text 2>/dev/null || echo "")

if [ -n "$SUBNET_IDS" ]; then
  echo "$SUBNET_IDS" | tr '\t' '\n' | while read -r SUBNET_ID; do
    if [ -n "$SUBNET_ID" ]; then
      echo "  📌 Subnet encontrada: $SUBNET_ID"
      echo "  🔄 Intentando importar..."
      
      # Verificar si ya está en el state
      STATE_LIST=$(terraform state list 2>/dev/null || echo "")
      if echo "$STATE_LIST" | grep -q "$SUBNET_ID"; then
        echo "  ✅ Ya está en el Terraform state"
        continue
      fi
      
      # Obtener tipo de subnet por tags
      SUBNET_TYPE=$(aws ec2 describe-subnets \
        --region "$AWS_REGION" \
        --subnet-ids "$SUBNET_ID" \
        --query 'Subnets[0].Tags[?Key==`Type`].Value' \
        --output text 2>/dev/null || echo "")
      
      IMPORTED=false
      if [ "$SUBNET_TYPE" = "public" ]; then
        timeout 30 terraform import \
          -var="environment=$ENVIRONMENT" \
          -var="project_name=$PROJECT_NAME" \
          "module.vpc.aws_subnet.public[0]" "$SUBNET_ID" > /tmp/import-output.log 2>&1
        if [ $? -eq 0 ]; then
          echo "  ✅ Subnet pública importada"
          IMPORTED=true
        else
          cat /tmp/import-output.log | grep -v "Warning" | tail -3
        fi
      elif [ "$SUBNET_TYPE" = "private-app" ]; then
        timeout 30 terraform import \
          -var="environment=$ENVIRONMENT" \
          -var="project_name=$PROJECT_NAME" \
          "module.vpc.aws_subnet.private_app[0]" "$SUBNET_ID" > /tmp/import-output.log 2>&1
        if [ $? -eq 0 ]; then
          echo "  ✅ Subnet privada de app importada"
          IMPORTED=true
        else
          cat /tmp/import-output.log | grep -v "Warning" | tail -3
        fi
      elif [ "$SUBNET_TYPE" = "private-data" ]; then
        timeout 30 terraform import \
          -var="environment=$ENVIRONMENT" \
          -var="project_name=$PROJECT_NAME" \
          "module.vpc.aws_subnet.private_data[0]" "$SUBNET_ID" > /tmp/import-output.log 2>&1
        if [ $? -eq 0 ]; then
          echo "  ✅ Subnet privada de datos importada"
          IMPORTED=true
        else
          cat /tmp/import-output.log | grep -v "Warning" | tail -3
        fi
      fi
      
      if [ "$IMPORTED" = false ]; then
        echo "  ⚠️  No se pudo importar $SUBNET_ID (tipo: $SUBNET_TYPE)"
      fi
    fi
  done
fi

# Limpiar VPCs huérfanas
echo ""
echo "🔍 Buscando VPCs huérfanas..."
VPC_IDS=$(aws ec2 describe-vpcs \
  --region "$AWS_REGION" \
  --filters "Name=tag:Project,Values=$PROJECT_NAME" "Name=tag:Environment,Values=$ENVIRONMENT" \
  --query 'Vpcs[*].VpcId' \
  --output text 2>/dev/null || echo "")

if [ -n "$VPC_IDS" ]; then
  echo "$VPC_IDS" | tr '\t' '\n' | while read -r VPC_ID; do
    if [ -n "$VPC_ID" ]; then
      echo "  📌 VPC encontrada: $VPC_ID"
      echo "  🔄 Intentando importar..."
      
      # Verificar si ya está en el state
      STATE_LIST=$(terraform state list 2>/dev/null || echo "")
      if echo "$STATE_LIST" | grep -q "$VPC_ID"; then
        echo "  ✅ Ya está en el Terraform state"
        continue
      fi
      
      timeout 30 terraform import \
        -var="environment=$ENVIRONMENT" \
        -var="project_name=$PROJECT_NAME" \
        "module.vpc.aws_vpc.main" "$VPC_ID" > /tmp/import-output.log 2>&1
      
      if [ $? -eq 0 ]; then
        echo "  ✅ VPC importada"
      else
        echo "  ⚠️  No se pudo importar $VPC_ID"
        cat /tmp/import-output.log | grep -v "Warning" | tail -3
      fi
    fi
  done
fi

# Limpiar RDS huérfanos
echo ""
echo "🔍 Buscando instancias RDS huérfanas..."
RDS_IDS=$(aws rds describe-db-instances \
  --region "$AWS_REGION" \
  --query "DBInstances[?contains(DBInstanceIdentifier, '$PROJECT_NAME') && contains(DBInstanceIdentifier, '$ENVIRONMENT')].DBInstanceIdentifier" \
  --output text 2>/dev/null || echo "")

if [ -n "$RDS_IDS" ]; then
  echo "$RDS_IDS" | tr '\t' '\n' | while read -r RDS_ID; do
    if [ -n "$RDS_ID" ]; then
      echo "  📌 RDS encontrado: $RDS_ID"
      echo "  🔄 Intentando importar..."
      
      # Verificar si ya está en el state
      STATE_LIST=$(terraform state list 2>/dev/null || echo "")
      if echo "$STATE_LIST" | grep -q "$RDS_ID"; then
        echo "  ✅ Ya está en el Terraform state"
        continue
      fi
      
      timeout 60 terraform import \
        -var="environment=$ENVIRONMENT" \
        -var="project_name=$PROJECT_NAME" \
        "module.rds.aws_db_instance.main" "$RDS_ID" > /tmp/import-output.log 2>&1
      
      if [ $? -eq 0 ]; then
        echo "  ✅ RDS importado"
      else
        echo "  ⚠️  No se pudo importar $RDS_ID"
        cat /tmp/import-output.log | grep -v "Warning" | tail -3
      fi
    fi
  done
fi

# Limpiar S3 buckets huérfanos
echo ""
echo "🔍 Buscando S3 buckets huérfanos..."
BUCKET_NAMES=$(aws s3api list-buckets \
  --region "$AWS_REGION" \
  --query "Buckets[?contains(Name, '$PROJECT_NAME')].Name" \
  --output text 2>/dev/null || echo "")

if [ -n "$BUCKET_NAMES" ]; then
  echo "$BUCKET_NAMES" | tr '\t' '\n' | while read -r BUCKET_NAME; do
    if [ -n "$BUCKET_NAME" ]; then
      echo "  📌 Bucket encontrado: $BUCKET_NAME"
      echo "  🔄 Intentando importar..."
      
      # Verificar si ya está en el state
      STATE_LIST=$(terraform state list 2>/dev/null || echo "")
      if echo "$STATE_LIST" | grep -q "$BUCKET_NAME"; then
        echo "  ✅ Ya está en el Terraform state"
        continue
      fi
      
      timeout 30 terraform import \
        -var="environment=$ENVIRONMENT" \
        -var="project_name=$PROJECT_NAME" \
        "module.foodoffice_frontend_bucket_name.aws_s3_bucket.main" "$BUCKET_NAME" > /tmp/import-output.log 2>&1
      
      if [ $? -eq 0 ]; then
        echo "  ✅ Bucket importado"
      else
        echo "  ⚠️  No se pudo importar $BUCKET_NAME"
        cat /tmp/import-output.log | grep -v "Warning" | tail -3
      fi
    fi
  done
fi

echo ""
echo "✅ Búsqueda de recursos huérfanos completada"
echo ""
echo "📊 Resumen de recursos en el Terraform state:"
terraform state list 2>/dev/null | head -20 || echo "  (No se pudo listar el state)"

echo ""
echo "💡 Recursos huérfanos importados al Terraform state."
echo "⚠️  IMPORTANTE: Revisa el state antes de destruir para asegurarte de que solo se destruyan los recursos correctos"
echo ""
echo "🔄 Los recursos importados serán destruidos cuando ejecutes: terraform destroy"
