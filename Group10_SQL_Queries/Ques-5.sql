-- Question 5: Which accounts represent the largest untapped prescription opportunity?

WITH DoctorOurDrugSales AS (
   
    SELECT 
        [HCP_ID],
        SUM([Prescription_Volume]) AS [HCP_Total_Volume]
    FROM [Sales]
    WHERE [Drug_ID] = 'DRG001'
    GROUP BY [HCP_ID]
    -- RESULT: subset of HCPs who have ever written a DRG001 script
),

AccountMetrics AS (
    
    SELECT 
        aff.[Account_ID],
        aff.[Account_Name],
        COUNT(DISTINCT aff.[HCP_ID]) AS [Affiliated_Doctors],
        COUNT(DISTINCT CASE WHEN d.[HCP_Total_Volume] > 0 THEN aff.[HCP_ID] END) AS [Active_Doctors],
        SUM(ISNULL(d.[HCP_Total_Volume], 0)) AS [Our_Drug_Prescription_Volume]
    FROM [Affiliation] aff
    LEFT JOIN DoctorOurDrugSales d ON aff.[HCP_ID] = d.[HCP_ID]
    GROUP BY aff.[Account_ID], aff.[Account_Name]
    -- RESULT: 108 total accounts. 1 account (ACC022, 2 affiliated doctors) has
    -- Active_Doctors = 0 - filtered out below rather than blended into the ratio ranking.
)

SELECT TOP 10
    ROW_NUMBER() OVER (ORDER BY 
        (CAST([Our_Drug_Prescription_Volume] AS DECIMAL(18,4)) / [Active_Doctors]) ASC
    ) AS [Rank],
    [Account_ID],
    [Account_Name],
    [Affiliated_Doctors],
    [Active_Doctors],
    [Our_Drug_Prescription_Volume],
    CAST((CAST([Our_Drug_Prescription_Volume] AS DECIMAL(18,2)) / [Active_Doctors]) AS DECIMAL(18,2))
        AS [Prescription_Volume_per_Active_Doctor]
FROM AccountMetrics
WHERE [Active_Doctors] > 0   
ORDER BY [Prescription_Volume_per_Active_Doctor] ASC;

WITH DoctorOurDrugSales AS (
    SELECT 
        [HCP_ID],
        SUM([Prescription_Volume]) AS [HCP_Total_Volume]
    FROM [Sales]
    WHERE [Drug_ID] = 'DRG001'
    GROUP BY [HCP_ID]
),

AccountMetrics AS (
    SELECT 
        aff.[Account_ID],
        aff.[Account_Name],
        COUNT(DISTINCT aff.[HCP_ID]) AS [Affiliated_Doctors],
        COUNT(DISTINCT CASE WHEN d.[HCP_Total_Volume] > 0 THEN aff.[HCP_ID] END) AS [Active_Doctors],
        SUM(ISNULL(d.[HCP_Total_Volume], 0)) AS [Our_Drug_Prescription_Volume]
    FROM [Affiliation] aff
    LEFT JOIN DoctorOurDrugSales d ON aff.[HCP_ID] = d.[HCP_ID]
    GROUP BY aff.[Account_ID], aff.[Account_Name]
)

SELECT 
    [Account_ID],
    [Account_Name],
    [Affiliated_Doctors],
    [Active_Doctors],
    [Our_Drug_Prescription_Volume]
FROM AccountMetrics
WHERE [Active_Doctors] = 0
ORDER BY [Affiliated_Doctors] DESC;

-- RESULT: ACC022 - 2 affiliated doctors, 0 active, 0 Rx volume - pure white space.
--
-- INSIGHT: Account size does NOT predict prescribing efficiency - ACC003 has 24
-- affiliated doctors (one of the largest accounts in the dataset) but ranks #5 for
-- lowest volume-per-active-doctor, while single-doctor accounts (ACC017, ACC023)
-- also show low efficiency for a different reason (a small base). The two failure
-- modes require different fixes: ACC003-type accounts need broader activation across
-- an already-large doctor base, while ACC017/ACC023-type accounts need to convert
-- their few doctors more deeply. ACC022, separately, has zero active prescribers
-- despite having doctors on record - a distinct "complete white space" problem that
-- a volume-per-doctor ratio alone would understate or misrank if left in the table.
