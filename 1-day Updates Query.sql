/*Lookup 1 day orders not shipped systematically*/
select b.*, 
(case 
 when order_status = 'PACKED' and (hum_current_location like 'SHIP-%' and load_number is null) then 'IN SHIP LANE'
 when order_status = 'PACKED' and (hum_current_location like 'OUT%' or load_number is not null) then 'IN LOAD'
 when order_status = 'RELEASED' then 'IN PROCESS'
 when order_status = 'RATEFAIL' then 'RATEFAIL'
 else 'INVESTIGATE' end) validation from
(select distinct orm.order_number, io.carrier_code import_cc, convert(varchar, orm.order_date,0) order_date, orm.order_type, orm.status order_status, orm.carrier_code,
t.tracking_number tracking_number, e.ordered_qty,
hum.location_id hum_current_location,
(select top 1 location_id from t_tran_log l (nolock)
where l.order_number = orm.order_number and tran_type = '317' and t.hu_id = l.hu_id
order by tran_log_id desc) last_pack_location, convert(varchar, hum.packed_on, 0) packed_on,
f.hu_id ship_lane_tracking, f.location_id ship_lane_loc,
hum.load_id load_number,
a.cls_error_count, isnull(ship_jackpots,0) shipping_jackpots
from t_order orm (nolock)
left join t_import_order io (nolock) on io.order_number = orm.order_number and io.carrier_code = 'FDE1' and io.importStatus not in ('E')
left join t_shipment_track t (nolock) on t.order_number = orm.order_number and t.label_status = 'COMPLETE' and suid is not null and puid is not null
left join (select order_number, count(error_text) cls_error_count from t_cls_xml_log l (nolock)
group by order_number) a on a.order_number = orm.order_number
left join t_hu_master hum (nolock) on hum.control_number = orm.order_number and hum.hu_id = t.hu_id
left join t_outbound_load ol (nolock) on ol.load_number = hum.load_id
left join (select order_number, hu_id, count(distinct tran_log_id) ship_jackpots from t_tran_log t (nolock)
where tran_type = '611' and location_id = 'Ship Jackpot'
group by order_number, hu_id) d on d.order_number = orm.order_number and d.hu_id = t.hu_id
left join (select t.order_number tl_order_number, hu_id, location_id from t_tran_log t (nolock)
where tran_type = '611' and location_id like 'Ship Lane%'
group by order_number, hu_id, location_id) f on f.tl_order_number = orm.order_number and f.hu_id = t.hu_id
left join (select order_number, sum(d.qty) ordered_qty from t_order_detail d (nolock)
group by d.order_number) e on e.order_number = orm.order_number
WHERE io.dateTimeInserted  >= CAST(CONVERT(VARCHAR(10), GETDATE()-1, 101) + ' 13:00:00' AS DATETIME)
AND io.dateTimeInserted <= CAST(CONVERT(VARCHAR(10), GETDATE(), 101) + ' 13:00:00' AS DATETIME)
and orm.status not in ('CANCELLED', 'SHIPPED')
and (io.carrier_code = 'FDE1' or orm.carrier_code = 'FDEP' or orm.carrier_code = 'FDE1')
and orm.order_type = 'ECOM'
) b
order by validation desc, packed_on