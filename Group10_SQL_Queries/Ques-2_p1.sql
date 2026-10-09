-- Question 2: Which doctors see the need but don't act on it?
-- part 1
WITH FirstPositiveAlert AS (
    SELECT 
        [HCP_ID],
        MIN([Alert_Date]) AS [First_Positive_Alert_Date],
        COUNT([Alert_ID]) AS [Total_Positive_Alerts]
    FROM [Alerts]
    WHERE [Lab_Result] = 'positive'
    GROUP BY [HCP_ID]

 -- RESULT: 214 unique HCPs have at least 1 positive alert (universe for this question)
),

PostAlertActivity AS (
    SELECT DISTINCT
        f.[HCP_ID]
    FROM FirstPositiveAlert f
    INNER JOIN [Sales] s 
        ON f.[HCP_ID] = s.[HCP_ID]
    WHERE s.[Prescription_Date] >= f.[First_Positive_Alert_Date]
      AND s.[Prescription_Date] <= DATEADD(day, 30, f.[First_Positive_Alert_Date])

-- RESULT: 146 of the 214 HCPs (~68%) had at least one Rx within the 30-day window
)


SELECT TOP 10
    ROW_NUMBER() OVER (ORDER BY f.[Total_Positive_Alerts] DESC) AS [Rank],
    f.[HCP_ID],
    f.[Total_Positive_Alerts] AS [Positive_Alerts]
FROM FirstPositiveAlert f
LEFT JOIN PostAlertActivity p 
    ON f.[HCP_ID] = p.[HCP_ID]
WHERE p.[HCP_ID] IS NULL 
ORDER BY [Positive_Alerts] DESC;

-- INSIGHT: HCP041, HCP011, HCP021, and HCP007 also appear in Q1's Top-10 by total
-- alert volume AND in Q3's zero-prescriber list - this is the same core group of
-- doctors showing up across three independent cuts of the data. They represent the
-- single highest-conviction outreach priority: doctors who are clearly seeing
-- clinical need (high alert volume, including repeat positive results) but have
-- written literally zero prescriptions for anything.







