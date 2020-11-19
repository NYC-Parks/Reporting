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
SELECT 
			cast(a.cal_week_start as date) as week_start, --week starts on Sunday
			left(a.district,1) as Boro_Code,
			a.district,
			a.sla,
			a.property_number,
			a.property_name,
			COALESCE(a.visits,0) as visits,
			/*SLA progress is the percentage of visits made out of the number necessary to meet the SLA. Currently caps out at 100 but can change to give credit for additional visits */
			CASE WHEN sla='A' and   a.visits >= 5 THEN 100
				WHEN sla='A' and  a.visits = 4 THEN 80
				WHEN sla='A' and  a.visits = 3 THEN 60
				WHEN sla='A' and  a.visits = 2 THEN 40
				WHEN sla='A' and  a.visits = 1 THEN 20
				WHEN sla='B' and  a.visits >= 3 THEN 100
				WHEN sla='B' and  a.visits = 2 THEN 66
				WHEN sla='B' and  a.visits = 1 THEN 33
				WHEN sla='C' and  a.visits >= 1 THEN 100
			ELSE 0 END as 'SLAProgress',
			SUM(CAST(b.labormns as float)) as wkly_labor_minutes
			FROM --includes subquery a, with visit information, and subquery b, with labor hour information.
				(SELECT
				calprop.cal_week_start,
				calprop.district,
				calprop.property_number,
				calprop.property_name,
				calprop.sla,
				wv.visits
				FROM --join subquery wv (weekly visits) with subquery calprop (full list of properties and all calendar weeks)
					(select dateadd(week, datediff(week,0,date_worked),-1) as week_start,
							omppropid as property_number,
							count(distinct date_worked) as visits
					 from [dataparks].dwh.dbo.tbl_dailytasks
					 group by dateadd(week, datediff(week,0,date_worked),-1), omppropid
							) as wv
					RIGHT OUTER JOIN (SELECT DISTINCT(DATEADD(week,datediff(week,0,cal.ref_date),-1)) as cal_week_start,
							pr.obj_code as property_number,
							pr.obj_desc as property_name,
							pr.obj_mrc as district,
							pr.obj_udfchar02 as sla
							FROM dwh.dbo.tbl_ref_calendar as cal
							CROSS JOIN [dataparks].EAMPROD.dbo.r5objects as pr
							WHERE cal.ref_date BETWEEN @Start and @End AND 
							pr.OBJ_UDFCHAR02 in ('A','B','C') and pr.OBJ_NOTUSED='-'
							--order by property_number, cal_week_start
							) as calprop
							on calprop.cal_week_start=wv.week_start AND 
							   calprop.property_number=LTRIM(RTRIM(wv.property_number))COLLATE SQL_Latin1_General_CP1_CI_AS
					) as a
					LEFT JOIN
						(select dateadd(week, datediff(week,0,date_worked),-1) as week_start,
								omppropid as property_number,
								daily_task__id,
								sum(ncrew) as allcrew,
								sum(napsw + ncpw + ncsa + npop) as paidcrew,
								cast(round(sum(nhours * 60), 0) as int) as mns,
								cast(round(sum(nhours * 60), 0) as int) * sum(napsw + ncpw + ncsa + npop) as labormns
						 from [dataparks].dwh.dbo.tbl_dailytasks
						 where lower(activity) = 'work' and
							   date_worked between @Start and @End
						 group by dateadd(week, datediff(week,0,date_worked),-1), omppropid, daily_task__id) as b
					on a.cal_week_start=b.week_start AND 
					   a.property_number=LTRIM(RTRIM(b.property_number))COLLATE SQL_Latin1_General_CP1_CI_AS
			WHERE left(district,1) = @Boro 
			GROUP BY a.cal_week_start, a.property_number, a.property_name, sla, district, a.visits 
			--HAVING a.sla  in('A','B','C') 
			ORDER BY visits, district,sla,property_number,cal_week_start