-- ============================================================
-- PROJET FIN DE MODULE : Système Bancaire Oracle
-- Script : 01_tables.sql
-- Description : Création de toutes les tables + contraintes
-- Connexion : bank_admin
-- ============================================================

-- ============================================================
-- MODULE 1 : UTILISATEURS
-- ============================================================

CREATE TABLE ROLES (
    id_role     NUMBER          PRIMARY KEY,
    nom_role    VARCHAR2(50)    NOT NULL UNIQUE,
    description VARCHAR2(200)
);

CREATE TABLE CLIENTS (
    id_client       NUMBER          PRIMARY KEY,
    nom             VARCHAR2(100)   NOT NULL,
    prenom          VARCHAR2(100)   NOT NULL,
    email           VARCHAR2(150)   NOT NULL UNIQUE,
    telephone       VARCHAR2(20),
    date_naissance  DATE            NOT NULL,
    adresse         VARCHAR2(300),
    date_inscription DATE           DEFAULT SYSDATE NOT NULL,
    statut          VARCHAR2(20)    DEFAULT 'ACTIF'
                    CONSTRAINT chk_statut_client CHECK (statut IN ('ACTIF','SUSPENDU','FERME')),
    id_role         NUMBER          REFERENCES ROLES(id_role),
    mot_de_passe    VARCHAR2(200)   NOT NULL,
    date_modification DATE          DEFAULT SYSDATE
);

CREATE TABLE ADMINS (
    id_admin        NUMBER          PRIMARY KEY,
    nom             VARCHAR2(100)   NOT NULL,
    prenom          VARCHAR2(100)   NOT NULL,
    email           VARCHAR2(150)   NOT NULL UNIQUE,
    mot_de_passe    VARCHAR2(200)   NOT NULL,
    id_role         NUMBER          REFERENCES ROLES(id_role),
    date_creation   DATE            DEFAULT SYSDATE,
    date_modification DATE          DEFAULT SYSDATE
);

CREATE TABLE HISTORIQUE_CONNEXIONS (
    id_connexion    NUMBER          PRIMARY KEY,
    id_client       NUMBER          REFERENCES CLIENTS(id_client),
    date_connexion  DATE            DEFAULT SYSDATE NOT NULL,
    ip_adresse      VARCHAR2(50),
    statut          VARCHAR2(20)    DEFAULT 'SUCCES'
                    CONSTRAINT chk_statut_cx CHECK (statut IN ('SUCCES','ECHEC'))
);

-- ============================================================
-- MODULE 2 : COMPTES & CARTES
-- ============================================================

CREATE TABLE COMPTES (
    id_compte       NUMBER          PRIMARY KEY,
    id_client       NUMBER          NOT NULL REFERENCES CLIENTS(id_client),
    type_compte     VARCHAR2(20)    NOT NULL
                    CONSTRAINT chk_type_compte CHECK (type_compte IN ('COURANT','EPARGNE')),
    solde           NUMBER(15,2)    DEFAULT 0
                    CONSTRAINT chk_solde CHECK (solde >= 0),
    date_ouverture  DATE            DEFAULT SYSDATE NOT NULL,
    statut          VARCHAR2(20)    DEFAULT 'ACTIF'
                    CONSTRAINT chk_statut_cpt CHECK (statut IN ('ACTIF','BLOQUE','FERME')),
    plafond_retrait NUMBER(15,2)    DEFAULT 5000,
    rib             VARCHAR2(30)    UNIQUE,
    date_modification DATE          DEFAULT SYSDATE
);

CREATE TABLE CARTES (
    id_carte            NUMBER          PRIMARY KEY,
    id_compte           NUMBER          NOT NULL REFERENCES COMPTES(id_compte),
    numero_carte        VARCHAR2(20)    NOT NULL UNIQUE,
    type_carte          VARCHAR2(20)    DEFAULT 'VISA'
                        CONSTRAINT chk_type_carte CHECK (type_carte IN ('VISA','MASTERCARD','GOLD')),
    date_expiration     DATE            NOT NULL,
    plafond_journalier  NUMBER(10,2)    DEFAULT 2000,
    statut              VARCHAR2(20)    DEFAULT 'ACTIVE'
                        CONSTRAINT chk_statut_carte CHECK (statut IN ('ACTIVE','BLOQUEE','EXPIREE')),
    date_modification   DATE            DEFAULT SYSDATE
);

-- ============================================================
-- MODULE 3 : VIREMENTS (= Commandes selon le sujet)
-- ============================================================

CREATE TABLE STATUTS_VIREMENT (
    id_statut   NUMBER          PRIMARY KEY,
    libelle     VARCHAR2(50)    NOT NULL UNIQUE,
    description VARCHAR2(200)
);

CREATE TABLE VIREMENTS (
    id_virement         NUMBER          PRIMARY KEY,
    id_compte_source    NUMBER          NOT NULL REFERENCES COMPTES(id_compte),
    id_compte_dest      NUMBER          NOT NULL REFERENCES COMPTES(id_compte),
    montant             NUMBER(15,2)    NOT NULL
                        CONSTRAINT chk_montant_vir CHECK (montant > 0),
    date_virement       DATE            DEFAULT SYSDATE NOT NULL,
    motif               VARCHAR2(300),
    id_statut           NUMBER          DEFAULT 1 REFERENCES STATUTS_VIREMENT(id_statut),
    frais               NUMBER(10,2)    DEFAULT 0,
    date_modification   DATE            DEFAULT SYSDATE,
    CONSTRAINT chk_comptes_differents CHECK (id_compte_source <> id_compte_dest)
);

-- ============================================================
-- MODULE 4 : TRANSACTIONS & PAIEMENTS
-- ============================================================

CREATE TABLE TRANSACTIONS (
    id_transaction  NUMBER          PRIMARY KEY,
    id_compte       NUMBER          NOT NULL REFERENCES COMPTES(id_compte),
    id_carte        NUMBER          REFERENCES CARTES(id_carte),
    type_transaction VARCHAR2(30)   NOT NULL
                    CONSTRAINT chk_type_tx CHECK (type_transaction IN
                    ('DEPOT','RETRAIT','VIREMENT_ENTRANT','VIREMENT_SORTANT','PAIEMENT')),
    montant         NUMBER(15,2)    NOT NULL
                    CONSTRAINT chk_montant_tx CHECK (montant > 0),
    date_transaction DATE           DEFAULT SYSDATE NOT NULL,
    description     VARCHAR2(300),
    statut          VARCHAR2(20)    DEFAULT 'VALIDEE'
                    CONSTRAINT chk_statut_tx CHECK (statut IN ('VALIDEE','EN_ATTENTE','REJETEE')),
    date_modification DATE          DEFAULT SYSDATE
);

-- ============================================================
-- MODULE 5 : CREDITS & ECHEANCES
-- ============================================================

CREATE TABLE CREDITS (
    id_credit       NUMBER          PRIMARY KEY,
    id_client       NUMBER          NOT NULL REFERENCES CLIENTS(id_client),
    id_compte       NUMBER          NOT NULL REFERENCES COMPTES(id_compte),
    montant_emprunte NUMBER(15,2)   NOT NULL
                    CONSTRAINT chk_montant_credit CHECK (montant_emprunte > 0),
    taux_interet    NUMBER(5,2)     NOT NULL
                    CONSTRAINT chk_taux CHECK (taux_interet > 0),
    duree_mois      NUMBER(3)       NOT NULL
                    CONSTRAINT chk_duree CHECK (duree_mois > 0),
    date_debut      DATE            DEFAULT SYSDATE NOT NULL,
    date_fin        DATE,
    statut          VARCHAR2(20)    DEFAULT 'EN_COURS'
                    CONSTRAINT chk_statut_credit CHECK (statut IN ('EN_COURS','SOLDE','EN_DEFAUT')),
    date_modification DATE          DEFAULT SYSDATE
);

CREATE TABLE ECHEANCES_CREDIT (
    id_echeance         NUMBER          PRIMARY KEY,
    id_credit           NUMBER          NOT NULL REFERENCES CREDITS(id_credit),
    date_echeance       DATE            NOT NULL,
    montant_principal   NUMBER(15,2)    NOT NULL,
    montant_interet     NUMBER(15,2)    NOT NULL,
    statut_paiement     VARCHAR2(20)    DEFAULT 'EN_ATTENTE'
                        CONSTRAINT chk_statut_ech CHECK (statut_paiement IN
                        ('EN_ATTENTE','PAYEE','EN_RETARD')),
    date_paiement       DATE,
    date_modification   DATE            DEFAULT SYSDATE
);

-- ============================================================
-- MODULE 6 : TABLES TECHNIQUES (Audit, Erreurs, Fraude)
-- ============================================================

CREATE TABLE AUDIT_LOG (
    id_audit        NUMBER          PRIMARY KEY,
    utilisateur     VARCHAR2(100)   NOT NULL,
    date_action     DATE            DEFAULT SYSDATE NOT NULL,
    table_cible     VARCHAR2(100)   NOT NULL,
    type_action     VARCHAR2(20)    NOT NULL
                    CONSTRAINT chk_type_audit CHECK (type_action IN ('INSERT','UPDATE','DELETE')),
    ancienne_valeur VARCHAR2(4000),
    nouvelle_valeur VARCHAR2(4000)
);

CREATE TABLE ERROR_LOG (
    id_erreur   NUMBER          PRIMARY KEY,
    code_erreur NUMBER,
    message     VARCHAR2(4000),
    date_erreur DATE            DEFAULT SYSDATE NOT NULL,
    contexte    VARCHAR2(500)
);

CREATE TABLE ALERTES_FRAUDE (
    id_alerte       NUMBER          PRIMARY KEY,
    id_compte       NUMBER          NOT NULL REFERENCES COMPTES(id_compte),
    id_transaction  NUMBER          REFERENCES TRANSACTIONS(id_transaction),
    type_alerte     VARCHAR2(50)    NOT NULL
                    CONSTRAINT chk_type_alerte CHECK (type_alerte IN
                    ('MONTANT_ELEVE','FREQUENCE_ELEVEE','HEURE_SUSPECTE','PAYS_ETRANGER')),
    montant         NUMBER(15,2),
    date_alerte     DATE            DEFAULT SYSDATE NOT NULL,
    statut          VARCHAR2(20)    DEFAULT 'OUVERTE'
                    CONSTRAINT chk_statut_alerte CHECK (statut IN ('OUVERTE','TRAITEE','FERMEE')),
    description     VARCHAR2(500)
);

-- ============================================================
-- MODULE 7 : PLAFONDS_CREDIT (module intelligent)
-- Gestion des plafonds d'autorisation de crédit par client
-- ============================================================

CREATE TABLE PLAFONDS_CREDIT (
    id_plafond          NUMBER          PRIMARY KEY,
    id_client           NUMBER          NOT NULL REFERENCES CLIENTS(id_client),
    id_compte           NUMBER          NOT NULL REFERENCES COMPTES(id_compte),
    plafond_autorise    NUMBER(15,2)    NOT NULL
                        CONSTRAINT chk_plafond CHECK (plafond_autorise > 0),
    plafond_utilise     NUMBER(15,2)    DEFAULT 0,
    plafond_disponible  NUMBER(15,2)    GENERATED ALWAYS AS (plafond_autorise - plafond_utilise) VIRTUAL,
    date_attribution    DATE            DEFAULT SYSDATE NOT NULL,
    date_revision       DATE,
    statut              VARCHAR2(20)    DEFAULT 'ACTIF'
                        CONSTRAINT chk_statut_plafond CHECK (statut IN ('ACTIF','SUSPENDU','EXPIRE')),
    motif_suspension    VARCHAR2(300),
    date_modification   DATE            DEFAULT SYSDATE
);

COMMIT;

SELECT 'Tables créées avec succès !' AS MESSAGE FROM DUAL;
