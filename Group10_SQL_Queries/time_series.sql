-- Time Analysis: 18-Month Trend for Our Drug (DRG001)
SELECT 
    -- Extract Year and Month for chronological sorting
    YEAR(s.[Prescription_Date]) AS [Sales_Year],
    MONTH(s.[Prescription_Date]) AS [Sales_Month],
    
    -- Format as 'YYYY-MM' for clean presentation labels
    FORMAT(s.[Prescription_Date], 'yyyy-MM') AS [Year_Month],
    
    -- Volume and Depth KPIs
    SUM(s.[Prescription_Volume]) AS [Total_Nexavir_Volume],
    COUNT(s.[Prescription_ID]) AS [Total_Prescription_Events]
    
    -- Efficiency KPI: Average volume written per active doctor that month
    CAST(SUM(s.[Prescription_Volume]) AS DECIMAL(18,2)) / COUNT(DISTINCT s.[HCP_ID]) AS [Volume_per_HCP]
FROM [Sales] s
WHERE s.[Drug_ID] = 'DRG001' -- Isolate Nexavir
GROUP BY 
    YEAR(s.[Prescription_Date]), 
    MONTH(s.[Prescription_Date]),
    FORMAT(s.[Prescription_Date], 'yyyy-MM')
ORDER BY 
    [Sales_Year] ASC, 
    [Sales_Month] ASC
   