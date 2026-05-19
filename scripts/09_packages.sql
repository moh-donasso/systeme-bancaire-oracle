-- ============================================================
-- PROJET FIN DE MODULE : Système Bancaire Oracle
-- Script : 09_packages.sql
-- Description : Package PKG_VIREMENTS (spécification + corps)
-- Connexion : bank_admin
-- ============================================================

-- ============================================================
-- PARTIE 1 : SPÉCIFICATION DU PACKAGE
-- Déclare les procédures et fonctions publiques
-- ============================================================
CREATE OR REPLACE PACKAGE pkg_virements AS

    -- Constantes métier
    C_SEUIL_FRAUDE      CONSTANT NUMBER := 10000;
    C_PLAFOND_DEFAUT    CONSTANT NUMBER := 5000;
    C_MAX_TX_HEURE      CONSTANT NUMBER := 5;

    -- Procédures
    PROCEDURE valider_virement(
        p_id_compte_source  IN NUMBER,
        p_id_compte_dest    IN NUMBER,
        p_montant           IN NUMBER,
        p_motif             IN VARCHAR2 DEFAULT 'Virement bancaire'
    );

    PROCEDURE annuler_virement(
        p_id_virement   IN NUMBER,
        p_motif         IN VARCHAR2 DEFAULT 'Annulation client'
    );

    PROCEDURE ouvrir_compte(
        p_id_client     IN NUMBER,
        p_type_compte   IN VARCHAR2,
        p_solde_initial IN NUMBER DEFAULT 0,
        p_rib           IN VARCHAR2 DEFAULT NULL
    );

    -- Fonctions
    FUNCTION calculer_total_compte(
        p_id_compte     IN NUMBER,
        p_type          IN VARCHAR2 DEFAULT 'TOUS',
        p_date_debut    IN DATE DEFAULT NULL,
        p_date_fin      IN DATE DEFAULT NULL
    ) RETURN NUMBER;

    FUNCTION calculer_remise(
        p_id_client IN NUMBER
    ) RETURN NUMBER;

    FUNCTION compte_disponible(
        p_id_compte IN NUMBER,
        p_montant   IN NUMBER DEFAULT 0
    ) RETURN VARCHAR2;

    FUNCTION get_solde(
        p_id_compte IN NUMBER
    ) RETURN NUMBER;

END pkg_virements;
/

-- ============================================================
-- PARTIE 2 : CORPS DU PACKAGE
-- Implémentation de toutes les procédures et fonctions
-- ============================================================
CREATE OR REPLACE PACKAGE BODY pkg_virements AS

    -- --------------------------------------------------------
    -- PROCÉDURE : VALIDER_VIREMENT
    -- --------------------------------------------------------
    PROCEDURE valider_virement(
        p_id_compte_source  IN NUMBER,
        p_id_compte_dest    IN NUMBER,
        p_montant           IN NUMBER,
        p_motif             IN VARCHAR2 DEFAULT 'Virement bancaire'
    ) AS
        v_solde_source      NUMBER;
        v_statut_source     VARCHAR2(20);
        v_statut_dest       VARCHAR2(20);
        v_id_virement       NUMBER;
        v_id_statut         NUMBER;
        v_plafond           NUMBER;
        v_err               VARCHAR2(200);
        v_motif             VARCHAR2(300);

        ex_solde_insuffisant    EXCEPTION;
        ex_compte_bloque        EXCEPTION;
        ex_montant_invalide     EXCEPTION;
        ex_plafond_depasse      EXCEPTION;
    BEGIN
        v_motif := p_motif;
        IF p_montant <= 0 THEN RAISE ex_montant_invalide; END IF;

        BEGIN
            SELECT solde, statut, plafond_retrait
            INTO v_solde_source, v_statut_source, v_plafond
            FROM COMPTES WHERE id_compte = p_id_compte_source FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
                VALUES(seq_error_log.NEXTVAL, -20001,
                       'Compte source introuvable',
                       'pkg_virements.valider_virement');
                RAISE_APPLICATION_ERROR(-20001, 'Compte source introuvable.');
        END;

        BEGIN
            SELECT statut INTO v_statut_dest
            FROM COMPTES WHERE id_compte = p_id_compte_dest;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
                VALUES(seq_error_log.NEXTVAL, -20002,
                       'Compte destination introuvable',
                       'pkg_virements.valider_virement');
                RAISE_APPLICATION_ERROR(-20002, 'Compte destination introuvable.');
        END;

        IF v_statut_source != 'ACTIF' THEN RAISE ex_compte_bloque; END IF;
        IF v_statut_dest   != 'ACTIF' THEN
            RAISE_APPLICATION_ERROR(-20003, 'Compte destination indisponible.');
        END IF;
        IF v_solde_source < p_montant  THEN RAISE ex_solde_insuffisant; END IF;
        IF p_montant > v_plafond       THEN RAISE ex_plafond_depasse;   END IF;

        SELECT id_statut INTO v_id_statut
        FROM STATUTS_VIREMENT WHERE libelle = 'EN_COURS';

        INSERT INTO VIREMENTS(
            id_virement, id_compte_source, id_compte_dest,
            montant, motif, id_statut, date_virement
        ) VALUES (
            seq_virements.NEXTVAL, p_id_compte_source, p_id_compte_dest,
            p_montant, v_motif, v_id_statut, SYSDATE
        ) RETURNING id_virement INTO v_id_virement;

        UPDATE COMPTES SET solde = solde - p_montant WHERE id_compte = p_id_compte_source;
        UPDATE COMPTES SET solde = solde + p_montant WHERE id_compte = p_id_compte_dest;

        INSERT INTO TRANSACTIONS(id_transaction, id_compte, type_transaction, montant, description)
        VALUES(seq_transactions.NEXTVAL, p_id_compte_source, 'VIREMENT_SORTANT',
               p_montant, 'Virement #' || v_id_virement || ' - ' || v_motif);

        INSERT INTO TRANSACTIONS(id_transaction, id_compte, type_transaction, montant, description)
        VALUES(seq_transactions.NEXTVAL, p_id_compte_dest, 'VIREMENT_ENTRANT',
               p_montant, 'Virement #' || v_id_virement || ' - ' || v_motif);

        SELECT id_statut INTO v_id_statut FROM STATUTS_VIREMENT WHERE libelle = 'VALIDE';
        UPDATE VIREMENTS SET id_statut = v_id_statut WHERE id_virement = v_id_virement;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Virement #' || v_id_virement || ' valide. Montant : ' || p_montant);

    EXCEPTION
        WHEN ex_solde_insuffisant THEN
            ROLLBACK;
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, -20004,
                   'Solde insuffisant',
                   'pkg_virements.valider_virement');
            COMMIT;
            RAISE_APPLICATION_ERROR(-20004, 'Solde insuffisant.');
        WHEN ex_compte_bloque THEN
            ROLLBACK;
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, -20005, 'Compte source bloque.',
                   'pkg_virements.valider_virement');
            COMMIT;
            RAISE_APPLICATION_ERROR(-20005, 'Compte source bloque.');
        WHEN ex_montant_invalide THEN
            ROLLBACK;
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, -20006,
                   'Montant invalide',
                   'pkg_virements.valider_virement');
            COMMIT;
            RAISE_APPLICATION_ERROR(-20006, 'Montant invalide.');
        WHEN ex_plafond_depasse THEN
            ROLLBACK;
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, -20007,
                   'Plafond depasse',
                   'pkg_virements.valider_virement');
            COMMIT;
            RAISE_APPLICATION_ERROR(-20007, 'Plafond de retrait depasse.');
        WHEN OTHERS THEN
            ROLLBACK;
            v_err := SUBSTR(SQLERRM, 1, 200);
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, SQLCODE, v_err,
                   'pkg_virements.valider_virement');
            COMMIT;
            RAISE;
    END valider_virement;

    -- --------------------------------------------------------
    -- PROCÉDURE : ANNULER_VIREMENT
    -- --------------------------------------------------------
    PROCEDURE annuler_virement(
        p_id_virement   IN NUMBER,
        p_motif         IN VARCHAR2 DEFAULT 'Annulation client'
    ) AS
        v_montant           NUMBER;
        v_id_compte_source  NUMBER;
        v_id_compte_dest    NUMBER;
        v_statut_libelle    VARCHAR2(50);
        v_id_statut_annule  NUMBER;
        v_err               VARCHAR2(200);
        v_motif_local       VARCHAR2(300);
        ex_deja_annule      EXCEPTION;
        ex_non_annulable    EXCEPTION;
    BEGIN
        v_motif_local := p_motif;
        BEGIN
            SELECT v.montant, v.id_compte_source, v.id_compte_dest, s.libelle
            INTO v_montant, v_id_compte_source, v_id_compte_dest, v_statut_libelle
            FROM VIREMENTS v JOIN STATUTS_VIREMENT s ON v.id_statut = s.id_statut
            WHERE v.id_virement = p_id_virement;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
                VALUES(seq_error_log.NEXTVAL, -20010,
                       'Virement introuvable',
                       'pkg_virements.annuler_virement');
                COMMIT;
                RAISE_APPLICATION_ERROR(-20010, 'Virement introuvable.');
        END;

        IF v_statut_libelle = 'ANNULE' THEN RAISE ex_deja_annule; END IF;
        IF v_statut_libelle NOT IN ('EN_COURS','VALIDE') THEN RAISE ex_non_annulable; END IF;

        UPDATE COMPTES SET solde = solde + v_montant WHERE id_compte = v_id_compte_source;
        UPDATE COMPTES SET solde = solde - v_montant WHERE id_compte = v_id_compte_dest;

        SELECT id_statut INTO v_id_statut_annule
        FROM STATUTS_VIREMENT WHERE libelle = 'ANNULE';

        UPDATE VIREMENTS SET id_statut = v_id_statut_annule
        WHERE id_virement = p_id_virement;

        INSERT INTO TRANSACTIONS(id_transaction, id_compte, type_transaction, montant, description)
        VALUES(seq_transactions.NEXTVAL, v_id_compte_source, 'VIREMENT_ENTRANT',
               v_montant, 'Annulation virement #' || p_id_virement);
        INSERT INTO TRANSACTIONS(id_transaction, id_compte, type_transaction, montant, description)
        VALUES(seq_transactions.NEXTVAL, v_id_compte_dest, 'VIREMENT_SORTANT',
               v_montant, 'Annulation virement #' || p_id_virement);

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Virement #' || p_id_virement || ' annule.');

    EXCEPTION
        WHEN ex_deja_annule THEN
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, -20011,
                   'Virement deja annule',
                   'pkg_virements.annuler_virement');
            COMMIT;
            RAISE_APPLICATION_ERROR(-20011, 'Virement deja annule.');
        WHEN ex_non_annulable THEN
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, -20012,
                   'Statut non annulable',
                   'pkg_virements.annuler_virement');
            COMMIT;
            RAISE_APPLICATION_ERROR(-20012, 'Virement non annulable.');
        WHEN OTHERS THEN
            ROLLBACK;
            v_err := SUBSTR(SQLERRM, 1, 200);
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, SQLCODE, v_err,
                   'pkg_virements.annuler_virement');
            COMMIT;
            RAISE;
    END annuler_virement;

    -- --------------------------------------------------------
    -- PROCÉDURE : OUVRIR_COMPTE
    -- --------------------------------------------------------
    PROCEDURE ouvrir_compte(
        p_id_client     IN NUMBER,
        p_type_compte   IN VARCHAR2,
        p_solde_initial IN NUMBER DEFAULT 0,
        p_rib           IN VARCHAR2 DEFAULT NULL
    ) AS
        v_id_compte     NUMBER;
        v_nb_comptes    NUMBER;
        v_statut_client VARCHAR2(20);
        v_err           VARCHAR2(200);
        v_type_local    VARCHAR2(20);
        ex_client_inactif   EXCEPTION;
        ex_type_invalide    EXCEPTION;
        ex_solde_negatif    EXCEPTION;
    BEGIN
        v_type_local := p_type_compte;
        IF p_solde_initial < 0 THEN RAISE ex_solde_negatif; END IF;
        IF p_type_compte NOT IN ('COURANT','EPARGNE') THEN RAISE ex_type_invalide; END IF;

        BEGIN
            SELECT statut INTO v_statut_client
            FROM CLIENTS WHERE id_client = p_id_client;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
                VALUES(seq_error_log.NEXTVAL, -20013,
                       'Client introuvable',
                       'pkg_virements.ouvrir_compte');
                COMMIT;
                RAISE_APPLICATION_ERROR(-20013, 'Client introuvable.');
        END;

        IF v_statut_client != 'ACTIF' THEN RAISE ex_client_inactif; END IF;

        SELECT COUNT(*) INTO v_nb_comptes FROM COMPTES
        WHERE id_client = p_id_client AND type_compte = p_type_compte AND statut = 'ACTIF';

        IF v_nb_comptes >= 3 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Maximum 3 comptes du meme type.');
        END IF;

        v_id_compte := seq_comptes.NEXTVAL;
        INSERT INTO COMPTES(id_compte, id_client, type_compte, solde, statut, date_ouverture, rib)
        VALUES(v_id_compte, p_id_client, v_type_local, p_solde_initial, 'ACTIF', SYSDATE,
               NVL(p_rib, 'RIB' || LPAD(v_id_compte, 10, '0')));

        IF p_solde_initial > 0 THEN
            INSERT INTO TRANSACTIONS(id_transaction, id_compte, type_transaction, montant, description)
            VALUES(seq_transactions.NEXTVAL, v_id_compte, 'DEPOT',
                   p_solde_initial, 'Depot initial ouverture compte');
        END IF;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Compte #' || v_id_compte || ' ouvert.');

    EXCEPTION
        WHEN ex_client_inactif THEN
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, -20015,
                   'Client inactif',
                   'pkg_virements.ouvrir_compte');
            COMMIT;
            RAISE_APPLICATION_ERROR(-20015, 'Client inactif.');
        WHEN ex_type_invalide THEN
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, -20016, 'Type de compte invalide',
                   'pkg_virements.ouvrir_compte');
            COMMIT;
            RAISE_APPLICATION_ERROR(-20016, 'Type de compte invalide.');
        WHEN ex_solde_negatif THEN
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, -20017,
                   'Solde initial negatif',
                   'pkg_virements.ouvrir_compte');
            COMMIT;
            RAISE_APPLICATION_ERROR(-20017, 'Solde initial negatif.');
        WHEN DUP_VAL_ON_INDEX THEN
            ROLLBACK;
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, -20018, 'RIB deja utilise.',
                   'pkg_virements.ouvrir_compte');
            COMMIT;
            RAISE_APPLICATION_ERROR(-20018, 'RIB deja attribue.');
        WHEN OTHERS THEN
            ROLLBACK;
            v_err := SUBSTR(SQLERRM, 1, 200);
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, SQLCODE, v_err,
                   'pkg_virements.ouvrir_compte');
            COMMIT;
            RAISE;
    END ouvrir_compte;

    -- --------------------------------------------------------
    -- FONCTION : CALCULER_TOTAL_COMPTE
    -- --------------------------------------------------------
    FUNCTION calculer_total_compte(
        p_id_compte     IN NUMBER,
        p_type          IN VARCHAR2 DEFAULT 'TOUS',
        p_date_debut    IN DATE DEFAULT NULL,
        p_date_fin      IN DATE DEFAULT NULL
    ) RETURN NUMBER AS
        v_total     NUMBER := 0;
        v_existe    NUMBER;
        v_err       VARCHAR2(200);
    BEGIN
        SELECT COUNT(*) INTO v_existe FROM COMPTES WHERE id_compte = p_id_compte;
        IF v_existe = 0 THEN
            RAISE_APPLICATION_ERROR(-20020, 'Compte introuvable ' || TO_CHAR(p_id_compte));
        END IF;

        IF p_type = 'TOUS' THEN
            SELECT NVL(SUM(montant), 0) INTO v_total FROM TRANSACTIONS
            WHERE id_compte = p_id_compte AND statut = 'VALIDEE'
              AND (p_date_debut IS NULL OR date_transaction >= p_date_debut)
              AND (p_date_fin   IS NULL OR date_transaction <= p_date_fin);
        ELSE
            SELECT NVL(SUM(montant), 0) INTO v_total FROM TRANSACTIONS
            WHERE id_compte = p_id_compte AND type_transaction = p_type
              AND statut = 'VALIDEE'
              AND (p_date_debut IS NULL OR date_transaction >= p_date_debut)
              AND (p_date_fin   IS NULL OR date_transaction <= p_date_fin);
        END IF;

        RETURN v_total;
    EXCEPTION
        WHEN OTHERS THEN
            v_err := SUBSTR(SQLERRM, 1, 200);
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, SQLCODE, v_err,
                   'pkg_virements.calculer_total_compte');
            COMMIT;
            RETURN -1;
    END calculer_total_compte;

    -- --------------------------------------------------------
    -- FONCTION : CALCULER_REMISE
    -- --------------------------------------------------------
    FUNCTION calculer_remise(
        p_id_client IN NUMBER
    ) RETURN NUMBER AS
        v_anciennete_mois   NUMBER;
        v_total_operations  NUMBER;
        v_remise            NUMBER := 0;
        v_nb_comptes        NUMBER;
        v_existe            NUMBER;
        v_err               VARCHAR2(200);
    BEGIN
        SELECT COUNT(*) INTO v_existe FROM CLIENTS WHERE id_client = p_id_client;
        IF v_existe = 0 THEN
            RAISE_APPLICATION_ERROR(-20024, 'Client introuvable ' || TO_CHAR(p_id_client));
        END IF;

        SELECT MONTHS_BETWEEN(SYSDATE, date_inscription) INTO v_anciennete_mois
        FROM CLIENTS WHERE id_client = p_id_client;

        SELECT NVL(SUM(t.montant), 0) INTO v_total_operations
        FROM TRANSACTIONS t JOIN COMPTES c ON t.id_compte = c.id_compte
        WHERE c.id_client = p_id_client AND t.statut = 'VALIDEE';

        SELECT COUNT(*) INTO v_nb_comptes FROM COMPTES
        WHERE id_client = p_id_client AND statut = 'ACTIF';

        IF    v_anciennete_mois < 6           THEN v_remise := 0;
        ELSIF v_anciennete_mois BETWEEN 6 AND 12  THEN v_remise := 5;
        ELSIF v_anciennete_mois BETWEEN 13 AND 36 THEN v_remise := 10;
        ELSE  v_remise := 15;
        END IF;

        IF v_total_operations > 100000 THEN v_remise := v_remise + 5; END IF;
        IF v_nb_comptes > 2            THEN v_remise := v_remise + 3; END IF;
        IF v_remise > 25               THEN v_remise := 25;           END IF;

        RETURN v_remise;
    EXCEPTION
        WHEN OTHERS THEN
            v_err := SUBSTR(SQLERRM, 1, 200);
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, SQLCODE, v_err, 'pkg_virements.calculer_remise');
            COMMIT;
            RETURN -1;
    END calculer_remise;

    -- --------------------------------------------------------
    -- FONCTION : COMPTE_DISPONIBLE
    -- --------------------------------------------------------
    FUNCTION compte_disponible(
        p_id_compte IN NUMBER,
        p_montant   IN NUMBER DEFAULT 0
    ) RETURN VARCHAR2 AS
        v_statut    VARCHAR2(20);
        v_solde     NUMBER;
        v_plafond   NUMBER;
        v_err       VARCHAR2(200);
    BEGIN
        SELECT statut, solde, plafond_retrait
        INTO v_statut, v_solde, v_plafond
        FROM COMPTES WHERE id_compte = p_id_compte;

        IF v_statut = 'FERME'  THEN RETURN 'NON : compte ferme';   END IF;
        IF v_statut = 'BLOQUE' THEN RETURN 'NON : compte bloque';  END IF;
        IF p_montant > 0 THEN
            IF v_solde   < p_montant THEN RETURN 'NON : solde insuffisant ' || TO_CHAR(v_solde); END IF;
            IF p_montant > v_plafond THEN RETURN 'NON : plafond depasse '   || TO_CHAR(v_plafond); END IF;
        END IF;
        RETURN 'OUI';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'NON : compte introuvable';
        WHEN OTHERS THEN
            v_err := SUBSTR(SQLERRM, 1, 200);
            INSERT INTO ERROR_LOG(id_erreur, code_erreur, message, contexte)
            VALUES(seq_error_log.NEXTVAL, SQLCODE, v_err, 'pkg_virements.compte_disponible');
            COMMIT;
            RETURN 'NON : erreur systeme';
    END compte_disponible;

    -- --------------------------------------------------------
    -- FONCTION : GET_SOLDE
    -- --------------------------------------------------------
    FUNCTION get_solde(
        p_id_compte IN NUMBER
    ) RETURN NUMBER AS
        v_solde NUMBER;
    BEGIN
        SELECT solde INTO v_solde FROM COMPTES WHERE id_compte = p_id_compte;
        RETURN v_solde;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN -1;
        WHEN OTHERS THEN        RETURN -1;
    END get_solde;

END pkg_virements;
/

-- ============================================================
-- VÉRIFICATION
-- ============================================================
SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('PACKAGE', 'PACKAGE BODY')
ORDER BY object_type, object_name;
