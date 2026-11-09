DROP SCHEMA IF EXISTS dw CASCADE;
CREATE SCHEMA dw;

CREATE TABLE dw.dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE UNIQUE NOT NULL,
    calendar_year INTEGER NOT NULL,
    month_number INTEGER NOT NULL,
    month_name VARCHAR(15) NOT NULL,
    day_of_month INTEGER NOT NULL
);

CREATE TABLE dw.dim_port (
    port_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    port_code VARCHAR(10) UNIQUE NOT NULL,
    port_name VARCHAR(100) NOT NULL,
    province VARCHAR(100) NOT NULL
);

CREATE TABLE dw.dim_species (
    species_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    species_code VARCHAR(10) UNIQUE NOT NULL,
    species_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL
);

CREATE TABLE dw.dim_vessel (
    vessel_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vessel_id VARCHAR(20) NOT NULL,
    vessel_name VARCHAR(100) NOT NULL,
    vessel_type VARCHAR(50) NOT NULL,
    cooperative VARCHAR(100) NOT NULL,
    effective_start DATE NOT NULL,
    effective_end DATE NOT NULL,
    is_current BOOLEAN NOT NULL
);

CREATE UNIQUE INDEX ux_dim_vessel_current
ON dw.dim_vessel(vessel_id)
WHERE is_current = TRUE;

CREATE TABLE dw.fact_landing (
    landing_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_key INTEGER NOT NULL REFERENCES dw.dim_date(date_key),
    port_key BIGINT NOT NULL REFERENCES dw.dim_port(port_key),
    species_key BIGINT NOT NULL REFERENCES dw.dim_species(species_key),
    vessel_key BIGINT NOT NULL REFERENCES dw.dim_vessel(vessel_key),
    kg NUMERIC(12,2) NOT NULL CHECK (kg > 0),
    price_per_kg NUMERIC(12,2) NOT NULL CHECK (price_per_kg > 0),
    total_value NUMERIC(14,2)
        GENERATED ALWAYS AS (kg * price_per_kg) STORED
);

INSERT INTO dw.dim_date (
    date_key, full_date, calendar_year,
    month_number, month_name, day_of_month
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER,
    d::DATE,
    EXTRACT(YEAR FROM d)::INTEGER,
    EXTRACT(MONTH FROM d)::INTEGER,
    TO_CHAR(d, 'FMMonth'),
    EXTRACT(DAY FROM d)::INTEGER
FROM GENERATE_SERIES(
    DATE '2020-01-01',
    DATE '2030-12-31',
    INTERVAL '1 day'
) AS dates(d);

INSERT INTO dw.dim_port (port_code, port_name, province)
VALUES
    ('P001', 'Bongao Fish Landing', 'Tawi-Tawi'),
    ('P002', 'Panglima Sugala Fish Landing', 'Tawi-Tawi'),
    ('P003', 'Sitangkai Fish Landing', 'Tawi-Tawi'),
    ('P004', 'Languyan Fish Landing', 'Tawi-Tawi'),
    ('P005', 'Sibutu Fish Landing', 'Tawi-Tawi'),
    ('P006', 'Simunul Fish Landing', 'Tawi-Tawi'),
    ('P007', 'Sapa-Sapa Fish Landing', 'Tawi-Tawi'),
    ('P008', 'Tandubas Fish Landing', 'Tawi-Tawi');
  

INSERT INTO dw.dim_species (species_code, species_name, category)
VALUES
    ('S001', 'Lumahan', 'Marine'),
    ('S002', 'Mangku', 'Marine'),
    ('S003', 'Mangagat', 'Marine'),
    ('S004', 'Tuna', 'Marine'),
    ('S005', 'Bulinaw', 'Marine'),
    ('S006', 'Kulapu', 'Marine'),
    ('S007', 'Bangasan', 'Marine'),
    ('S008', 'Kutambak', 'Marine');
    
    

INSERT INTO dw.dim_vessel (
    vessel_id, vessel_name, vessel_type, cooperative,
    effective_start, effective_end, is_current
)
VALUES
    ('V001', 'MV Bongao', 'Motorized', 'Bongao Fishers Cooperative',
     DATE '2020-01-01', DATE '9999-12-31', TRUE),
    ('V002', 'MV Panglima Sugala', 'Motorized', 'Panglima Sugala Fishers Cooperative',
     DATE '2020-01-01', DATE '9999-12-31', TRUE),
    ('V003', 'MV Sitangkai', 'Commercial', 'Sitangkai Fishers Cooperative',
     DATE '2020-01-01', DATE '9999-12-31', TRUE),
    ('V004', 'MV Languyan', 'Motorized', 'Languyan Fishers Cooperative',
     DATE '2020-01-01', DATE '9999-12-31', TRUE),
    ('V005', 'MV Sibutu', 'Commercial', 'Sibutu Fishers Cooperative',
     DATE '2020-01-01', DATE '9999-12-31', TRUE),
     ('V006', 'MV Simunul', 'Motorized', 'Simunul Fishers Cooperative',
     DATE '2020-01-01', DATE '9999-12-31', TRUE),
    ('V007', 'MV Sapa-Sapa', 'Commercial', 'Sapa-Sapa Fishers Cooperative',
     DATE '2020-01-01', DATE '9999-12-31', TRUE),
    ('V008', 'MV Tandubas', 'Commercial', 'Tandubas Fishers Cooperative',
     DATE '2020-01-01', DATE '9999-12-31', TRUE);
    


WITH numbered AS (
    SELECT
        n,
        DATE '2020-01-01'
        + ((n * 17) % (DATE '2030-12-31' - DATE '2020-01-01' + 1))
        AS landing_date
    FROM GENERATE_SERIES(1, 200) AS s(n)
),
ports AS (
    SELECT port_key,
           ROW_NUMBER() OVER (ORDER BY port_key) AS rn
    FROM dw.dim_port
),
species AS (
    SELECT species_key,
           ROW_NUMBER() OVER (ORDER BY species_key) AS rn
    FROM dw.dim_species
),
vessels AS (
    SELECT vessel_key,
           ROW_NUMBER() OVER (ORDER BY vessel_key) AS rn
    FROM dw.dim_vessel
    WHERE is_current = TRUE
)
INSERT INTO dw.fact_landing (
    date_key, port_key, species_key,
    vessel_key, kg, price_per_kg
)
SELECT
    d.date_key,
    p.port_key,
    s.species_key,
    v.vessel_key,
    (25 + ((n.n * 37) % 300))::NUMERIC(12,2),
    (50 + ((n.n * 13) % 80))::NUMERIC(12,2)
FROM numbered n
JOIN dw.dim_date d
    ON d.full_date = n.landing_date
JOIN ports p
    ON p.rn = ((n.n - 1) % (SELECT COUNT(*) FROM dw.dim_port)) + 1
JOIN species s
    ON s.rn = ((n.n - 1) % (SELECT COUNT(*) FROM dw.dim_species)) + 1
JOIN vessels v
    ON v.rn = ((n.n - 1) % (
        SELECT COUNT(*) FROM dw.dim_vessel WHERE is_current = TRUE
    )) + 1;

SELECT
    d.calendar_year,
    d.month_number,
    d.month_name,
    SUM(f.kg) AS total_kg
FROM dw.fact_landing f
JOIN dw.dim_date d ON d.date_key = f.date_key
GROUP BY d.calendar_year, d.month_number, d.month_name
ORDER BY d.calendar_year, d.month_number;

WITH species_totals AS (
    SELECT
        p.port_name,
        s.species_name,
        SUM(f.kg) AS total_kg,
        RANK() OVER (
            PARTITION BY p.port_key
            ORDER BY SUM(f.kg) DESC
        ) AS species_rank
    FROM dw.fact_landing f
    JOIN dw.dim_port p ON p.port_key = f.port_key
    JOIN dw.dim_species s ON s.species_key = f.species_key
    GROUP BY p.port_key, p.port_name,
             s.species_key, s.species_name
)
SELECT port_name, species_name, total_kg
FROM species_totals
WHERE species_rank = 1
ORDER BY port_name;

SELECT
    v.cooperative,
    SUM(f.total_value) AS total_value
FROM dw.fact_landing f
JOIN dw.dim_vessel v ON v.vessel_key = f.vessel_key
GROUP BY v.cooperative
ORDER BY total_value DESC;

DROP TABLE IF EXISTS pg_temp.report_before;
CREATE TEMP TABLE report_before AS
SELECT
    d.calendar_year,
    d.month_number,
    v.vessel_id,
    v.cooperative,
    SUM(f.kg) AS total_kg,
    SUM(f.total_value) AS total_value
FROM dw.fact_landing f
JOIN dw.dim_date d ON d.date_key = f.date_key
JOIN dw.dim_vessel v ON v.vessel_key = f.vessel_key
GROUP BY
    d.calendar_year, d.month_number,
    v.vessel_id, v.cooperative;

UPDATE dw.dim_vessel
SET
    effective_end = CURRENT_DATE - 1,
    is_current = FALSE
WHERE vessel_id = 'V001'
  AND is_current = TRUE;

INSERT INTO dw.dim_vessel (
    vessel_id, vessel_name, vessel_type, cooperative,
    effective_start, effective_end, is_current
)
SELECT
    vessel_id,
    vessel_name,
    vessel_type,
    'Tawi-Tawi Island Fishers Cooperative',
    CURRENT_DATE,
    DATE '9999-12-31',
    TRUE
FROM dw.dim_vessel
WHERE vessel_id = 'V001'
  AND is_current = FALSE
  AND effective_end = CURRENT_DATE - 1;

DROP TABLE IF EXISTS pg_temp.report_after;
CREATE TEMP TABLE report_after AS
SELECT
    d.calendar_year,
    d.month_number,
    v.vessel_id,
    v.cooperative,
    SUM(f.kg) AS total_kg,
    SUM(f.total_value) AS total_value
FROM dw.fact_landing f
JOIN dw.dim_date d ON d.date_key = f.date_key
JOIN dw.dim_vessel v ON v.vessel_key = f.vessel_key
GROUP BY
    d.calendar_year, d.month_number,
    v.vessel_id, v.cooperative;

WITH differences AS (
    (SELECT * FROM report_before
     EXCEPT
     SELECT * FROM report_after)

    UNION ALL

    (SELECT * FROM report_after
     EXCEPT
     SELECT * FROM report_before)
)
SELECT
    CASE
        WHEN COUNT(*) = 0
        THEN 'PASS: Old reports unchanged'
        ELSE 'FAIL: Old reports changed'
    END AS scd_type2_test,
    COUNT(*) AS difference_count
FROM differences;

SELECT *
FROM dw.dim_vessel
WHERE vessel_id = 'V001'
ORDER BY effective_start;

SELECT COUNT(*) AS fact_row_count
FROM dw.fact_landing;
