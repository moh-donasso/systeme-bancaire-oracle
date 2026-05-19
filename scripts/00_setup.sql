
-- ============================================================
-- PROJET FIN DE MODULE : Système Bancaire Oracle
-- Script : 00_setup.sql
-- Description : Création de l'utilisateur/schéma principal
-- Auteur : Équipe X
-- Date : 2025-2026
-- ============================================================
-- CONNEXION INITIALE : se connecter en tant que SYSTEM ou SYS
-- Dans VS Code : utiliser la connexion oracle-docker (SYSTEM)
-- ============================================================

-- 1. Suppression de l'utilisateur s'il existe déjà (pour reset propre)
BEGIN
   EXECUTE IMMEDIATE 'DROP USER bank_admin CASCADE';
   DBMS_OUTPUT.PUT_LINE('Utilisateur bank_admin supprimé.');
EXCEPTION
   WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Utilisateur bank_admin inexistant, création en cours...');
END;
/

-- 2. Création de l'utilisateur principal (propriétaire du schéma)
CREATE USER bank_admin IDENTIFIED BY Admin1234
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

-- 3. Attribution des privilèges système nécessaires
GRANT CONNECT, RESOURCE, DBA TO bank_admin;
GRANT CREATE SESSION TO bank_admin;
GRANT CREATE TABLE TO bank_admin;
GRANT CREATE VIEW TO bank_admin;
GRANT CREATE SEQUENCE TO bank_admin;
GRANT CREATE PROCEDURE TO bank_admin;
GRANT CREATE TRIGGER TO bank_admin;
GRANT CREATE SYNONYM TO bank_admin;
GRANT CREATE PUBLIC SYNONYM TO bank_admin;
GRANT CREATE MATERIALIZED VIEW TO bank_admin;
GRANT UNLIMITED TABLESPACE TO bank_admin;

-- 4. Activer l'audit (nécessaire pour la section 3.4)
AUDIT CREATE SESSION BY bank_admin;

-- ============================================================
-- INSTRUCTIONS DE CONNEXION APRÈS CE SCRIPT :
-- Host     : localhost
-- Port     : 1521
-- Service  : XE
-- Username : bank_admin
-- Password : Admin1234
-- ============================================================

COMMIT;

SELECT 'Setup terminé. Connectez-vous maintenant avec bank_admin.' AS MESSAGE FROM DUAL;
