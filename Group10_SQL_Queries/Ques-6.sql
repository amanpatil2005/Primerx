-- Question 6: Did alerts actually change doctor behavior - before vs. after?
-- Part A: Top 10 HCPs by Percentage Lift

WITH FirstPositiveAlert AS (
    -- Step 1: First positive alert date per doctor
    SELECT 
        [HCP_ID],
        MIN([Alert_Date]) AS [First_Positive_Alert_Date]
    FROM [Alerts]
    WHERE [Lab_Result] = 'positive'
    GROUP BY [HCP_ID]
    -- RESULT: 214 HCPs 
),

HCP_Window_Volumes AS (
    -- Step 2: 90-day pre/post DRG001 prescription volume around each HCP's first positive alert
    SELECT 
        f.[HCP_ID],
        f.[First_Positive_Alert_Date],
        ISNULL(SUM(CASE 
            WHEN s.[Prescription_Date] >= DATEADD(day, -90, f.[First_Positive_Alert_Date]) 
             AND s.[Prescription_Date] < f.[First_Positive_Alert_Date] 
            THEN s.[Prescription_Volume] ELSE 0 END), 0) AS [Pre_Rx_Volume],
        ISNULL(SUM(CASE 
            WHEN s.[Prescription_Date] >= f.[First_Positive_Alert_Date] 
             AND s.[Prescription_Date] <= DATEADD(day, 90, f.[First_Positive_Alert_Date]) 
            THEN s.[Prescription_Volume] ELSE 0 END), 0) AS [Post_Rx_Volume]
    FROM FirstPositiveAlert f
    LEFT JOIN [Sales] s ON f.[HCP_ID] = s.[HCP_ID] AND s.[Drug_ID] = 'DRG001'
    GROUP BY f.[HCP_ID], f.[First_Positive_Alert_Date]
    -- RESULT: 214 rows; of these, 64 have Pre_Rx_Volume = 0 and Post_Rx_Volume > 0
    -- ("New Starters" - lift% undefined, excluded from Part A ranking below)
),

CalculatedLift AS (
    -- Step 3: Lift% = (Post - Pre) / Pre * 100, NULL when Pre = 0
    SELECT 
        [HCP_ID],
        [Pre_Rx_Volume],
        [Post_Rx_Volume],
        CASE 
            WHEN [Pre_Rx_Volume] = 0 THEN NULL
            ELSE ((CAST([Post_Rx_Volume] AS DECIMAL(18,2)) - [Pre_Rx_Volume]) / [Pre_Rx_Volume]) * 100.0
        END AS [Lift_Pct]
    FROM HCP_Window_Volumes
    -- RESULT: 150 rows have a defined (non-NULL) Lift_Pct (214 - 64 New Starters)
)

-- Step 4: Top 10 growers with highest defined percentage lift
SELECT TOP 10
    ROW_NUMBER() OVER (ORDER BY [Lift_Pct] DESC) AS [Rank],
    [HCP_ID],
    [Pre_Rx_Volume] AS [Total_Prescription_Volume_Before_Alert],
    [Post_Rx_Volume] AS [Total_Prescription_Volume_After_Alert],
    CAST([Lift_Pct] AS DECIMAL(18,2)) AS [Lift_Pct]
FROM CalculatedLift
WHERE [Lift_Pct] IS NOT NULL
ORDER BY [Lift_Pct] DESC;

-- INSIGHT: every doctor in this Top 10 had meaningful baseline prescribing (Pre_Rx_Volume
-- 8-72) - these are not near-zero-base outliers producing inflated percentages, they are
-- genuine multi-hundred-percent increases in an already-active prescribing pattern.


-- Part B: Behavioral Segment Summary Table

WITH FirstPositiveAlert AS (
    SELECT 
        [HCP_ID],
        MIN([Alert_Date]) AS [First_Positive_Alert_Date]
    FROM [Alerts]
    WHERE [Lab_Result] = 'positive'
    GROUP BY [HCP_ID]
    -- RESULT: 214 HCPs
),

HCP_Window_Volumes AS (
    SELECT 
        f.[HCP_ID],
        ISNULL(SUM(CASE WHEN s.[Prescription_Date] >= DATEADD(day, -90, f.[First_Positive_Alert_Date]) AND s.[Prescription_Date] < f.[First_Positive_Alert_Date] THEN s.[Prescription_Volume] ELSE 0 END), 0) AS [Pre_Rx_Volume],
        ISNULL(SUM(CASE WHEN s.[Prescription_Date] >= f.[First_Positive_Alert_Date] AND s.[Prescription_Date] <= DATEADD(day, 90, f.[First_Positive_Alert_Date]) THEN s.[Prescription_Volume] ELSE 0 END), 0) AS [Post_Rx_Volume]
    FROM FirstPositiveAlert f
    LEFT JOIN [Sales] s ON f.[HCP_ID] = s.[HCP_ID] AND s.[Drug_ID] = 'DRG001'
    GROUP BY f.[HCP_ID]
    -- RESULT: 214 rows 
),

SegmentedHCPs AS (
    -- Categorize per the case's 3-bucket rule
    SELECT 
        [HCP_ID],
        [Pre_Rx_Volume],
        [Post_Rx_Volume],
        CASE 
            WHEN [Pre_Rx_Volume] = 0 AND [Post_Rx_Volume] > 0 THEN 'New starters'
            WHEN [Pre_Rx_Volume] > 0 AND (((CAST([Post_Rx_Volume] AS DECIMAL(18,2)) - [Pre_Rx_Volume]) / [Pre_Rx_Volume]) * 100.0) >= 20.0 THEN 'Growers'
            ELSE 'Non-responders'
        END AS [Segment],
        CASE 
            WHEN [Pre_Rx_Volume] = 0 THEN 0.0  -- forces New Starters' lift to 0 so AVG() doesn't error;
                                                 -- excluded from the segment's TRUE average lift narrative below
            ELSE ((CAST([Post_Rx_Volume] AS DECIMAL(18,2)) - [Pre_Rx_Volume]) / [Pre_Rx_Volume]) * 100.0
        END AS [Lift_Pct]
    FROM HCP_Window_Volumes
    -- RESULT: New starters = 64 HCPs | Growers = 25 HCPs | Non-responders = 125 HCPs
)

-- Final segment KPIs
SELECT 
    [Segment],
    COUNT([HCP_ID]) AS [HCPs],
    CAST(AVG([Lift_Pct]) AS DECIMAL(18,2)) AS [Avg_Lift_Pct]
FROM SegmentedHCPs
GROUP BY [Segment]

UNION ALL

SELECT 
    'Total' AS [Segment],
    COUNT([HCP_ID]) AS [HCPs],
    CAST(AVG([Lift_Pct]) AS DECIMAL(18,2)) AS [Avg_Lift_Pct]
FROM SegmentedHCPs;



-- INSIGHT: Growers are the smallest segment (25 of 214, ~12%) but show by far the
-- strongest response (+323% avg lift) - proof the alert mechanism drives real
-- incremental behavior change when it lands on an already-engaged prescriber.
-- Non-responders are the largest segment (125, ~58%) and trend DOWN on average (-68%),
-- meaning alerts alone are not enough to move this majority group - a different
-- intervention (not just more alerts) is likely needed for them, which directly informs
-- the lower call-allocation weighting recommended for this segment in Q7.