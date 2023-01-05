-- Creare pachet


CREATE OR REPLACE TYPE t_imbri_title_lco AS TABLE OF VARCHAR2(50);
/

ALTER TABLE actors_lco
ADD (plays t_imbri_title_lco)
NESTED TABLE plays STORE AS info_plays;

SELECT * FROM actors_lco;
UPDATE actors_lco
SET plays = null;
ALTER TABLE actors_lco
DROP COLUMN plays;

CREATE OR REPLACE PACKAGE exercitii_proiect IS
    TYPE rec_act IS RECORD
        (cod_actor actors_lco.actor_id%TYPE,
         prenume actors_lco.first_name%TYPE,
         nume actors_lco.last_name%TYPE);
    TYPE t_index_rec IS TABLE OF rec_act INDEX BY BINARY_INTEGER;
    PROCEDURE actors_with_max_num_plays (t_rec OUT t_index_rec, 
                                         num_max_plays OUT NUMBER);
    
    TYPE tab_events IS TABLE OF events_lco.event_id%TYPE;
    PROCEDURE num_events_for_play(v_play_id IN NUMBER, 
                                  num_events OUT NUMBER,
                                  t OUT tab_events);

    FUNCTION max_price_for_location(id_v venues_lco.venue_id%TYPE)
    RETURN VARCHAR2;
    
    PROCEDURE set_error_messages_lco(error_message IN VARCHAR2, msg_type IN VARCHAR2);
END exercitii_proiect;
/
    
    
CREATE OR REPLACE PACKAGE BODY exercitii_proiect IS

    PROCEDURE actors_with_max_num_plays (t_rec OUT t_index_rec, num_max_plays OUT NUMBER)
    IS
        TYPE tab_index_actors IS TABLE OF rec_act INDEX BY BINARY_INTEGER;
        t_act tab_index_actors;
        t_title t_imbri_title_lco;
        idx NUMBER := 0;
        i NUMBER;
    BEGIN
        num_max_plays := 0;
        SELECT MAX(COUNT(play_id)) INTO num_max_plays
        FROM plays_actors_lco
        GROUP BY actor_id;
        
        SELECT actor_id, first_name, last_name BULK COLLECT INTO t_act
        FROM actors_lco;
        
        i := t_act.FIRST;
        WHILE (i <= t_act.LAST) LOOP
            SELECT title BULK COLLECT INTO t_title
            FROM plays_lco
            JOIN plays_actors_lco USING (play_id)
            WHERE actor_id = t_act(i).cod_actor;
            
            UPDATE actors_lco
            SET plays = t_title
            WHERE actor_id = t_act(i).cod_actor;
            
            IF t_title.COUNT = num_max_plays THEN
                idx := idx + 1;
                t_rec(idx) := t_act(i);
            END IF;
            i:= t_act.NEXT(i);
        END LOOP;
    END actors_with_max_num_plays;
    
    
    PROCEDURE num_events_for_play(v_play_id IN NUMBER, num_events OUT NUMBER, t OUT tab_events)
    IS
        ck NUMBER := -1;
        exceptie EXCEPTION;
        error_msg VARCHAR2(100);
        CURSOR c_ev IS
            (SELECT ord.event_id
            FROM events_lco ev
            JOIN orders_lco ord ON (ord.event_id = ev.event_id)
            WHERE ev.play_id = v_play_id
            GROUP BY ord.event_id
            HAVING COUNT(DISTINCT ord.customer_id) >= 2);
    BEGIN
        SELECT COUNT(*) INTO ck   
        FROM plays_lco
        WHERE play_id = v_play_id;

        IF ck = 0 THEN
            RAISE exceptie;
        END IF;

        IF c_ev%ISOPEN THEN
            CLOSE c_ev;
            exercitii_proiect.set_error_messages_lco('Ati uitat cursorul deschis', 'W');
        END IF;
        
        OPEN c_ev;
        FETCH c_ev BULK COLLECT INTO t;
        num_events := t.COUNT ;
        CLOSE c_ev;
    
    EXCEPTION
        WHEN exceptie THEN
            exercitii_proiect.set_error_messages_lco('Nu exista piesa cu id-ul specificat', 'E');
            RAISE_APPLICATION_ERROR(-20210, 'Nu exista piesa cu id-ul specificat');
        WHEN OTHERS THEN
            error_msg := SUBSTR(SQLERRM,1,100);
            exercitii_proiect.set_error_messages_lco(error_msg, 'E');
            RAISE_APPLICATION_ERROR(-20001, error_msg);
    END num_events_for_play;
    
    
    FUNCTION max_price_for_location(id_v venues_lco.venue_id%TYPE)
    RETURN VARCHAR2
    IS
        ck NUMBER := -1;
        exceptie EXCEPTION;
        error_msg VARCHAR2(200);
        nume VARCHAR2(100);
        max_sum NUMBER(5) := 0;
    BEGIN
    
        SELECT COUNT(*) INTO ck
        FROM venues_lco
        WHERE venue_id = id_v;
        
        IF ck = 0 THEN
            RAISE exceptie;
        END IF;
        
        SELECT MAX(MAX(num_seats * price)) INTO max_sum
        FROM orders_lco ord 
        JOIN events_lco ev ON (ord.event_id = ev.event_id)
        WHERE venue_id = id_v
        GROUP BY customer_id;
        DBMS_OUTPUT.PUT_LINE('Suma maxima: ' || max_sum);
        SELECT last_name INTO nume
        FROM customers_lco cust
        JOIN orders_lco ord ON (cust.customer_id = ord.customer_id)
        JOIN events_lco ev ON (ord.event_id = ev.event_id)
        WHERE venue_id = id_v
        GROUP BY ord.customer_id, last_name
        HAVING MAX(num_seats * price) = max_sum;
        
        RETURN nume;
        
        EXCEPTION
            WHEN exceptie THEN
                exercitii_proiect.set_error_messages_lco('Nu exista sala cu id-ul specificat', 'E');
                RAISE_APPLICATION_ERROR(-20220, 'Nu exista sala cu id-ul specificat');
            WHEN NO_DATA_FOUND THEN
                error_msg := SUBSTR(SQLERRM,1,100);
                exercitii_proiect.set_error_messages_lco(error_msg, 'E');
                RAISE_APPLICATION_ERROR(-20001, error_msg);
            WHEN TOO_MANY_ROWS THEN
                error_msg := SUBSTR(SQLERRM,1,100);
                exercitii_proiect.set_error_messages_lco(error_msg, 'E');
                RAISE_APPLICATION_ERROR(-20001, error_msg);
            WHEN OTHERS THEN
                error_msg := SUBSTR(SQLERRM,1,100);
                exercitii_proiect.set_error_messages_lco(error_msg, 'E');
                RAISE_APPLICATION_ERROR(-20001, error_msg);
    END max_price_for_location;

    PROCEDURE set_error_messages_lco(error_message IN VARCHAR2, msg_type IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO messages_lco
        VALUES(messages_seq_lco.NEXTVAL, error_message, msg_type, SYS.LOGIN_USER, SYSDATE); 
        COMMIT;
    END;
    
END exercitii_proiect;
/

---- Cerinta 1: 
SET SERVEROUTPUT ON;

DECLARE
t_rec exercitii_proiect.t_index_rec;
num_max_plays NUMBER;

BEGIN
    exercitii_proiect.actors_with_max_num_plays(t_rec, num_max_plays);
    DBMS_OUTPUT.PUT_LINE('Numarul maxim de piese este: ' || num_max_plays);
    DBMS_OUTPUT.PUT_LINE('Actorii cu numar maxim de piese sunt:');
    FOR i IN t_rec.FIRST..t_rec.LAST LOOP
        IF t_rec.exists(i) THEN
            DBMS_OUTPUT.PUT_LINE(t_rec(i).cod_actor || ' ' || t_rec(i).prenume || ' ' || t_rec(i).nume);
        END IF;
    END LOOP;
END;
/

SELECT * FROM actors_lco;


----- Cerinta 2

DECLARE
    nr_ev NUMBER(5);
    t_ev exercitii_proiect.tab_events;
BEGIN
    -- Apel exceptie nu a fost gasita piesa cu id-ul respectiv
    -- exercitii_proiect.num_events_for_play(14, nr_ev, t_ev);
    -- Apel piesa cu evenimente
    exercitii_proiect.num_events_for_play(2, nr_ev, t_ev);
    DBMS_OUTPUT.PUT_LINE('Numarul de evenimente pentru piesa cu id-ul dat ca parametru cu minim 2 clienti: ' || nr_ev);
    IF (t_ev.COUNT > 0) THEN
        DBMS_OUTPUT.PUT_LINE('Id-urile evenimentelor sunt:');
        FOR i IN t_ev.FIRST..t_ev.LAST LOOP
            IF t_ev.EXISTS(i) THEN
                DBMS_OUTPUT.PUT_LINE(t_ev(i));
            END IF;
        END LOOP;
    END IF;

END;
/


---- Cerinta 3

SELECT * FROM orders_lco;
BEGIN
    -- Nu exista venue
    -- DBMS_OUTPUT.PUT_LINE(exercitii_proiect.max_price_for_location(23));
    -- No data found: 
    -- DBMS_OUTPUT.PUT_LINE(exercitii_proiect.max_price_for_location(3));
    DBMS_OUTPUT.PUT_LINE(exercitii_proiect.max_price_for_location(1));
END;
/


SELECT * FROM messages_lco ORDER BY 1;
SELECT * FROM venues_lco; 



/*Trigger de tip LMD la nivel de comanda si trigger de tip LMD la nivel de linie 
Sa se creeze un trigger care se declanseaza daca se rezerva mai multe locuri intr-o sala decat capacitatea salii*/

CREATE OR REPLACE PACKAGE pkt_max_seats_lco
AS
TYPE t_idx_cod_event IS TABLE OF events_lco.event_id%TYPE INDEX BY BINARY_INTEGER;
TYPE t_idx_cod_client IS TABLE OF customers_lco.customer_id%TYPE INDEX BY BINARY_INTEGER;
t_cod_event t_idx_cod_event;
t_cod_client t_idx_cod_client;
v_nr_elem BINARY_INTEGER := 0;
END pkt_max_seats_lco;
/
DROP PACKAGE pkt_max_seats;

-- trigger la nivel de linie
CREATE OR REPLACE TRIGGER trig_max_seats_linie
BEFORE INSERT OR UPDATE OF num_seats, event_id ON orders_lco
FOR EACH ROW
BEGIN
pkt_max_seats_lco.v_nr_elem := pkt_max_seats_lco.v_nr_elem + 1;
pkt_max_seats_lco.t_cod_event(pkt_max_seats_lco.v_nr_elem) := :NEW.event_id;
END;
/
-- trigger la nivel de comanda
CREATE OR REPLACE TRIGGER trig_max_seats_instr
AFTER INSERT OR UPDATE OF num_seats, event_id ON orders_lco
DECLARE
v_cod_event events_lco.event_id%TYPE;
v_nr_seats NUMBER;
v_max_seats NUMBER;
BEGIN
FOR i IN 1..pkt_max_seats_lco.v_nr_elem LOOP
    v_cod_event := pkt_max_seats_lco.t_cod_event(i);
    SELECT SUM(num_seats) INTO v_nr_seats
    FROM orders_lco
    WHERE event_id = v_cod_event;
    
    SELECT seat_capacity INTO v_max_seats
    FROM venues_lco
    JOIN events_lco USING(venue_id)
    WHERE event_id = v_cod_event;

    IF v_nr_seats > v_max_seats THEN
        exercitii_proiect.set_error_messages_lco('Numarul de scaune rezervate depaseste capacitatea ramasa a salii', 'E');
        RAISE_APPLICATION_ERROR(-20230, 'Numarul de scaune rezervate depaseste capacitatea ramasa a salii');
    END IF;
END LOOP;

pkt_max_seats_lco.v_nr_elem := 0;
END;
/


ROLLBACK;
SELECT * FROM orders_lco;
ALTER TRIGGER trig_max_seats_instr DISABLE;

-- Nu da eroare
UPDATE orders_lco
SET num_seats = 9
WHERE event_id = 1
AND customer_id = 3;

-- Da eroare
UPDATE orders_lco
SET num_seats = 99
WHERE event_id = 1
AND customer_id = 3;

-- Eroare
UPDATE orders_lco
SET num_seats = 51
WHERE event_id = 1
AND customer_id = 3;
-- Eroare aici
UPDATE orders_lco
SET event_id = 1
WHERE event_id = 4
AND customer_id = 1;

ROLLBACK;
SELECT * FROM messages_lco ORDER BY message_id;



-- Trigger de tip LMD la nivel de linie 
-- Nu se permite modificarea pretului biletelor daca s-au cumparat deja bilete la eveniment

CREATE OR REPLACE TRIGGER check_for_price_updates
BEFORE UPDATE OF price ON events_lco
FOR EACH ROW
DECLARE
nr NUMBER := 0;
BEGIN
SELECT COUNT(customer_id) INTO nr
FROM orders_lco
WHERE event_id = :NEW.event_id;

IF (nr != 0) AND (:OLD.price != :NEW.price) THEN
    exercitii_proiect.set_error_messages_lco('Valoarea unui bilet nu poate fi modificata', 'E');
    RAISE_APPLICATION_ERROR (-20240, 'Valoarea unui bilet nu poate fi modificata');

END IF;
END;
/


SELECT * FROM orders_lco;

-- Se poate modifica
UPDATE events_lco
SET price = 100
WHERE event_id = 2;

-- Nu se poate modifica
UPDATE events_lco
SET price = 120
WHERE event_id = 4;
ROLLBACK;
SELECT * FROM messages_lco ORDER BY message_id;

/* Trigger de tip LDD: la create, alter sau drop pe schema, sa se insereze un mesaj in tabelul messages_lco*/
CREATE OR REPLACE TRIGGER trig_alter_drop_table
AFTER CREATE OR ALTER OR DROP  ON SCHEMA
BEGIN
    exercitii_proiect.set_error_messages_lco('Create, alter or drop was performed on schema', 'I');
END;
/


CREATE TABLE messages_lco
(message_id NUMBER PRIMARY KEY,
message VARCHAR2(255),
message_type VARCHAR2(1) CHECK (message_type in ('E','W','I')),
created_by VARCHAR2(40) NOT NULL,
created_at DATE NOT NULL);

CREATE SEQUENCE messages_seq_lco 
START WITH 1
INCREMENT BY 1;

SET SERVEROUTPUT ON;