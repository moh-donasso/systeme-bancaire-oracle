-- ============================================================
-- PROJET FIN DE MODULE : Système Bancaire Oracle
-- Script : 05_synonyms.sql
-- Description : Synonymes privé et public
-- Connexion : bank_admin
-- ============================================================

-- ============================================================
-- 1. SYNONYMES PRIVÉS
--    Accessibles uniquement par bank_admin
--    Simplifient l'écriture des requêtes fréquentes
-- ============================================================

-- Synonyme privé pour vue_comptes_clients
CREATE OR REPLACE SYNONYM comptes_clients
FOR bank_admin.vue_comptes_clients;

-- Synonyme privé pour vue_stats_transactions
CREATE OR REPLACE SYNONYM stats_transactions
FOR bank_admin.vue_stats_transactions;

-- Synonyme privé pour vue_virements_statuts
CREATE OR REPLACE SYNONYM virements_detail
FOR bank_admin.vue_virements_statuts;

-- Synonyme privé pour mv_stats_mensuelles_virements
CREATE OR REPLACE SYNONYM stats_mensuelles
FOR bank_admin.mv_stats_mensuelles_virements;

-- ============================================================
-- 2. SYNONYMES PUBLICS
--    Accessibles par tous les utilisateurs de la base
--    Utiles pour les applications et autres schémas
--    Connexion requise : doit avoir CREATE PUBLIC SYNONYM
-- ============================================================

-- Synonyme public pour la table PRODUITS (COMPTES ici)
CREATE OR REPLACE PUBLIC SYNONYM pub_comptes
FOR bank_admin.COMPTES;

-- Synonyme public pour la vue comptes_clients
CREATE OR REPLACE PUBLIC SYNONYM pub_comptes_clients
FOR bank_admin.vue_comptes_clients;

-- ============================================================
-- VÉRIFICATION : synonymes privés
-- ============================================================
SELECT synonym_name, table_owner, table_name
FROM user_synonyms
ORDER BY synonym_name;

-- VÉRIFICATION : synonymes publics (nécessite droits DBA)
SELECT synonym_name, table_owner, table_name
FROM all_synonyms
WHERE owner = 'PUBLIC'
AND table_owner = 'BANK_ADMIN'
ORDER BY synonym_name;