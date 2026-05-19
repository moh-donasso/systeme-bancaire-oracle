-- ============================================================
-- PROJET FIN DE MODULE : Système Bancaire Oracle
-- Script : 10_users_roles.sql
-- Description : Utilisateurs, rôles, droits et audit
-- Connexion : SYSTEM (pas bank_admin !)
-- ============================================================

-- ============================================================
-- 1. CRÉATION DES RÔLES
-- ============================================================

-- Rôle gestionnaire_stock (adapté : gestionnaire_comptes)
-- Peut consulter et modifier les comptes et virements
CREATE ROLE gestionnaire_comptes;

-- Rôle client_app
-- Peut consulter les produits et passer des commandes
CREATE ROLE client_app;

-- ============================================================
-- 2. ATTRIBUTION DES DROITS AUX RÔLES
-- ============================================================

-- gestionnaire_comptes : SELECT + UPDATE sur tables critiques
GRANT SELECT, UPDATE ON bank_admin.COMPTES       TO gestionnaire_comptes;
GRANT SELECT, UPDATE ON bank_admin.VIREMENTS     TO gestionnaire_comptes;
GRANT SELECT, UPDATE ON bank_admin.CLIENTS       TO gestionnaire_comptes;
GRANT SELECT, UPDATE ON bank_admin.CARTES        TO gestionnaire_comptes;
GRANT SELECT         ON bank_admin.TRANSACTIONS  TO gestionnaire_comptes;
GRANT SELECT         ON bank_admin.AUDIT_LOG     TO gestionnaire_comptes;
GRANT SELECT         ON bank_admin.ALERTES_FRAUDE TO gestionnaire_comptes;

-- client_app : SELECT sur comptes + INSERT sur virements et transactions
GRANT SELECT         ON bank_admin.COMPTES          TO client_app;
GRANT SELECT         ON bank_admin.STATUTS_VIREMENT TO client_app;
GRANT INSERT         ON bank_admin.VIREMENTS        TO client_app;
GRANT INSERT         ON bank_admin.TRANSACTIONS     TO client_app;
GRANT SELECT         ON bank_admin.TRANSACTIONS     TO client_app;
GRANT SELECT         ON bank_admin.CARTES           TO client_app;

-- ============================================================
-- 3. CRÉATION DES UTILISATEURS APPLICATIFS
-- ============================================================

-- Utilisateur gestionnaire
BEGIN
    EXECUTE IMMEDIATE 'DROP USER gestionnaire CASCADE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE USER gestionnaire IDENTIFIED BY gest1234
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 10M ON USERS;

GRANT CREATE SESSION TO gestionnaire;
GRANT gestionnaire_comptes TO gestionnaire;

-- Utilisateur application client
BEGIN
    EXECUTE IMMEDIATE 'DROP USER app_client CASCADE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE USER app_client IDENTIFIED BY client1234
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 5M ON USERS;

GRANT CREATE SESSION TO app_client;
GRANT client_app TO app_client;

-- ============================================================
-- 4. AUDIT DES ACTIONS SENSIBLES
-- Exigence du sujet : au moins 2 actions auditées
-- ============================================================

-- Audit UPDATE sur le prix/solde des comptes
AUDIT UPDATE ON bank_admin.COMPTES BY ACCESS;

-- Audit DELETE sur les virements
AUDIT DELETE ON bank_admin.VIREMENTS BY ACCESS;

-- Audit INSERT sur les transactions (détection fraude)
AUDIT INSERT ON bank_admin.TRANSACTIONS BY ACCESS;

-- Audit connexions des utilisateurs applicatifs
AUDIT CREATE SESSION BY gestionnaire;
AUDIT CREATE SESSION BY app_client;

-- ============================================================
-- 5. VÉRIFICATION
-- ============================================================

-- Afficher les rôles créés
SELECT role FROM dba_roles
WHERE role IN ('GESTIONNAIRE_COMPTES', 'CLIENT_APP');

-- Afficher les utilisateurs créés
SELECT username, account_status, default_tablespace
FROM dba_users
WHERE username IN ('GESTIONNAIRE', 'APP_CLIENT', 'BANK_ADMIN');

-- Afficher les droits accordés aux rôles
SELECT grantee, owner, table_name, privilege
FROM dba_tab_privs
WHERE grantee IN ('GESTIONNAIRE_COMPTES', 'CLIENT_APP')
ORDER BY grantee, table_name;
    
-- Afficher les audits configurés
SELECT object_name, object_type, alt, aud, com, del, exe, gra, ind,
       ins, loc, ren, sel, upd
FROM dba_obj_audit_opts
WHERE owner = 'BANK_ADMIN';