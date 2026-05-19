-- ============================================================
-- PROJET FIN DE MODULE : Système Bancaire Oracle
-- Script : 03_views.sql
-- Description : Vues simples, complexe et matérialisée
-- Connexion : bank_admin
-- ============================================================

-- ============================================================
-- 1. VUE SIMPLE : jointure de deux tables
--    Affiche les comptes avec les informations du client
-- ============================================================
CREATE OR REPLACE VIEW vue_comptes_clients AS
SELECT
    c.id_compte,
    c.type_compte,
    c.solde,
    c.statut,
    c.date_ouverture,
    c.rib,
    cl.id_client,
    cl.nom,
    cl.prenom,
    cl.email,
    cl.telephone
FROM COMPTES c
JOIN CLIENTS cl ON c.id_client = cl.id_client;

-- ============================================================
-- 2. VUE SIMPLE 2 : jointure virements + statuts
--    Affiche les virements avec leur statut lisible
-- ============================================================
CREATE OR REPLACE VIEW vue_virements_statuts AS
SELECT
    v.id_virement,
    v.montant,
    v.date_virement,
    v.motif,
    v.frais,
    s.libelle AS statut_libelle,
    v.id_compte_source,
    v.id_compte_dest
FROM VIREMENTS v
JOIN STATUTS_VIREMENT s ON v.id_statut = s.id_statut;

-- ============================================================
-- 3. VUE COMPLEXE : agrégation avec GROUP BY
--    Statistiques des transactions par compte et par type
-- ============================================================
CREATE OR REPLACE VIEW vue_stats_transactions AS
SELECT
    c.id_compte,
    cl.nom || ' ' || cl.prenom        AS client,
    c.type_compte,
    t.type_transaction,
    COUNT(t.id_transaction)           AS nombre_transactions,
    SUM(t.montant)                    AS montant_total,
    AVG(t.montant)                    AS montant_moyen,
    MAX(t.montant)                    AS montant_max,
    MIN(t.montant)                    AS montant_min,
    TRUNC(MIN(t.date_transaction))    AS premiere_transaction,
    TRUNC(MAX(t.date_transaction))    AS derniere_transaction
FROM TRANSACTIONS t
JOIN COMPTES c      ON t.id_compte = c.id_compte
JOIN CLIENTS cl     ON c.id_client = cl.id_client
GROUP BY
    c.id_compte,
    cl.nom,
    cl.prenom,
    c.type_compte,
    t.type_transaction;

-- ============================================================
-- 4. VUE MATÉRIALISÉE : statistiques mensuelles des virements
--    Méthode de rafraîchissement : ON DEMAND (REFRESH COMPLETE)
--    Justification : les statistiques mensuelles ne changent
--    pas en temps réel. Un rafraîchissement manuel périodique
--    (ex: chaque nuit) est suffisant et évite la surcharge
--    de ON COMMIT qui recalcule à chaque transaction.
-- ============================================================
CREATE MATERIALIZED VIEW mv_stats_mensuelles_virements
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    EXTRACT(YEAR  FROM date_virement)   AS annee,
    EXTRACT(MONTH FROM date_virement)   AS mois,
    id_statut,
    COUNT(*)                            AS nombre_virements,
    SUM(montant)                        AS montant_total,
    AVG(montant)                        AS montant_moyen,
    MAX(montant)                        AS montant_max,
    SUM(frais)                          AS frais_total
FROM VIREMENTS
GROUP BY
    EXTRACT(YEAR  FROM date_virement),
    EXTRACT(MONTH FROM date_virement),
    id_statut;

-- Rafraîchir manuellement la vue matérialisée :
-- EXEC DBMS_MVIEW.REFRESH('mv_stats_mensuelles_virements', 'C');

-- ============================================================
-- VÉRIFICATION
-- ============================================================
SELECT object_name, object_type
FROM user_objects
WHERE object_type IN ('VIEW', 'MATERIALIZED VIEW')
ORDER BY object_type, object_name;