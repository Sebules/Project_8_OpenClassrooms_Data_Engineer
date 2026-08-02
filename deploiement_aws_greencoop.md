# Déploiement AWS – Projet 8 GreenCoop (PostgreSQL / Airbyte / DBT)

Ce guide reprend votre architecture locale (Docker Compose PostgreSQL sur le port 5433, Airbyte via `abctl`, projet dbt `greencoop_projet` avec schémas `raw` et `analytics`) et la transpose sur AWS, dans l'ordre recommandé par la consigne.

**Avant de commencer** : créez une alarme de facturation (Billing → Budgets) à un seuil bas (ex. 10€) pour être alerté immédiatement. Notez l'heure de début : la plupart des ressources ci-dessous ne sont pas gratuites.

---

## 0. Architecture cible

```
                         ┌─────────────────────────┐
   Sources météo   ───►  │   EC2 (Airbyte / abctl)  │
 (InfoClimat, WU)        └───────────┬─────────────┘
                                      │ écrit dans schéma "raw"
                                      ▼
                          ┌───────────────────────┐
                          │  Amazon RDS PostgreSQL │
                          └───────────┬───────────┘
                                      │ lit "raw", écrit "analytics"
                                      ▼
                          ┌───────────────────────┐
                          │  ECS Fargate (dbt run) │◄── EventBridge Scheduler (cron quotidien)
                          └───────────┬───────────┘
                                      │
                          ┌───────────▼───────────┐
                          │      CloudWatch        │  (logs Airbyte + dbt, métriques RDS, alarmes)
                          └────────────────────────┘
```

Tout est déployé dans **une seule région** (ex. `eu-west-3` – Paris) et idéalement dans un VPC dédié avec un sous-réseau privé pour RDS et ECS, et un sous-réseau public pour l'EC2 Airbyte (ou privé + bastion si vous voulez rester strict).

---

## 1. Sécurité et gestion des secrets (à faire en premier)

Avant toute chose, créez le secret dans **AWS Secrets Manager** — vous le référencerez partout ensuite, jamais de mot de passe en dur.

```bash
aws secretsmanager create-secret \
  --name greencoop/rds/postgres \
  --description "Identifiants RDS PostgreSQL GreenCoop" \
  --secret-string '{"username":"greencoop_admin","password":"REMPLACER_PAR_UN_MDP_FORT"}'
```

Utilisez un mot de passe généré (`aws secretsmanager get-random-password`) plutôt que `Seb+postgresql1` utilisé en local. Ce secret sera référencé :
- par la tâche ECS dbt (variable d'environnement injectée depuis Secrets Manager),
- par Airbyte pour sa destination PostgreSQL,
- jamais commité dans `profiles.yml`, `dbt_project.yml` ou le repo Git.

---

## 2. Déployer PostgreSQL sur Amazon RDS

### 2.1 Réseau
Créez (ou réutilisez) un VPC avec au moins 2 sous-réseaux privés dans des AZ différentes (RDS l'exige pour le subnet group, même en mono-AZ).

```bash
aws rds create-db-subnet-group \
  --db-subnet-group-name greencoop-subnet-group \
  --db-subnet-group-description "Subnet group RDS GreenCoop" \
  --subnet-ids subnet-aaaa subnet-bbbb
```

### 2.2 Security Group
Un SG dédié à RDS, ouvert uniquement sur le port 5432, **uniquement** depuis les SG d'Airbyte (EC2) et de dbt (ECS) — jamais 0.0.0.0/0.

```bash
aws ec2 create-security-group \
  --group-name greencoop-rds-sg \
  --description "SG RDS PostgreSQL GreenCoop" \
  --vpc-id vpc-xxxx

# Autoriser uniquement depuis le SG Airbyte et le SG ECS (à créer plus tard,
# vous pourrez ajouter ces règles après leur création)
aws ec2 authorize-security-group-ingress \
  --group-id sg-rds-xxxx --protocol tcp --port 5432 \
  --source-group sg-airbyte-xxxx
```

### 2.3 Instance RDS

```bash
aws rds create-db-instance \
  --db-instance-identifier greencoop-postgres \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 16.4 \
  --master-username greencoop_admin \
  --manage-master-user-password \
  --allocated-storage 20 \
  --storage-type gp3 \
  --vpc-security-group-ids sg-rds-xxxx \
  --db-subnet-group-name greencoop-subnet-group \
  --backup-retention-period 7 \
  --preferred-backup-window "02:00-03:00" \
  --enable-performance-insights \
  --no-publicly-accessible \
  --no-multi-az
```

Points clés :
- `--manage-master-user-password` : RDS génère et stocke lui-même le mot de passe dans Secrets Manager (alternative à créer le secret vous-même à l'étape 1).
- `--backup-retention-period 7` : sauvegardes automatiques quotidiennes conservées 7 jours (répond au point de vigilance "oublier les sauvegardes automatiques").
- `--no-publicly-accessible` : la base n'est joignable que depuis l'intérieur du VPC.
- `db.t3.micro` + mono-AZ suffisent largement pour un projet pédagogique ; activez Multi-AZ seulement si vous voulez démontrer la haute disponibilité (coût x2).

### 2.4 Créer la base et les schémas
Une fois l'instance `available`, connectez-vous (depuis un EC2 dans le VPC, ou temporairement en autorisant votre IP) :

```bash
psql "host=<endpoint-rds>.rds.amazonaws.com port=5432 dbname=postgres user=greencoop_admin"
```

```sql
CREATE DATABASE greencoop;
\c greencoop
CREATE SCHEMA raw;
CREATE SCHEMA analytics;
```

---

## 3. Déployer Airbyte sur AWS

Comme en local vous utilisez `abctl` (cluster kind basé sur Docker), la façon la plus directe de reproduire cela sur AWS est une **instance EC2** dédiée qui fait tourner `abctl` exactement comme votre poste. C'est l'approche la plus simple pour un projet de ce type (Airbyte ne propose pas de déploiement ECS officiel).

### 3.1 Lancer l'EC2

```bash
aws ec2 run-instances \
  --image-id ami-xxxxxxxx \
  --instance-type t3.large \
  --key-name votre-cle \
  --security-group-ids sg-airbyte-xxxx \
  --subnet-id subnet-public-xxxx \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=greencoop-airbyte}]'
```
- `t3.large` minimum (Airbyte + kind sont gourmands en RAM/CPU).
- Security group : port 8000 (UI Airbyte) restreint à votre IP, port 22 (SSH) restreint à votre IP.

### 3.2 Installer Docker + abctl sur l'instance

```bash
sudo yum update -y && sudo yum install -y docker
sudo systemctl enable --now docker
curl -LsfS https://get.airbyte.com | bash -
abctl local install
abctl local credentials
```

### 3.3 Connecter Airbyte à RDS
Dans l'UI Airbyte (`http://<ip-publique-ec2>:8000`), créez une **destination PostgreSQL** :
- Host : endpoint RDS
- Port : 5432
- Database : `greencoop`
- Schema : `raw`
- Username/Password : récupérés depuis Secrets Manager (jamais saisis en clair dans un script versionné)

Recréez ensuite vos connecteurs sources (InfoClimat, Weather Underground) comme en local, et testez une synchronisation manuelle pour vérifier que les données arrivent bien dans le schéma `raw` de RDS.

> Astuce coût : cette instance EC2 tourne en continu tant qu'Airbyte doit ingérer. Si vos syncs sont peu fréquentes, envisagez de l'arrêter (`aws ec2 stop-instances`) entre les fenêtres d'ingestion, ou de planifier son démarrage/arrêt via EventBridge + Lambda.

---

## 4. Exécution planifiée de dbt via ECS

### 4.1 Containeriser le projet dbt

Dans le dossier `greencoop_projet` :

```dockerfile
FROM python:3.12-slim
RUN pip install dbt-core dbt-postgres
WORKDIR /dbt
COPY . .
ENTRYPOINT ["dbt"]
CMD ["run"]
```

Le `profiles.yml` ne doit **pas** contenir le mot de passe en dur. Utilisez les variables d'environnement dbt supporte nativement :

```yaml
greencoop_projet:
  target: prod
  outputs:
    prod:
      type: postgres
      host: "{{ env_var('DBT_HOST') }}"
      user: "{{ env_var('DBT_USER') }}"
      password: "{{ env_var('DBT_PASSWORD') }}"
      port: 5432
      dbname: greencoop
      schema: analytics
      threads: 4
```

### 4.2 Construire et pousser l'image sur ECR

```bash
aws ecr create-repository --repository-name greencoop-dbt
aws ecr get-login-password | docker login --username AWS \
  --password-stdin <account-id>.dkr.ecr.eu-west-3.amazonaws.com

docker build -t greencoop-dbt .
docker tag greencoop-dbt:latest <account-id>.dkr.ecr.eu-west-3.amazonaws.com/greencoop-dbt:latest
docker push <account-id>.dkr.ecr.eu-west-3.amazonaws.com/greencoop-dbt:latest
```

### 4.3 Cluster + Task Definition Fargate

```bash
aws ecs create-cluster --cluster-name greencoop-cluster
```

Task definition (`dbt-task-def.json`), avec les secrets injectés depuis Secrets Manager (pas de credentials en clair) :

```json
{
  "family": "greencoop-dbt-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::<account-id>:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "dbt-run",
      "image": "<account-id>.dkr.ecr.eu-west-3.amazonaws.com/greencoop-dbt:latest",
      "command": ["run"],
      "secrets": [
        {"name": "DBT_HOST", "valueFrom": "arn:aws:secretsmanager:...:secret:greencoop/rds/postgres:host::"},
        {"name": "DBT_USER", "valueFrom": "arn:aws:secretsmanager:...:secret:greencoop/rds/postgres:username::"},
        {"name": "DBT_PASSWORD", "valueFrom": "arn:aws:secretsmanager:...:secret:greencoop/rds/postgres:password::"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/greencoop/dbt",
          "awslogs-region": "eu-west-3",
          "awslogs-stream-prefix": "dbt"
        }
      }
    }
  ]
}
```

```bash
aws logs create-log-group --log-group-name /greencoop/dbt
aws ecs register-task-definition --cli-input-json file://dbt-task-def.json
```

### 4.4 Planification avec EventBridge Scheduler
Plutôt qu'un serveur qui tourne en continu, on planifie l'exécution ponctuelle de la tâche (ex. tous les jours à 6h, après la dernière sync Airbyte) :

```bash
aws scheduler create-schedule \
  --name greencoop-dbt-daily \
  --schedule-expression "cron(0 6 * * ? *)" \
  --flexible-time-window '{"Mode": "OFF"}' \
  --target '{
    "Arn": "arn:aws:ecs:eu-west-3:<account-id>:cluster/greencoop-cluster",
    "RoleArn": "arn:aws:iam::<account-id>:role/schedulerEcsRunTaskRole",
    "EcsParameters": {
      "TaskDefinitionArn": "arn:aws:ecs:eu-west-3:<account-id>:task-definition/greencoop-dbt-task",
      "LaunchType": "FARGATE",
      "NetworkConfiguration": {
        "awsvpcConfiguration": {
          "Subnets": ["subnet-priv-xxxx"],
          "SecurityGroups": ["sg-ecs-xxxx"],
          "AssignPublicIp": "DISABLED"
        }
      }
    }
  }'
```

On préférera exécuter `dbt run` puis `dbt test` comme deux commandes (deux schedules, ou un `command` combiné `["run", "&&", "dbt", "test"]` via un petit script `entrypoint.sh`) afin de séparer les logs et pouvoir alerter spécifiquement sur les échecs de tests qualité.

---

## 5. Centraliser les logs dans CloudWatch

- **dbt (ECS)** : déjà configuré ci-dessus via `awslogs` driver → groupe `/greencoop/dbt`. Chaque exécution planifiée crée un nouveau log stream, consultable directement dans CloudWatch Logs Insights.
- **Airbyte (EC2)** : installez le **CloudWatch agent** sur l'instance pour envoyer les logs Docker d'Airbyte :

```bash
sudo yum install -y amazon-cloudwatch-agent
```

Configuration minimale (`/opt/aws/amazon-cloudwatch-agent/etc/config.json`) pour capter les logs des conteneurs Airbyte (via le pilote de logs Docker `json-file`, chemin `/var/lib/docker/containers/*/*.log`) vers un groupe `/greencoop/airbyte`.

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json -s
```

- **RDS** : activez l'export des logs PostgreSQL vers CloudWatch directement au niveau de l'instance :

```bash
aws rds modify-db-instance \
  --db-instance-identifier greencoop-postgres \
  --cloudwatch-logs-export-configuration '{"EnableLogTypes":["postgresql","upgrade"]}' \
  --apply-immediately
```

Vous avez ainsi 3 groupes de logs centralisés : `/greencoop/dbt`, `/greencoop/airbyte`, `/aws/rds/instance/greencoop-postgres/postgresql`.

---

## 6. Monitoring et sauvegardes automatiques

### 6.1 Sauvegardes RDS (déjà activées à l'étape 2.3)
Vérifiez et complétez avec un snapshot manuel avant chaque étape risquée :

```bash
aws rds create-db-snapshot \
  --db-instance-identifier greencoop-postgres \
  --db-snapshot-identifier greencoop-postgres-manual-$(date +%Y%m%d)
```

### 6.2 Alarmes CloudWatch sur RDS
Au minimum : CPU, espace disque, connexions, et échec de la tâche ECS dbt.

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name greencoop-rds-cpu-high \
  --namespace AWS/RDS --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=greencoop-postgres \
  --statistic Average --period 300 --threshold 80 \
  --comparison-operator GreaterThanThreshold --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:eu-west-3:<account-id>:greencoop-alerts

aws cloudwatch put-metric-alarm \
  --alarm-name greencoop-rds-storage-low \
  --namespace AWS/RDS --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value=greencoop-postgres \
  --statistic Average --period 300 --threshold 2000000000 \
  --comparison-operator LessThanThreshold --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:eu-west-3:<account-id>:greencoop-alerts
```

Créez une alarme sur le nombre d'échecs de la tâche ECS (métrique custom via un filtre de métrique sur le log group `/greencoop/dbt`, cherchant `ERROR` ou `Completed with errors`), et connectez tout à un topic **SNS** avec votre e-mail en abonné pour être notifié.

### 6.3 Performance Insights
Déjà activé à la création RDS (`--enable-performance-insights`) : permet de visualiser les requêtes lentes générées par les modèles dbt et d'ajuster les index si besoin (vous en avez déjà défini certains sur `dim_weather_stations` / `fact_weather_observations`).

---

## 7. Vérifier disponibilité et performance globale

Checklist finale avant la démo :

1. **Connectivité** : `dbt debug` depuis un environnement pointant vers RDS → doit passer au vert.
2. **Ingestion** : lancer une sync Airbyte manuelle, vérifier dans `raw.*` que les lignes arrivent (`SELECT count(*) FROM raw.weather_underground_ichtegem_be;`).
3. **Transformation planifiée** : déclencher manuellement le schedule EventBridge une première fois (`aws scheduler` ne permet pas de "run now" directement — lancez la task ECS via `aws ecs run-task` avec la même task-definition pour tester), vérifier les logs dans `/greencoop/dbt`, vérifier que `analytics.dim_weather_stations` et `analytics.fact_weather_observations` sont à jour.
4. **Tests qualité** : la commande `dbt test` doit tourner dans le même conteneur/schedule et ses résultats doivent apparaître dans les logs CloudWatch — c'est votre indicateur de "taux d'erreur" pour la présentation à Ouly.
5. **Performance** : dans Performance Insights, vérifiez qu'aucune requête ne sature le CPU pendant les runs dbt ; dans CloudWatch, vérifiez la latence RDS (`ReadLatency`/`WriteLatency`) reste stable.
6. **Disponibilité** : simulez une coupure (arrêt/redémarrage RDS en heures creuses) pour vérifier le comportement de reprise, et documentez le délai de récupération pour la partie "délai de mise à disposition des données" de votre présentation.

---

## 8. À la fin du projet — nettoyage (important)

```bash
aws scheduler delete-schedule --name greencoop-dbt-daily
aws ecs deregister-task-definition --task-definition greencoop-dbt-task:1
aws ecs delete-cluster --cluster greencoop-cluster
aws ec2 terminate-instances --instance-ids i-xxxxxxxx   # instance Airbyte
aws rds delete-db-instance --db-instance-identifier greencoop-postgres \
  --skip-final-snapshot   # ou --final-db-snapshot-identifier si vous voulez garder une trace
aws ecr delete-repository --repository-name greencoop-dbt --force
aws logs delete-log-group --log-group-name /greencoop/dbt
aws logs delete-log-group --log-group-name /greencoop/airbyte
aws secretsmanager delete-secret --secret-id greencoop/rds/postgres --force-delete-without-recovery
```

Vérifiez ensuite l'onglet **Billing → Cost Explorer** que le coût journalier retombe bien à zéro sur les services utilisés.

---

## Récapitulatif des points de vigilance couverts

| Point de vigilance | Réponse dans ce guide |
|---|---|
| Secrets en dur | Secrets Manager partout (§1, §4.1, §4.3) |
| Sauvegardes oubliées | `--backup-retention-period 7` + snapshots manuels (§2.3, §6.1) |
| Pas de monitoring | Performance Insights + alarmes CloudWatch + SNS (§6.2–6.3) |
| Déployer sans tester en local | Vous êtes parti d'une base locale déjà validée (schema, tests dbt) avant ce déploiement |
