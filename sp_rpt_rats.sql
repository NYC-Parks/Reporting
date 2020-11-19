/***********************************************************************************************************************
 Created By: Emma Dixon, emma.dixon@parks.nyc.gov, Innovation & Performance Management         											   
 Modified By: Dan Gallagher, daniel.gallagher@parks.nyc.gov, Innovation & Performance Management  																						   			          
 Created Date:  04/01/2018																							   
 Modified Date: 08/01/2019																							   
											       																	   
 Project: Neighborhood Rat Reduction Program	
 																							   
 Tables Used: dwh.dbo.tbl_nrr_sites																							   
 			  [dataparks].dwh.dbo.tbl_supervisorinspections_inspectionresults																								   
 			  [dataparks].dwh.dbo.tbl_supervisorinspections_featurefindings
			  [dataparks].dwh.dbo.tbl_pip_conditionshazards
			  [dataparks].dwh.dbo.tbl_pip_inspectionmain
			  [dataparks].eamprod.dbo.r5events
			  [dataparks].eamprod.dbo.r5bookedhours
			  [dataparks].eamprod.dbo.r5addetails
			  [dataparks].eamprod.dbo.r5eventobjects
			  [dataparks].dwh.dbo.tbl_dailytasks
			  				
			  																				   
 Description: Create a stored procedure that produces the weekly Rats! report. This report brings together data from
	          daily tasks, AMPS, supervisor inspections and PIP. 									   
																													   												
***********************************************************************************************************************/

use [reportdb]
go

set ansi_nulls on
go

set quoted_identifier on
go

--drop procedure dbo.sp_rpt_rats
create or alter procedure rpt.sp_rpt_rats @startdate date,
										  @enddate date as

/*declare @startdate date = '2019-07-07',
		@enddate date = '2019-07-13';*/

--Create the table that holds the NRR Site information
declare @nrrsites table(gispropnum nvarchar(30),
						omppropid nvarchar(30), 
						district nvarchar(15),
						borough nvarchar(1),
						site_name nvarchar(128),
					    gisobjid bigint, 
						nrr_name nvarchar(128) ,
						sla nvarchar(80));

insert into @nrrsites(gispropnum,
					  omppropid, 
					  district,
					  borough,
					  site_name,
					  gisobjid,
					  nrr_name,
					  sla)	
	select gispropnum,
		   omppropid, 
		   district,
		   left(district, 1) as borough, 
		   site_name,
		   gisobjid, 
		   nrr_name,
		   sla
   from reportdb.rpt.tbl_nrr_sites;


--Create the table that holds the AMPS_Ins data
declare @amps_ins table(omppropid nvarchar(30), 
						nsupervisor_inspections int,
						last_supervisorInspection date,
						nsupervisor_inspections_rodents int,
						nsupervisor_inspections_burrows int);

insert into @amps_ins(omppropid, nsupervisor_inspections, last_supervisorInspection, nsupervisor_inspections_rodents, nsupervisor_inspections_burrows)
	select omppropid,
		   count(distinct(inspection_date)) as nsupervisor_inspections,
		   --max(inspection_date) as last_supervisorInspection,
		   max(last_supervisorinspection) as last_supervisorinspection,
		   sum(rodent) as nsupervisor_inspections_rodents,
		   sum(nsupervisor_inspections_burrows) as nsupervisor_inspections_burrows
	from (select r.district,
				 l.omppropid,
				 cast(r.inspection_date as date) as inspection_date,
				 r3.last_supervisorinspection,
				 r.date_started,
				 r.date_completed,
				 r.overall_rating,
				 r.cleanliness_rating,
				 r2.feature_category,
				 r2.feature,
				 r2.results,
				 r2.findings,
				 case when lower(r2.findings) like '%rodent%' then cast(1 as int) 
			  		  else cast(0 as int)
				 end as rodent,
				 r2.[action],
				 --,isnumeric(comments) as is_numeric
				 case when isnumeric(substring(r2.comments, dwh.dbo.fn_bracket_num_st(r2.comments) + 1, dwh.dbo.fn_bracket_num_len(r2.comments))) = 1 then
			   			   cast(substring(r2.comments, dwh.dbo.fn_bracket_num_st(r2.comments) + 1, dwh.dbo.fn_bracket_num_len(r2.comments)) as int)
			   		  else cast(0 as int)
				 end as nsupervisor_inspections_burrows
	  from @nrrsites as l
	  left join
		   (select *
			from [dataparks].dwh.dbo.tbl_supervisorinspections_inspectionresults
			where cast(inspection_date as date) between @startdate and @enddate and
				  lower(inspection_status) = 'completed')  as r
	  on l.omppropid = r.omppropid
	  left join 
		   (select *
			from [dataparks].dwh.dbo.tbl_supervisorinspections_featurefindings
			where lower(feature) = 'litter') as r2
	  on r.inspection_id = r2.inspection_id
	  left join
		   (select omppropid,
				   max(cast(inspection_date as date)) as last_supervisorinspection
			from [dataparks].dwh.dbo.tbl_supervisorinspections_inspectionresults
			where lower(inspection_status) = 'completed'
			group by omppropid)  as r3
	  on l.omppropid = r3.omppropid) t
	  group by omppropid

--Create the table that holds the AMPS_Ins data
declare @pip table(omppropid nvarchar(30), 
				   npip_rodents int,
				   npip_inspections int,
				   last_pipinspection date);

insert into @pip(omppropid, npip_rodents, npip_inspections, last_pipinspection)
	select l.omppropid,
		   sum(r.burrows) as npip_rodents,
		   count(distinct r.inspection_id) as npip_inspections,
		   max(r2.last_pipinspection) as last_pipinspection
	from @nrrsites as l
	left join
		 (select [prop id] as omppropid,
				 case when lower(probhaz) = 'rodent holes' and isnumeric(number)= 1 then cast(number as int)
					  when lower(probhaz) = 'rodent holes' and number='10+' then cast(10 as int)
					  else cast(0 as int)
				 end as burrows,
				 [inspection id] as inspection_id,
				 cast([Date] as date) as inspection_date
		   from [dataparks].dwh.dbo.tbl_pip_conditionshazards
		   where cast([date] as date) between @startdate and @enddate and
				 lower(inspectiontype) = 'pip') as r
	on l.omppropid = r.omppropid
	left join
		 (select [prop id] as omppropid,
				 max(cast([date] as date)) as last_pipinspection
		  from [dataparks].dwh.dbo.tbl_pip_inspectionmain
		  group by [prop id]) as r2
	on l.omppropid = r2.omppropid
	group by l.omppropid

declare @amps_wos table(evt_code nvarchar(30), 
						ndays_baited int,
						ndryice_application int,
						nhours_baiting decimal(10,2));

insert into @amps_wos(evt_code, 
					  ndays_baited,
					  ndryice_application,
					  nhours_baiting)
	select l.evt_code,
		   --count(distinct cast(r.boo_date as date)) as ndays_baited,
		   sum(ndays_baited) as ndays_baited,
		   sum(isnull(r2.ice_app, cast(0 as int))) as ndryice_application,
		   sum(nhours_baiting) as nhours_baiting
		   --cast(sum(r.boo_hours) as decimal(10,2)) as nhours_baiting
	from (select *
		  from [dataparks].eamprod.dbo.r5events
		   /*Only include work orders that are of standard work order type = "pest" and the description is like " rat " or " rodent " Include
			 all comibinations of spaces in the words.*/
		   where lower(evt_standwork) = 'pest' and
				 (lower(evt_desc) like '% rat %' or lower(evt_desc) like '% rodent %'  or
				  lower(evt_desc) like '% rats %' or lower(evt_desc) like '% rodents %' or 
				  lower(evt_desc) like 'rats %' or lower(evt_desc) like 'rodents %' or 
				  lower(evt_desc) like '% rats' or lower(evt_desc) like '% rodents' or
				  lower(evt_desc) like 'rat %' or lower(evt_desc) like 'rodent %' or 
				  lower(evt_desc) like '% rat' or lower(evt_desc) like '% rodent' or
				  lower(evt_desc) like '%rodent%')) as l
	inner join
		  (select boo_event,
				  count(distinct cast(boo_date as date)) as ndays_baited,
				  sum(boo_hours) as nhours_baiting
		   from [dataparks].eamprod.dbo.r5bookedhours
		   /*Apply the date filter to the booked hours table.*/
		   where boo_date between @startdate and @enddate and
			     boo_act = 10
		   group by boo_event) as r
	on l.evt_code = r.boo_event
	left join
		(select add_code,
				/*If the comments contain "rat ice" or "dry ice" then count them a 1 application.*/
				case when lower(convert(nvarchar(max), add_text)) like '%rat ice%' then cast(1 as int)
					 when lower(convert(nvarchar(max), add_text))  like '%dry ice%' then cast(1 as int)
					 /*If there are no comments then count as 0 applications.*/
					 --when lower(cast(add_text as nvarchar)) is null then cast(0 as int)
					 /*Otherwise count as 0 applications*/
					 else cast(0 as int)
				end as ice_app
		 from [dataparks].eamprod.dbo.r5addetails
		 /*Filter the comments aka additional details to the selected dates and events aka work orders.*/
		 where add_created between @startdate and @enddate and
			   add_entity = 'EVNT') as r2
	on l.evt_code = r2.add_code
	group by l.evt_code--, r.boo_date

declare @amps_rollup table(omppropid nvarchar(30), 
						   ndays_baited int,
						   ndryice_application int,
						   nhours_baiting decimal(10,2));

/*In order to capture work orders that are not directly booked to NRR Sites (ex: access points) join to event object,
  which tracks the hierarchy.*/
insert into @amps_rollup(omppropid, 
						 ndays_baited,
						 ndryice_application,
						 nhours_baiting)
	select omppropid,
		   max(ndays_baited) as ndays_baited,
		   sum(ndryice_application) as ndryice_application,
		   sum(nhours_baiting) as nhours_baiting
	from (select l.evt_code,
				 r2.omppropid,
				 l.ndays_baited,
				 l.ndryice_application,
				 l.nhours_baiting,
				 r.eob_level,
				 min(r.eob_level) over(partition by l.evt_code order by l.evt_code) as min_eob_level
		  from @amps_wos as l
		  left join
			   [dataparks].eamprod.dbo.r5eventobjects as r
		  on l.evt_code = r.eob_event collate SQL_Latin1_General_CP1_CI_AS
		  right join
			   @nrrsites as r2
		  on r.eob_object = r2.omppropid collate latin1_general_bin) as t
	where eob_level = min_eob_level
	group by omppropid

declare @dailytasks table(omppropid nvarchar(30),
						  ncleaning_visits int,
						  ncleaning_days_visits int,
						  ncleaning_hours decimal(10,2),
						  npacker_visits int,
						  npacker_days_visits int,
						  overflowing_cans int,
						  food_waste int,
						  last_dailytaskentry date);

insert into @dailytasks(omppropid, ncleaning_visits, ncleaning_days_visits, ncleaning_hours, npacker_visits, npacker_days_visits, overflowing_cans, food_waste, last_dailytaskentry)
	select omppropid,
		   sum(nvisits - npacker_visits) as ncleaning_visits,
		   count(distinct ncleaning_dates) as ncleaning_days_visits,
		   sum((ncrew * nhours) - npacker_hours) as ncleaning_hours,
		   sum(npacker_visits) as npacker_visits,
		   count(distinct npacker_dates) as npacker_days_visits,
		   sum(overflowing_cans) as overflowing_cans,
		   sum(food_waste) as food_waste,
		   last_dailytaskentry
	from (select l.omppropid,
				 r.date_worked,
				 --max(r.date_worked) over(partition by r.omppropid order by r.omppropid) as last_dailytaskentry,
				 r2.last_dailytaskentry,
				 case when lower(route_name) not like '%packer%' then r.nhours * r.ncrew
					  else cast(0 as decimal(10,2))
				 end as ncleaning_hours,
				 case when lower(r.route_name) like '%packer%' then r.nhours * r.ncrew
					  else cast(0 as decimal(10,2))
				 end as npacker_hours,
				 case when lower(r.route_name) not like '%packer%' then cast(1 as int)
					  else cast(0 as int)
				 end as ncleaning_visits,
				 case when lower(r.route_name) like '%packer%' then cast(1 as int)
					  else cast(0 as int)
				 end as npacker_visits,
				 case when lower(r.notes) like '%overflow%' then cast(1 as int) 
					  else cast(0 as int)
				 end as overflowing_cans,
				 case when lower(r.notes) like '%food%' then cast(1 as int) 
					  else cast(0 as int)
				 end as food_waste,
				 case when lower(r.route_name) like '%packer%' then cast(null as date)
					  else date_worked
				 end as ncleaning_dates,
				 case when lower(r.route_name) like '%packer%' then r.date_worked
					  else cast(null as date)
				 end as npacker_dates,
				 cast(1 as int) as nvisits,
				 r.gisobjid,
				 r.nhours,
				 r.ncrew
		  from @nrrsites as l
		  left join
			   (select *
			    from [dataparks].dwh.dbo.tbl_dailytasks
				where date_worked between @startdate and @enddate and
					  lower(activity) = 'work') as r
		  on l.gisobjid = r.gisobjid
		  left join	
			   (select gisobjid, 
					   max(date_worked) as last_dailytaskentry
			    from [dataparks].dwh.dbo.tbl_dailytasks
				where lower(activity) = 'work'
				group by gisobjid)	as r2	
		  on l.gisobjid = r2.gisobjid) as t 
	group by omppropid, last_dailytaskentry

declare @cube table(gispropnum nvarchar(30),
					omppropid nvarchar(30), 
					ncleaning_visits int,
					ncleaning_days_visits int,
					ncleaning_hours decimal(10,2),
					npacker_visits int,
					npacker_days_visits int,
					--overflowing_cans int,
					--food_waste int,
					last_dailytaskentry date,
					nsupervisor_inspections int,
					nsupervisor_inspections_rodents int,
					nsupervisor_inspections_burrows int,
					last_supervisorInspection date,
					npip_inspections int,
					npip_rodents int,
				    last_pipinspection date,
					ndays_baited int,
					nhours_baiting decimal(10,2),
					ndryice_application int,
					gispropnum_count int)

insert into @cube(gispropnum,
				  omppropid, 
				  ncleaning_visits,
				  ncleaning_days_visits,
				  ncleaning_hours,
				  npacker_visits,
				  npacker_days_visits,
				  --overflowing_cans int,
				  --food_waste int,
				  last_dailytaskentry,
				  nsupervisor_inspections,
				  nsupervisor_inspections_rodents,
				  nsupervisor_inspections_burrows,
				  last_supervisorInspection ,
				  npip_inspections,
				  npip_rodents,
				  last_pipinspection,
				  ndays_baited,
				  nhours_baiting,
				  ndryice_application,
				  gispropnum_count)

	select l.gispropnum,
		   l.omppropid,
		   sum(isnull(r4.ncleaning_visits, 0)) as ncleaning_visits,
		   sum(isnull(r4.ncleaning_days_visits, 0)) as ncleaning_days_visits,
		   sum(isnull(r4.ncleaning_hours, 0.0)) as ncleaning_hours,
		   sum(isnull(r4.npacker_visits, 0)) as npacker_visits,
		   sum(isnull(r4.npacker_days_visits, 0.0)) as npacker_days_visits,
		   max(r4.last_dailytaskentry) as last_dailytaskentry,
		   sum(isnull(r.nsupervisor_inspections, 0)) as nsupervisor_inspections,
		   sum(isnull(r.nsupervisor_inspections_rodents, 0)) as nsupervisor_inspections_rodents,
		   sum(isnull(r.nsupervisor_inspections_burrows, 0)) as nsupervisor_inspections_burrows,
		   max(r.last_supervisorInspection) as last_supervisorInspection,
		   sum(isnull(r2.npip_inspections, 0)) as npip_inspections,
		   sum(isnull(r2.npip_rodents, 0)) as npip_rodents,
		   max(r2.last_pipinspection) as last_pipinspection,
		   sum(isnull(r3.ndays_baited, 0)) as ndays_baited,
		   sum(isnull(r3.nhours_baiting, 0.0)) as nhours_baiting,
		   sum(isnull(r3.ndryice_application, 0)) as ndryice_application,
		   count(gispropnum)  
	from @nrrsites as l
	left join
		@amps_ins as r
	on l.omppropid = r.omppropid
	left join
		 @pip as r2
	on l.omppropid = r2.omppropid
	left join
		 @amps_rollup as r3
	on l.omppropid = r3.omppropid
	left join
		 @dailytasks as r4
	on l.omppropid = r4.omppropid
	group by grouping sets((l.omppropid, l.gispropnum),
							l.gispropnum)

	select *
	from(
	select l.borough,
		   l.nrr_name,
		   l.district,
		   l.gispropnum,
		   l.omppropid,
		   l.site_name,
		   l.sla,
		   r.ncleaning_visits,
		   r.ncleaning_days_visits,
		   r.ncleaning_hours,
		   r.npacker_visits,
		   r.npacker_days_visits,
		   r.last_dailytaskentry,
		   r.nsupervisor_inspections,
		   r.nsupervisor_inspections_rodents,
		   r.nsupervisor_inspections_burrows,
		   r.last_supervisorinspection,
		   r.npip_inspections,
		   r.npip_rodents,
		   r.last_pipinspection,
		   r.ndays_baited,
		   r.nhours_baiting,
		   r.ndryice_application
	from @nrrsites as l
	left join
		 @cube as r
	on l.omppropid = r.omppropid) as t1
	union all
	(select l.borough,
		   l.nrr_name,
		   l.district,
		   l.gispropnum,
		   cast(null as nvarchar(30)) as omppropid,
		   l.site_name,
		   l.sla,
		   r.ncleaning_visits,
		   r.ncleaning_days_visits,
		   r.ncleaning_hours,
		   r.npacker_visits,
		   r.npacker_days_visits,
		   r.last_dailytaskentry,
		   r.nsupervisor_inspections,                                
		   r.nsupervisor_inspections_rodents,
		   r.nsupervisor_inspections_burrows,
		   r.last_supervisorInspection,
		   r.npip_inspections,
		   r.npip_rodents,
		   r.last_pipinspection,
		   r.ndays_baited,
		   r.nhours_baiting,
		   r.ndryice_application
	from @nrrsites as l
	right join
		 @cube as r
	on l.gispropnum = r.gispropnum
	where r.omppropid is null and
		  l.gispropnum = l.omppropid and
		  r.gispropnum_count > 1)
	order by gispropnum, omppropid
	--order by last_pipinspection desc
	 
	 
