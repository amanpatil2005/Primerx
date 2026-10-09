-- Question 4: Top 10 High-Alert Accounts Ranked by Lowest Conversion
WITH AccountAlerts AS (
    SELECT 
        aff.[Account_ID],
        aff.[Account_Name],
        COUNT(al.[Alert_ID]) AS [Total_Alerts]
    FROM [Affiliation] aff
    INNER JOIN [Alerts] al ON aff.[HCP_ID] = al.[HCP_ID]
    GROUP BY aff.[Account_ID], aff.[Account_Name]
 -- RESULT: 74 unique accounts have at least 1 mapped alert
 -- (note: 4 HCPs in Alerts have no Affiliation record, so their alerts are excluded here)
),

Top10AlertAccounts AS (
        SELECT TOP 10
        [Account_ID],
        [Account_Name],
        [Total_Alerts]
    FROM AccountAlerts
    ORDER BY [Total_Alerts] DESC
-- RESULT: ACC001 (3,296) is a massive outlier
),

AccountOurDrugSales AS (
    SELECT 
        aff.[Account_ID],
        COUNT(s.[Prescription_ID]) AS [Our_Drug_Prescription_Count]
    FROM [Affiliation] aff
    INNER JOIN [Sales] s ON aff.[HCP_ID] = s.[HCP_ID]
    WHERE s.[Drug_ID] = 'DRG001' -- Filter specifically for Nexavir
    GROUP BY aff.[Account_ID]
 -- RESULT: all 10 top-alert accounts have at least some DRG001 activity
)

SELECT 
    ROW_NUMBER() OVER (ORDER BY 
        CASE 
            WHEN t.[Total_Alerts] = 0 THEN 0.0
            ELSE (CAST(ISNULL(s.[Our_Drug_Prescription_Count], 0) AS DECIMAL(18,4)) / t.[Total_Alerts])
        END ASC
    ) AS [Rank],
    t.[Account_ID],
    t.[Account_Name],
    t.[Total_Alerts],
    ISNULL(s.[Our_Drug_Prescription_Count], 0) AS [Our_Drug_Prescription_Count],
    
    CASE 
        WHEN t.[Total_Alerts] = 0 THEN 0.0
        ELSE (CAST(ISNULL(s.[Our_Drug_Prescription_Count], 0) AS DECIMAL(18,2)) / t.[Total_Alerts]) 
    END AS [Conversion_Ratio_Pct]
FROM Top10AlertAccounts t
LEFT JOIN AccountOurDrugSales s ON t.[Account_ID] = s.[Account_ID]
ORDER BY [Conversion_Ratio_Pct] ASC;

-- INSIGHT: ACC001, ACC002, ACC003 - the three largest-volume accounts - occupy the
-- bottom 3 conversion ranks. This is not a small-account problem; it's concentrated
-- in the hospitals generating the most clinical signal in absolute terms, making them
-- the highest-value targets for account-level intervention (formulary access,
-- administrative barriers, KOL engagement) rather than simple doctor-level outreach.