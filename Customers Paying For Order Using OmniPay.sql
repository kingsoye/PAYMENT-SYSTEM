--#----------------------- Mapping Tables ----------------------#--
-- CUSTOMERS INFO
DROP TABLE IF EXISTS #tempCustomerOrgType;
select 
a.userid, a.organizationtypeid, b.organizationtype OrgType
INTO #tempCustomerOrgType
from VconnectMasterDWR..customerorganization a
INNER JOIN  VconnectMasterDWR..organizationtype b ON b.contentid=a.organizationtypeid
WHERE 
a.userid in (SELECT DISTINCT d.CustomerId FROM VconnectMasterDWR..OmnipayCustomerWallets d) 
AND a.businessid in (select distinct Fulfilement_Center_ID from  VconnectMasterDWR..Stock_Point_Master)
AND a.status=1
AND a.contentid in (select max(Contentid) from VconnectMasterDWR..CustomerOrganization c 
					WHERE c.Userid=a.Userid AND
					c.Businessid in (select distinct Fulfilement_Center_ID from VconnectMasterDWR..Stock_Point_Master) 
					and c.Status=1); 

DROP TABLE IF EXISTS #tempOmnipayCustomerinfo;
SELECT 
a.CustomerId, a.CustomerRef, a.WalletId, a.DateCreated, a.CreatedBy, 
b.Name as RetailerName, b.FullAddress as FullAddress, b.Email as Email, b.StateName  as RetailerStateName,
b.Phone as  Phone, b.alternatephone, b.alternatephone2,
(SELECT top 1 d.OrgType FROM #tempCustomerOrgType d WHERE d.userid = a.CustomerId)  OrgType
INTO #tempOmnipayCustomerinfo
FROM VconnectMasterDWR..OmnipayCustomerWallets a
INNER JOIN VconnectMasterDWR..BusinessAddressbook b ON b.Userid = a.CustomerId 
--AND isnull(b.status, 0) in (0,1,2,7) and b.Businessid = 76
AND b.contentid in (select max(contentid) from VconnectMasterDWR..BusinessAddressbook ab where ab.userid=a.CustomerId and ab.Businessid=76 and isnull(ab.status,0)in(0,1,2,7))
group by a.CustomerId, a.CustomerRef, a.WalletId, a.DateCreated, a.CreatedBy, 
b.Name, b.FullAddress, b.Email, b.StateName, b.Phone, b.alternatephone, b.alternatephone2; --,d.organizationtype; 





--#----------------------- OMNIPAY TRANSACTION TABLE -------------------#--
DROP TABLE IF EXISTS #cte1CustomerOmniPayOrderReport;
SELECT  
a.id, a.customerRef, 
(SELECT TOP 1 b.CustomerId FROM #tempOmnipayCustomerinfo b WHERE b.customerRef = a.customerRef) CustomerId,  
(SELECT TOP 1 b.WalletId FROM #tempOmnipayCustomerinfo b WHERE b.customerRef = a.customerRef) AS WalletId,
ISNULL((SELECT TOP 1 b.RetailerName FROM #tempOmnipayCustomerinfo b WHERE b.customerRef = a.customerRef),'') RetailerName,
(SELECT TOP 1 b.RetailerStateName FROM #tempOmnipayCustomerinfo b WHERE b.customerRef = a.customerRef) RetailerStateName,
(SELECT TOP 1 b.OrgType FROM #tempOmnipayCustomerinfo b WHERE b.customerRef = a.customerRef) OrgType,
(SELECT TOP 1 b.Phone FROM #tempOmnipayCustomerinfo b WHERE b.customerRef = a.customerRef) Phone,
ROUND(a.amount/100,2) amount,  
ROUND(a.walletPayment/100,2) walletPayment,	
ROUND(a.paylaterPayment/100,2) paylaterPayment,  
ROUND(a.promoPayment/100,2) promoPayment,
ROUND(a.orderValue/100,2) orderValue,
CAST(createdAt AS datetime) as CreatedTime,
event,
CASE 
WHEN event = 'orderpayment.successful' THEN 'debit'  
END AS transactionType
INTO #cte1CustomerOmniPayOrderReport
FROM VconnectMasterPOS..OmniPayOrderReport a
WHERE event = 'orderpayment.successful' AND a.userRef IS NULL;

DROP TABLE IF EXISTS #tempCustomerOmniPayOrderReport;
WITH #cte2CustomerOmniPayOrderReport AS (
SELECT a.*,
ROW_NUMBER() OVER (PARTITION BY a.customerRef ORDER BY a.CreatedTime DESC) as TransNoDesc
FROM #cte1CustomerOmniPayOrderReport a
WHERE a.WalletId IS NOT NULL
AND  ISNULL(a.RetailerName,'') NOT LIKE '%test%'
)
SELECT 
id, CustomerId, WalletId, RetailerName, RetailerStateName, OrgType, Phone, amount, walletPayment, paylaterPayment, 
promoPayment, orderValue,
CreatedTime, event, transactionType, TransNoDesc,(walletPayment + paylaterPayment + promoPayment) as AmountPaidForOrder
INTO #tempCustomerOmniPayOrderReport 
FROM #cte2CustomerOmniPayOrderReport;


--- Your Interest is 
select   
CreatedTime, CustomerId, event, transactionType, orderValue,  AmountPaidForOrder
FROM #tempCustomerOmniPayOrderReport;