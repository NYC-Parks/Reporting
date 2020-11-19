/***********************************************************************************************************************
																													   	
 Created By: Dan Gallagher, daniel.gallagher@parks.nyc.gov, Innovation & Performance Management         											   
 Modified By: <Modifier Name>																						   			          
 Created Date:  <MM/DD/YYYY>																							   
 Modified Date: <MM/DD/YYYY>																							   
											       																	   
 Project: <Project Name>	
 																							   
 Tables Used: <Database>.<Schema>.<Table Name1>																							   
 			  <Database>.<Schema>.<Table Name2>																								   
 			  <Database>.<Schema>.<Table Name3>				
			  																				   
 Description: <Lorem ipsum dolor sit amet, legimus molestiae philosophia ex cum, omnium voluptua evertitur nec ea.     
	       Ut has tota ullamcorper, vis at aeque omnium. Est sint purto at, verear inimicus at has. Ad sed dicat       
	       iudicabit. Has ut eros tation theophrastus, et eam natum vocent detracto, purto impedit appellantur te	   
	       vis. His ad sonet probatus torquatos, ut vim tempor vidisse deleniti.>  									   
																													   												
***********************************************************************************************************************/
use reportdb
go

create or alter procedure rpt.sp_rpt_weekly_sla @Start date, @End date, @Boro nvarchar(1) as 
--declare @Start date ='2020-06-28', @End date = '2020-07-04', @Boro nvarchar(1) = 'Q';

if object_id('tempdb..#ref_calndr') is not null
	drop table #ref_calndr

/*Create a calendar reference table that contains all the dates in the selected time period and the number of days in the week.*/
select ref_date,
	   /*Find the minimum date of the week selected (this will always be Sunday)*/
	   min(ref_date) over(partition by calndr_week, calndr_year order by calndr_week, calndr_year) as week_start,
	   /*Count the number of days in the given week, particularly if a partial week is chosen.*/
	   count(*) over(partition by calndr_week, calndr_year order by calndr_week, calndr_year) as week_days
into #ref_calndr
from [dataparks].dwh.dbo.tbl_ref_calendar
where ref_date between @Start and @End

if object_id('tempdb..#ref_date_units') is not null
	drop table #ref_date_units

select distinct r.borough,
	   r.district,
	   r.unit_id,
	   r2.unit_desc,
	   r.sla_id,
	   /*Multiply these values by 1.0 to make them floats*/
	   r.sla_min_days * 1. as sla_min_days,
	   r.sla_max_days * 1. as sla_max_days,
	   l.week_start,
	   l.week_days
into #ref_date_units
from #ref_calndr as l
full outer join
/*Find all historic SLAs where the selected dates fall between the effective start and effective end dates.*/
	 (select *
	  from sladb.dbo.vw_sla_historic
	  where (@Start between effective_start_adj and effective_end_adj or
			 @End between effective_start_adj and effective_end_adj or
			 effective_start_adj between @Start and @End or
			 effective_end_adj between @Start and @End) and
			borough = @Boro) as r
on l.ref_date between effective_start_adj and effective_end_adj
left join
	 sladb.dbo.tbl_ref_unit as r2
on r.unit_id = r2.unit_id

if object_id('tempdb..#unit_visits') is not null
	 drop table #unit_visits

select l.unit_id,
	   sum(l.visits) as visits,
	   r.week_start
into #unit_visits
from (select omppropid as unit_id,
			 date_worked as ref_date,
			 count(distinct date_worked) * 1. as visits
	  from [dataparks].dwh.dbo.tbl_dailytasks
	  where date_worked between @Start and @End and
			lower(activity) = 'work' /*and
			/*This doesn't work because fixed post sites don't have sectors.*/
			left(sector, 1) = @Boro*/
	  group by omppropid, date_worked) as l
left join
	 #ref_calndr as r
on l.ref_date = r.ref_date
group by l.unit_id, r.week_start

select l.week_start,
	   l.borough as Boro_Code,
	   l.district, 
	   l.sla_id as sla,
	   l.unit_id as property_number,
	   l.unit_desc as property_name,
	   coalesce(r.visits, 0.0) as visits,
	   case when r.visits/l.sla_min_days > 1 then 100.
			else coalesce(r.visits, 0.0)/l.sla_min_days * 100 
	   end as SLAProgress
from #ref_date_units as l
left join
	 #unit_visits as r
on l.week_start = r.week_start and
   l.unit_id = r.unit_id
where l.unit_id is not null and 
	  l.sla_id != 'N' and l.sla_id is not null
order by district, sla, week_start, property_number
