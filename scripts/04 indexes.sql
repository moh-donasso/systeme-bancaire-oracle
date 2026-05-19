-- ============================================================
-- PROJET FIN DE MODULE : Système Bancaire Oracle
-- Script : 04_indexes.sql
-- Description : Index B-TREE, BITMAP et fonctionnel
-- Connexion : bank_admin
-- ============================================================

-- ============================================================
-- 1. INDEX B-TREE : colonnes de recherche fréquente
--    Justification : utilisés pour les recherches par égalité
--    et par plage sur des colonnes à haute cardinalité
-- ============================================================

-- Recherche des transactions par compte
CREATE INDEX idx_btree_tx_compte
ON TRANSACTIONS(id_compte);

-- Recherche des virements par date
CREATE INDEX idx_btree_vir_date
ON VIREMENTS(date_virement);

-- Recherche des comptes par client
CREATE INDEX idx_btree_comptes_client
ON COMPTES(id_client);

-- Recherche des crédits par client
CREATE INDEX idx_btree_credits_client
ON CREDITS(id_client);

-- Recherche des transactions par date
CREATE INDEX idx_btree_tx_date
ON TRANSACTIONS(date_transaction);

-- Recherche des virements par compte source
CREATE INDEX idx_btree_vir_source
ON VIREMENTS(id_compte_source);

-- ============================================================
-- 2. INDEX BITMAP : colonnes à faible cardinalité
--    Justification : colonnes STATUT et TYPE_COMPTE ont peu
--    de valeurs distinctes (3 à 5 valeurs). Les index BITMAP
--    sont efficaces pour les requêtes analytiques avec WHERE
--    sur ces colonnes. La faible fréquence de mise à jour
--    (statut change rarement) justifie ce choix car les
--    BITMAP sont coûteux en écriture mais très rapides en lecture.
-- ============================================================

-- Statut des comptes (ACTIF / BLOQUE / FERME)
CREATE BITMAP INDEX idx_bitmap_comptes_statut
ON COMPTES(statut);

-- Type de compte (COURANT / EPARGNE)
CREATE BITMAP INDEX idx_bitmap_comptes_type
ON COMPTES(type_compte);

-- Statut des transactions (VALIDEE / EN_ATTENTE / REJETEE)
CREATE BITMAP INDEX idx_bitmap_tx_statut
ON TRANSACTIONS(statut);

-- Statut des virements
CREATE BITMAP INDEX idx_bitmap_vir_statut
ON VIREMENTS(id_statut);

-- ============================================================
-- 3. INDEX FONCTIONNEL : UPPER(nom) pour recherche insensible
--    à la casse sur la table CLIENTS
--    Justification : les recherches par nom sont souvent
--    faites sans respect de la casse (ex: WHERE UPPER(nom)
--    = UPPER('dupont')). Sans cet index, Oracle fait un
--    full table scan. Avec l'index fonctionnel, la recherche
--    est directe même sur UPPER(nom).
-- ============================================================

-- Index fonctionnel sur UPPER(nom) des clients
CREATE INDEX idx_func_clients_nom
ON CLIENTS(UPPER(nom));

-- Index fonctionnel sur UPPER(prenom) des clients
CREATE INDEX idx_func_clients_prenom
ON CLIENTS(UPPER(prenom));

-- Index fonctionnel sur UPPER(email) des clients
CREATE INDEX idx_func_clients_email
ON CLIENTS(UPPER(email));

-- ============================================================
-- 4. MISE À JOUR DES STATISTIQUES
--    Nécessaire pour que l'optimiseur Oracle utilise
--    correctement les index dans les plans d'exécution
-- ============================================================
EXEC DBMS_STATS.GATHER_TABLE_STATS('BANK_ADMIN', 'TRANSACTIONS');
EXEC DBMS_STATS.GATHER_TABLE_STATS('BANK_ADMIN', 'VIREMENTS');
EXEC DBMS_STATS.GATHER_TABLE_STATS('BANK_ADMIN', 'COMPTES');
EXEC DBMS_STATS.GATHER_TABLE_STATS('BANK_ADMIN', 'CLIENTS');
EXEC DBMS_STATS.GATHER_TABLE_STATS('BANK_ADMIN', 'CREDITS');

-- ============================================================
-- VÉRIFICATION : afficher tous les index créés
-- ============================================================
SELECT
    index_name,
    index_type,
    table_name,
    uniqueness
FROM user_indexes
ORDER BY index_type, table_name;