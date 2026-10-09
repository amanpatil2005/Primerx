-- PART 2 (FUNNEL)
WITH FirstPositiveAlert AS (
    SELECT 
        [HCP_ID],
        MIN([Alert_Date]) AS [First_Positive_Alert_Date],
        COUNT([Alert_ID]) AS [Total_Positive_Alerts]
    FROM [Alerts]
    WHERE [Lab_Result] = 'positive'
    GROUP BY [HCP_ID]
),

PostAlertActivity AS (
    SELECT DISTINCT
        f.[HCP_ID]
    FROM FirstPositiveAlert f
    INNER JOIN [Sales] s 
        ON f.[HCP_ID] = s.[HCP_ID]
    WHERE s.[Prescription_Date] >= f.[First_Positive_Alert_Date]
      AND s.[Prescription_Date] <= DATEADD(day, 30, f.[First_Positive_Alert_Date])
),

FunnelBase AS (
    SELECT 
        f.[HCP_ID],
        f.[Total_Positive_Alerts],
        CASE 
            WHEN p.[HCP_ID] IS NOT NULL THEN 1 
            ELSE 0 
        END AS [Has_Prescribed]
    FROM FirstPositiveAlert f
    LEFT JOIN PostAlertActivity p 
        ON f.[HCP_ID] = p.[HCP_ID]     -- RESULT: 214 rows; 198 have Total_Positive_Alerts > 1; 68 have Has_Prescribed = 0      
)
SELECT
    -- Doctors with at least one positive alert
    COUNT(CASE WHEN [Total_Positive_Alerts] >= 1 THEN 1 END) 
        AS [Funnel_Step_1_At_Least_One_Positive_Alert],
    
    -- Doctors with multiple positive alerts (higher potential load)
    COUNT(CASE WHEN [Total_Positive_Alerts] > 1 THEN 1 END) 
        AS [Funnel_Step_2_Multiple_Positive_Alerts],
    
    -- High unmet need (multiple positive alerts but zero 30-day follow-through)
    COUNT(CASE WHEN [Total_Positive_Alerts] > 1 AND [Has_Prescribed] = 0 THEN 1 END) 
        AS [Funnel_Step_3_Multiple_Alerts_But_Zero_Activity]
FROM FunnelBase;

-- INSIGHT: Roughly 1 in 3 doctors who are repeatedly seeing positive lab signals
-- take zero prescribing action within 30 days. This is the core "leaky funnel"