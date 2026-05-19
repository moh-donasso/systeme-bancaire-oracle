-- ============================================================
-- PROJET FIN DE MODULE : Système Bancaire Oracle
-- Script : 08_triggers.sql
-- Description : 3 triggers obligatoires
-- Connexion : bank_admin
-- ============================================================

-- ============================================================
-- TRIGGER 1 : RÈGLE MÉTIER
-- Empêche le solde d'un compte de devenir négatif
-- et bloque les opérations sur comptes fermés/bloqués
-- ============================================================
CREATE OR REPLACE TRIGGER trg_solde_negatif
BEFORE UPDATE OF solde ON COMPTES
FOR EACH ROW
BEGIN
    -- Empêcher solde négatif
    IF :NEW.solde < 0 THEN
        RAISE_APPLICATION_ERROR(-20030,
            'ERREUR METIER : Le solde du compte #' || :NEW.id_compte ||
            ' ne peut pas être négatif. Solde actuel : ' || :OLD.solde ||
            ' | Nouveau solde demandé : ' || :NEW.solde);
    END IF;

    -- Empêcher toute modification sur compte fermé
    IF :OLD.statut = 'FERME' AND :NEW.solde != :OLD.solde THEN
        RAISE_APPLICATION_ERROR(-20031,
            'ERREUR METIER : Impossible de modifier le solde d un compte fermé (#' ||
            :NEW.id_compte || ')');
    END IF;

    -- Empêcher toute modification sur compte bloqué
    IF :OLD.statut = 'BLOQUE' AND :NEW.solde != :OLD.solde THEN
        RAISE_APPLICATION_ERROR(-20032,
            'ERREUR METIER : Impossible de modifier le solde d un compte bloqué (#' ||
            :NEW.id_compte || '). Contactez l administration.');
    END IF;
END trg_solde_negatif;
/

-- ============================================================
-- TRIGGER 2 : AUDIT
-- Journalise chaque UPDATE et DELETE sur COMPTES et VIREMENTS
-- Stocke utilisateur, date, table, action, ancien/nouveau solde
-- ============================================================
CREATE OR REPLACE TRIGGER trg_audit_comptes
AFTER UPDATE OR DELETE ON COMPTES
FOR EACH ROW
DECLARE
    v_action        VARCHAR2(10);
    v_nouvelle_val  VARCHAR2(500);
BEGIN
    IF DELETING THEN
        v_action       := 'DELETE';
        v_nouvelle_val := 'SUPPRIME';
    ELSE
        v_action       := 'UPDATE';
        v_nouvelle_val := 'id=' || :NEW.id_compte ||
                          ' | solde=' || :NEW.solde ||
                          ' | statut=' || :NEW.statut;
    END IF;

    INSERT INTO AUDIT_LOG(
        id_audit, utilisateur, date_action,
        table_cible, type_action,
        ancienne_valeur, nouvelle_valeur
    ) VALUES (
        seq_audit_log.NEXTVAL,
        SYS_CONTEXT('USERENV', 'SESSION_USER'),
        SYSDATE,
        'COMPTES',
        v_action,
        'id=' || :OLD.id_compte ||
        ' | solde=' || :OLD.solde ||
        ' | statut=' || :OLD.statut,
        v_nouvelle_val
    );
END trg_audit_comptes;
/

CREATE OR REPLACE TRIGGER trg_audit_virements
AFTER UPDATE OR DELETE ON VIREMENTS
FOR EACH ROW
DECLARE
    v_action        VARCHAR2(10);
    v_nouvelle_val  VARCHAR2(500);
BEGIN
    IF DELETING THEN
        v_action       := 'DELETE';
        v_nouvelle_val := 'SUPPRIME';
    ELSE
        v_action       := 'UPDATE';
        v_nouvelle_val := 'id=' || :NEW.id_virement ||
                          ' | montant=' || :NEW.montant ||
                          ' | statut=' || :NEW.id_statut;
    END IF;

    INSERT INTO AUDIT_LOG(
        id_audit, utilisateur, date_action,
        table_cible, type_action,
        ancienne_valeur, nouvelle_valeur
    ) VALUES (
        seq_audit_log.NEXTVAL,
        SYS_CONTEXT('USERENV', 'SESSION_USER'),
        SYSDATE,
        'VIREMENTS',
        v_action,
        'id=' || :OLD.id_virement ||
        ' | montant=' || :OLD.montant ||
        ' | statut=' || :OLD.id_statut,
        v_nouvelle_val
    );
END trg_audit_virements;
/

-- ============================================================
-- TRIGGER 3 : TECHNIQUE
-- Met à jour automatiquement DATE_MODIFICATION
-- sur COMPTES, CLIENTS, VIREMENTS, CARTES
-- ============================================================
CREATE OR REPLACE TRIGGER trg_detection_fraude
AFTER INSERT ON TRANSACTIONS
FOR EACH ROW
DECLARE
    v_seuil_montant NUMBER := 10000;
BEGIN
    IF :NEW.montant > v_seuil_montant THEN
        INSERT INTO ALERTES_FRAUDE(
            id_alerte, id_compte, id_transaction,
            type_alerte, montant, date_alerte, statut, description
        ) VALUES (
            seq_alertes_fraude.NEXTVAL,
            :NEW.id_compte, :NEW.id_transaction,
            'MONTANT_ELEVE', :NEW.montant, SYSDATE,
            'OUVERTE',
            'Transaction de ' || TO_CHAR(:NEW.montant) ||
            ' MAD sur compte ' || TO_CHAR(:NEW.id_compte)
        );
    END IF;
END trg_detection_fraude;
/

-- ============================================================
-- VÉRIFICATION
-- ============================================================
SELECT trigger_name, trigger_type, triggering_event,
       table_name, status
FROM user_triggers
ORDER BY table_name;


SELECT USER FROM DUAL;