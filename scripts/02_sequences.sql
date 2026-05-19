-- ============================================================
-- PROJET FIN DE MODULE : Système Bancaire Oracle
-- Script : 02_sequences.sql
-- Description : Création des séquences pour chaque table
-- Connexion : bank_admin
-- ============================================================

-- Règle du sujet : START WITH 1, INCREMENT BY 1, NOCACHE

-- Module Utilisateurs
CREATE SEQUENCE seq_roles
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE SEQUENCE seq_clients
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE SEQUENCE seq_admins
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE SEQUENCE seq_historique_connexions
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Module Comptes & Cartes
CREATE SEQUENCE seq_comptes
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE SEQUENCE seq_cartes
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Module Virements
CREATE SEQUENCE seq_statuts_virement
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE SEQUENCE seq_virements
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Module Transactions
CREATE SEQUENCE seq_transactions
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Module Crédits
CREATE SEQUENCE seq_credits
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE SEQUENCE seq_echeances_credit
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Tables techniques
CREATE SEQUENCE seq_audit_log
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE SEQUENCE seq_error_log
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE SEQUENCE seq_alertes_fraude
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Module Intelligent
CREATE SEQUENCE seq_plafonds_credit
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

COMMIT;

-- Vérification : afficher toutes les séquences créées
SELECT sequence_name, min_value, increment_by, cache_size
FROM user_sequences
ORDER BY sequence_name;