Use Role sysadmin;

-- Create or replace the database
CREATE OR REPLACE DATABASE InsuranceDB;

-- Create or replace the schema
CREATE OR REPLACE SCHEMA InsuranceDB.data;

-- Create or replace the warehouse
CREATE OR REPLACE WAREHOUSE InsuranceWarehouse
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

-- Set the warehouse for use
USE WAREHOUSE InsuranceWarehouse;
-- Set the warehouse as default for the current user, if there is no default warehouse currently set
SET CUR_USER = (SELECT CURRENT_USER());
DESC USER IDENTIFIER($CUR_USER);
SET DEF_WAREHOUSE = (SELECT "value" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) WHERE "property" = 'DEFAULT_WAREHOUSE');
SET WAREHOUSE_TO_SET = IFF(EQUAL_NULL($DEF_WAREHOUSE, 'null'), 'INSURANCEWAREHOUSE', $DEF_WAREHOUSE);
ALTER USER IDENTIFIER($CUR_USER) SET DEFAULT_WAREHOUSE = $WAREHOUSE_TO_SET;
    
-- Create or replace the Customers table
CREATE OR REPLACE TABLE InsuranceDB.data.Customers (
    client_id STRING PRIMARY KEY,
    name STRING,
    start_date DATE,
    total_claimed FLOAT,
    claims ARRAY, 
    state STRING,  
    city STRING,  
    zip_code STRING,  
    driver_license_state STRING
);

-- Create or replace the Claims table (now includes line_items)
CREATE OR REPLACE TABLE InsuranceDB.data.Claims (
    claim_number STRING PRIMARY KEY,
    client_id STRING,
    claim_type STRING,
    claim_amount FLOAT,
    status STRING,
    date_filed DATE,
    line_items ARRAY,  -- Stores structured line items
    FOREIGN KEY (client_id) REFERENCES InsuranceDB.data.Customers(client_id)
);

-- Create or replace an internal stage

CREATE STAGE CLAIM_STORAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

CREATE OR REPLACE TABLE InsuranceDB.data.SupportDocs_Vectorized (
    file_name STRING,
    content STRING
);

INSERT INTO InsuranceDB.data.SupportDocs_Vectorized (file_name, content)
VALUES ('commercial_fleet_insurance_appraisal.pdf', '
# Appraisal Clause Considerations for Commercial Fleet Insurance

## Overview
Commercial fleet insurance policies contain appraisal clauses to resolve valuation disputes.

## Key Considerations
- **Bulk Valuation Adjustments:** Large fleets often receive fleet-based discounts that impact appraisal calculations.
- **Depreciation Metrics:** Commercial use vehicles, including rental snowmobiles, may follow accelerated depreciation schedules.
- **Dispute Resolution Process:** Companies may use third-party fleet valuation experts to resolve claim disagreements.

## Additional Resources
Check fleet insurance policies to understand appraisal and dispute resolution procedures.
');

INSERT INTO InsuranceDB.data.SupportDocs_Vectorized (file_name, content)
VALUES ('rental_vehicle_insurance_appraisal.pdf', '
# Appraisal Clauses for Rental Vehicles and Temporary Insurance Policies

## Overview
Short-term rental vehicle insurance policies include specific appraisal clauses due to varying risk exposure.

## Coverage Scope
- **Rental Cars & Snowmobiles:** Seasonal rental agreements may define damage appraisal differently.
- **Policyholder vs. Rental Agency Disputes:** Insurers may only cover factory parts, not additional rental features.
- **Third-Party Involvement:** Many rental policies require arbitration through a neutral third-party adjuster.

## Additional Resources
Review rental agreements for details on how claim disputes are handled.
');

INSERT INTO InsuranceDB.data.SupportDocs_Vectorized (file_name, content)
VALUES ('high_risk_auto_insurance_appraisal.pdf', '
# Arbitration and Appraisal Clauses in Auto Insurance for High-Risk Drivers

## Overview
High-risk drivers face stricter insurance appraisal clauses due to increased claim probability.

## Key Provisions
- **Higher Deductibles:** Some policies adjust claims based on higher-than-average deductibles.
- **Mandatory Arbitration:** High-risk policies often require arbitration in case of disputes.
- **Snowmobile Coverage:** Some policies classify seasonal vehicle claims under high-risk due to off-road use.

## Additional Resources
Check with insurers about risk-classified policies and how disputes are managed.
');

INSERT INTO InsuranceDB.data.SupportDocs_Vectorized (file_name, content)
VALUES ('catastrophic_damage_insurance_appraisal.pdf', '
# Appraisal Clauses in Catastrophic Damage Claims

## Overview
Large-scale damage from natural disasters often triggers special appraisal clauses in insurance policies.

## Common Scenarios
- **Total Loss Valuation:** Appraisals determine whether a vehicle is a total loss.
- **Multi-Vehicle Claims:** Large claims affecting multiple policyholders require standardized valuations.
- **Snowmobile and Seasonal Vehicles:** Winter storms may lead to mass appraisal disputes over snowmobile damages.

## Additional Resources
Verify with your insurer how total loss appraisals are handled in large-scale claims.
');

INSERT INTO InsuranceDB.data.SupportDocs_Vectorized (file_name, content)
VALUES ('classic_vehicle_insurance_appraisal.pdf', '
# Appraisal Clauses for Classic and Collector Vehicle Insurance

## Overview
Classic and collector vehicle insurance policies include specialized appraisal clauses due to fluctuating market values.

## Policy Considerations
- **Agreed Value vs. Market Value:** Many classic car policies use agreed-value coverage, bypassing standard depreciation rules.
- **Appraisal Frequency:** Periodic reappraisals may be required to maintain coverage accuracy.
- **Seasonal Use Considerations:** Policies may include snowmobiles under classic vehicle insurance if stored long-term.

## Additional Resources
Consult classic vehicle insurers to understand appraisal requirements for rare or vintage vehicles.
');

INSERT INTO InsuranceDB.data.SupportDocs_Vectorized (file_name, content)
VALUES ('inflation_impact_insurance_appraisal.pdf', '
# Appraisal Clauses and the Impact of Inflation on Insurance Claims

## Overview
Rising costs of vehicle parts and labor impact insurance claim appraisals.

## Key Issues
- **Inflation Adjustments:** Some insurers adjust coverage limits annually to keep pace with inflation.
- **Supply Chain Delays:** Replacement parts may be valued higher than pre-inflation estimates.
- **Snowmobiles and Off-Road Vehicles:** High-end parts for specialized vehicles can fluctuate significantly in value.

## Additional Resources
Check your policy for inflation-adjusted claim limits.
');

INSERT INTO InsuranceDB.data.SupportDocs_Vectorized (file_name, content)
VALUES ('aftermarket_vehicle_modifications_appraisal.pdf', '
# Appraisal Clause Considerations for Vehicles with Aftermarket Modifications

## Overview
Vehicles with aftermarket modifications require specialized appraisals to determine true claim values.

## Key Coverage Factors
- **Custom Equipment Endorsements:** Some insurers require add-ons to cover non-factory modifications.
- **Depreciation Calculations:** Aftermarket parts may have different depreciation rates compared to OEM components.
- **Dispute Resolution for Custom Work:** Snowmobiles and ATVs with performance modifications often require third-party assessment.

## Additional Resources
Verify whether your policy includes additional coverage for aftermarket modifications.
');

CREATE OR REPLACE CORTEX SEARCH SERVICE support_docs_search
  ON content
  ATTRIBUTES file_name
  WAREHOUSE = insurancewarehouse
  TARGET_LAG = '1 hour'
  AS (
    SELECT
        file_name,
        content
    FROM InsuranceDB.data.SupportDocs_Vectorized
);

INSERT INTO InsuranceDB.data.Claims (claim_number, client_id, claim_type, claim_amount, status, date_filed, line_items) SELECT 'CLM-367168', 'CUST0006', 'Health', 20022.58, 'Approved', DATE '2019-10-22', ARRAY_CONSTRUCT(ARRAY_CONSTRUCT('RC001', 'Repair Costs', 308.47), ARRAY_CONSTRUCT('PD003', 'Property Damage', 4532.35), ARRAY_CONSTRUCT('ER007', 'Equipment Replacement', 2285.83), ARRAY_CONSTRUCT('RC001', 'Repair Costs', 3509.33));
INSERT INTO InsuranceDB.data.Claims (claim_number, client_id, claim_type, claim_amount, status, date_filed, line_items) SELECT 'CLM-594826', 'CUST0008', 'Health', 9220.62, 'Denied', DATE '2021-04-18', ARRAY_CONSTRUCT(ARRAY_CONSTRUCT('CF006', 'Consultation Fees', 3331.68), ARRAY_CONSTRUCT('PD003', 'Property Damage', 4856.37));
INSERT INTO InsuranceDB.data.Claims (claim_number, client_id, claim_type, claim_amount, status, date_filed, line_items) SELECT 'CLM-802822', 'CUST0060', 'Life', 6403.84, 'Under Review', DATE '2016-06-17', ARRAY_CONSTRUCT(ARRAY_CONSTRUCT('PD003', 'Property Damage', 3241.41), ARRAY_CONSTRUCT('ER007', 'Equipment Replacement', 1408.17), ARRAY_CONSTRUCT('LF004', 'Legal Fees', 623.76), ARRAY_CONSTRUCT('PD003', 'Property Damage', 4965.53));
INSERT INTO InsuranceDB.data.Claims (claim_number, client_id, claim_type, claim_amount, status, date_filed, line_items) SELECT 'CLM-330688', 'CUST0005', 'Health', 37048.62, 'Under Review', DATE '2015-09-10', ARRAY_CONSTRUCT(ARRAY_CONSTRUCT('LF004', 'Legal Fees', 3585.53), ARRAY_CONSTRUCT('RC001', 'Repair Costs', 1253.93), ARRAY_CONSTRUCT('CF006', 'Consultation Fees', 3762.57));
INSERT INTO InsuranceDB.data.Claims (claim_number, client_id, claim_type, claim_amount, status, date_filed, line_items) SELECT 'CLM-665240', 'CUST0087', 'Life', 18282.89, 'Approved', DATE '2020-07-07', ARRAY_CONSTRUCT(ARRAY_CONSTRUCT('RC005', 'Rental Car', 4737.18), ARRAY_CONSTRUCT('RC005', 'Rental Car', 3447.19), ARRAY_CONSTRUCT('RC001', 'Repair Costs', 2195.11));
INSERT INTO InsuranceDB.data.Claims (claim_number, client_id, claim_type, claim_amount, status, date_filed, line_items) SELECT 'CLM-608926', 'CUST0013', 'Home', 27283.51, 'Pending', DATE '2020-07-22', ARRAY_CONSTRUCT(ARRAY_CONSTRUCT('LF004', 'Legal Fees', 1847.66), ARRAY_CONSTRUCT('RC001', 'Repair Costs', 288.22), ARRAY_CONSTRUCT('ER007', 'Equipment Replacement', 2745.08), ARRAY_CONSTRUCT('ER007', 'Equipment Replacement', 1113.04));
INSERT INTO InsuranceDB.data.Claims (claim_number, client_id, claim_type, claim_amount, status, date_filed, line_items) SELECT 'CLM-365178', 'CUST0010', 'Health', 664.96, 'Approved', DATE '2016-05-28', ARRAY_CONSTRUCT(ARRAY_CONSTRUCT('CF006', 'Consultation Fees', 183.09), ARRAY_CONSTRUCT('ME002', 'Medical Expenses', 1236.33), ARRAY_CONSTRUCT('RC005', 'Rental Car', 2536.67), ARRAY_CONSTRUCT('ME002', 'Medical Expenses', 863.98), ARRAY_CONSTRUCT('RC005', 'Rental Car', 3989.21));
INSERT INTO InsuranceDB.data.Claims (claim_number, client_id, claim_type, claim_amount, status, date_filed, line_items) SELECT 'CLM-215730', 'CUST0019', 'Home', 15105.4, 'Pending', DATE '2019-06-16', ARRAY_CONSTRUCT(ARRAY_CONSTRUCT('RC005', 'Rental Car', 4817.78), ARRAY_CONSTRUCT('CF006', 'Consultation Fees', 1760.24), ARRAY_CONSTRUCT('PD003', 'Property Damage', 197.28), ARRAY_CONSTRUCT('ER007', 'Equipment Replacement', 1278.23), ARRAY_CONSTRUCT('RC005', 'Rental Car', 1753.11));
INSERT INTO InsuranceDB.data.Claims (claim_number, client_id, claim_type, claim_amount, status, date_filed, line_items) SELECT 'CLM-587954', 'CUST0044', 'Life', 36319.06, 'Approved', DATE '2018-12-29', ARRAY_CONSTRUCT(ARRAY_CONSTRUCT('ME002', 'Medical Expenses', 2023.88), ARRAY_CONSTRUCT('RC005', 'Rental Car', 465.89), ARRAY_CONSTRUCT('RC001', 'Repair Costs', 2644.47), ARRAY_CONSTRUCT('ER007', 'Equipment Replacement', 4754.63));
INSERT INTO InsuranceDB.data.Claims (claim_number, client_id, claim_type, claim_amount, status, date_filed, line_items) SELECT 'CLM-344800', 'CUST0024', 'Life', 13083.97, 'Approved', DATE '2023-02-13', ARRAY_CONSTRUCT(ARRAY_CONSTRUCT('ME002', 'Medical Expenses', 1294.9), ARRAY_CONSTRUCT('CF006', 'Consultation Fees', 3153.95));

INSERT INTO InsuranceDB.data.Customers 
(client_id, name, start_date, total_claimed, claims, state, city, zip_code, driver_license_state)
SELECT 'CUST0959', 'Steven Bush', DATE '2020-11-07', 480219.25, 
ARRAY_CONSTRUCT('CLM-100958', 'CLM-100959', 'CLM-100960', 'CLM-100961'),
'MI', 'Detroit', '48226', 'OH';

INSERT INTO InsuranceDB.data.Customers 
(client_id, name, start_date, total_claimed, claims, state, city, zip_code, driver_license_state)
SELECT 'CUST0960', 'Kayla Powers', DATE '2020-12-08', 480720.0, 
ARRAY_CONSTRUCT('CLM-100959', 'CLM-100960', 'CLM-100961', 'CLM-100962', 'CLM-100963'),
'PA', 'Philadelphia', '19103', 'NY';

INSERT INTO InsuranceDB.data.Customers 
(client_id, name, start_date, total_claimed, claims, state, city, zip_code, driver_license_state)
SELECT 'CUST0961', 'Adam Smith', DATE '2020-01-09', 481220.75, 
ARRAY_CONSTRUCT('CLM-100960'),
'TX', 'Austin', '73301', 'TX';

INSERT INTO InsuranceDB.data.Customers 
(client_id, name, start_date, total_claimed, claims, state, city, zip_code, driver_license_state)
SELECT 'CUST0962', 'Angel Miller', DATE '2020-02-10', 481721.5, 
ARRAY_CONSTRUCT('CLM-100961', 'CLM-100962'),
'CA', 'Los Angeles', '90001', 'NV';

INSERT INTO InsuranceDB.data.Customers 
(client_id, name, start_date, total_claimed, claims, state, city, zip_code, driver_license_state)
SELECT 'CUST0963', 'Douglas Williams', DATE '2020-03-11', 482222.25, 
ARRAY_CONSTRUCT('CLM-100962', 'CLM-100963', 'CLM-100964'),
'FL', 'Miami', '33101', 'GA';

INSERT INTO InsuranceDB.data.Customers 
(client_id, name, start_date, total_claimed, claims, state, city, zip_code, driver_license_state)
SELECT 'CUST0964', 'Erin Jenkins', DATE '2020-04-12', 482723.0, 
ARRAY_CONSTRUCT('CLM-100963', 'CLM-100964', 'CLM-100965', 'CLM-100966'),
'NY', 'New York', '10001', 'NJ';

INSERT INTO InsuranceDB.data.Customers 
(client_id, name, start_date, total_claimed, claims, state, city, zip_code, driver_license_state)
SELECT 'CUST0965', 'Edward Jensen', DATE '2020-05-13', 483223.75, 
ARRAY_CONSTRUCT('CLM-100964', 'CLM-100965', 'CLM-100966', 'CLM-100967', 'CLM-100968'),
'IL', 'Chicago', '60601', 'MO';

INSERT INTO InsuranceDB.data.Customers 
(client_id, name, start_date, total_claimed, claims, state, city, zip_code, driver_license_state)
SELECT 'CUST0966', 'Brian Aguilar', DATE '2020-06-14', 483724.5, 
ARRAY_CONSTRUCT('CLM-100965'),
'WA', 'Seattle', '98101', 'WA';

INSERT INTO InsuranceDB.data.Customers 
(client_id, name, start_date, total_claimed, claims, state, city, zip_code, driver_license_state)
SELECT 'CUST0967', 'Sarah Harris', DATE '2020-07-15', 484225.25, 
ARRAY_CONSTRUCT('CLM-100966', 'CLM-100967'),
'OH', 'Columbus', '43215', 'PA';

INSERT INTO InsuranceDB.data.Customers 
(client_id, name, start_date, total_claimed, claims, state, city, zip_code, driver_license_state)
SELECT 'CUST0968', 'Sarah Griffin', DATE '2020-08-16', 484726.0, 
ARRAY_CONSTRUCT('CLM-100967', 'CLM-100968', 'CLM-100969'),
'GA', 'Atlanta', '30301', 'FL';