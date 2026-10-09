-- Q1 Who are the most active doctors and are they helping our product?


--Ranking 1 - Top 10 by Alert Volume
select top 10
HCP_Id, count (Alert_ID)
from alerts
group by HCP_ID
Order by count (Alert_ID) desc

-- INSIGHT: These 10 doctors each generate 170+ alerts (over the ~18-month
-- window) - worth sanity-checking whether this reflects a large patient panel or
-- repeat testing on a smaller set of patients before treating alert volume as pure signal.

--Ranking 2 - Top 10 by prescription volume
select top 10
s.Hcp_id, sum (s.prescription_volume) 
from sales as s
where hcp_id in  (select distinct a.HCP_ID from alerts as a )
group by s.HCP_ID
order by sum (s.prescription_volume) desc

--INSIGHT: Only ONE HCP (HCP019) appears in BOTH Top-10 lists -
-- i.e., the doctors who are most clinically "flagged" are almost entirely a
-- DIFFERENT population from the doctors who are the biggest overall prescribers.
-- High alert volume is not, by itself, a proxy for high prescribing activity.