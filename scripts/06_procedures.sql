-- ============================================================
-- PROJET FIN DE MODULE : Système Bancaire Oracle
-- Script : 06_procedures.sql
-- Description : Procédures stockées avec gestion exceptions
-- Connexion : bank_admin
-- ============================================================

-- ============================================================
-- PROCÉDURE 1 : VALIDER_VIREMENT
-- Valide un virement entre deux comptes avec vérifications
-- Équivalent de "validation de commande" du sujet
-- ============================================================
CREATE OR REPLACE PROCEDURE valider_virement(
    p_id_compte_source  IN NUMBER,
    p_id_compte_dest    IN NUMBER,
    p_montant           IN NUMBER,
    p_motif             IN VARCHAR2 DEFAULT 'Virement bancaire'
)
AS
    v_solde_source      NUMBER;
    v_statut_source     VARCHAR2(20);
    v_statut_dest       VARCHAR2(20);
    v_id_virement       NUMBER;
    v_id_statut         NUMBER;
    v_plafond           NUMBER;

    -- Exceptions personnalisées
    ex_solde_insuffisant    EXCEPTION;
    ex_compte_bloque        EXCEPTION;
    ex_montant_invalide     EXCEPTION;
    ex_plafond_depasse      EXCEPTION;
BEGIN
    -- Vérification montant
    IF p_montant <= 0 THEN
        RAISE ex_montant_invalide;
    END IF;

    -- Vérification compte source
    BEGIN
        SELECT solde, statut, plafond_retrait
        INTO v_solde_source, v_statut_source, v_plafond
        FROM COMPTES
        WHERE id_compte = p_id_compte_source
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, -20001,
                   'Compte source introuvable : ' || p_id_compte_source,
                   'valider_virement');
            RAISE_APPLICATION_ERROR(-20001, 'Compte source introuvable.');
    END;

    -- Vérification compte destination
    BEGIN
        SELECT statut INTO v_statut_dest
        FROM COMPTES
        WHERE id_compte = p_id_compte_dest;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, -20002,
                   'Compte destination introuvable : ' || p_id_compte_dest,
                   'valider_virement');
            RAISE_APPLICATION_ERROR(-20002, 'Compte destination introuvable.');
    END;

    -- Vérification statuts
    IF v_statut_source != 'ACTIF' THEN
        RAISE ex_compte_bloque;
    END IF;

    IF v_statut_dest != 'ACTIF' THEN
        RAISE_APPLICATION_ERROR(-20003, 'Compte destination bloqué ou fermé.');
    END IF;

    -- Vérification solde suffisant
    IF v_solde_source < p_montant THEN
        RAISE ex_solde_insuffisant;
    END IF;

    -- Vérification plafond de retrait
    IF p_montant > v_plafond THEN
        RAISE ex_plafond_depasse;
    END IF;

    -- Récupérer statut "EN_COURS"
    SELECT id_statut INTO v_id_statut
    FROM STATUTS_VIREMENT WHERE libelle = 'EN_COURS';

    -- Créer le virement
    INSERT INTO VIREMENTS(
        id_virement, id_compte_source, id_compte_dest,
        montant, motif, id_statut, date_virement
    ) VALUES (
        seq_virements.NEXTVAL, p_id_compte_source, p_id_compte_dest,
        p_montant, p_motif, v_id_statut, SYSDATE
    ) RETURNING id_virement INTO v_id_virement;

    -- Débiter le compte source
    UPDATE COMPTES SET solde = solde - p_montant
    WHERE id_compte = p_id_compte_source;

    -- Créditer le compte destination
    UPDATE COMPTES SET solde = solde + p_montant
    WHERE id_compte = p_id_compte_dest;

    -- Enregistrer transactions
    INSERT INTO TRANSACTIONS(id_transaction, id_compte, type_transaction, montant, description)
    VALUES(seq_transactions.NEXTVAL, p_id_compte_source,
           'VIREMENT_SORTANT', p_montant, 'Virement #' || v_id_virement || ' - ' || p_motif);

    INSERT INTO TRANSACTIONS(id_transaction, id_compte, type_transaction, montant, description)
    VALUES(seq_transactions.NEXTVAL, p_id_compte_dest,
           'VIREMENT_ENTRANT', p_montant, 'Virement #' || v_id_virement || ' - ' || p_motif);

    -- Mettre à jour statut virement à VALIDE
    SELECT id_statut INTO v_id_statut
    FROM STATUTS_VIREMENT WHERE libelle = 'VALIDE';

    UPDATE VIREMENTS SET id_statut = v_id_statut
    WHERE id_virement = v_id_virement;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Virement #' || v_id_virement || ' validé avec succès. Montant : ' || p_montant);

EXCEPTION
    WHEN ex_solde_insuffisant THEN
        ROLLBACK;
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20004,
               'Solde insuffisant. Solde : ' || v_solde_source || ' Montant demandé : ' || p_montant,
               'valider_virement');
        COMMIT;
        RAISE_APPLICATION_ERROR(-20004, 'Solde insuffisant pour effectuer le virement.');

    WHEN ex_compte_bloque THEN
        ROLLBACK;
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20005, 'Compte source bloqué ou fermé.', 'valider_virement');
        COMMIT;
        RAISE_APPLICATION_ERROR(-20005, 'Compte source bloqué ou fermé.');

    WHEN ex_montant_invalide THEN
        ROLLBACK;
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20006, 'Montant invalide : ' || p_montant, 'valider_virement');
        COMMIT;
        RAISE_APPLICATION_ERROR(-20006, 'Le montant doit être supérieur à zéro.');

    WHEN ex_plafond_depasse THEN
        ROLLBACK;
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20007,
               'Plafond dépassé. Plafond : ' || v_plafond || ' Montant : ' || p_montant,
               'valider_virement');
        COMMIT;
        RAISE_APPLICATION_ERROR(-20007, 'Montant dépasse le plafond de retrait autorisé.');

    WHEN ZERO_DIVIDE THEN
        ROLLBACK;
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20008, 'Division par zéro.', 'valider_virement');
        COMMIT;
        RAISE_APPLICATION_ERROR(-20008, 'Erreur de calcul : division par zéro.');

    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20009, 'Doublon détecté.', 'valider_virement');
        COMMIT;
        RAISE_APPLICATION_ERROR(-20009, 'Erreur : enregistrement dupliqué.');

    WHEN OTHERS THEN
        ROLLBACK;
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, SQLCODE, SUBSTR(SQLERRM,1,200), 'valider_virement');
        COMMIT;
        RAISE;
END valider_virement;
/

-- ============================================================
-- PROCÉDURE 2 : ANNULER_VIREMENT
-- Annule un virement et restaure les soldes
-- Équivalent de "annulation de commande" du sujet
-- ============================================================
CREATE OR REPLACE PROCEDURE annuler_virement(
    p_id_virement   IN NUMBER,
    p_motif         IN VARCHAR2 DEFAULT 'Annulation client'
)
AS
    v_montant           NUMBER;
    v_id_compte_source  NUMBER;
    v_id_compte_dest    NUMBER;
    v_statut_libelle    VARCHAR2(50);
    v_id_statut_annule  NUMBER;

    ex_deja_annule      EXCEPTION;
    ex_non_annulable    EXCEPTION;
BEGIN
    -- Récupérer les infos du virement
    BEGIN
        SELECT v.montant, v.id_compte_source, v.id_compte_dest, s.libelle
        INTO v_montant, v_id_compte_source, v_id_compte_dest, v_statut_libelle
        FROM VIREMENTS v
        JOIN STATUTS_VIREMENT s ON v.id_statut = s.id_statut
        WHERE v.id_virement = p_id_virement;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, -20010,
                   'Virement introuvable : ' || p_id_virement, 'annuler_virement');
            COMMIT;
            RAISE_APPLICATION_ERROR(-20010, 'Virement introuvable.');
    END;

    -- Vérifier si déjà annulé
    IF v_statut_libelle = 'ANNULE' THEN
        RAISE ex_deja_annule;
    END IF;

    -- Vérifier si annulable (seulement EN_COURS ou VALIDE)
    IF v_statut_libelle NOT IN ('EN_COURS', 'VALIDE') THEN
        RAISE ex_non_annulable;
    END IF;

    -- Restaurer le solde source
    UPDATE COMPTES SET solde = solde + v_montant
    WHERE id_compte = v_id_compte_source;

    -- Débiter le compte destination
    UPDATE COMPTES SET solde = solde - v_montant
    WHERE id_compte = v_id_compte_dest;

    -- Mettre à jour le statut du virement
    SELECT id_statut INTO v_id_statut_annule
    FROM STATUTS_VIREMENT WHERE libelle = 'ANNULE';

    UPDATE VIREMENTS
    SET id_statut = v_id_statut_annule,
        motif = motif || ' | ANNULÉ : ' || p_motif
    WHERE id_virement = p_id_virement;

    -- Enregistrer les transactions d'annulation
    INSERT INTO TRANSACTIONS(id_transaction, id_compte, type_transaction, montant, description)
    VALUES(seq_transactions.NEXTVAL, v_id_compte_source,
           'VIREMENT_ENTRANT', v_montant,
           'Annulation virement #' || p_id_virement || ' - ' || p_motif);

    INSERT INTO TRANSACTIONS(id_transaction, id_compte, type_transaction, montant, description)
    VALUES(seq_transactions.NEXTVAL, v_id_compte_dest,
           'VIREMENT_SORTANT', v_montant,
           'Annulation virement #' || p_id_virement || ' - ' || p_motif);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Virement #' || p_id_virement || ' annulé. Soldes restaurés.');

EXCEPTION
    WHEN ex_deja_annule THEN
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20011,
               'Virement déjà annulé : ' || p_id_virement, 'annuler_virement');
        COMMIT;
        RAISE_APPLICATION_ERROR(-20011, 'Ce virement est déjà annulé.');

    WHEN ex_non_annulable THEN
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20012,
               'Virement non annulable, statut : ' || v_statut_libelle, 'annuler_virement');
        COMMIT;
        RAISE_APPLICATION_ERROR(-20012, 'Ce virement ne peut pas être annulé (statut : ' || v_statut_libelle || ').');

    WHEN OTHERS THEN
        ROLLBACK;
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, SQLCODE, SUBSTR(SQLERRM,1,200), 'annuler_virement');
        COMMIT;
        RAISE;
END annuler_virement;
/

-- ============================================================
-- PROCÉDURE 3 : OUVRIR_COMPTE
-- Crée un nouveau compte bancaire pour un client existant
-- ============================================================
CREATE OR REPLACE PROCEDURE ouvrir_compte(
    p_id_client     IN NUMBER,
    p_type_compte   IN VARCHAR2,
    p_solde_initial IN NUMBER DEFAULT 0,
    p_rib           IN VARCHAR2 DEFAULT NULL
)
AS
    v_id_compte     NUMBER;
    v_nb_comptes    NUMBER;
    v_statut_client VARCHAR2(20);

    ex_client_inactif   EXCEPTION;
    ex_type_invalide    EXCEPTION;
    ex_solde_negatif    EXCEPTION;
BEGIN
    -- Vérifications initiales
    IF p_solde_initial < 0 THEN
        RAISE ex_solde_negatif;
    END IF;

    IF p_type_compte NOT IN ('COURANT', 'EPARGNE') THEN
        RAISE ex_type_invalide;
    END IF;

    -- Vérifier que le client existe et est actif
    BEGIN
        SELECT statut INTO v_statut_client
        FROM CLIENTS WHERE id_client = p_id_client;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, -20013,
                   'Client introuvable : ' || p_id_client, 'ouvrir_compte');
            COMMIT;
            RAISE_APPLICATION_ERROR(-20013, 'Client introuvable.');
    END;

    IF v_statut_client != 'ACTIF' THEN
        RAISE ex_client_inactif;
    END IF;

    -- Vérifier le nombre de comptes existants
    SELECT COUNT(*) INTO v_nb_comptes
    FROM COMPTES
    WHERE id_client = p_id_client AND type_compte = p_type_compte AND statut = 'ACTIF';

    IF v_nb_comptes >= 3 THEN
        RAISE_APPLICATION_ERROR(-20014,
            'Un client ne peut pas avoir plus de 3 comptes du même type.');
    END IF;

    -- Créer le compte
    v_id_compte := seq_comptes.NEXTVAL;

    INSERT INTO COMPTES(
        id_compte, id_client, type_compte,
        solde, statut, date_ouverture, rib
    ) VALUES (
        v_id_compte, p_id_client, p_type_compte,
        p_solde_initial, 'ACTIF', SYSDATE,
        NVL(p_rib, 'RIB' || LPAD(v_id_compte, 10, '0'))
    );

    -- Enregistrer le dépôt initial si > 0
    IF p_solde_initial > 0 THEN
        INSERT INTO TRANSACTIONS(
            id_transaction, id_compte, type_transaction,
            montant, description
        ) VALUES (
            seq_transactions.NEXTVAL, v_id_compte,
            'DEPOT', p_solde_initial,
            'Dépôt initial à l ouverture du compte'
        );
    END IF;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Compte #' || v_id_compte ||
        ' (' || p_type_compte || ') ouvert pour client #' || p_id_client);

EXCEPTION
    WHEN ex_client_inactif THEN
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20015,
               'Client inactif : ' || p_id_client, 'ouvrir_compte');
        COMMIT;
        RAISE_APPLICATION_ERROR(-20015, 'Le client est inactif ou suspendu.');

    WHEN ex_type_invalide THEN
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20016,
               'Type de compte invalide : ' || p_type_compte, 'ouvrir_compte');
        COMMIT;
        RAISE_APPLICATION_ERROR(-20016, 'Type de compte invalide. Utilisez COURANT ou EPARGNE.');

    WHEN ex_solde_negatif THEN
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20017,
               'Solde initial négatif : ' || p_solde_initial, 'ouvrir_compte');
        COMMIT;
        RAISE_APPLICATION_ERROR(-20017, 'Le solde initial ne peut pas être négatif.');

    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, -20018, 'RIB déjà utilisé.', 'ouvrir_compte');
        COMMIT;
        RAISE_APPLICATION_ERROR(-20018, 'Ce RIB est déjà attribué à un autre compte.');

    WHEN OTHERS THEN
        ROLLBACK;
        INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
        VALUES(seq_error_log.NEXTVAL, SQLCODE, SUBSTR(SQLERRM,1,200), 'ouvrir_compte');
        COMMIT;
        RAISE;
END ouvrir_compte;
/

-- ============================================================
-- VÉRIFICATION
-- ============================================================
SELECT object_name, object_type, status
FROM user_objects
WHERE object_type = 'PROCEDURE'
ORDER BY object_name;