-- ============================================================
-- PROJET FIN DE MODULE : Système Bancaire Oracle
-- Script : 12_explain_plan.sql
-- Description : EXPLAIN PLAN avant/après index
-- Connexion : bank_admin
-- Exigence : réduction d'au moins 50% du COST
-- ============================================================

-- ============================================================
-- REQUÊTE CRITIQUE TESTÉE :
-- Recherche des transactions d'un client sur une période
-- C'est la requête la plus fréquente dans un système bancaire
-- ============================================================

-- ============================================================
-- ÉTAPE 1 : SUPPRIMER TEMPORAIREMENT LES INDEX
-- pour simuler l'état "sans index"
-- ============================================================
DROP INDEX idx_btree_tx_compte;
DROP INDEX idx_btree_tx_date;
DROP INDEX idx_btree_comptes_client;

-- ============================================================
-- ÉTAPE 2 : EXPLAIN PLAN SANS INDEX
-- ============================================================
EXPLAIN PLAN FOR
SELECT
    t.id_transaction,
    t.type_transaction,
    t.montant,
    t.date_transaction,
    t.description,
    c.id_compte,
    c.type_compte,
    cl.nom,
    cl.prenom
FROM TRANSACTIONS t
JOIN COMPTES c  ON t.id_compte  = c.id_compte
JOIN CLIENTS cl ON c.id_client  = cl.id_client
WHERE cl.id_client       = 1
  AND t.date_transaction >= DATE '2024-01-01'
  AND t.date_transaction <= DATE '2024-12-31'
  AND t.statut           = 'VALIDEE'
ORDER BY t.date_transaction DESC;

-- Afficher le plan SANS index
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    format => 'TYPICAL +COST +ROWS +BYTES'
));

-- ============================================================
-- ÉTAPE 3 : RECRÉER LES INDEX
-- ============================================================
CREATE INDEX idx_btree_tx_compte
ON TRANSACTIONS(id_compte);

CREATE INDEX idx_btree_tx_date
ON TRANSACTIONS(date_transaction);

CREATE INDEX idx_btree_comptes_client
ON COMPTES(id_client);

-- Index composite pour optimisation maximale
CREATE INDEX idx_btree_tx_compte_date
ON TRANSACTIONS(id_compte, date_transaction, statut);

-- Mettre à jour les statistiques
EXEC DBMS_STATS.GATHER_TABLE_STATS('BANK_ADMIN', 'TRANSACTIONS');
EXEC DBMS_STATS.GATHER_TABLE_STATS('BANK_ADMIN', 'COMPTES');
EXEC DBMS_STATS.GATHER_TABLE_STATS('BANK_ADMIN', 'CLIENTS');

-- ============================================================
-- ÉTAPE 4 : EXPLAIN PLAN AVEC INDEX
-- ============================================================
EXPLAIN PLAN FOR
SELECT
    t.id_transaction,
    t.type_transaction,
    t.montant,
    t.date_transaction,
    t.description,
    c.id_compte,
    c.type_compte,
    cl.nom,
    cl.prenom
FROM TRANSACTIONS t
JOIN COMPTES c  ON t.id_compte  = c.id_compte
JOIN CLIENTS cl ON c.id_client  = cl.id_client
WHERE cl.id_client       = 1
  AND t.date_transaction >= DATE '2024-01-01'
  AND t.date_transaction <= DATE '2024-12-31'
  AND t.statut           = 'VALIDEE'
ORDER BY t.date_transaction DESC;

-- Afficher le plan AVEC index
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    format => 'TYPICAL +COST +ROWS +BYTES'
));

-- ============================================================
-- ÉTAPE 5 : TEST AVEC HINT POUR FORCER LE FULL SCAN
-- (pour comparaison explicite dans le rapport)
-- ============================================================
EXPLAIN PLAN FOR
SELECT /*+ FULL(t) FULL(c) FULL(cl) */
    t.id_transaction,
    t.type_transaction,
    t.montant,
    t.date_transaction,
    cl.nom,
    cl.prenom
FROM TRANSACTIONS t
JOIN COMPTES c  ON t.id_compte = c.id_compte
JOIN CLIENTS cl ON c.id_client = cl.id_client
WHERE cl.id_client = 1
  AND t.statut     = 'VALIDEE';

SELECT '=== PLAN FULL SCAN (SANS INDEX) ===' AS info FROM DUAL;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    format => 'TYPICAL +COST +ROWS +BYTES'
));

-- Plan avec index
EXPLAIN PLAN FOR
SELECT /*+ INDEX(t idx_btree_tx_compte_date) INDEX(c idx_btree_comptes_client) */
    t.id_transaction,
    t.type_transaction,
    t.montant,
    t.date_transaction,
    cl.nom,
    cl.prenom
FROM TRANSACTIONS t
JOIN COMPTES c  ON t.id_compte = c.id_compte
JOIN CLIENTS cl ON c.id_client = cl.id_client
WHERE cl.id_client = 1
  AND t.statut     = 'VALIDEE';

SELECT '=== PLAN AVEC INDEX ===' AS info FROM DUAL;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    format => 'TYPICAL +COST +ROWS +BYTES'
));

-- ============================================================
-- ÉTAPE 6 : DÉMONSTRATION VUE MATÉRIALISÉE
-- Comparer requête directe vs vue matérialisée
-- ============================================================

-- Requête sans vue matérialisée (calcul en temps réel)
EXPLAIN PLAN FOR
SELECT
    EXTRACT(YEAR  FROM date_virement) AS annee,
    EXTRACT(MONTH FROM date_virement) AS mois,
    COUNT(*)                          AS nb_virements,
    SUM(montant)                      AS total
FROM VIREMENTS
GROUP BY
    EXTRACT(YEAR  FROM date_virement),
    EXTRACT(MONTH FROM date_virement);

SELECT '=== REQUETE DIRECTE SANS VUE MATERIALISEE ===' AS info FROM DUAL;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    format => 'TYPICAL +COST +ROWS +BYTES'
));

-- Requête via vue matérialisée (données précalculées)
EXEC DBMS_MVIEW.REFRESH('mv_stats_mensuelles_virements', 'C');

EXPLAIN PLAN FOR
SELECT annee, mois, nombre_virements, montant_total
FROM mv_stats_mensuelles_virements
ORDER BY annee, mois;

SELECT '=== REQUETE VIA VUE MATERIALISEE ===' AS info FROM DUAL;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    format => 'TYPICAL +COST +ROWS +BYTES'
));

-- ============================================================
-- RÉSUMÉ DES INDEX CRÉÉS
-- ============================================================
SELECT index_name, index_type, table_name, uniqueness
FROM user_indexes
ORDER BY table_name, index_name;