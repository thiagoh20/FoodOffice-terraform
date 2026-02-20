# Guía: Limpiar Estado de Terraform en S3

## 📋 Descripción

Esta guía explica cómo limpiar el estado de Terraform almacenado en S3 de forma segura, creando un backup antes de borrarlo.

## ⚠️ Advertencias Importantes

**ANTES de borrar el estado, entiende que:**

1. **Terraform perderá el registro de todos los recursos**: No sabrá qué recursos ya existen en AWS
2. **Necesitarás importar recursos existentes**: O Terraform intentará crearlos de nuevo (causando errores de "already exists")
3. **Hacer backup es crítico**: El script crea un backup automáticamente, pero verifica que se haya creado correctamente

## 🚀 Uso del Script

### Opción 1: Uso Básico (Ambiente Dev)

```bash
cd /ruta/al/proyecto/FoodOffice-terraform

# Ejecutar el script (usará dev por defecto)
./scripts/cleanup-terraform-state.sh
```

### Opción 2: Especificar Ambiente

```bash
# Para ambiente de desarrollo
ENVIRONMENT=dev ./scripts/cleanup-terraform-state.sh

# Para ambiente de staging
ENVIRONMENT=staging ./scripts/cleanup-terraform-state.sh

# Para ambiente de producción
ENVIRONMENT=prod ./scripts/cleanup-terraform-state.sh
```

### Opción 3: Configuración Personalizada

```bash
ENVIRONMENT=dev \
BUCKET_NAME=foodoffice-terraform-state \
BACKEND_REGION=us-east-2 \
DYNAMODB_TABLE=terraform-state-lock \
./scripts/cleanup-terraform-state.sh
```

## 📝 Proceso Paso a Paso

### 1. Verificación Inicial

El script verifica:
- ✅ Credenciales de AWS válidas
- ✅ Si el estado existe en S3
- ✅ Si hay locks activos en DynamoDB

### 2. Manejo de Locks

Si hay un lock activo:
- El script te preguntará si quieres eliminarlo
- **Recomendación**: Solo elimina locks si estás seguro de que no hay operaciones en curso

### 3. Backup Automático

El script crea un backup automático en:
```
./backups/terraform-state/terraform.tfstate.{ENVIRONMENT}.{TIMESTAMP}
```

**Ejemplo**: `./backups/terraform-state/terraform.tfstate.dev.20241215-143022`

### 4. Confirmación

El script requiere que escribas **"BORRAR"** para confirmar la operación.

### 5. Eliminación

Una vez confirmado, el script:
- Borra el estado de S3
- Verifica que se haya borrado correctamente

## 🔄 Después de Limpiar el Estado

### Opción A: Importar Recursos Existentes (Recomendado)

Si los recursos ya existen en AWS y quieres que Terraform los gestione:

```bash
# 1. Inicializar Terraform de nuevo
cd terraform
terraform init \
  -backend-config="bucket=foodoffice-terraform-state" \
  -backend-config="key=environments/dev/terraform.tfstate" \
  -backend-config="region=us-east-2" \
  -backend-config="dynamodb_table=terraform-state-lock" \
  -backend-config="encrypt=true"

# 2. Importar recursos existentes
cd ..
./scripts/import-existing-resources.sh
```

### Opción B: Empezar desde Cero

Si quieres recrear toda la infraestructura:

```bash
cd terraform
terraform init \
  -backend-config="bucket=foodoffice-terraform-state" \
  -backend-config="key=environments/dev/terraform.tfstate" \
  -backend-config="region=us-east-2" \
  -backend-config="dynamodb_table=terraform-state-lock" \
  -backend-config="encrypt=true"

# Ver qué se crearía
terraform plan

# Aplicar (cuidado: puede intentar crear recursos que ya existen)
terraform apply
```

**⚠️ Nota**: Si los recursos ya existen, Terraform mostrará errores. Necesitarás importarlos o eliminarlos manualmente primero.

### Opción C: Restaurar desde Backup

Si cambias de opinión y quieres restaurar el estado:

```bash
# Restaurar desde backup
aws s3 cp \
  ./backups/terraform-state/terraform.tfstate.dev.20241215-143022 \
  s3://foodoffice-terraform-state/environments/dev/terraform.tfstate \
  --region us-east-2
```

## 🔍 Verificar Estado Actual

### Ver si el estado existe en S3

```bash
aws s3 ls s3://foodoffice-terraform-state/environments/dev/terraform.tfstate \
  --region us-east-2
```

### Ver locks activos en DynamoDB

```bash
aws dynamodb get-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S": "foodoffice-terraform-state/environments/dev/terraform.tfstate"}}' \
  --region us-east-2
```

### Ver todos los locks

```bash
aws dynamodb scan \
  --table-name terraform-state-lock \
  --region us-east-2 \
  --projection-expression "LockID, Info"
```

## 🐛 Troubleshooting

### Error: "State file is locked"

**Causa**: Hay una operación de Terraform en curso o un lock quedó atascado.

**Solución**:
1. Verificar si hay workflows de GitHub Actions ejecutándose
2. Si es seguro, eliminar el lock manualmente:
   ```bash
   aws dynamodb delete-item \
     --table-name terraform-state-lock \
     --key '{"LockID": {"S": "foodoffice-terraform-state/environments/dev/terraform.tfstate"}}' \
     --region us-east-2
   ```

### Error: "No se pudo crear backup"

**Causa**: Problemas de permisos o el estado no existe.

**Solución**:
1. Verificar permisos de AWS (necesitas `s3:GetObject` y `s3:PutObject`)
2. Verificar que el estado existe antes de ejecutar el script

### Error: "El estado aún existe después de borrar"

**Causa**: Problemas de permisos o el estado está en otra ubicación.

**Solución**:
1. Verificar permisos de AWS (necesitas `s3:DeleteObject`)
2. Verificar la ruta exacta del estado:
   ```bash
   aws s3 ls s3://foodoffice-terraform-state/environments/dev/ --recursive --region us-east-2
   ```

## 📚 Recursos Relacionados

- [ESTRATEGIA_TERRAFORM_STATE.md](./ESTRATEGIA_TERRAFORM_STATE.md): Documentación completa sobre gestión del estado
- [import-existing-resources.sh](../scripts/import-existing-resources.sh): Script para importar recursos existentes

## ⚡ Comandos Rápidos

```bash
# Limpiar estado de dev
ENVIRONMENT=dev ./scripts/cleanup-terraform-state.sh

# Ver backups creados
ls -lh ./backups/terraform-state/

# Restaurar desde backup más reciente
LATEST_BACKUP=$(ls -t ./backups/terraform-state/ | head -1)
aws s3 cp "./backups/terraform-state/${LATEST_BACKUP}" \
  s3://foodoffice-terraform-state/environments/dev/terraform.tfstate \
  --region us-east-2
```

---

**Última actualización**: 2024  
**Mantenedor**: Equipo de DevOps FoodOffice
