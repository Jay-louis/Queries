select order_number, item_number, order_qty, picked_qty, order_qty - picked_qty qty_needed, active_inv, problem_stock , where_else AS "Inv_QTY" from
(select o.order_number,
 d.item_number, 
 count(d.qty) order_qty, 
 sum(p.picked_quantity) picked_qty,
 
  isnull((
  SELECT sum(isnull(actual_qty,0)) AS else_qty
  FROM t_stored_item stg (nolock)
  WHERE type IN ('0', '-1', '-85') 
  AND location_id NOT LIKE 'LOST%'
  AND stg.item_number = d.item_number
  GROUP BY item_number
 ),0) where_else,

 isnull((
  SELECT sum(isnull(actual_qty,0)) AS active
  FROM t_stored_item stg (nolock)
  WHERE type = '0' 
  AND location_id NOT LIKE 'LOST%'
  AND( location_id LIKE 'BS%'
  OR location_id LIKE 'A[A-D]%'
  OR location_id LIKE '%STAGE%'
  OR location_id LIKE '%OS%'
  OR location_id LIKE '%RB%'
  OR location_id LIKE 'CP%'
  OR location_id LIKE '[0-1]%'
  OR location_id LIKE 'INV[1-2]%'
  OR location_id LIKE 'PICKMOD%'
  OR location_id LIKE 'RCV%'
  OR location_id LIKE 'RESTOCKER%'
  OR location_id LIKE 'SC%'
  OR location_id LIKE 'SV%'
  OR location_id LIKE '%TRAN%')
  AND stg.item_number = d.item_number
  GROUP BY item_number
 ),0) active_inv,

 isnull((
  SELECT sum(isnull(actual_qty,0)) AS investigate
  FROM t_stored_item stg (nolock)
  WHERE type IN ('-1', '-85', '-80') 
  AND location_id NOT LIKE 'LOST%'
  AND( location_id LIKE 'BS%'
  OR location_id LIKE 'A[A-D]%'
  OR location_id LIKE '%STAGE%'
  OR location_id LIKE '%OS%'
  OR location_id LIKE '%RB%'
  OR location_id LIKE 'CP%'
  OR location_id LIKE '[0-1]%'
  OR location_id LIKE 'INV%'
  OR location_id LIKE 'PICKMOD%'
  OR location_id LIKE 'RCV%'
  OR location_id LIKE 'RESTOCKER%'
  OR location_id LIKE 'SC%'
  OR location_id LIKE 'SV%'
  OR location_id LIKE '%TRAN%')
  AND stg.item_number = d.item_number
  GROUP BY item_number
 ),0) problem_stock

from t_order o (nolock)
join t_order_detail d (nolock) on d.order_number = o.order_number
join t_pick_detail p (nolock) on p.order_number = o.order_number and p.line_number = d.line_number and p.item_number = d.item_number and p.status not in ('CANCELLED')
where cast(order_date as date) = '2020-09-17' and o.status NOT IN ('SHIPPED','CANCELLED','PACKED','LOADED','S', 'PROCESSING', 'SHIPPING')
and o.order_type IN ('SM', 'EO', 'ECOM')
and wcs_status in ('R', 'M', 'P', 'S', 'C', 'A')
group by o.order_number, d.item_number) a
where (order_qty - picked_qty) > 0 and (problem_stock > 0 and active_inv = 0)
order by item_number, order_number
