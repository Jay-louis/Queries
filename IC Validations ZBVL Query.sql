-- WCS Cofe Shorts Validation Report
SELECT sto.location_id
     , sto.hu_id
     , sto.item_number
     , sto.actual_qty
     , CASE
           WHEN sto.location_id LIKE 'BS%' THEN 'SFS BULK'
           WHEN sto.location_id LIKE 'SC%' OR sto.location_id LIKE 'SV%' THEN 'SEV BULK'
           WHEN sto.location_id LIKE 'RCV%' THEN 'RCV'
           WHEN sto.location_id IN ('RECSTAGE', 'SEVSTAGE', 'SFSSTAGE') THEN 'STAGING'
           WHEN sto.location_id LIKE 'RESTOCKER%' THEN 'RESTOCKER'
           WHEN sto.location_id LIKE 'REC%' THEN 'RECEIVING-HOLD'
           WHEN sto.location_id LIKE '[1-9]%' OR sto.location_id LIKE 'CP%' THEN 'BADGE'
           WHEN sto.location_id LIKE 'PICK%' THEN 'PICKCONVEYOR'
           WHEN sto.location_id LIKE 'PACK%' THEN 'PACKSTAGE'
           WHEN sto.location_id LIKE 'TRANSIT%' THEN 'TRANSIT'
           WHEN sto.location_id LIKE 'RTV%' THEn 'RTVADJ-SFS'
           WHEN sto.location_id LIKE 'LOSTITMLOC' THEn 'LOSTITMLOC'
           WHEN sto.location_id LIKE 'LOSTLPNLOC' THEn 'LOSTLPNLOC'
           WHEN sto.location_id LIKE 'A%' THEN 'PICKMOD' END    AS 'Building'
     , sto.type
     , CASE
           WHEN sto.type = '0' THEN 'SELLING'
           WHEN sto.type > '0' THEN 'COMMITTED'
           WHEN sto.type = '-85' THEN 'HOLD'
           WHEN sto.type = '-1' THEN 'QC-HOLD'
           WHEN sto.type = '-80' THEN 'R-HOLD'
    END                                                         AS 'Selling Status'
     , CASE
           WHEN tloc.type = 'M' THEN 'Bulk'
           WHEN tloc.type = 'P' THEN 'Pickmod'
           WHEN tloc.type = 'C' THEN 'Conveyor'
           WHEN tloc.type = 'S' THEN 'Staging'
           WHEN tloc.type = 'F' THEN 'Fork'
           ELSE tloc.type END                                   AS 'loc_type'
     , CASE
           WHEN a.hu_id IS NOT NULL THEN CONVERT(varchar, DATEDIFF(DAY, a.last_tran_date, GETDATE()))
           WHEN a.hu_id IS NULL THEN 'Greater than 30 Days' END AS 'Age in Days'
FROM t_stored_item sto WITH (NOLOCK)
         JOIN t_item_master itm WITH (NOLOCK) ON sto.item_number = itm.item_number
         JOIN t_location tloc WITH (NOLOCK) ON tloc.location_id = sto.location_id
         LEFT JOIN (SELECT sti.hu_id, MAX(ttl.end_tran_date + ttl.end_tran_time) AS last_tran_date
                    FROM t_tran_log ttl WITH (NOLOCK)
                             JOIN t_stored_item sti WITH (NOLOCK) ON ttl.hu_id = sti.hu_id AND
                                                                     (ttl.location_id_2 = sti.location_id OR
                                                                      ttl.generic_attribute_2 = sti.location_id)
                    WHERE ttl.tran_type IN ('202', '614', '800')
                    GROUP BY sti.hu_id) a ON sto.hu_id = a.hu_id -- Find Last Scan Date Into Current Loc
WHERE (sto.type = '0' -- All Selling Inventory
    OR (sto.type < '0' AND tloc.type IN ('F','S','C','M','P') -- All Hold Inventory (Forks/Staging/Conveyor/Pickmod/Bulk)
        AND sto.hu_id LIKE 'LP%' -- Only valid LPNs & Locations where cartons move in & out
        AND sto.location_id NOT LIKE 'SHIP%'
        AND sto.location_id NOT LIKE 'RTV%'
        AND sto.location_id NOT IN
            ('SevilleDamages', 'QCSAMPLE-STAGE', 'LOSTITMLOC', 'FTL01', 'INVALIDSTG',
              'PROBRESSTG', 'PROMO1-STG', 'PACKRES')))
  AND sto.item_number IN (select distinct item_number from
(select order_number, item_number, order_qty, picked_qty, order_qty - picked_qty qty_needed, all_qty AS all_qty, bad_qty, bad_qty2, good_qty from
(select o.order_number,
 d.item_number, 
 count(d.qty) order_qty, 
 sum(p.picked_quantity) picked_qty,
  isnull((
  SELECT sum(isnull(actual_qty,0)) AS else_qty
  FROM t_stored_item stg (nolock)
  WHERE type IN ('0', '-1', '-85') 
  AND location_id NOT LIKE 'LOST%'
  AND location_id NOT LIKE 'OUT%'
  AND location_id NOT LIKE 'PACKRES%'
  AND location_id NOT LIKE 'RTV%'
  AND location_id NOT LIKE 'SEVDON%'
  AND UPPER(location_id) NOT LIKE '%DAM%'
  AND (location_id NOT LIKE 'SHIP-[0-9][0-9]-STG%')
  AND location_id NOT LIKE 'SHIP%'
  AND location_id NOT LIKE 'PICKCONVEYOR%'
  AND location_id NOT LIKE '%PRS%'
  AND stg.item_number = d.item_number
  GROUP BY item_number
 ),0) all_qty,
   isnull((
  SELECT sum(isnull(actual_qty,0)) AS else_qty
  FROM t_stored_item stg (nolock)
  WHERE (type IN ('-1', '-85', '-80') 
  AND location_id NOT LIKE 'LOST%'
  AND location_id NOT LIKE 'OUT%'
  AND location_id NOT LIKE 'PACKRES%'
  AND location_id NOT LIKE 'RTV%'
  AND location_id NOT LIKE 'SEVDON%'
  AND UPPER(location_id) NOT LIKE '%DAM%'
  AND (location_id NOT LIKE 'SHIP-[0-9][0-9]-STG%')
  AND location_id NOT LIKE 'SHIP%'
  AND location_id NOT LIKE 'PICKCONVEYOR%'
  AND location_id NOT LIKE '%PRS%')
  AND stg.item_number = d.item_number
  GROUP BY item_number
 ),0) bad_qty,
 isnull((
  SELECT sum(isnull(actual_qty,0)) AS else_qty
  FROM t_stored_item stg (nolock)
  WHERE  (type = '0' AND (
  location_id LIKE 'CP%'
  OR location_id LIKE 'INV%'
  OR location_id LIKE 'OS%'
  OR location_id LIKE 'RCV%'
  OR location_id LIKE 'RESTOCKER%'
  OR location_id LIKE 'SFS%'
  OR location_id LIKE 'TRANSIT%'))
  AND stg.item_number = d.item_number
  GROUP BY item_number
 ),0) bad_qty2,
  isnull((
  SELECT sum(isnull(actual_qty,0)) AS else_qty
  FROM t_stored_item stg (nolock)
  WHERE (type IN ('0') 
  AND location_id NOT LIKE 'LOST%'
  AND location_id NOT LIKE 'OUT%'
  AND location_id NOT LIKE 'PACKRES%'
  AND location_id NOT LIKE 'RTV%'
  AND location_id NOT LIKE 'SEVDON%'
  AND UPPER(location_id) NOT LIKE '%DAM%'
  AND (location_id NOT LIKE 'SHIP-[0-9][0-9]-STG%')
  AND location_id NOT LIKE 'SHIP%'
  AND location_id NOT LIKE 'PICKCONVEYOR%'
  AND location_id NOT LIKE '%PRS%'
  AND location_id NOT LIKE 'CP%'
  AND location_id NOT LIKE 'INV%'
  AND location_id NOT LIKE 'OS%'
  AND location_id NOT LIKE 'RCV%'
  AND location_id NOT LIKE 'RESTOCKER%'
  AND location_id NOT LIKE 'SFS%'
  AND location_id NOT LIKE 'TRANSIT%')
  AND stg.item_number = d.item_number
  GROUP BY item_number
 ),0) good_qty
from t_order o (nolock)
join t_order_detail d (nolock) on d.order_number = o.order_number
join t_pick_detail p (nolock) on p.order_number = o.order_number and p.line_number = d.line_number and p.item_number = d.item_number and p.status not in ('CANCELLED')
where cast(order_date as date) >= '2020-09-16' and o.status NOT IN ('SHIPPED','CANCELLED','PACKED','LOADED','S', 'PROCESSING', 'SHIPPING', 'ERROR')
and o.order_type IN ('SM', 'EO', 'ECOM')
and wcs_status in ('R', 'M', 'P', 'S', 'C', 'A')
group by o.order_number, d.item_number) a
where (order_qty - picked_qty) > 0 and good_qty = 0 and (bad_qty + bad_qty2) > 0
) a)
ORDER BY location_id
