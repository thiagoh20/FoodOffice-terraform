#!/bin/bash
# Script para limpiar ENIs de Lambda atascadas antes de terraform destroy

# No usar set -e para permitir manejo de errores
set +e

# Configurar región de AWS (usar la región del contexto o us-east-1 por defecto)
AWS_REGION=${AWS_REGION:-us-east-1}
export AWS_DEFAULT_REGION=$AWS_REGION

echo "🔍 Buscando funciones Lambda con configuración VPC en región $AWS_REGION..."

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

# Obtener todas las funciones Lambda
LAMBDA_FUNCTIONS=$(aws lambda list-functions \
  --region "$AWS_REGION" \
  --query 'Functions[?VpcConfig.VpcId != null].FunctionName' \
  --output text 2>/dev/null || echo "")

if [ -z "$LAMBDA_FUNCTIONS" ]; then
  echo "✅ No se encontraron funciones Lambda con VPC configurado"
  exit 0
fi

echo "📋 Funciones Lambda encontradas:"
echo "$LAMBDA_FUNCTIONS" | tr '\t' '\n' | while read -r FUNCTION; do
  if [ -n "$FUNCTION" ]; then
    echo "  - $FUNCTION"
    
    # Remover configuración VPC de Lambda
    echo "  🔄 Removiendo configuración VPC de $FUNCTION..."
    aws lambda update-function-configuration \
      --function-name "$FUNCTION" \
      --region "$AWS_REGION" \
      --vpc-config "{}" \
      --no-cli-pager 2>/dev/null
    
    if [ $? -eq 0 ]; then
      echo "  ✅ VPC removido de $FUNCTION"
    else
      echo "  ⚠️  No se pudo actualizar $FUNCTION (puede que ya no tenga VPC o no exista)"
    fi
  fi
done

echo ""
echo "⏳ Esperando 30 segundos para que AWS libere las ENIs..."
sleep 30

echo ""
echo "🔍 Buscando ENIs de Lambda atascadas..."

# Obtener ENIs de Lambda que están en estado "in-use"
ENIS=$(aws ec2 describe-network-interfaces \
  --region "$AWS_REGION" \
  --filters "Name=description,Values=*Lambda*" "Name=status,Values=in-use" \
  --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,Description]' \
  --output text 2>/dev/null || echo "")

if [ -z "$ENIS" ]; then
  echo "✅ No se encontraron ENIs de Lambda atascadas"
  exit 0
fi

echo "📋 ENIs encontradas:"
echo "$ENIS" | while read -r ENI_ID STATUS DESC; do
  if [ -n "$ENI_ID" ]; then
    echo "  - $ENI_ID ($STATUS): $DESC"
    
    # Intentar forzar la eliminación de la ENI
    echo "  🔄 Intentando forzar eliminación de $ENI_ID..."
    
    # Primero intentar detach
    echo "  🔌 Detachando ENI $ENI_ID..."
    aws ec2 detach-network-interface \
      --region "$AWS_REGION" \
      --network-interface-id "$ENI_ID" \
      --force \
      --no-cli-pager 2>/dev/null
    
    if [ $? -eq 0 ]; then
      echo "  ✅ ENI $ENI_ID detached"
    else
      echo "  ⚠️  No se pudo detach $ENI_ID (puede que ya esté detached o no exista)"
    fi
    
    # Esperar un poco para que AWS procese el detach
    sleep 10
    
    # Verificar estado antes de eliminar
    ENI_STATUS=$(aws ec2 describe-network-interfaces \
      --region "$AWS_REGION" \
      --network-interface-ids "$ENI_ID" \
      --query 'NetworkInterfaces[0].Status' \
      --output text 2>/dev/null || echo "unknown")
    
    if [ "$ENI_STATUS" = "available" ] || [ "$ENI_STATUS" = "detached" ]; then
      echo "  🗑️  Eliminando ENI $ENI_ID (estado: $ENI_STATUS)..."
      aws ec2 delete-network-interface \
        --region "$AWS_REGION" \
        --network-interface-id "$ENI_ID" \
        --no-cli-pager 2>/dev/null
      
      if [ $? -eq 0 ]; then
        echo "  ✅ ENI $ENI_ID eliminada exitosamente"
      else
        echo "  ⚠️  No se pudo eliminar $ENI_ID (puede requerir más tiempo o ya fue eliminada)"
      fi
    else
      echo "  ⏳ ENI $ENI_ID aún en estado '$ENI_STATUS', esperando más tiempo..."
      sleep 20
      
      # Intentar eliminar de nuevo
      aws ec2 delete-network-interface \
        --region "$AWS_REGION" \
        --network-interface-id "$ENI_ID" \
        --no-cli-pager 2>/dev/null && {
        echo "  ✅ ENI $ENI_ID eliminada después de esperar"
      } || {
        echo "  ⚠️  ENI $ENI_ID aún no disponible para eliminación"
      }
    fi
  fi
done

echo ""
echo "✅ Limpieza de ENIs completada"
echo "💡 Si aún hay ENIs atascadas, espera unos minutos y ejecuta terraform destroy nuevamente"
