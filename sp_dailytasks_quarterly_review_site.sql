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

create or alter procedure rpt.sp_dailytasks_quarterly_review_site @Start as datetime, @End as datetime as

--declare @Start date = '2019-08-25';
--declare @End date = '2019-11-30';
--set @Start = '2020-02-01';
--set @End = '2020-03-01';

--declare @Start date = '2019-05-26';
--declare @End date = '2019-09-01';
--set @Start = '2020-02-01';
--set @End = '2020-03-01';

if object_id('tempdb..#prop_cal') is not null
	drop table #prop_cal;

select r.omppropid,
	   l.ref_date,
	   l.fiscal_day,
	   l.fiscal_week,
	   l.ndays,
	   r.district,
	   left(r.district, 1) as borough,
	   r.obj_gisobjid
into #prop_cal
from (select *,
		     count(ref_date) over(partition by fiscal_week order by fiscal_week) as ndays
	  from [dataparks].dwh.dbo.tbl_ref_calendar
	  where ref_date between @Start and @End) as l
cross join
     /*How does this differ from tbl_ref_unit_sla_season.*/
	 (select *
	  from [dataparks].dwh.dbo.vw_dailytask_property_dropdown
	  where obj_withdraw is null or
		    obj_withdraw between @Start and @End) as r

if object_id('tempdb..#compliance') is not null
	drop table #compliance;

select distinct l.omppropid,
	   l.borough,
	   l.district,
	   l.fiscal_week,
	   l.ndays,
	   r2.sla_id,
	   --r2.sla_min_days,
       /*If the number of days in a given week is less than the number minimum days required to comply then set the value equal to ndays/7. If the number
         of days in a given week is greater than or equal to the minimum days required to comply with an SLA then set the value to the sla_min_days/7*/
	   case when ndays < sla_min_days then ndays/7.
			else sla_min_days/7.
	   end as sla_min_days,
	   case when sum(isnull(r.nvisits, 0)) over(partition by l.omppropid, l.fiscal_week order by l.omppropid, l.fiscal_week) = 0 then 1
			else 0
	   end as nzerovisits,
       /*Sum the hours by unit (omppropid) and week*/
	   sum(isnull(r.nhours, 0.0)) over(partition by l.omppropid, l.fiscal_week order by l.omppropid, l.fiscal_week) as nhours,
       /*Sum the crew hours by unit (omppropid) and week*/
	   sum(isnull(r.ncrewhours, 0.0)) over(partition by l.omppropid, l.fiscal_week order by l.omppropid, l.fiscal_week) as ncrewhours,
	   /*Sum the unique visits by unit (omppropid) and week*/
       sum(isnull(r.nvisitsunq, 0)) over(partition by l.omppropid, l.fiscal_week order by l.omppropid, l.fiscal_week) as nvisitsunq,
	   sum(isnull(r.nvisits, 0)) over(partition by l.omppropid, l.fiscal_week order by l.omppropid, l.fiscal_week) as nvisits
into #compliance
from #prop_cal as l
left join
	 (select distinct omppropid,
		     date_worked,
             /*Count the distinct visits to an unit (omppropid) each day, capped at 1*/
			 count(distinct omppropid) as nvisitsunq,
             /*Count the total visits to an unit (ommpropid) each day, with no cap*/
			 count(omppropid) as nvisits,
             /*Calculate the total number of hours an unit (omppropid) was serviced.*/
		     sum(nhours) as nhours,--omppropid,
             /*Calculate the total number of person hours an unit (omppropid) was serviced.*/
			 sum(nhours * ncrew) as ncrewhours
		     --sum(nhours),
			 --sum(ncrew)
	  from [dataparks].dwh.dbo.tbl_dailytasks
      /*Include only work activities that occur between the chosen dates where the unit (omppropid) is not null*/
	  where lower(activity) = 'work' and
		    date_worked between @Start and @End and
			omppropid is not null
	  group by omppropid, date_worked) as r
on l.ref_date = r.date_worked and
   l.omppropid = r.omppropid
left join
	 sladb.dbo.vw_sla_historic as r2
on l.omppropid = r2.unit_id and
   l.ref_date between r2.effective_start_adj and r2.effective_end_adj;
 /* Start and End can be any day of the week, but the report will include the week(s) that begin on the Sunday prior to each and all weeks in between. Could update this query to pull 
 PIP inspection period dates instead of manually entering. */

select l.omppropid,
	   r.description,
	   l.sla_id,
	   l.district,
	   sum(l.ndays) as ndays,
	   cast(round(avg(l.nvisits * 1.), 2) as decimal(10,2)) as avgvisits,
	   cast(round(avg(l.nvisitsunq * 1.), 2) as decimal(10,2))as avgvisitsunq,
	   cast(round(avg(l.nhours * 1.), 2) as decimal(10,2))as avghours,
       /*Calculate the total number of person hours an unit (omppropid) was serviced.*/
	   cast(round(avg(l.ncrewhours * 1.), 2) as decimal(10,2))as avgcrewhours
from #compliance as l
left join
	 [dataparks].dwh.dbo.vw_dailytask_property_dropdown as r
on l.omppropid = r.omppropid
group by l.omppropid, l.district, r.description, l.sla_id
order by omppropid
