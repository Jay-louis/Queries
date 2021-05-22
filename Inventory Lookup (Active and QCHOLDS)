-- WCS Check For Inventory Query--
SELECT * FROM
(SELECT sto.location_id
     , sto.hu_id
     , sto.item_number
     , sto.actual_qty
     , CASE
           WHEN sto.location_id LIKE 'BS%' THEN 'SFS BULK'
		   WHEN sto.location_id LIKE 'RB%' THEN 'RIM BULK'
		   WHEN sto.location_id = 'SFSTORIM' THEN 'SFSTORIM'
		   WHEN sto.location_id = 'RECRIM' THEN 'RECRIM'
		   WHEN sto.location_id = 'RIMTOSFS' THEN 'RIMTOSFS'
           WHEN sto.location_id LIKE 'SC%' OR sto.location_id LIKE 'SV%' THEN 'SEV BULK'
           WHEN sto.location_id LIKE 'RCV%' THEN 'RCV'
           WHEN sto.location_id IN ('RECSTAGE', 'SEVSTAGE', 'SFSSTAGE', 'RIM-STAGE', 'RIMSTAGE') THEN 'STAGING'
           WHEN sto.location_id LIKE 'RESTOCKER%' THEN 'RESTOCKER'
           WHEN sto.location_id LIKE 'REC%' THEN 'RECEIVING-HOLD'
           WHEN sto.location_id LIKE '[1-9]%' OR sto.location_id LIKE 'CP%' THEN 'BADGE'
           WHEN sto.location_id LIKE 'PICK%' THEN 'PICKCONVEYOR'
           WHEN sto.location_id LIKE 'PACK%' THEN 'PACKSTAGE'
           WHEN sto.location_id LIKE 'TRANSIT%' THEN 'TRANSIT'
           WHEN sto.location_id LIKE 'RTV%' THEn 'RTVADJ-SFS'
           WHEN sto.location_id LIKE 'LOSTITMLOC' THEn 'LOSTITMLOC'
           WHEN sto.location_id LIKE 'LOSTLPNLOC' THEn 'LOSTLPNLOC'
		   WHEN sto.location_id LIKE 'RB%' THEn 'RIM'
		   WHEN sto.location_id LIKE 'INVSTAGE%' THEN 'INVSTAGE'
		   WHEN sto.location_id LIKE 'PHOTOLAB%' THEN 'PHOTOLAB'
		   WHEN sto.location_id LIKE 'RMA%' THEN 'RMA'
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
         LEFT JOIN (SELECT sti.hu_id, MAX(case when ttl.end_tran_date = ttl.end_tran_time then end_tran_time else ttl.end_tran_date + ttl.end_tran_time end) AS last_tran_date
                    FROM t_tran_log ttl WITH (NOLOCK)
                             JOIN t_stored_item sti WITH (NOLOCK) ON ttl.hu_id = sti.hu_id AND
                                                                     (ttl.location_id_2 = sti.location_id OR
                                                                      ttl.generic_attribute_2 = sti.location_id OR ttl.location_id = sti.location_id)
                  --  WHERE ttl.tran_type IN ('202', '614', '800', '603')
                    GROUP BY sti.hu_id) a ON sto.hu_id = a.hu_id -- Find Last Scan Date Into Current Loc
WHERE (sto.type = '0' -- All Selling Inventory
    OR (sto.type < '0' AND tloc.type IN ('F','S','C','M','P') -- All Hold Inventory (Forks/Staging/Conveyor/Pickmod/Bulk)
        AND sto.hu_id LIKE 'LP%' -- Only valid LPNs & Locations where cartons move in & out
        AND sto.location_id NOT LIKE 'SHIP%'
        AND sto.location_id NOT LIKE 'RTV%'
        AND sto.location_id NOT IN
            ('SevilleDamages', 'QCSAMPLE-STAGE', 'LOSTITMLOC', 'FTL01', 'INVALIDSTG',
             'PROBRESSTG', 'PROMO1-STG')) 
	OR (sto.type < '0' AND sto.location_id = 'RMA' AND sto.hu_id is null)
	))a
	WHERE-- (a.location_id NOT LIKE 'LOST%')
	--AND 
	((a.[Age in Days] <> 'Greater than 30 Days') or [Selling Status] = 'SELLING')
	AND 
	a.item_number IN ('731002') -- Insert SKUs Here
order by location_id asc
