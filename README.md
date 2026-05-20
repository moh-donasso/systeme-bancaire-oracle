#  Système Bancaire Oracle
> Projet de Fin de Module — Bases de Données Avancées  
> CI1 — 2025/2026 — Pr. Yasser EL MADANI EL ALAMI

---

## Description

Ce projet implémente une base de données Oracle complète pour un **système bancaire intelligent**.  
Il couvre la modélisation, le développement SQL/PL/SQL, l'administration Oracle et l'optimisation des performances.

---

##  Équipe

| Membre |
|--------|
| COULIBALY Donasso Mohamed |
| VASSOU guidjinga Xavier |

---

## Architecture

```
systeme-bancaire-oracle/
├── scripts/
│   ├── 00_setup.sql          # Création utilisateur bank_admin
│   ├── 01_tables.sql         # Tables + contraintes (15 tables)
│   ├── 02_sequences.sql      # Séquences (15 séquences)
│   ├── 03_views.sql          # Vues simples, complexe, matérialisée
│   ├── 04_indexes.sql        # Index B-TREE, BITMAP, fonctionnel
│   ├── 05_synonyms.sql       # Synonymes privés et publics
│   ├── 06_procedures.sql     # 3 procédures PL/SQL
│   ├── 07_functions.sql      # 3 fonctions PL/SQL
│   ├── 08_triggers.sql       # 3 triggers + module fraude
│   ├── 09_packages.sql       # Package PKG_VIREMENTS
│   ├── 10_users_roles.sql    # Utilisateurs, rôles, audit
│   ├── 11_data_test.sql      # Jeu de test (20+ lignes/table)
│   ├── 12_explain_plan.sql   # EXPLAIN PLAN avant/après index
│   └── 99_drop_all.sql       # Nettoyage complet
├── docs/
│   ├── rapport.pdf           # Rapport technique 
│   ├── presentation.pptx     # Diaporama soutenance
│   └── schema/
│       └── erd.png           # Diagramme Entité-Relation
└── README.md
```

---

##  Prérequis

| Outil | Version | Rôle |
|-------|---------|------|
| Docker Desktop | 4.x+ | Conteneur Oracle |
| Oracle Database XE | 21c | Moteur de base de données |
| VS Code | 1.8x+ | Éditeur SQL |
| SQL Developer Extension | Latest | Connexion Oracle dans VS Code |
| Git | 2.x+ | Versioning |

---

##  Installation

### 1. Cloner le dépôt

```bash
git clone https://github.com/<votre-groupe>/systeme-bancaire-oracle.git
cd systeme-bancaire-oracle
```

### 2. Démarrer Oracle avec Docker

```bash
docker start oracle-xe
```

Vérifier que le container tourne sur le port `1521`.

### 3. Créer le schéma (connexion SYSTEM)

```bash
docker exec -it oracle-xe sqlplus / as sysdba
```

```sql
ALTER SESSION SET CONTAINER = XEPDB1;
```

Puis exécuter `scripts/00_setup.sql`.

### 4. Se connecter en tant que bank_admin

| Paramètre | Valeur |
|-----------|--------|
| Host | localhost |
| Port | 1521 |
| Service | XEPDB1 |
| Username | bank_admin |
| Password | bank1234 |

### 5. Exécuter les scripts dans l'ordre

```sql
-- Dans VS Code avec connexion bank_admin
@scripts/01_tables.sql
@scripts/02_sequences.sql
@scripts/03_views.sql
@scripts/04_indexes.sql
@scripts/05_synonyms.sql
@scripts/06_procedures.sql
@scripts/07_functions.sql
@scripts/08_triggers.sql
@scripts/09_packages.sql
@scripts/11_data_test.sql
@scripts/12_explain_plan.sql
```

```sql
-- Dans VS Code avec connexion SYSTEM
@scripts/10_users_roles.sql
```

---

##  Modèle de données

### Tables principales (15 tables)

| Module | Tables |
|--------|--------|
| Utilisateurs | `ROLES`, `CLIENTS`, `ADMINS`, `HISTORIQUE_CONNEXIONS` |
| Comptes | `COMPTES`, `CARTES` |
| Virements | `VIREMENTS`, `STATUTS_VIREMENT` |
| Transactions | `TRANSACTIONS` |
| Crédits | `CREDITS`, `ECHEANCES_CREDIT` |
| Module intelligent | `PLAFONDS_CREDIT`, `ALERTES_FRAUDE` |
| Technique | `AUDIT_LOG`, `ERROR_LOG` |

---

##  Objets Oracle

| Objet | Nom | Description |
|-------|-----|-------------|
| Vue simple | `vue_comptes_clients` | Jointure COMPTES + CLIENTS |
| Vue simple | `vue_virements_statuts` | Jointure VIREMENTS + STATUTS |
| Vue complexe | `vue_stats_transactions` | Agrégation GROUP BY |
| Vue matérialisée | `mv_stats_mensuelles_virements` | Stats mensuelles ON DEMAND |
| Package | `pkg_virements` | 3 procédures + 4 fonctions |
| Trigger métier | `trg_solde_negatif` | Bloque solde négatif |
| Trigger audit | `trg_audit_comptes` | Journalise UPDATE/DELETE |
| Trigger technique | `trg_date_modif_*` | Met à jour DATE_MODIFICATION |
| Trigger fraude | `trg_detection_fraude` | Détecte montants suspects |

---

##  Sécurité & Administration

### Rôles

| Rôle | Droits |
|------|--------|
| `gestionnaire_comptes` | SELECT + UPDATE sur COMPTES, VIREMENTS, CLIENTS |
| `client_app` | SELECT sur COMPTES + INSERT sur VIREMENTS, TRANSACTIONS |

### Utilisateurs applicatifs

| Utilisateur | Rôle | Mot de passe |
|-------------|------|-------------|
| `gestionnaire` | gestionnaire_comptes | gest1234 |
| `app_client` | client_app | client1234 |

### Audit activé sur
- `UPDATE` sur `COMPTES`
- `DELETE` sur `VIREMENTS`
- `INSERT` sur `TRANSACTIONS`

---

##  Module Intelligent — Détection de Fraude

Le trigger `trg_detection_fraude` génère automatiquement une alerte dans `ALERTES_FRAUDE` pour chaque transaction dépassant **10 000 MAD**.

```sql
-- Voir les alertes générées
SELECT * FROM ALERTES_FRAUDE ORDER BY date_alerte DESC;
```

---

##  Optimisation

Le script `12_explain_plan.sql` compare les plans d'exécution avant et après création des index.  
La réduction du COST est d'au moins **50%** grâce à l'index composite :

```sql
idx_btree_tx_compte_date ON TRANSACTIONS(id_compte, date_transaction, statut)
```

---

##  Reset complet

```sql
--  Supprime toutes les données !
@scripts/99_drop_all.sql
```

---

##  Livrable GitHub

-  14 scripts SQL dans `scripts/`
-  Rapport technique dans `docs/`
-  Diagramme ERD dans `docs/schema/`
-  Historique de commits régulier

---

*Projet réalisé dans le cadre du module Bases de Données Avancées — ISMAGI CI1 2025/2026*
