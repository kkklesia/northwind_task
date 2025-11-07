-- CTE: total category sales
with sales as (
select 
	c.category_name, 
	sum(od.unit_price * od.quantity * (1 - od.discount)) as total_sales
from order_details od
join products p on od.product_id = p.product_id
join categories c on p.category_id = c.category_id
group by c.category_name
order by c.category_name
),
	
-- CTE with a subquery: AOV per category
avg_order_value as (
select
	orders_per_category.category_name,
	avg(orders_per_category.order_value) as avg_order_value
from (
		select 
    		o.order_id,
        	c.category_name,
        	sum(od.unit_price * od.quantity * (1 - od.discount)) as order_value
    	from orders o
    	join order_details od on o.order_id = od.order_id
    	join products p on od.product_id = p.product_id
    	join categories c on p.category_id = c.category_id
    	group by o.order_id, c.category_name
	) as orders_per_category
group by orders_per_category.category_name
),

-- CTE: average number of days to ship
avg_time_to_ship as (
select
	c.category_name,
    avg(o.shipped_date - o.order_date) as avg_days_to_ship
from orders o
join order_details od on o.order_id = od.order_id
join products p on od.product_id = p.product_id
join categories c on p.category_id = c.category_id
group by c.category_name
),

-- CTE with a window function and a subquery: ranked products per categories by total_sales descending
ranked_products as (
select 
	category_name,
    product_id,
    total_sales,
    row_number() over (partition by category_name order by total_sales desc) as rn
from (
	select 
		c.category_name,
        p.product_id,
        sum(od.unit_price * od.quantity * (1 - od.discount)) as total_sales
    from order_details od
    join products p on od.product_id = p.product_id
    join categories c on p.category_id = c.category_id
    group by c.category_name, p.product_id) 
),

-- CTE: total sales of the top 5 products devided by the total sales of all products in the category	
top_5_ratio as (
select
	category_name,
    sum(total_sales) filter (where rn <= 5) / sum(total_sales) as top_5_ratio
from ranked_products
group by category_name
),

-- CTE: number of orders per customer
avg_order_freq as (
select 
	c.category_name,
    count(distinct o.order_id) / count(distinct o.customer_id) as avg_order_frequency
from orders o
join order_details od on o.order_id = od.order_id
join products p on od.product_id = p.product_id
join categories c on p.category_id = c.category_id
group by c.category_name
)

-- final query
select 
    s.category_name,
    round(s.total_sales::numeric, 0) as total_sales,
    round(aov.avg_order_value::numeric, 0) as avg_order_value,
    round(ats.avg_days_to_ship, 0) as avg_days_to_ship,
    round(t.top_5_ratio::numeric * 100, 2) as top_5_ratio_percent,
    aof.avg_order_frequency
from sales s
left join avg_order_value aov on s.category_name = aov.category_name
left join avg_time_to_ship ats on s.category_name = ats.category_name
left join top_5_ratio t on s.category_name = t.category_name
left join avg_order_freq aof on s.category_name = aof.category_name
order by s.total_sales desc;
