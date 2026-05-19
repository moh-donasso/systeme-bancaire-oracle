-- ============================================================
-- PROJET FIN DE MODULE : Système Bancaire Oracle
-- Script : 07_functions.sql
-- Description : Fonctions stockées
-- Connexion : bank_admin
-- ============================================================

-- ============================================================
-- FONCTION 1 : CALCULER_TOTAL_COMPTE
-- Calcule le total des transactions d'un compte
-- sur une période donnée
-- Équivalent de "calcul total d'une commande" du sujet
-- ============================================================
CREATE OR REPLACE FUNCTION calculer_total_compte(
    p_id_compte     IN NUMBER,
    p_type          IN VARCHAR2 DEFAULT 'TOUS',
    p_date_debut    IN DATE DEFAULT NULL,
    p_date_fin      IN DATE DEFAULT NULL
) RETURN NUMBER
AS
    v_total         NUMBER := 0;
    v_nb_tx         NUMBER := 0;
    v_existe        NUMBER;
BEGIN
    -- Vérifier que le compte existe
    SELECT COUNT(*) INTO v_existe
    FROM COMPTES WHERE id_compte = p_id_compte;

    IF v_existe = 0 THEN
        RAISE_APPLICATION_ERROR(-20020, 'Compte introuvable : ' || p_id_compte);
    END IF;

    -- Calculer le total selon le type demandé
    IF p_type = 'TOUS' THEN
        SELECT NVL(SUM(montant), 0), COUNT(*)
        INTO v_total, v_nb_tx
        FROM TRANSACTIONS
        WHERE id_compte = p_id_compte
          AND statut = 'VALIDEE'
          AND (p_date_debut IS NULL OR date_transaction >= p_date_debut)
          AND (p_date_fin   IS NULL OR date_transaction <= p_date_fin);

    ELSIF p_type IN ('DEPOT','RETRAIT','VIREMENT_ENTRANT','VIREMENT_SORTANT','PAIEMENT') THEN
        SELECT NVL(SUM(montant), 0), COUNT(*)
        INTO v_total, v_nb_tx
        FROM TRANSACTIONS
        WHERE id_compte        = p_id_compte
          AND type_transaction = p_type
          AND statut           = 'VALIDEE'
          AND (p_date_debut IS NULL OR date_transaction >= p_date_debut)
          AND (p_date_fin   IS NULL OR date_transaction <= p_date_fin);

    ELSE
        RAISE_APPLICATION_ERROR(-20021,
            'Type invalide. Valeurs : TOUS, DEPOT, RETRAIT, VIREMENT_ENTRANT, VIREMENT_SORTANT, PAIEMENT');
    END IF;

    DBMS_OUTPUT.PUT_LINE('Compte #' || p_id_compte ||
        ' | Type : ' || p_type ||
        ' | Nb transactions : ' || v_nb_tx ||
        ' | Total : ' || v_total);

    RETURN v_total;

EXCEPTION
    WHEN ZERO_DIVIDE THEN
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20022, 'Division par zero.', 'calculer_total_compte');
        COMMIT;
        RETURN 0;

    WHEN NO_DATA_FOUND THEN
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20023,
               'Aucune transaction trouvee pour compte ' || TO_CHAR(p_id_compte),
               'calculer_total_compte');
        COMMIT;
        RETURN 0;

    WHEN OTHERS THEN
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, SQLCODE, SUBSTR(SQLERRM,1,200), 'calculer_total_compte');
        COMMIT;
        RETURN -1;
END calculer_total_compte;
/

-- ============================================================
-- FONCTION 2 : CALCULER_REMISE
-- Calcule une remise sur les frais bancaires selon
-- l'ancienneté du client et le montant total de ses opérations
-- Équivalent de "calcul d'une remise" du sujet
-- ============================================================
CREATE OR REPLACE FUNCTION calculer_remise(
    p_id_client IN NUMBER
) RETURN NUMBER
AS
    v_anciennete_mois   NUMBER;
    v_total_operations  NUMBER;
    v_remise            NUMBER := 0;
    v_nb_comptes        NUMBER;
    v_existe            NUMBER;
BEGIN
    -- Vérifier que le client existe
    SELECT COUNT(*) INTO v_existe
    FROM CLIENTS WHERE id_client = p_id_client;

    IF v_existe = 0 THEN
        RAISE_APPLICATION_ERROR(-20024, 'Client introuvable : ' || p_id_client);
    END IF;

    -- Calculer l'ancienneté en mois
    SELECT MONTHS_BETWEEN(SYSDATE, date_inscription)
    INTO v_anciennete_mois
    FROM CLIENTS
    WHERE id_client = p_id_client;

    -- Calculer le total des opérations du client
    SELECT NVL(SUM(t.montant), 0)
    INTO v_total_operations
    FROM TRANSACTIONS t
    JOIN COMPTES c ON t.id_compte = c.id_compte
    WHERE c.id_client = p_id_client
      AND t.statut = 'VALIDEE';

    -- Nombre de comptes actifs
    SELECT COUNT(*) INTO v_nb_comptes
    FROM COMPTES
    WHERE id_client = p_id_client AND statut = 'ACTIF';

    -- Règle de remise :
    -- Ancienneté < 6 mois  → 0%
    -- Ancienneté 6-12 mois → 5%
    -- Ancienneté 1-3 ans   → 10%
    -- Ancienneté > 3 ans   → 15%
    -- + Bonus 5% si total opérations > 100 000
    -- + Bonus 3% si client a plus de 2 comptes actifs

    IF v_anciennete_mois < 6 THEN
        v_remise := 0;
    ELSIF v_anciennete_mois BETWEEN 6 AND 12 THEN
        v_remise := 5;
    ELSIF v_anciennete_mois BETWEEN 13 AND 36 THEN
        v_remise := 10;
    ELSE
        v_remise := 15;
    END IF;

    -- Bonus montant
    IF v_total_operations > 100000 THEN
        v_remise := v_remise + 5;
    END IF;

    -- Bonus multi-comptes
    IF v_nb_comptes > 2 THEN
        v_remise := v_remise + 3;
    END IF;

    -- Plafond à 25%
    IF v_remise > 25 THEN
        v_remise := 25;
    END IF;

    DBMS_OUTPUT.PUT_LINE('Client #' || p_id_client ||
        ' | Ancienneté : ' || ROUND(v_anciennete_mois) || ' mois' ||
        ' | Total ops : ' || v_total_operations ||
        ' | Remise : ' || v_remise || '%');

    RETURN v_remise;

EXCEPTION
    WHEN ZERO_DIVIDE THEN
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20025, 'Division par zero.', 'calculer_remise');
        COMMIT;
        RETURN 0;

    WHEN NO_DATA_FOUND THEN
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20026,
               'Donnees introuvables pour client ' || TO_CHAR(p_id_client),
               'calculer_remise');
        COMMIT;
        RETURN 0;

    WHEN OTHERS THEN
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, SQLCODE, SUBSTR(SQLERRM,1,200), 'calculer_remise');
        COMMIT;
        RETURN -1;
END calculer_remise;
/

-- ============================================================
-- FONCTION 3 : COMPTE_DISPONIBLE
-- Vérifie si un compte est disponible pour une opération
-- Retourne : 'OUI' ou 'NON : <raison>'
-- Équivalent de "fonction de disponibilité produit" du sujet
-- ============================================================
CREATE OR REPLACE FUNCTION compte_disponible(
    p_id_compte IN NUMBER,
    p_montant   IN NUMBER DEFAULT 0
) RETURN VARCHAR2
AS
    v_statut        VARCHAR2(20);
    v_solde         NUMBER;
    v_plafond       NUMBER;
    v_type          VARCHAR2(20);
BEGIN
    -- Récupérer les infos du compte
    SELECT statut, solde, plafond_retrait, type_compte
    INTO v_statut, v_solde, v_plafond, v_type
    FROM COMPTES
    WHERE id_compte = p_id_compte;

    -- Vérifier le statut
    IF v_statut = 'FERME' THEN
        RETURN 'NON : compte fermé';
    END IF;

    IF v_statut = 'BLOQUE' THEN
        RETURN 'NON : compte bloqué';
    END IF;

    -- Vérifier le solde si montant demandé
    IF p_montant > 0 THEN
        IF v_solde < p_montant THEN
            RETURN 'NON : solde insuffisant (' || v_solde || ' disponible)';
        END IF;

        IF p_montant > v_plafond THEN
            RETURN 'NON : montant dépasse le plafond (' || v_plafond || ')';
        END IF;
    END IF;

    RETURN 'OUI';

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20027,
               'Compte introuvable ' || TO_CHAR(p_id_compte), 'compte_disponible');
        COMMIT;
        RETURN 'NON : compte introuvable';

    WHEN OTHERS THEN
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, SQLCODE, SUBSTR(SQLERRM,1,200), 'compte_disponible');
        COMMIT;
        RETURN 'NON : erreur systeme';
END compte_disponible;
/

-- ============================================================
-- VÉRIFICATION
-- ============================================================
SELECT object_name, object_type, status
FROM user_objects
WHERE object_type = 'FUNCTION'
ORDER BY object_name;