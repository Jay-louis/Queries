--LPN Updates for Pick Shortage 2022--

SELECT a.*, CASE WHEN a.Location LIKE'RCV%' OR a.Location LIKE '%STAGE'
					  OR a.Location LIKE  'RESTOCKER%'
					  OR a.Location LIKE  '%TRANS%'
					  OR a.Location LIKE  'INV%'
					  OR a.Location LIKE  'OS%'
					  OR a.Location LIKE  'CART%'
					  OR a.Location = 'CP DRIVER' THEN 'In Process'

				 WHEN a.Location IN  ('SFS BULK', 'RIM BULK', 'SEV BULK' )THEN 'Not Pulled'
				 WHEN a.Location = 'PICKMOD' OR a.Location LIKE 'EMPTYBOX%'  THEN 'Done'
				 ELSE 'Unknown' END AS 'Status'

INTO #lpnupdate

FROM 

(SELECT sto.location_id, sto.hu_id, sto.item_number, sto.actual_qty,
CASE WHEN sto.location_id LIKE 'BS%' THEN 'SFS BULK'
	 WHEN sto.location_id LIKE 'RB%' THEN 'RIM BULK'
	 WHEN sto.location_id = 'RIM-STAGE' THEN 'RIM-STAGE'
	 WHEN sto.location_id = 'RIMSTAGE' THEN 'RIM-STAGE'
     WHEN sto.location_id LIKE 'SC%' OR sto.location_id LIKE 'SV%' THEN 'SEV BULK'
     WHEN sto.location_id = 'RCVCONVEYOR' THEN 'RCVCONVEYOR'
     WHEN sto.location_id = 'RCVCONVEYOR-A' THEN 'RCVCONVEYOR-A'
     WHEN sto.location_id = 'RCVCONVEYOR-B' THEN 'RCVCONVEYOR-B'
     WHEN sto.location_id = 'RCVCONVEYOR-C' THEN 'RCVCONVEYOR-C'
     WHEN sto.location_id = 'RCVCONVEYOR-D' THEN 'RCVCONVEYOR-D'
	 WHEN sto.location_id LIKE 'SEVSTAGE' THEN 'SEVSTAGE'
	 WHEN sto.location_id LIKE 'RECSTAGE' THEN 'RECSTAGE'
	 WHEN sto.location_id LIKE 'SFSSTAGE' THEN 'SFSSTAGE'
	 WHEN sto.location_id LIKE 'RESTOCKER%' THEN 'RESTOCKER'
	 WHEN sto.location_id LIKE '%TRANS%' THEN 'TRANSIT'
	 WHEN sto.location_id LIKE 'INV2%' THEN 'INV2'
	 WHEN sto.location_id LIKE 'INV1%' THEN 'INV1'
	 WHEN sto.location_id LIKE 'OS-STAGE' THEN 'OS-STAGE'
	 WHEN sto.location_id LIKE 'OS-WIP' THEN 'OS-WIP'
	 WHEN sto.location_id LIKE 'CART-AB%' THEN 'CART-AB'
	 WHEN sto.location_id LIKE 'CART-AA%' THEN 'CART-AA'
	 WHEN sto.location_id LIKE 'CART-AC%' THEN 'CART-AC'
	 WHEN sto.location_id LIKE 'CART-AD%' THEN 'CART-AD'
	 WHEN sto.location_id LIKE '[1-9]%' OR sto.location_id LIKE 'CP%' THEN 'CP DRIVER'
     WHEN sto.location_id LIKE 'A%' THEN 'PICKMOD'
	 WHEN sto.location_id LIKE 'EMPTY%' THEN 'EMPTYBOX' END AS 'Location',
	 CASE
	 WHEN itm.size = 'OS' THEN 'OS' ELSE 'NOT OS' END AS 'Size'
	-- ,type
FROM t_stored_item sto WITH (NOLOCK)
JOIN t_item_master itm WITH (NOLOCK)
ON sto.item_number = itm.item_number
WHERE sto.status = 'A'
AND sto.type = '0'
AND sto.hu_id IN ()-- input LPN's here--
GROUP BY sto.location_id, sto.hu_id, sto.item_number, sto.actual_qty, itm.size)a
ORDER BY location_id ASC


--pull data for tran lookup NO NEED TO CHANGE ANYTHING BEYOND THIS POINT--
select z.*, l.employee_id, UPPER(e.name) name, CONVERT(varchar, DATEDIFF(MINUTE, z.dropped_time, getdate())) aging_time  from
(SELECT stg.hu_id stg_hu_id, stg.item_number, stg.location_id current_location , isnull(stg.actual_qty,0) AS actual_qty, b.hu_id pulled_hu_id, b.location_id pulled_location, b.pulled_time,
z.dropped_time dropped_time, ISNULL(olp.Status, 'Done') "Status"
from t_stored_item stg
          left join 
		  (select l.hu_id, location_id, end_tran_date + end_tran_time pulled_time from t_tran_log l (nolock)
		  join
		  (select hu_id, max(tran_log_id) first_location from t_tran_log l (nolock)
		  where (location_id like 'RB%' or location_id like 'BS%') and tran_type = '201'
		  group by hu_id) a on a.hu_id = l.hu_id and l.tran_log_id = a.first_location
		  group by l.hu_id, location_id, end_tran_date + end_tran_time) b on b.hu_id = stg.hu_id
		  left join
		  (select hu_id, location_id_2, max(end_tran_date + end_tran_time) dropped_time from t_tran_log l3 (nolock)
		  where tran_type = '202'
		  group by hu_id, location_id_2) z on z.hu_id = stg.hu_id and z.location_id_2 = stg.location_id
		  LEFT JOIN #lpnupdate olp WITH(NOLOCK) ON olp.hu_id = b.hu_id 
		  WHERE type = '0'
		  AND stg.hu_id in (
(SELECT hu_id FROM #lpnupdate)

)
 GROUP BY stg.hu_id, stg.location_id, stg.item_number, stg.actual_qty, b.hu_id, b.location_id, b.pulled_time, z.dropped_time, olp.Status) z
left join t_tran_log l (nolock) on l.hu_id = z.stg_hu_id and (l.end_tran_date + l.end_tran_time) = z.dropped_time and z.current_location = l.location_id_2
left join t_employee e (nolock) on e.id = l.employee_id
order by cast(CONVERT(varchar, DATEDIFF(MINUTE, dropped_time, getdate())) as int) desc





DROP TABLE #lpnupdate