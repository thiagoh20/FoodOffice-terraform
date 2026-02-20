# Estrategia de Terraform State - FoodOffice

## 📋 Índice
1. [Arquitectura del Backend](#arquitectura-del-backend)
2. [Estructura del State](#estructura-del-state)
3. [State Locking](#state-locking)
4. [Gestión por Ambientes](#gestión-por-ambientes)
5. [Backup y Recuperación](#backup-y-recuperación)
6. [Seguridad](#seguridad)
7. [Mejores Prácticas](#mejores-prácticas)
8. [Troubleshooting](#troubleshooting)

---

## 🏗️ Arquitectura del Backend

### Arquitectura Híbrida: S3 + DynamoDB

El proyecto utiliza una **arquitectura híbrida** que combina **Amazon S3** y **Amazon DynamoDB** para gestionar el estado de Terraform de forma segura y confiable:

#### Amazon S3 - Almacenamiento del Estado

**Amazon S3** se utiliza como backend remoto para almacenar el estado de Terraform, con las siguientes características:

- **Bucket**: `foodoffice-terraform-state`
- **Región**: `us-east-2` (Ohio)
- **Encriptación**: Habilitada (`encrypt = true`)
- **Versionado**: Recomendado (habilitar en bucket)
- **Propósito**: Almacenar los archivos de estado (`terraform.tfstate`)

#### Amazon DynamoDB - State Locking

**Amazon DynamoDB** se utiliza para implementar el mecanismo de **state locking**, previniendo modificaciones concurrentes del estado:

- **Table**: `terraform-state-lock`
- **Región**: `us-east-2` (Ohio) - misma región que S3 para baja latencia
- **Primary Key**: `LockID` (String)
- **Billing Mode**: `PAY_PER_REQUEST` (on-demand)
- **Propósito**: Prevenir operaciones concurrentes que puedan corromper el estado

### Configuración Actual

```hcl
backend "s3" {
  bucket         = "foodoffice-terraform-state"
  key            = "environments/{ENVIRONMENT}/terraform.tfstate"
  region         = "us-east-2"
  dynamodb_table = "terraform-state-lock"  # Tabla DynamoDB para locking
  encrypt        = true
}
```

**Nota**: La configuración se pasa mediante `-backend-config` en los workflows para mayor flexibilidad.

### Ventajas de esta Arquitectura

✅ **Concurrencia Segura**: DynamoDB previene modificaciones simultáneas  
✅ **Alta Disponibilidad**: S3 y DynamoDB son servicios altamente disponibles  
✅ **Bajo Costo**: DynamoDB on-demand solo cobra por operaciones de locking  
✅ **Baja Latencia**: Misma región para S3 y DynamoDB  
✅ **Escalabilidad**: Ambos servicios escalan automáticamente  
✅ **Durabilidad**: S3 garantiza 99.999999999% (11 9's) de durabilidad

---

## 📁 Estructura del State

### Organización por Ambientes




### Ventajas de esta Estructura

✅ **Aislamiento**: Cada ambiente tiene su propio estado  
✅ **Seguridad**: Fácil aplicar políticas IAM por ambiente  
✅ **Escalabilidad**: Fácil agregar nuevos ambientes  
✅ **Trazabilidad**: Historial claro por ambiente  

---

## 🔒 State Locking

### DynamoDB como Mecanismo de Locking

**Amazon DynamoDB** es el componente crítico que previene modificaciones concurrentes del estado de Terraform. Sin DynamoDB, múltiples operaciones de Terraform podrían ejecutarse simultáneamente y corromper el estado.

#### Configuración de la Tabla DynamoDB

- **Table Name**: `terraform-state-lock`
- **Región**: `us-east-2` (misma que S3 para baja latencia)
- **Primary Key**: `LockID` (String) - Formato: `{bucket}/{key}`
- **Billing Mode**: `PAY_PER_REQUEST` (on-demand)
- **Atributos Adicionales** (automáticos de Terraform):
  - `Info` (String): Metadata del lock (JSON)
  - `Digest` (String): Hash del estado
  - `Created` (String): Timestamp de creación

#### Estructura del Lock

Cada lock en DynamoDB contiene:

```json
{
  "LockID": "foodoffice-terraform-state/environments/dev/terraform.tfstate",
  "Info": "{\"ID\":\"...\",\"Operation\":\"OperationTypeApply\",\"Who\":\"user@example.com\",\"Version\":\"1.13.4\",\"Created\":\"2024-01-15T10:30:00Z\",\"Path\":\"foodoffice-terraform-state/environments/dev/terraform.tfstate\"}"
}
```

### Cómo Funciona el Locking con DynamoDB

1. Cuando Terraform inicia una operación (`plan`, `apply`, `destroy`):
   - Crea un registro en DynamoDB con `LockID = {bucket}/{key}`
   - Incluye metadata: timestamp, operación, usuario

2. Si otro proceso intenta modificar el mismo estado:
   - Detecta el lock existente
   - Falla con error: `Error acquiring the state lock`

3. Al completar la operación:
   - Terraform elimina el lock automáticamente

### Creación de la Tabla DynamoDB

La tabla DynamoDB debe crearse **antes** de usar Terraform con el backend S3. Puedes crearla manualmente o con Terraform:

#### Opción 1: Creación Manual con AWS CLI

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-2 \
  --tags Key=Project,Value=FoodOffice Key=Purpose,Value=TerraformStateLock
```

#### Opción 2: Verificar si la Tabla Existe

```bash
aws dynamodb describe-table \
  --table-name terraform-state-lock \
  --region us-east-2
```

#### Opción 3: Crear con Terraform (Recomendado)

Si prefieres gestionar la tabla con Terraform, puedes crear un módulo separado:

```hcl
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "terraform-state-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock"
    Project     = "FoodOffice"
    Purpose     = "Terraform State Locking"
    ManagedBy   = "Terraform"
  }
}
```

**Nota**: Esta tabla debe crearse **una sola vez** y puede ser compartida entre todos los ambientes (dev, staging, prod) ya que cada ambiente usa un `LockID` diferente.

### Troubleshooting de Locks

**Problema**: Lock "stuck" (bloqueado permanentemente)

**Solución**:
```bash
# 1. Verificar locks existentes
aws dynamodb scan \
  --table-name terraform-state-lock \
  --region us-east-2

# 2. Eliminar lock manualmente (SOLO si estás seguro)
aws dynamodb delete-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S": "foodoffice-terraform-state/environments/dev/terraform.tfstate"}}' \
  --region us-east-2
```

⚠️ **ADVERTENCIA**: Solo eliminar locks si estás 100% seguro de que no hay operaciones en curso.

---

## 🌍 Gestión por Ambientes

### Ambientes Soportados

| Ambiente | Branch | State Key | Propósito |
|----------|--------|-----------|-----------|
| **dev** | `develop` | `environments/dev/terraform.tfstate` | Desarrollo activo |
| **prod** | `main` | `environments/prod/terraform.tfstate` | Producción |

### Inicialización por Ambiente

#### Desarrollo Local

```bash
cd terraform

# Inicializar para dev
terraform init \
  -backend-config="bucket=foodoffice-terraform-state" \
  -backend-config="key=environments/dev/terraform.tfstate" \
  -backend-config="region=us-east-2" \
  -backend-config="dynamodb_table=terraform-state-lock" \
  -backend-config="encrypt=true"
```

#### En CI/CD (GitHub Actions)

Los workflows configuran automáticamente el backend según el ambiente:

```yaml
- name: Terraform Init
  working-directory: ./terraform
  run: |
    terraform init \
      -backend-config="bucket=foodoffice-terraform-state" \
      -backend-config="key=environments/${{ env.ENVIRONMENT }}/terraform.tfstate" \
      -backend-config="region=us-east-2" \
      -backend-config="dynamodb_table=terraform-state-lock" \
      -backend-config="encrypt=true"
```

### Variables por Ambiente

Cada ambiente tiene sus propias variables (secrets en GitHub):

- `TF_VAR_environment`: `dev`, `staging`, `prod`
- `TF_VAR_bucket_name`: Nombre del bucket S3
- `TF_VAR_db_password`: Password de base de datos
- `TF_VAR_github_repository`: Repo de GitHub Actions
- `TF_VAR_oidc_provider_arn`: ARN del OIDC provider

---

## 💾 Backup y Recuperación

### Versionado de S3

**Recomendación**: Habilitar versionado en el bucket `foodoffice-terraform-state`

```bash
aws s3api put-bucket-versioning \
  --bucket foodoffice-terraform-state \
  --versioning-configuration Status=Enabled \
  --region us-east-2
```

### Backup Manual

```bash
# Descargar estado actual
aws s3 cp \
  s3://foodoffice-terraform-state/environments/dev/terraform.tfstate \
  ./backups/terraform.tfstate.$(date +%Y%m%d-%H%M%S) \
  --region us-east-2
```

### Restaurar desde Backup

```bash
# 1. Verificar versión a restaurar
aws s3api list-object-versions \
  --bucket foodoffice-terraform-state \
  --prefix environments/dev/terraform.tfstate \
  --region us-east-2

# 2. Restaurar versión específica
aws s3api get-object \
  --bucket foodoffice-terraform-state \
  --key environments/dev/terraform.tfstate \
  --version-id {VERSION_ID} \
  terraform.tfstate \
  --region us-east-2

# 3. Subir estado restaurado
aws s3 cp terraform.tfstate \
  s3://foodoffice-terraform-state/environments/dev/terraform.tfstate \
  --region us-east-2
```

### Lifecycle Policies (Opcional)

Para ahorrar costos, configurar lifecycle en S3:

```json
{
  "Rules": [
    {
      "Id": "ArchiveOldStates",
      "Status": "Enabled",
      "Prefix": "environments/",
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ]
    }
  ]
}
```

---

## 🔐 Seguridad

### Encriptación

- ✅ **Encriptación en tránsito**: HTTPS/TLS para S3
- ✅ **Encriptación en reposo**: `encrypt = true` en backend config
- ✅ **KMS**: Opcional, usar KMS keys para encriptación avanzada

### IAM Policies

#### Permisos Mínimos para Terraform

La política IAM debe incluir permisos tanto para **S3** (almacenamiento) como para **DynamoDB** (locking):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3StateBackendAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::foodoffice-terraform-state",
        "arn:aws:s3:::foodoffice-terraform-state/*"
      ]
    },
    {
      "Sid": "DynamoDBStateLockAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:us-east-2:*:table/terraform-state-lock"
    }
  ]
}
```

#### Explicación de Permisos DynamoDB

- **`dynamodb:GetItem`**: Leer locks existentes para verificar si hay operaciones en curso
- **`dynamodb:PutItem`**: Crear nuevos locks cuando Terraform inicia una operación
- **`dynamodb:DeleteItem`**: Eliminar locks cuando Terraform completa una operación

**Nota**: No se requieren permisos adicionales como `dynamodb:Scan` o `dynamodb:Query` para el funcionamiento básico del locking.

### Acceso por Ambiente

**Recomendación**: Usar políticas IAM separadas por ambiente para mayor seguridad:

- `TerraformDevRole`: Solo acceso a `environments/dev/*`
- `TerraformStagingRole`: Solo acceso a `environments/staging/*`
- `TerraformProdRole`: Solo acceso a `environments/prod/*`

### Secrets Management

- ❌ **NUNCA** commitear estados con secrets
- ✅ Usar variables de entorno o secrets managers
- ✅ Habilitar `-backend-config` desde archivos o variables
- ✅ Rotar credenciales regularmente

---

## 💡 Mejores Prácticas

### 1. No Modificar State Manualmente

❌ **NUNCA** editar `terraform.tfstate` directamente  
✅ Usar comandos de Terraform: `terraform import`, `terraform state mv`

### 2. Usar Workspaces con Precaución

Si necesitas múltiples estados en el mismo ambiente:

```bash
terraform workspace new feature-branch
terraform workspace select feature-branch
```

⚠️ **Nota**: Workspaces comparten el mismo backend. Para aislamiento completo, usar diferentes keys.

### 3. State Remoto Siempre

❌ No usar estado local en producción  
✅ Siempre configurar backend remoto

### 4. Revisar State en PRs

Antes de hacer merge, revisar cambios en el state:

```bash
terraform plan  # Muestra cambios propuestos
```


### 5. State Outputs

Usar outputs para compartir información entre módulos:

```hcl
output "vpc_id" {
  value = aws_vpc.main.id
  description = "ID de la VPC principal"
}
```

---

## 🔧 Troubleshooting

### Error: "Error acquiring the state lock"

**Causa**: Otra operación está en curso o lock quedó "stuck"

**Solución**:
1. Verificar si hay operaciones en curso
2. Si no hay, eliminar lock manualmente (ver sección State Locking)

### Error: "Backend configuration changed"

**Causa**: Cambio en configuración de backend

**Solución**:
```bash
terraform init -reconfigure
```

### Error: "State file is locked"

**Causa**: Múltiples procesos intentando modificar el mismo state

**Solución**:
- Esperar a que termine la operación en curso
- O eliminar lock si es seguro (ver State Locking)

### State Out of Sync

**Síntoma**: Terraform quiere destruir recursos que existen


---

## 📊 Monitoreo y Alertas

### CloudWatch Metrics para S3

Configurar métricas para:
- Operaciones de Terraform (apply, destroy)
- Tamaño del state file
- Frecuencia de cambios en el estado

### CloudWatch Metrics para DynamoDB

Monitorear la tabla `terraform-state-lock`:

- **`ConsumedReadCapacityUnits`**: Lecturas de locks
- **`ConsumedWriteCapacityUnits`**: Escrituras/eliminaciones de locks
- **`UserErrors`**: Errores al adquirir locks
- **`SystemErrors`**: Errores del sistema DynamoDB

#### Consultar Locks Activos

```bash
# Ver todos los locks actuales
aws dynamodb scan \
  --table-name terraform-state-lock \
  --region us-east-2 \
  --projection-expression "LockID, Info" \
  --output json | jq '.Items[] | {LockID: .LockID.S, Info: .Info.S}'
```

### Alertas Recomendadas

#### S3
- ⚠️ State file size > 10MB (considerar refactor)
- ⚠️ Múltiples versiones del mismo state (posible problema)

#### DynamoDB
- ⚠️ Lock duration > 1 hora (posible stuck lock)
- ⚠️ Múltiples locks simultáneos para el mismo estado
- ⚠️ UserErrors > 0 (problemas al adquirir locks)
- ⚠️ SystemErrors > 0 (problemas con DynamoDB)

### Costos de DynamoDB

Con **PAY_PER_REQUEST** (on-demand), los costos son muy bajos:

- **Escritura (PutItem)**: ~$1.25 por millón de requests
- **Lectura (GetItem)**: ~$0.25 por millón de requests
- **Eliminación (DeleteItem)**: ~$1.25 por millón de requests

**Ejemplo de uso típico**:
- 100 operaciones de Terraform/día = ~300 requests/día (GetItem + PutItem + DeleteItem)
- Costo mensual estimado: **< $0.10 USD**

💡 **Recomendación**: El costo de DynamoDB para state locking es insignificante comparado con los beneficios de seguridad y confiabilidad.

---

## 📚 Recursos Adicionales

- [Terraform Backend Configuration](https://www.terraform.io/docs/language/settings/backends/index.html)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)

---
