# FoodOffice - Infraestructura y Frontend

## 📋 Descripción del Proyecto

FoodOffice es una aplicación web completa para gestión de pedidos, construida con una arquitectura moderna que combina un frontend React con Vite y una infraestructura en AWS gestionada mediante Terraform.

Este repositorio contiene:
- **Frontend**: Aplicación React con TypeScript, Vite, y tRPC
- **Infraestructura**: Configuración completa de AWS usando Terraform
- **CI/CD**: Workflows de GitHub Actions para despliegue automático
- **Scripts**: Utilidades para gestión y limpieza de recursos

---

## 🏗️ Arquitectura

### Stack Tecnológico

#### Frontend
- **Framework**: React 19.2.1
- **Build Tool**: Vite 7.1.7
- **Lenguaje**: TypeScript 5.9.3
- **Routing**: Wouter 3.7.1
- **State Management**: TanStack Query (React Query) 5.90.2
- **API Client**: tRPC 11.6.0
- **UI Components**: Radix UI
- **Styling**: Tailwind CSS 4.1.14
- **Testing**: Jest 29.7.0 + Testing Library

#### Infraestructura (AWS)
- **Frontend Hosting**: Amazon S3 + CloudFront
- **Base de Datos**: Amazon RDS PostgreSQL 16.3
- **Red**: Amazon VPC con arquitectura de 3 capas
- **CI/CD**: GitHub Actions con OIDC
- **State Management**: Terraform con backend S3 + DynamoDB


**Componentes de Red:**
- **Public Subnets**: NAT Instance (t2.micro) para acceso a internet desde subnets privadas
- **Private App Subnets**: Para funciones Lambda, ECS, y servicios de aplicación
- **Private Data Subnets**: Para RDS y otros servicios de datos

### Recursos AWS Desplegados

| Recurso | Descripción | Módulo Terraform |
|---------|-------------|------------------|
| **S3 Bucket** | Almacenamiento estático del frontend | `terraform-modules/s3` |
| **CloudFront** | CDN para distribución global | `terraform-modules/cloudfront` |
| **RDS PostgreSQL** | Base de datos relacional | `terraform-modules/rds` |
| **VPC** | Red virtual privada | `terraform-modules/vpc` |
| **Security Groups** | Reglas de firewall | `terraform-modules/security-groups` |
| **IAM Role (OIDC)** | Autenticación sin credenciales para GitHub Actions | `terraform-modules/iam-oidc` |

---


## ☁️ Infraestructura con Terraform

### Configuración del Backend

El proyecto utiliza un backend remoto de Terraform con las siguientes características:

- **Backend**: Amazon S3
- **Bucket**: `foodoffice-terraform-state`
- **Región**: `us-east-2` (Ohio)
- **State Locking**: DynamoDB (`terraform-state-lock`)
- **Encriptación**: Habilitada

### Ambientes

El proyecto soporta 3 ambientes:

| Ambiente | Branch | State Key | Propósito |
|----------|--------|-----------|-----------|
| **dev** | `develop` | `environments/dev/terraform.tfstate` | Desarrollo activo |
| **prod** | `main` | `environments/prod/terraform.tfstate` | Producción |


### Variables Requeridas

Las siguientes variables deben configurarse (vía secrets de GitHub o archivo `terraform.tfvars`):

```hcl
environment          = "dev"                    # dev, staging, prod
bucket_name          = "foodoffice-frontend-dev" # Debe ser único globalmente
github_repository    = "owner/repo"             # Formato: owner/repo
oidc_provider_arn    = "arn:aws:iam::..."       # ARN del OIDC provider
db_password          = "..."                    # Password de RDS (sensible)
```



### Outputs Importantes

Después de aplicar Terraform, puedes obtener información importante:

```bash
# URL de CloudFront
terraform output cloudfront_distribution_url

# Nombre del bucket S3
terraform output s3_bucket_name

# Endpoint de RDS
terraform output rds_endpoint

# IDs de Security Groups (útil para SAM)
terraform output lambda_security_group_id
terraform output rds_security_group_id
```

---

## 🔄 CI/CD con GitHub Actions

### Workflows Disponibles

#### 1. Deploy Frontend (`deploy.yml`)

**Trigger**: Push a `develop`, o `main` / Manual dispatch

**Funcionalidad**:
- Construye la aplicación frontend
- Sincroniza archivos con S3
- Invalida caché de CloudFront
- Despliega automáticamente según el branch

**Ambientes**:
- `develop` → Deploy a desarrollo
- `main` → Deploy a producción

#### 2. Deploy Manual de Infraestructura (`manual-deploy.yml`)

**Trigger**: Manual dispatch únicamente

**Acciones disponibles**:
- `apply`: Crear/actualizar infraestructura
- `destroy`: Eliminar infraestructura

**Características**:
- Importa recursos existentes automáticamente
- Maneja errores de recursos duplicados
- Limpia ENIs de Lambda antes de destroy
- Importa recursos huérfanos antes de destroy

#### 3. PR Checks (`pr-checks.yml`)

**Trigger**: Pull Requests a `develop`, o `main`

**Validaciones**:
- ✅ **Lint Frontend**: ESLint + Prettier
- ✅ **Test Frontend**: Jest tests
- ✅ **Análisis de Costos**: Infracost para estimar costos de infraestructura

**Requisitos para merge**:
- Todos los checks deben pasar
- Aprobación de revisores (según configuración de branch)

### Secrets Requeridos en GitHub

Configurar los siguientes secrets en GitHub Settings → Secrets:

```
# AWS
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY

# Terraform Variables
TF_VAR_BUCKET_NAME
TF_VAR_GITHUB_REPOSITORY
TF_VAR_OIDC_PROVIDER_ARN
TF_VAR_DB_PASSWORD

# Frontend Environment Variables
OWNER_OPEN_ID
OWNER_NAME
VITE_APP_TITLE
VITE_APP_LOGO
OAUTH_SERVER_URL
VITE_APP_ID
VITE_OAUTH_PORTAL_URL
OAUTH_CLIENT_SECRET
VITE_API_URL

# Infracost (opcional)
INFRACOST_API_KEY
```

---

## 🛠️ Scripts de Utilidad

### `cleanup-lambda-enis.sh`

Limpia las Network Interfaces (ENIs) de Lambda que pueden quedar atascadas después de actualizaciones o antes de destruir infraestructura.

**Uso**:
```bash
chmod +x scripts/cleanup-lambda-enis.sh
./scripts/cleanup-lambda-enis.sh
```

**Variables de entorno**:
```bash
AWS_REGION=us-east-1 ./scripts/cleanup-lambda-enis.sh
```

### `cleanup-orphaned-resources.sh`

Identifica e importa recursos huérfanos (existen en AWS pero no en Terraform state) al estado de Terraform.

**Uso**:
```bash
chmod +x scripts/cleanup-orphaned-resources.sh
./scripts/cleanup-orphaned-resources.sh
```

**Variables de entorno requeridas**:
```bash
AWS_REGION=us-east-1
PROJECT_NAME=foodoffice
ENVIRONMENT=dev
TERRAFORM_DIR=terraform
BACKEND_BUCKET=foodoffice-terraform-state
BACKEND_KEY=environments/dev/terraform.tfstate
BACKEND_REGION=us-east-2
BACKEND_DYNAMODB=terraform-state-lock
```

### `import-existing-resources.sh`

Importa recursos existentes en AWS al estado de Terraform para evitar conflictos durante `terraform apply`.

**Uso**:
```bash
chmod +x scripts/import-existing-resources.sh
./scripts/import-existing-resources.sh
```

**Variables de entorno requeridas**:
```bash
AWS_REGION=us-east-1
ENVIRONMENT=dev
PROJECT_NAME=foodoffice
TERRAFORM_DIR=terraform
TF_VAR_environment=dev
TF_VAR_bucket_name=<bucket-name>
TF_VAR_github_repository=<owner/repo>
TF_VAR_oidc_provider_arn=<arn>
TF_VAR_db_password=<password>
```

---

## 📚 Documentación Adicional

### Estrategias y Guías

- **[ESTRATEGIA_GIT.md](docs/ESTRATEGIA_GIT.md)**: Modelo de branching, convenciones de commits, y flujo de trabajo
- **[ESTRATEGIA_TERRAFORM_STATE.md](docs/ESTRATEGIA_TERRAFORM_STATE.md)**: Gestión del estado de Terraform, state locking, y mejores prácticas

### Conceptos Clave

#### State Locking con DynamoDB

Terraform utiliza DynamoDB para prevenir modificaciones concurrentes del estado:
- **Tabla**: `terraform-state-lock`
- **Región**: `us-east-2`
- **Primary Key**: `LockID`
- **Billing**: PAY_PER_REQUEST (muy bajo costo)

#### Módulos de Terraform

El proyecto utiliza módulos externos desde un repositorio privado:
- `terraform-modules/s3`
- `terraform-modules/cloudfront`
- `terraform-modules/vpc`
- `terraform-modules/rds`
- `terraform-modules/security-groups`
- `terraform-modules/iam-oidc`

---

## 🔐 Seguridad

### Mejores Prácticas Implementadas

- ✅ **State remoto encriptado**: Estado de Terraform encriptado en S3
- ✅ **State locking**: DynamoDB previene modificaciones concurrentes
- ✅ **OIDC para GitHub Actions**: Autenticación sin credenciales estáticas
- ✅ **Security Groups**: Reglas de firewall restrictivas
- ✅ **VPC privada**: Recursos sensibles en subnets privadas
- ✅ **Secrets en GitHub**: Variables sensibles en GitHub Secrets
- ✅ **RDS encriptado**: Base de datos con encriptación en reposo

### Variables Sensibles

Nunca commitees:
- ❌ `.env` files
- ❌ `terraform.tfvars` con valores reales
- ❌ Credenciales de AWS
- ❌ Passwords de base de datos
- ❌ Tokens de API

---

## 🧪 Testing

### Frontend Tests

```bash
# Ejecutar todos los tests
npm run test

# Tests en modo watch
npm run test:watch

# Tests con cobertura
npm run test:coverage
```

### Validación de Terraform

```bash
cd terraform

# Validar sintaxis
terraform validate

# Formatear código
terraform fmt

# Verificar plan
terraform plan
```

---

## 📊 Monitoreo y Costos

### Análisis de Costos

El workflow de PR incluye análisis automático de costos con **Infracost**:
- Se ejecuta en cada Pull Request
- Publica comentario con estimación de costos
- Ayuda a identificar cambios costosos antes del merge

### Recursos AWS (Estimación)

| Recurso | Tipo | Costo Estimado (dev) |
|---------|------|----------------------|
| S3 | Bucket estático | ~$0.023/GB/mes |
| CloudFront | CDN | ~$0.085/GB transferido |
| RDS | db.t3.micro | ~$15/mes |
| VPC | NAT Instance t2.micro | Gratis (Free Tier) |
| DynamoDB | State Lock | < $0.10/mes |

**Nota**: Los costos varían según el uso. Consulta la calculadora de AWS para estimaciones precisas.

---

## 🐛 Troubleshooting

### Problemas Comunes

#### Error: "State file is locked"

**Causa**: Otra operación de Terraform está en curso.

**Solución**:
1. Verificar si hay workflows de GitHub Actions ejecutándose
2. Si es seguro, eliminar el lock manualmente en DynamoDB:
   ```bash
   aws dynamodb delete-item \
     --table-name terraform-state-lock \
     --key '{"LockID": {"S": "foodoffice-terraform-state/environments/dev/terraform.tfstate"}}' \
     --region us-east-2
   ```

#### Error: "InvalidPermission.Duplicate" en Security Groups

**Causa**: Regla de seguridad duplicada.

**Solución**: El workflow `manual-deploy.yml` maneja esto automáticamente. Si ocurre localmente:
```bash
# Eliminar regla duplicada manualmente
aws ec2 revoke-security-group-ingress \
  --group-id <rds-sg-id> \
  --protocol tcp \
  --port 5432 \
  --source-group <lambda-sg-id>
```

#### Error: ENIs de Lambda atascadas

**Causa**: Network Interfaces de Lambda no se liberan correctamente.

**Solución**: Ejecutar script de limpieza:
```bash
./scripts/cleanup-lambda-enis.sh
```

#### Frontend no se actualiza después del deploy

**Causa**: Caché de CloudFront.

**Solución**: El workflow invalida automáticamente. Si persiste:
```bash
aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths "/*"
```

---

## 🤝 Contribución

### Flujo de Trabajo

1. Crear feature branch desde `develop`
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/mi-feature
   ```

2. Hacer cambios y commits siguiendo [convenciones](docs/ESTRATEGIA_GIT.md)

3. Crear Pull Request a `develop`

4. Esperar aprobación y que pasen todos los checks

5. Merge después de aprobación

### Convenciones de Commits

Formato: `<tipo>(<ámbito>): <descripción>`

Ejemplos:
- `feat(frontend): agregar página de productos`
- `fix(terraform): corregir security group de RDS`
- `docs(readme): actualizar instrucciones de instalación`

Ver [ESTRATEGIA_GIT.md](docs/ESTRATEGIA_GIT.md) para más detalles.

---

## 📝 Licencia

MIT

---

## 👥 Equipo

**Mantenedores**: Equipo de Desarrollo FoodOffice

---

## 🔗 Enlaces Útiles

- [Documentación de Terraform](https://www.terraform.io/docs)
- [Documentación de AWS](https://docs.aws.amazon.com/)
- [Documentación de React](https://react.dev/)
- [Documentación de Vite](https://vitejs.dev/)
- [GitHub Actions](https://docs.github.com/en/actions)

---

**Última actualización**: 2024
