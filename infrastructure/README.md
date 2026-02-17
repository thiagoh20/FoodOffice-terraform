# Infrastructure as Code - FoodOffice

Este directorio contiene la configuración de infraestructura como código usando Terraform y los pipelines de CI/CD con GitHub Actions.

## Estructura del Proyecto

```
infrastructure/
├── terraform/
│   ├── environments/          # Configuraciones por ambiente
│   │   ├── dev/               # Desarrollo
│   │   ├── staging/           # Staging
│   │   └── prod/              # Producción
│   ├── modules/               # Módulos reutilizables
│   │   ├── vpc/              # VPC y networking
│   │   ├── rds/              # Base de datos MySQL
│   │   ├── s3/               # Almacenamiento S3
│   │   ├── ecs/              # Cluster ECS
│   │   └── alb/              # Application Load Balancer
│   ├── main.tf               # Configuración principal
│   ├── variables.tf          # Variables globales
│   ├── outputs.tf            # Outputs globales
│   └── versions.tf           # Versiones de providers
│
.github/
└── workflows/                # Pipelines de GitHub Actions
    ├── ci.yml               # Continuous Integration
    ├── cd-dev.yml           # Continuous Deployment - Dev
    ├── cd-staging.yml       # Continuous Deployment - Staging
    └── cd-prod.yml          # Continuous Deployment - Prod
```

## Requisitos Previos

1. **Terraform** >= 1.6.0
   ```bash
   brew install terraform
   # o descargar desde https://www.terraform.io/downloads
   ```

2. **AWS CLI** configurado
   ```bash
   aws configure
   ```

3. **GitHub Secrets** configurados (para CI/CD):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `VERCEL_TOKEN` (opcional, si usas Vercel)
   - `VERCEL_ORG_ID` (opcional)
   - `VERCEL_PROJECT_ID` (opcional)

## Uso de Terraform

### Inicializar Terraform

```bash
cd infrastructure/terraform/environments/dev
terraform init
```

### Configurar Variables

Copia el archivo de ejemplo y completa los valores:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edita terraform.tfvars con tus valores
```

### Plan y Apply

```bash
# Ver qué cambios se van a realizar
terraform plan

# Aplicar los cambios
terraform apply
```

### Trabajar con Módulos

Los módulos están en `infrastructure/terraform/modules/`. Para usarlos, descomenta las referencias en `main.tf`:

```hcl
module "vpc" {
  source = "../modules/vpc"
  
  environment = var.environment
  project_name = var.project_name
}
```

## Pipelines de GitHub Actions

### CI Pipeline (`ci.yml`)

Se ejecuta automáticamente en:
- Push a `main` o `develop`
- Pull requests a `main` o `develop`

**Tareas:**
- Verificación de tipos TypeScript
- Ejecución de tests
- Verificación de formato de código
- Build de la aplicación

### CD Pipelines

#### Desarrollo (`cd-dev.yml`)
- Se ejecuta en push a `develop`
- Deploy automático a ambiente de desarrollo

#### Staging (`cd-staging.yml`)
- Se ejecuta en push a `main`
- Deploy a ambiente de staging

#### Producción (`cd-prod.yml`)
- Se ejecuta en tags `v*` (ej: `v1.0.0`)
- Requiere confirmación manual para deploy
- Deploy a producción

## Configuración de Backend (State)

Para trabajar en equipo, configura un backend remoto para el estado de Terraform. Descomenta y configura en `versions.tf`:

```hcl
backend "s3" {
  bucket         = "foodoffice-terraform-state"
  key            = "terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-state-lock"
}
```

**Importante:** Crea el bucket S3 y la tabla DynamoDB antes de usar el backend.

## Módulos Disponibles

### VPC
Crea una VPC con subnets públicas y privadas, Internet Gateway y route tables.

### RDS
Crea una instancia RDS MySQL con:
- Subnet group
- Security group
- Backups automáticos
- Encryption habilitado

### S3
Crea buckets S3 con:
- Versionado
- Encryption
- Lifecycle policies
- Public access bloqueado

### ECS
Crea un cluster ECS con:
- Container Insights
- CloudWatch Logs

### ALB
Crea un Application Load Balancer con:
- Target group
- Health checks
- Security group

## Mejores Prácticas

1. **Nunca commitear archivos `.tfvars`` con secretos`**
2. **Usar variables de entorno o AWS Secrets Manager para credenciales**
3. **Revisar siempre el plan antes de aplicar**
4. **Usar workspaces de Terraform para ambientes diferentes**
5. **Mantener el estado de Terraform en un backend remoto**
6. **Taggear todos los recursos para mejor organización**

## Troubleshooting

### Error: "Backend configuration changed"
Si cambias la configuración del backend, necesitas migrar el estado:
```bash
terraform init -migrate-state
```

### Error: "Provider version mismatch"
Asegúrate de tener la versión correcta del provider en `versions.tf`.

## Recursos Adicionales

- [Documentación de Terraform](https://www.terraform.io/docs)
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions](https://docs.github.com/en/actions)
