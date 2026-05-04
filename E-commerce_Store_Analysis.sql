create database ecommerce_store_db;
use ecommerce_store_db;
show tables;
select * from customer_behavior;
select * from customer_churn;
select * from customers;

-- ========================================================= --
-- Data Cleaning 
-- ========================================================= --
#1.Customer Behaviour Table

#Remove Duplicate Records
select CustomerID,count(*) from customer_behavior group by CustomerID having count(*) >1;
-- No duplicates records.
select * from customer_behavior where OrderCount < 0 or CashbackAmount <0;
select * from customer_behavior where PreferedOrderCat is NULL;
-- No null values.
select * from customer_behavior where OrderAmountHikeFromlastYear = 0; 
update customer_behavior set OrderAmountHikeFromLastYear =0 where Tenure =0;
select * from customer_behavior where OrderAmountHikeFromLastYear =0 ; 
-- Changed OrderAmountHikeFromLastYear to 0 for 0 tenure.
select max(Tenure),min(Tenure) from customer_behavior;
alter table customer_behavior add column TenureBins varchar(20);
update customer_behavior set TenureBins =
   case when Tenure = 0 then '0'
   when Tenure between 1 and 10 then '1-10'
   when Tenure between 11 and 30 then '11-30'
   when Tenure between 31 and 49 then '31-49'
   else '50+'
   end;
-- Create TenureBins for better analysis.

#2.Customer Churn Table
select CustomerID,count(*) from customer_churn group by CustomerID having count(*) >1;
select distinct churn from customer_churn;
-- No duplicates records.
alter table customer_churn add column ChurnLabel varchar(20);
update customer_churn set ChurnLabel = 
case when Churn=1 then 'Churned'
else 'Retained' end;
-- Created label for better understanding.

#3.Customers Table
select CustomerID,count(*) from customers group by CustomerID having count(*) >1;
select * from customers where gender is Null or PreferredLoginDevice is Null or PreferredPaymentMode is NULL;
update customers set PreferredLoginDevice = "Mobile Phone" where PreferredLoginDevice ="Phone";
update customers set PreferredPaymentMode = "Cash on Delivery" where PreferredPaymentMode = "COD";
update customers set PreferredPaymentMode = "Credit Card" where PreferredPaymentMode = "CC";
-- No duplicates records and null values. Standarised the formats.


-- ========================================================= --
-- Joining Tables
-- ========================================================= --
create or replace view churn_analysis as
select
    cc.CustomerID,
    cc.Churn,
    cc.SatisfactionScore,
    cc.Complain,
    cc.DaySinceLastOrder,
    cc.WarehouseToHome,
    cc.ChurnLabel,

    c.Gender,
    c.MaritalStatus,
    c.CityTier,
    c.PreferredLoginDevice,
    c.PreferredPaymentMode,
    c.NumberofAddress,
	
    cb.Tenure,
    cb.TenureBins,
    cb.HourSpendOnApp,
    cb.NumberOfDeviceRegistered,
    cb.PreferedOrderCat,
    cb.OrderCount,
    cb.OrderAmountHikeFromlastYear,
    cb.CouponUsed,
    cb.CashbackAmount
    
from customers as c
left join customer_behavior as cb on c.CustomerID = cb.CustomerID
left join customer_churn as cc on c.CustomerID = cc.CustomerID;

select * from churn_analysis;
-- Created a single analytical view by joining all related tables

-- ========================================================= --
-- KPI Summary
-- ========================================================= --
select
count(*) as total_customers,
sum(case when Gender="Male" then 1 else 0 end) as total_male,
sum(case when Gender="Female" then 1 else 0 end) as total_female,
sum(churn) as churned_customers,
round(avg(Churn)*100,2) as churn_rate,
round(avg(SatisfactionScore)) as avg_satisfaction,
round(avg(OrderCount)) as avg_orders,
round(avg(Tenure)) as avg_tenure,
round(avg(HourSpendOnApp)) as avg_hour_spend_on_app
from churn_analysis;
-- A Quick KPI Summary.

-- ========================================================= --
-- Overall Churn Analysis
-- ========================================================= --

#1. What percentage of customers have churned?
select sum(case when churn=1 then 1 else 0 end) / count(distinct CustomerID) * 100 as churn_rate 
from churn_analysis;
-- Nearly 15.97 percentage of customers have churned.

#2.How does the churned vs retained customer count compare?
select churned.total_churn as total_churn,retained.total_retained as total_retained from
(select count(*) as total_churn from churn_analysis where churn=1) as churned,
(select count(*) as total_retained from churn_analysis where churn=0) as retained;
-- Out of the total customer base, 631 customers have churned, while 3,143 customers have been retained, 
-- indicating a strong retention rate.

#3.Is the churn rate significantly high for the business?
-- Refer #1 for churn percentage.
-- For e-commerce businesses, an annual churn rate in the range of 10%–20% is generally considered acceptable. 
-- With an annual churn rate of 15.97%, the business falls within this normal range, indicating that churn is not significantly high.

-- ========================================================= --
-- Demographic-Based Analysis
-- ========================================================= --

#1. Does churn vary by gender?
select gender, count(*) as total_customers,
sum(case when churn=1 then 1 else 0 end) as churned_customers,
round((sum(case when churn=1 then 1 else 0 end))/count(*) * 100.0,2) as churn_rate from churn_analysis group by gender;
-- Churn rate is higher among male customers (17.75%) compared to female customers (15.17%), indicating that male users are slightly more prone to churn.

#2.Which marital status group shows higher churn?
select MaritalStatus, count(*) as total_customers,
sum(case when churn=1 then 1 else 0 end) as churned_customers,
round(sum(case when churn=1 then 1 else 0 end)/count(*) * 100.0,2) as churn_rate from churn_analysis 
group by MaritalStatus order by churn_rate desc;
-- Single customers exhibit the highest churn rate at 26.27%.

#3.How does churn differ across city tiers?
select CityTier, count(*) as total_customers,
sum(case when churn=1 then 1 else 0 end) as churned_customers,
round(sum(case when churn=1 then 1 else 0 end)/count(*)*100.0,2) as churn_rate from churn_analysis
group by CityTier order by churn_rate;
-- Tier1 City have 14.65% churn rate(lowest),followed by Tier2 with 17.02% and Tier3 with 20.55(highest).

#4. Do customers with a higher number of addresses churn more?
select NumberofAddress, count(*) as total_customers,
sum(case when churn=1 then 1 else 0 end) as churned_customers,
round(sum(case when churn=1 then 1 else 0 end)/count(*) * 100.0,2)as churn_rate
from churn_analysis group by NumberofAddress order by churn_rate desc;
--  Customers with a higher number of addresses show a higher churn rate, indicating lower stability and higher likelihood of churn.

#5. Which preferred login device is associated with higher churn?
select PreferredLoginDevice, count(*) as total_customers,
sum(case when churn=1 then 1 else 0 end) as churned_customers,
round(sum(case when churn=1 then 1 else 0 end)/count(*) * 100.0,2)as churn_rate
from churn_analysis group by PreferredLoginDevice order by churn_rate desc;
-- Mobile Phone has the highest churn rate of 19.08% followed by Computer with 15.73%.

#6. Does payment mode preference influence churn behavior?
select PreferredPaymentMode, count(*) as total_customers, sum(case when churn=1 then 1 else 0 end) as churned_customers,
round(sum(case when churn=1 then 1 else 0 end)/count(*) * 100.0,2) as churn_rate from churn_analysis 
group by PreferredPaymentMode order by churn_rate desc;
-- Customers who prefer Credit Cards show the highest churn rate, while those using Debit Cards or Cash on Delivery churn less.

-- ========================================================= --
-- Customer Behavior Analysis
-- ========================================================= --

#1. Is churn higher among customers with low tenure?
select TenureBins, count(*) as total_customers,
sum(case when churn=1 then 1 else 0 end) as churned_customers,
round(sum(case when churn=1 then 1 else 0 end)/count(*) * 100.0,2) as churn_rate from churn_analysis 
group by TenureBins order by churn_rate desc;
-- Churn rate is highest among low-tenure customers, with 0-tenure customers showing a 52.81% churn rate,
-- while customers in the 30–49 and 50+ tenure bins exhibit 0% churn.

#2. How does churn vary by hours spent on the app?
select HourSpendOnApp, count(*) as total_customers, 
sum(case when churn=1 then 1 else 0 end)as churned_customers,
sum(case when churn=0 then 1 else 0 end)as retained_customers 
from churn_analysis group by HourSpendOnApp;
-- Churn is higher among moderately active users (2–3 hours),
-- while very low (0 hours) and very high (5 hours) app usage shows better retention.

#3. Do customers with fewer registered devices churn more?
select NumberOfDeviceRegistered,count(*) as total_customer,
sum(case when churn=1 then 1 else 0 end) as churned_customer,
round(sum(case when churn=1 then 1 else 0 end)/count(*) *100.0,2) as churn_rate from churn_analysis 
group by NumberOfDeviceRegistered order by churn_rate desc;
-- Customers with fewer registered devices tend to have a lower churn rate,
-- As the number of registered devices increases, the churn rate increases. 

#4. Which preferred order category has the highest churn?
select PreferedOrderCat, count(*) as total_customers, sum(case when churn=1 then 1 else 0 end) as churned_customers,
round(sum(case when churn=1 then 1 else 0 end)/count(*) *100.0,2) as churn_rate 
from churn_analysis group by PreferedOrderCat order by churn_rate desc ;
-- 'Mobile Phone' product category shows the highest churn rate among all preferred order categories.

#5. Which preferred order category has the least churn?
select PreferedOrderCat, count(*) as total_customers,sum(case when churn=1 then 1 else 0 end) as churned_customers ,
round(sum(case when churn=1 then 1 else 0 end)/count(*) *100.0,2) as churn_rate 
from churn_analysis group by PreferedOrderCat order by churn_rate ;
-- 'Grocery' product category shows the least churn rate among all preferred order categories.

#6. Does order count have an inverse relationship with churn?
select OrderCount, count(*) as total_customers, sum(case when churn=1 then 1 else 0 end) as churned_customers ,
round(sum(case when churn=1 then 1 else 0 end)/count(*) *100.0,2) as churn_rate 
from churn_analysis group by OrderCount order by churn_rate desc;
-- Yes, churn generally shows an inverse relationship with order count;
-- Zero churn at 12, 13, and 14 orders suggests these customers are highly engaged and unlikely to leave.
-- There's a spike at 16 orders (50% churn), but this likely reflects small sample size (only 2 churned customers). 
-- Similarly, the 15-order group shows elevated churn with just 2 customers.

#7. Are customers with low order growth from last year more likely to churn?
select OrderAmountHikeFromlastYear, count(*) as total_customers,sum(case when churn=1 then 1 else 0 end) as churned_customers ,
round(sum(case when churn=1 then 1 else 0 end)/count(*) *100.0,2) as churn_rate 
from churn_analysis group by OrderAmountHikeFromlastYear order by OrderAmountHikeFromlastYear;
-- Yes, nearly 52.81% churned customers have 0 order growth. 
-- Churn rates here are much lower (around 10–17%) compared to the “0” group.

-- ========================================================= --
-- Satisfaction & Experience Factors
-- ========================================================= --
#1. How does satisfaction score impact churn?
select SatisfactionScore, count(*) as total_customers,sum(case when churn=1 then 1 else 0 end) as churned_customers ,
round(sum(case when churn=1 then 1 else 0 end)/count(*) *100.0,2) as churn_rate 
from churn_analysis group by SatisfactionScore order by churn_rate desc;
-- Satisfaction score has a less impact on Churn rate as those who rated 5 has the highest churn rate(23.34%).

#2. Is churn higher among customers who have raised complaints?
select Complain, count(*) as total_customers,sum(case when churn=1 then 1 else 0 end) as churned_customers ,
round(sum(case when churn=1 then 1 else 0 end)/count(*) *100.0,2) as churn_rate 
from churn_analysis group by Complain order by churn_rate desc;
-- Yes, churn rate is higher among customers who have raised complaints.

#3. Does distance from warehouse to home influence churn?
select WarehouseToHome, count(*) as total_customers,sum(case when churn=1 then 1 else 0 end) as churned_customers ,
round(sum(case when churn=1 then 1 else 0 end)/count(*) *100.0,2) as churn_rate 
from churn_analysis group by WarehouseToHome order by churn_rate desc;
-- Distance has direct influence on the churn rate.
-- Extreme distances 29-36km has more churn rate whereas 6-13km distance has the lowest churn rates.

#4. Do customers with a higher days since last order show increased churn?
select DaySinceLastOrder, count(*) as total_customers,sum(case when churn=1 then 1 else 0 end) as churned_customers ,
round(sum(case when churn=1 then 1 else 0 end)/count(*) *100.0,2) as churn_rate 
from churn_analysis group by DaySinceLastOrder order by churn_rate desc;
-- Churn peaks among customers who ordered very recently (0–1 days),
-- while longer inactivity periods (12–18, 30–31 days) show no churn.

-- ========================================================= --
-- Offers, Discounts & Loyalty
-- ========================================================= --
#1. customers who use coupons churn less?
select case 
    when CouponUsed = 0 then 'No Coupon Used'
    else 'Coupon Used'
  end as coupon_group,
count(*) as total_customers,
sum(case when churn=1 then 1 else 0 end) as churned_customers ,
round(sum(case when churn=1 then 1 else 0 end)/count(*) *100.0,2) as churn_rate 
from churn_analysis group by coupon_group order by churn_rate desc;
-- Coupon users show a higher churn rate compared to non-coupon users,
-- suggesting that coupon usage alone does not ensure retention.

#2. How does cashback amount relate to churn?
select CashbackAmount, count(*) as total_customers,sum(case when churn=1 then 1 else 0 end) as churned_customers ,
round(sum(case when churn=1 then 1 else 0 end)/count(*) *100.0,2) as churn_rate 
from churn_analysis group by CashbackAmount order by churn_rate desc;
-- Cashback amount does not show a consistent relationship with churn.
-- Higher cashback(232,110,111) have higher churn rate whereas lower cashback(37,81) have 0 churn raate.

-- ========================================================= --
-- Customer Churn Rate by Product Category (Ranked)
-- ========================================================= --
with pref_ord as (select PreferedOrderCat, count(*) as total_customers, sum(case when churn=1 then 1 else 0 end) as churned_customers,
round(sum(case when churn=1 then 1 else 0 end)/count(*) *100.0,2) as churn_rate 
from churn_analysis group by PreferedOrderCat) 
select PreferedOrderCat, total_customers, churned_customers, churn_rate,
       rank() over (order by churn_rate desc) as churn_rank from pref_ord;
-- Customer preferred order categories are ranked by their churn rate, 
-- identifying which category’s customers are most likely to churn compared to others.

-- ========================================================= --
-- Churned Customers with Low Satisfaction and Complaints
-- ========================================================= --
select CustomerID, SatisfactionScore, Complain, Churn from churn_analysis where SatisfactionScore <=2 and Complain=1 and Churn=1;
-- 86 customers churned after reporting low satisfaction and complaints, indicating preventable service-driven customer loss.

-- ========================================================= --
-- Order Frequency–Based Customer Segmentation and Churn
-- ========================================================= --
With value_seg as 
(select CustomerID, OrderCount, 
case when OrderCount >= 7 then 'High Value'
when OrderCount >= 3 then 'Medium Value'
else 'Low Value' end as value_segment,churn from churn_analysis)
select value_segment, count(*) as total, avg(Churn)*100 as churn_rate
from value_seg group by value_segment;
-- Medium Value has the lowest churn rate,meaning this group is the most loyal.
-- Both Low and High-value segments show elevated churn risk, indicating the need for differentiated retention strategies.

-- ========================================================= --
-- Customer Segments with Highest Churn Probability
-- ========================================================= --
select CityTier, MaritalStatus, PreferredPaymentMode, round(avg(churn)*100,2) as churn_rate
from churn_analysis
group by CityTier, MaritalStatus, PreferredPaymentMode
order by churn_rate desc limit 10;
-- Customers in Tier-2 and Tier-3 cities using Cash on Delivery (COD) show the highest churn.
-- Tier-3 also churn heavily, especially with COD and UPI payments.
