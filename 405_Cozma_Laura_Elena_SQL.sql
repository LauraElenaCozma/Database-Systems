/*Platforma creeaza un sistem de puncte,  oferind puncte bonus (care ulterior pot fi folosite la reduceri ale pretului biletelor) pentru urmatoarele categorii:
20 pct. pentru persoana cu cele mai multe bilete cumparate
10 pct. daca a cumparat cel putin 5 bilete in total si cel putin 2 sunt pe anul curent 
 2 pct. Daca nu se incadreaza in celelalte doua categorii, dar au persoanele care au numarul de telefon in reteaua Vodafone
Sa se afiseze persoanele care indeplinesc categoriile, impreuna cu numarul de bilete cumparate si numarul de punct bonus.
*/
SELECT first_name, last_name, phone_number, tickets, 
CASE
WHEN (ROWNUM = 1) THEN 20
WHEN (tickets > 4 AND tickets_2021 >= 2) THEN 10
WHEN (phone_number IS NOT NULL AND INSTR(phone_number, '072') = 1) 
        THEN 2
ELSE 0
END puncte_bonus
FROM (SELECT customer_id, first_name, last_name, phone_number, SUM(num_seats) tickets
        FROM customers_lco
        JOIN orders_lco USING(customer_id)
        GROUP BY customer_id, first_name, last_name, phone_number
        ORDER BY tickets DESC) customers_ordered
LEFT JOIN (SELECT customer_id, SUM(num_seats) tickets_2021
        FROM orders_lco 
        JOIN events_lco USING (event_id) 
        WHERE EXTRACT(YEAR FROM event_date) = '2022'
        GROUP BY customer_id) USING (customer_id);

/*
Datorita numarului crescut de cazuri Covid, se verifica posibilitatea mutarii spectacolelor peste 3 luni, daca indeplinesc una din urmatoarele conditii:
sunt din viitor si sunt anulate
au mai multe bilete vandute decat jumatatea capacitatii salii
Sa se afiseze evenimentele care verifica conditiile, impreuna cu data de peste 3 luni.
*/

SELECT event_id, event_date, ADD_MONTHS(event_date, 3)
FROM events_lco ev
WHERE (status IS NOT NULL AND UPPER(status) = 'ANULAT' AND event_date > sysdate) OR
event_id IN (SELECT event_id
             FROM orders_lco ord
             GROUP BY event_id
             HAVING SUM(num_seats) > (SELECT seat_capacity / 2                                                                             
                                      FROM venues_lco
                                      JOIN events_lco USING (venue_id)
                                      WHERE event_id = ord.event_id));


/*Sa se afiseze subalternii responsabilului grupei de teatru care a jucat in cele mai multe piese. Daca sunt mai multi, se selecteaza cel mai batran.*/
SELECT LPAD(first_name || ' ' || last_name, LEVEL - 1 + LENGTH(first_name               
            || ' ' || last_name)) nume
FROM actors_lco
START WITH actor_id = (SELECT actor_id
                       FROM (
                            SELECT actor_id
                            FROM actors_lco
                            WHERE representative_id IS NULL 
                            AND actor_id IN (SELECT actor_id
                                        FROM plays_actors_lco
                                        GROUP BY actor_id
                                        HAVING COUNT(play_id) = (SELECT 
                                                    MAX(COUNT(play_id))
                                                    FROM plays_actors_lco
                                                    GROUP BY actor_id))                                                                            
                            ORDER BY date_of_birth)
                        WHERE ROWNUM = 1)
CONNECT BY PRIOR actor_id = representative_id;

/*Sa se afiseze toate datele calendaristice dintre cele mai indepartate evenimente.*/

SELECT date_min + ROWNUM
FROM (SELECT MIN(event_date) date_min
        FROM events_lco)
CROSS JOIN (SELECT MAX(event_date) date_max
        FROM events_lco) 
CONNECT BY ROWNUM < TO_DATE(date_max, 'DD/MM/YYYY') - TO_DATE(date_min, 'DD/MM/YYYY');

/*Sa se afiseze clientii care au cumparat cel putin aceleasi bilete ca cele cumparate de clientul Alexandra Popa.*/
SELECT *
FROM customers_lco cust
WHERE NOT EXISTS (SELECT event_id
                  FROM orders_lco
                  JOIN customers_lco 
                  ON orders_lco.customer_id = customers_lco.customer_id
                  WHERE INITCAP(first_name) = 'Ioana' 
                  AND INITCAP(last_name) = 'Pop'

                  MINUS

                  SELECT event_id
                  FROM orders_lco
                  WHERE customer_id = cust.customer_id)
AND INITCAP(first_name) != 'Alexandra' AND INITCAP(last_name) != 'Popa';


/*Sa se afiseze actorii care au spectacole in 2022 neanulate si nu joaca singuri intr-o piesa.*/
SELECT act.first_name, act.last_name, act.date_of_birth FROM actors_lco act  
JOIN plays_actors_lco ON plays_actors_lco.actor_id = act.actor_id
JOIN plays_lco ON plays_actors_lco.play_id = plays_lco.play_id
JOIN events_lco ev ON plays_lco.play_id = ev.play_id
WHERE (ev.status IS NULL OR UPPER(ev.status) != 'ANULAT')
AND EXTRACT(YEAR FROM event_date) = '2022'

INTERSECT

SELECT act.first_name, act.last_name, act.date_of_birth FROM actors_lco act
JOIN plays_actors_lco pa ON pa.actor_id = act.actor_id
WHERE EXISTS (SELECT 1
FROM plays_actors_lco
WHERE actor_id <> act.actor_id AND pa.play_id = play_id);

SELECT * FROM orders_lco;

/*Sa se afiseze pentru fiecare piesa de teatru, numarul de spectatori care vin in medie la acestea.*/
SELECT title, 
      (SELECT NVL(ROUND(AVG(total_seats), 1), 0)
       FROM (SELECT event_id, SUM(num_seats) total_seats
             FROM orders_lco
             GROUP BY event_id)
       JOIN events_lco USING(event_id)
       WHERE play_id = p.play_id) avg_seats,
      (SELECT NVL(AVG(price), 0)
       FROM events_lco
       WHERE play_id = p.play_id) avg_price
FROM plays_lco p;

/*Sa se afiseze piesele de teatru, pentru fiecare numarul de actori care joaca in piesa si numarul de evenimente. Piesele trebuie sa aiba cel mai mare numar de evenimente in 2021.*/
SELECT title, actors, COUNT(event_id) num_events
FROM plays_lco p
JOIN (SELECT play_id, COUNT(actor_id) actors
                FROM plays_actors_lco
                GROUP BY play_id) num_actors 
      ON p.play_id = num_actors.play_id
JOIN events_lco ev ON ev.play_id = num_actors.play_id
WHERE TO_CHAR(event_date, 'YYYY') = '2021'
GROUP BY ev.play_id, title, actors
HAVING COUNT(event_id) = (SELECT MAX(COUNT(event_id)) 
                            FROM events_lco
                            WHERE TO_CHAR(event_date, 'YYYY') = '2021'
                            GROUP BY play_id);


/*Sa se afiseze detalii despre evenimentele din cea mai populara sala (are cele mai multe bilete cumparate in numar de clienti) si in a caror piesa de teatru joaca minim doi actori.*/
SELECT * FROM events_lco
WHERE venue_id IN (SELECT venue_id 
                    FROM events_lco ev
                    JOIN orders_lco ord ON ord.event_id = ev.event_id
                    GROUP BY venue_id
                    HAVING COUNT(ord.event_id) = (SELECT                       
                                              MAX(COUNT(ord.event_id))
                                              FROM orders_lco ord
                                              JOIN events_lco ev ON
                                              ord.event_id = ev.event_id
                                              GROUP BY venue_id)) 
AND play_id IN (SELECT play_id FROM plays_actors_lco
            GROUP BY play_id
            HAVING COUNT(actor_id) >= 2);

/*Sa se afiseze salile si institutiile din Bucuresti care au spectacole in mai putin de o luna, impreuna cu toti actorii care vor urca pe scena in acea luna. Numele actorilor va fi afisat in formatul P. Nume*/

SELECT DISTINCT institution_name, venue_name, 
       SUBSTR(actors_lco.first_name, 1, 1) || '. ' || actors_lco.last_name        
       actor
FROM address_venues_lco
JOIN venues_lco USING (address_id)
JOIN events_lco USING (venue_id)
JOIN plays_lco USING (play_id)
JOIN plays_actors_lco USING (play_id)
JOIN actors_lco USING (actor_id)
WHERE MONTHS_BETWEEN(event_date, sysdate) <= 1 
      AND (status IS NULL OR LOWER(status) != 'anulat')
      AND LOWER(city) = 'bucuresti'
ORDER BY institution_name, venue_name;

/*Sa se afiseze clientii care au achizitionat la spectacole in minim doua sali diferite in 2022 si spectacolele nu sunt anulate sau au cel putin un bilet la un spectacol anulat in 2021.*/

SELECT customer_id, first_name, last_name
FROM customers_lco
JOIN orders_lco USING (customer_id)
JOIN events_lco USING (event_id)
WHERE (status IS NULL OR UPPER(status) != 'ANULAT') AND EXTRACT(YEAR FROM event_date) = '2022'
GROUP BY customer_id, first_name, last_name
HAVING COUNT(DISTINCT venue_id) >= 2

UNION

SELECT customer_id, first_name, last_name FROM customers_lco
JOIN orders_lco USING (customer_id)
JOIN events_lco USING (event_id)
WHERE status IS NOT NULL AND UPPER(status) = 'ANULAT' AND EXTRACT(YEAR FROM event_date) = '2021';

/*Sa se afiseze piesele de teatru din Bucuresti impreuna cu profitul acestora, in ordine descrescatoare. Se mentioneaza ca unele piese nu vor avea profit pentru ca nu au fost bilete vandute, iar alte piese vor fi anulate, dar ar putea totusi sa aiba profit.*/
SELECT event_id, title, NVL(price * sold_seats, 0) profit, DECODE(status, NULL, 'ACTIV', status)
FROM (SELECT event_id, NVL(SUM(num_seats), 0) sold_seats
                FROM events_lco
                JOIN plays_lco USING (play_id)
                JOIN venues_lco USING (venue_id)
                JOIN address_venues_lco USING (address_id)
                LEFT JOIN orders_lco USING (event_id)
                WHERE UPPER(city) = 'BUCURESTI' 
                GROUP BY event_id) ev_filtered
RIGHT JOIN events_lco USING(event_id)
JOIN plays_lco USING(play_id)
ORDER BY profit DESC;

/*Sa se afiseze perechi de tipul (id eveniment: valoare, id sala: valoare) pentru toate evenimentele care vor avea loc intre data curenta si ‘31/12/2021’, iar drept locatie va fi Teatrul National Bucuresti.*/
SELECT '(id eveniment: ' || DECODE(event_id, NULL, ' nu are evenimente', event_id) || ', id sala: ' || DECODE(venue_id, NULL, ' nu are locatia stabilita', venue_id) || ')' perechi
FROM events_lco
FULL JOIN venues_lco USING (venue_id)
LEFT JOIN address_venues_lco USING(address_id)
WHERE (event_id IS NULL 
OR TO_DATE(event_date, 'DD/MM/YYYY') BETWEEN TO_DATE(SYSDATE, 'DD/MM/YYYY') AND TO_DATE('31/12/2022', 'DD/MM/YYYY')) 
AND (venue_id IS NULL 
OR INITCAP(institution_name) = 'Teatrul National Bucuresti');

/*Sa se afiseze informatii despre toti clientii care au cumparat bilete pentru toate evenimentele (inclusiv cele anulate) din ianuarie 2022.*/
SELECT DISTINCT cust_1.*
FROM orders_lco ord_1
JOIN customers_lco cust_1 ON ord_1.customer_id = cust_1.customer_id
WHERE NOT EXISTS (SELECT 1
                  FROM events_lco ev_2
                  WHERE TO_CHAR(event_date, 'MM/YYYY') = '01/2022'
                  AND NOT EXISTS (SELECT 1
                                  FROM orders_lco
                                  WHERE ev_2.event_id = event_id AND ord_1.customer_id = customer_id));


/*Sa se afiseze capacitatea ramasa a salilor de teatru la evenimentele cele mai populare (cu cele mai multe bilete vandute).*/
SELECT popular_ev.event_id, seat_capacity - scaune as "Capacitate ramasa"
FROM events_lco ev
JOIN venues_lco ven ON ev.venue_id = ven.venue_id
JOIN (SELECT event_id, SUM(num_seats) scaune
      FROM events_lco
      JOIN orders_lco USING (event_id)
      GROUP BY event_id
      HAVING SUM(num_seats) = (SELECT MAX(SUM(num_seats))
                               FROM orders_lco
                               GROUP BY event_id)) popular_ev 
      ON ev.event_id = popular_ev.event_id;


/*Sa se afiseze numarul de actori pentru piesele de teatru care sunt drame si au cel putin un actor care nu e din Bucuresti.*/
SELECT p.play_id, p.title, COUNT(actor_id) num_act
FROM plays_lco p
JOIN plays_actors_lco pa ON (p.play_id = pa.play_id)
WHERE NULLIF(LOWER(genre), 'drama') IS NULL
AND EXISTS (SELECT 
            actor_id
            FROM plays_actors_lco
            JOIN actors_lco USING (actor_id)
            WHERE play_id = p.play_id 
            AND NULLIF(LOWER(place_of_birth), 'bucuresti') IS NOT NULL)
GROUP BY p.play_id, p.title;

SELECT * FROM plays_actors_lco;