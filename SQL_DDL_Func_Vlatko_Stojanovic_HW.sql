CREATE SCHEMA IF NOT EXISTS core;

SET search_path TO core, public;

-- Task 1
CREATE OR REPLACE VIEW core.sales_revenue_by_category_qtr AS
SELECT
    c.name AS category_name,
    EXTRACT(YEAR FROM p.payment_date)    AS sales_year,
    EXTRACT(QUARTER FROM p.payment_date) AS sales_quarter,
    SUM(p.amount) AS total_revenue
FROM public.payment p
JOIN public.rental r         ON r.rental_id    = p.rental_id
JOIN public.inventory i      ON i.inventory_id = r.inventory_id
JOIN public.film f           ON f.film_id      = i.film_id
JOIN public.film_category fc ON fc.film_id     = f.film_id
JOIN public.category c       ON c.category_id  = fc.category_id
WHERE EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
GROUP BY
    c.name,
    EXTRACT(YEAR FROM p.payment_date),
    EXTRACT(QUARTER FROM p.payment_date)
HAVING SUM(p.amount) > 0;

-- Check view 
SELECT * FROM core.sales_revenue_by_category_qtr;


-- Task 2
CREATE OR REPLACE FUNCTION core.get_sales_revenue_by_category_qtr(
    p_ref_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    category_name  TEXT,
    sales_year     INT,
    sales_quarter  INT,
    total_revenue  NUMERIC
)
LANGUAGE SQL
AS $$
    SELECT
        c.name AS category_name,
        EXTRACT(YEAR FROM p.payment_date)    AS sales_year,
        EXTRACT(QUARTER FROM p.payment_date) AS sales_quarter,
        SUM(p.amount) AS total_revenue
    FROM public.payment p
    JOIN public.rental r         ON r.rental_id    = p.rental_id
    JOIN public.inventory i      ON i.inventory_id = r.inventory_id
    JOIN public.film f           ON f.film_id      = i.film_id
    JOIN public.film_category fc ON fc.film_id     = f.film_id
    JOIN public.category c       ON c.category_id  = fc.category_id
    WHERE EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM p_ref_date)
      AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM p_ref_date)
    GROUP BY
        c.name,
        EXTRACT(YEAR FROM p.payment_date),
        EXTRACT(QUARTER FROM p.payment_date)
    HAVING SUM(p.amount) > 0;
$$;

-- Check for current quarter
SELECT * FROM core.get_sales_revenue_by_category_qtr();

-- Check for another date
SELECT * FROM core.get_sales_revenue_by_category_qtr(DATE '2005-02-01');


-- Task 3
CREATE OR REPLACE FUNCTION core.most_popular_films_by_countries(
    p_countries TEXT[]
)
RETURNS TABLE (
    country_name  TEXT,
    film_title    TEXT,
    rating        TEXT,
    language_name TEXT,
    length        INT,
    release_year  INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validate input
    IF p_countries IS NULL OR array_length(p_countries, 1) = 0 THEN
        RAISE EXCEPTION 'Country list must not be empty';
    END IF;

    RETURN QUERY
    SELECT
        co.country        AS country_name,
        f.title           AS film_title,
        f.rating::TEXT    AS rating,
        l.name::TEXT      AS language_name,
        f.length::INT     AS length,
        f.release_year::INT
    FROM (
        SELECT
            co.country_id,
            f.film_id,
            COUNT(r.rental_id) AS rental_count,
            ROW_NUMBER() OVER (
                PARTITION BY co.country_id
                ORDER BY COUNT(r.rental_id) DESC
            ) AS rn
        FROM public.country co
        JOIN public.city ci        ON ci.country_id = co.country_id
        JOIN public.address a      ON a.city_id     = ci.city_id
        JOIN public.customer cu    ON cu.address_id = a.address_id
        JOIN public.rental r       ON r.customer_id = cu.customer_id
        JOIN public.inventory i    ON i.inventory_id = r.inventory_id
        JOIN public.film f         ON f.film_id      = i.film_id
        WHERE co.country = ANY (p_countries)
        GROUP BY co.country_id, f.film_id
    ) top
    JOIN public.country  co ON co.country_id  = top.country_id
    JOIN public.film     f  ON f.film_id      = top.film_id
    JOIN public.language l  ON l.language_id  = f.language_id
    WHERE top.rn = 1
    ORDER BY co.country;

END;
$$;

-- Check
SELECT *
FROM core.most_popular_films_by_countries(
    ARRAY['Afghanistan','Brazil','United States']
);


-- Task 4
CREATE OR REPLACE FUNCTION core.films_in_stock_by_title(
    p_title_pattern TEXT DEFAULT '%love%'
)
RETURNS TABLE (
    row_num       INT,
    film_title    TEXT,
    language_name TEXT,
    customer_name TEXT,
    rental_date   TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validate input
    IF p_title_pattern IS NULL OR LENGTH(TRIM(p_title_pattern)) = 0 THEN
        RAISE EXCEPTION 'Title pattern must not be empty';
    END IF;

    RETURN QUERY
    WITH available_inventory AS (
        SELECT
            i.inventory_id,
            f.film_id,
            f.title,
            l.name::TEXT AS language_name
        FROM public.inventory i
        JOIN public.film f      ON f.film_id      = i.film_id
        JOIN public.language l  ON l.language_id  = f.language_id
        WHERE f.title ILIKE p_title_pattern
          AND NOT EXISTS (
                SELECT 1
                FROM public.rental r
                WHERE r.inventory_id = i.inventory_id
                  AND r.return_date IS NULL
          )
    ),
    last_rentals AS (
        SELECT
            ai.inventory_id,
            ai.title,
            ai.language_name,
            r.customer_id,
            r.rental_date,
            ROW_NUMBER() OVER (
                PARTITION BY ai.inventory_id
                ORDER BY r.rental_date DESC
            ) AS rn
        FROM available_inventory ai
        LEFT JOIN public.rental r
               ON r.inventory_id = ai.inventory_id
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY lr.title, lr.rental_date NULLS LAST)::INT AS row_num,
        lr.title         AS film_title,
        lr.language_name,
        (c.first_name || ' ' || c.last_name) AS customer_name,
        lr.rental_date::timestamp AS rental_date
    FROM last_rentals lr
    LEFT JOIN public.customer c
           ON c.customer_id = lr.customer_id
    WHERE lr.rn = 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No films in stock found for pattern %', p_title_pattern;
    END IF;
END;
$$;

-- Check
SELECT *
FROM core.films_in_stock_by_title('%love%');


-- Task 5
CREATE OR REPLACE FUNCTION core.new_movie(
    p_title         text,
    p_release_year  public.year DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::integer,
    p_language_name text        DEFAULT 'Klingon'
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_language_id integer;
    v_new_film_id integer;
BEGIN
    IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
        RAISE EXCEPTION 'Title must not be empty';
    END IF;

    SELECT l.language_id
    INTO v_language_id
    FROM public.language AS l
    WHERE trim(l.name) = trim(p_language_name);

    IF v_language_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" does not exist in table "language"', p_language_name;
    END IF;

    PERFORM 1
    FROM public.film f
    WHERE f.title = p_title
      AND f.release_year = p_release_year
      AND f.language_id = v_language_id;

    IF FOUND THEN
        RAISE EXCEPTION 'Film "%", year %, language id % already exists',
            p_title, p_release_year, v_language_id;
    END IF;

    INSERT INTO public.film (
        title,
        language_id,
        release_year,
        rental_duration,
        rental_rate,
        replacement_cost
    )
    VALUES (
        p_title,
        v_language_id,
        p_release_year,
        3,
        4.99,
        19.99
    )
    RETURNING film_id INTO v_new_film_id;

    RETURN v_new_film_id;
END;
$$;