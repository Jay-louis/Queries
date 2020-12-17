DECLARE @bld1 as NVARCHAR(25)
SET @bld1 = 'BS-%'
DECLARE @bld2 as NVARCHAR(25)
SET @bld2 = 'BS-%'
 
 select 
 e.item_number, e.pm_qty, e.bs_qty, e.scrb_qty, e.stg_qty, e.total_qty, e.location_id, e.hu_id,
 e.item_number as item_number2, e.actual_qty, 
 (case when m.size = 'OS' then 'OS' else 'NOT OS' end) SFS,/* m.style, m.color,*/ m.size,
 (CASE WHEN m.size LIKE '%' THEN 'Urgent' END) "replen_status",
 
  (case when location_id like 'RB-%' then 'RIM'
  when location_id like 'SV-%' or location_id like 'SC-%' then 'SEVILLE'
  when location_id like 'BS-%' then 'SFS' end) building from (
 select 
     b.*,
	 i.location_id, i.hu_id, i.actual_qty, i.status, i.type,
	 ROW_NUMBER () OVER ( PARTITION BY i.item_number ORDER BY i.item_number DESC, i.location_id ASC ) AS 'rowNumber' from
(select a.*,  pm_qty + bs_qty + scrb_qty + stg_qty total_qty from
(select
i.item_number,
isnull((
		  SELECT sum(isnull(pm.actual_qty,0)) AS pm_qty
		  FROM t_stored_item pm (nolock)
		  WHERE type = '0'  
		  AND (location_id LIKE 'AA%' OR location_id LIKE 'AB%' OR location_id LIKE 'AC%' OR location_id LIKE 'AD%') 
		  AND pm.item_number = i.item_number
		  GROUP BY item_number
		  ), 0) pm_qty,
		 isnull((
		  SELECT sum(isnull(actual_qty,0)) AS bs_qty
		  FROM t_stored_item bs (nolock)
		  WHERE type = '0' 
		  AND (location_id LIKE 'BS-%')
		  AND bs.item_number = i.item_number
		  GROUP BY item_number
		 ),0) bs_qty,
		 isnull((
		  SELECT sum(isnull(actual_qty,0)) AS scrb_qty
		  FROM t_stored_item scrb (nolock)
		  WHERE type = '0' 
		  AND (location_id LIKE 'SC-%'
		  OR location_id LIKE 'SV-%'
		  OR location_id LIKE 'RB-%') 
		  AND scrb.item_number = i.item_number
		 GROUP BY item_number
         ),0) scrb_qty,
		 isnull((
		  SELECT sum(isnull(actual_qty,0)) AS stg_qty
		  FROM t_stored_item stg (nolock)
		  WHERE type = '0' 
		  AND (location_id LIKE 'CP%'
		  OR location_id LIKE 'OS%'
		  OR location_id LIKE 'RCV%'
		  OR location_id LIKE 'RESTOCKER%'
		  OR location_id LIKE 'CART%'
		  OR location_id LIKE 'SFS%'
		  OR location_id LIKE 'REC%'
		  OR location_id LIKE 'TRANS%'
		  OR location_id LIKE 'INV%'
		  OR location_id LIKE 'RIM%')
		  AND stg.item_number = i.item_number
		  GROUP BY item_number
		 ),0) stg_qty
from t_stored_item i (nolock)
group by i.item_number) a
where (scrb_qty > 0 or bs_qty > 0) and pm_qty <= 5) b -- change as needed for pm qty
join t_stored_item i (nolock) on i.item_number = b.item_number and i.type = '0' 
AND (i.location_id LIKE @bld1 or i.location_id like @bld2)) e -- Bulk locations (SFS only or include RB/SEV)
join t_item_master m (nolock) on m.item_number = e.item_number
where rowNumber = 1 and stg_qty = 0
