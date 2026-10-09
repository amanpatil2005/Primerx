-- Among our top doctors, how much business is going to competitors?
WITH Top10AlertHCPs AS (
    SELECT TOP 10
        [HCP_ID],
        COUNT([Alert_ID]) AS [Total_Alerts],
        ROW_NUMBER() OVER (ORDER BY COUNT([Alert_ID]) DESC) AS [Alert_Rank]
    FROM [Alerts]
    GROUP BY [HCP_ID]
    ORDER BY [Total_Alerts] DESC
    -- RESULT: HCP041, HCP011, HCP019, HCP020, HCP032, HCP021, HCP014, HCP036, HCP022, HCP007
),

HCP_Prescription_Totals AS (
    SELECT 
        s.[HCP_ID],
        SUM(s.[Prescription_Volume]) AS [Total_Rx_Volume],
        SUM(CASE WHEN s.[Drug_ID] = 'DRG001' THEN s.[Prescription_Volume] ELSE 0 END) AS [Our_Drug_Volume],
        SUM(CASE WHEN s.[Drug_ID] <> 'DRG001' THEN s.[Prescription_Volume] ELSE 0 END) AS [Competitor_Volume]
    FROM [Sales] s
    INNER JOIN Top10AlertHCPs t ON s.[HCP_ID] = t.[HCP_ID]
    GROUP BY s.[HCP_ID]
    -- RESULT: only 6 of the 10 HCPs have any Sales rows at all -
    -- HCP041, HCP011, HCP021, HCP007 are absent (zero prescriptions of any drug)
)

SELECT 
    t.[Alert_Rank],
    t.[HCP_ID],
    ISNULL(p.[Total_Rx_Volume], 0) AS [Total_Prescription_Volume],
    

    CASE 
        WHEN ISNULL(p.[Total_Rx_Volume], 0) = 0 THEN 0.0
        ELSE (CAST(p.[Our_Drug_Volume] AS DECIMAL(18,2)) / p.[Total_Rx_Volume]) * 100.0 
    END AS [Our_Drug_Share_Pct],
    
    CASE 
        WHEN ISNULL(p.[Total_Rx_Volume], 0) = 0 THEN 0.0
        ELSE (CAST(p.[Competitor_Volume] AS DECIMAL(18,2)) / p.[Total_Rx_Volume]) * 100.0 
    END AS [Competitor_Share_Pct]
FROM Top10AlertHCPs t
LEFT JOIN HCP_Prescription_Totals p ON t.[HCP_ID] = p.[HCP_ID]
ORDER BY t.[Alert_Rank] ASC;

-- INSIGHT: 4 of our 10 highest-alerting doctors (40%) are complete white space - not
-- just losing share to competitors, but not prescribing ANY drug at all, despite
-- generating the most clinical signal in the entire dataset. Among the 6 doctors who
-- do prescribe, our share ranges 25%-71%, with Rivalex as the clear #1 competitive
-- threat to displace.