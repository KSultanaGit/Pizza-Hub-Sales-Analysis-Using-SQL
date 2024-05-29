

create database pizzahub_case_study;
use pizzahub_case_study;
#drop tables if exists pizza_names,pizza_toppings,pizza_recipes,runners_orders,customer_orders,runners_table;

create table pizza_names (pizza_id int PRIMARY KEY, pizza_name varchar(40));

create table pizza_toppings (topping_id int primary key, topping_name varchar(20));

create table pizza_recipes (
pizza_id int, 
toppings int,
foreign key (pizza_id) references pizza_names(pizza_id),
foreign key (toppings) references pizza_toppings(topping_id)
);


create table runners_table (runner_id int primary key,registration_date date);

create table runner_orders(
order_id int primary key,
runner_id int,
pickup_time timestamp,
distance varchar(20),
duration varchar(20),
cancellation varchar(50),
foreign key (runner_id) references runners_table(runner_id)
);


create table customer_orders(
order_id int,
customer_id int,
pizza_id int,
exclusions varchar(10),
extras varchar(10),
order_time timestamp,
foreign key (order_id) references runner_orders(order_id),
foreign key (pizza_id) references pizza_names(pizza_id)

);
-- import csvs ------------------------------------------------------------------------------------

#customer order table
select * from customer_orders;

#1.data cleaning and preprocessing
# handling missing/null values in customer order table
CREATE TABLE tcustomer_orders( SELECT order_id, customer_id, pizza_id,
CASE
WHEN exclusions is null OR exclusions LIKE 'null' OR exclusions LIKE 'NaN' THEN  ''
ELSE exclusions
END AS exclusions,
CASE
WHEN extras is NULL or extras LIKE 'null' or extras LIKE 'NaN'THEN ''
ELSE extras
END AS extras,
order_time
FROM customer_orders);
SELECT * FROM tcustomer_orders;

#changing datatypes in tcustomer_orders
ALTER TABLE tcustomer_orders
MODIFY COLUMN order_time TIMESTAMP;

#runner orders table
SELECT * FROM runner_orders;

#handling missing/null values in trunner_orders

CREATE TABLE trunner_orders
(SELECT order_id, runner_id,
CASE
	WHEN pickup_time is null or pickup_time LIKE 'null' THEN NULL
	ELSE pickup_time
END AS pickup_time,
CASE
	WHEN distance is null or distance LIKE 'null' THEN '0'
	WHEN distance LIKE '%km' THEN TRIM('km' from distance)
ELSE distance END AS distance,
CASE
	WHEN duration is null or duration LIKE 'null' THEN '0'
	WHEN duration LIKE '%mins' THEN TRIM('mins' from duration)
	WHEN duration LIKE '%minute' THEN TRIM('minute' from
	duration)
	WHEN duration LIKE '%minutes' THEN TRIM('minutes' from
	duration)
ELSE duration END AS duration,
CASE
	WHEN cancellation IS NULL or cancellation LIKE 'Nan'or cancellation LIKE 'NaN'or cancellation LIKE '' THEN 'none'
	ELSE cancellation 
END AS cancellation

FROM runner_orders);
SELECT * FROM trunner_orders;

#changing datatypes in trunner_orders
ALTER TABLE trunner_orders
MODIFY COLUMN pickup_time TIMESTAMP NULL,
MODIFY COLUMN distance FLOAT,
MODIFY COLUMN duration INT;
SELECT * FROM trunner_orders;


--------------------------------------------------------------------------------------------------------------------------------------------


#2. How many pizzas were ordered?
SELECT COUNT(pizza_id) AS total_pizza_orders
FROM tcustomer_orders;


--------------------------------------------------------------------------------------------------------------------------------------------



#3. How many unique customer orders were made?
SELECT COUNT(distinct order_id) AS unique_orders_count
FROM tcustomer_orders;


--------------------------------------------------------------------------------------------------------------------------------------------



#4. How many successful orders were delivered by each runner?
SELECT runner_id, COUNT(order_id) AS successful_orders_count
FROM trunner_orders
WHERE cancellation='none'
GROUP BY runner_id;


--------------------------------------------------------------------------------------------------------------------------------------------


#5. How many of each type of pizza was delivered?
SELECT c.pizza_id, COUNT(c.pizza_id) AS
pizza_delivered
FROM tcustomer_orders AS c
JOIN trunner_orders AS r
ON c.order_id = r.order_id
WHERE  r.cancellation='none'
GROUP BY c.pizza_id;


--------------------------------------------------------------------------------------------------------------------------------------------


#6. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT c.customer_id, p.pizza_name, COUNT(c.pizza_id)  AS orders_count
FROM tcustomer_orders AS c
JOIN pizza_names AS p
ON c.pizza_id= p.pizza_id 
GROUP BY c.customer_id ,c.pizza_id, p.pizza_name
ORDER BY c.customer_id,p.pizza_name ;


--------------------------------------------------------------------------------------------------------------------------------------------


#7.What was the maximum number of pizzas delivered in a single order?
WITH pizzas_in_single_order_cte AS
(
SELECT c.order_id, COUNT(c.pizza_id) AS pizzas_in_single_order
FROM tcustomer_orders AS c
JOIN trunner_orders AS r
ON c.order_id = r.order_id
WHERE r.cancellation='none'
GROUP BY c.order_id
)
SELECT MAX(pizzas_in_single_order) 
FROM pizzas_in_single_order_cte;

--------------------------------------------------------------------------------------------------------------------------------------------

#8. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

SELECT c.customer_id,
COUNT(CASE
WHEN c.exclusions!='' OR c.extras!='' THEN c.pizza_id
END) AS at_least_1_change,
COUNT(CASE
WHEN c.exclusions= ''  AND c.extras='' THEN c.pizza_id
END) AS no_change
FROM tcustomer_orders AS c
JOIN trunner_orders AS r
ON c.order_id = r.order_id
WHERE r.cancellation='none'
GROUP BY c.customer_id;

--------------------------------------------------------------------------------------------------------------------------------------------

#9.How many pizzas were delivered that had both exclusions and extras?

SELECT 
COUNT(
CASE
  WHEN c.exclusions!='' AND c.extras!='' THEN c.pizza_id
END
) AS count_of_pizzas_with_changes
FROM tcustomer_orders AS c
JOIN trunner_orders AS r
ON c.order_id = r.order_id
WHERE r.cancellation='none';

--------------------------------------------------------------------------------------------------------------------------------------------

#10. What was the total volume of pizzas ordered for each hour of the day?
SELECT DATE_FORMAT(order_time, '%Y-%m-%d %H:00:00') AS hours, COUNT(order_id) AS hourly_orders
FROM tcustomer_orders
GROUP BY hours;

--------------------------------------------------------------------------------------------------------------------------------------------

#11 What was the volume of orders for each day of the week?

SELECT DAYNAME(order_time) AS day_of_week, COUNT(order_id) AS count
FROM tcustomer_orders
GROUP BY day_of_week;


--------------------------------------------------------------------------------------------------------------------------------------------


#12 How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT WEEK(registration_date) AS registration_week,
       COUNT(runner_id) 
FROM runners_table
GROUP BY registration_week;


#correcting the pick up time
SET SQL_SAFE_UPDATES = 0; 
UPDATE trunner_orders
SET pickup_time = '2021-01-08 21:30:45'
WHERE order_id=7;
UPDATE trunner_orders
SET pickup_time = '2021-01-10 00:15:02'
WHERE order_id=8;
UPDATE trunner_orders
SET pickup_time = '2021-01-11 18:50:20'
WHERE order_id=10;


------------------------------------------------------------------------------------------------------------------------------
#13.What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
#table entry is wrong

WITH avgtime_cte AS
(
SELECT c.order_id, c.order_time, r.pickup_time,
TIMESTAMPDIFF(minute,c.order_time, r.pickup_time) AS
pickup_in_minutes
FROM tcustomer_orders AS c
JOIN trunner_orders AS r
ON c.order_id = r.order_id
WHERE r.cancellation='none'
GROUP BY c.order_id, c.order_time, r.pickup_time
)
SELECT AVG(pickup_in_minutes) AS avg_pickup FROM avgtime_cte; 


-------------------------------------------------------------------------------------------------------------------------------------


#14.Is there any relationship between the number of pizzas and how long the order takes to prepare?

WITH count_and_prep_time_cte AS
(
SELECT c.order_id, COUNT(c.pizza_id) AS count_of_pizzas,
c.order_time, r.pickup_time,
TIMESTAMPDIFF(MINUTE, c.order_time, r.pickup_time) AS
prep_time_minutes
FROM tcustomer_orders AS c
JOIN trunner_orders AS r
ON c.order_id = r.order_id
WHERE r.cancellation='none'
GROUP BY c.order_id, c.order_time, r.pickup_time
)

SELECT count_of_pizzas, round(AVG(prep_time_minutes),2) AS
avg_prep_time_minutes
FROM count_and_prep_time_cte
GROUP BY count_of_pizzas;



----------------------------------------------------------------------------------------------------------------------------------------


#15.What was the average distance travelled for each customer?
SELECT c.customer_id, round(AVG(r.distance),2) AS avg_distance
FROM tcustomer_orders AS c
JOIN trunner_orders AS r
ON c.order_id = r.order_id
WHERE r.cancellation='none' and distance!=0
GROUP BY c.customer_id;



-----------------------------------------------------------------------------------------------------------------------------------------


#16. What was the difference between the longest and shortest delivery times for all orders?
SELECT (MAX(duration)-MIN(duration)) AS
delivery_time_diff
FROM trunner_orders;

--------------------------------------------------------------------------------------------------------------------------------------------

#17 What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT r.runner_id, c.customer_id, c.order_id,
ROUND(AVG(r.distance/r.duration * 60), 2) AS speed
FROM trunner_orders AS r
JOIN tcustomer_orders AS c
ON r.order_id = c.order_id
WHERE distance != 0 and cancellation='none'
GROUP BY r.runner_id, c.customer_id, c.order_id
ORDER BY r.runner_id,c.customer_id,c.order_id;


#solution 2
SELECT r.runner_id, c.customer_id, c.order_id,
COUNT(c.order_id) AS pizza_count,
r.distance, (r.duration / 60) AS duration_hr ,
ROUND((r.distance/r.duration * 60), 2) AS avg_speed
FROM trunner_orders AS r
JOIN tcustomer_orders AS c
ON r.order_id = c.order_id
WHERE distance != 0
GROUP BY r.runner_id, c.customer_id, c.order_id, r.distance,
r.duration
ORDER BY c.order_id;


--------------------------------------------------------------------------------------------------------------------------------------------


#18) What is the successful delivery percentage for each runner?
SELECT runner_id,
(COUNT(CASE  WHEN distance != 0 THEN distance END) / COUNT(distance) *100) AS 'succ_delivery%'
FROM trunner_orders
GROUP BY runner_id;

