/****** 
RATS Query
Created By: Emma Dixon 
Modified By: Sara Esquibel
Created Date:  <MM/DD/YYYY>                                                                                                                                                          
Modified Date: 01/18/2019
Project: Neighborhood Rat Reduction Program
Tables Used:	ParksGIS.DPR.PROPERTY_EVW
				ParksGIS.DPR.PLAYGROUND_EVW
				ParksGIS.DPR.ZONE_EVW
				ParksGIS.DPR.GREENSTREET
				EAMPROD.dbo.r5objects
				EAMPROD.dbo.R5Events
				EAMPROD.dbo.R5ADDETAILS
				EAMPROD.dbo.R5Bookedhours
				DWH.dbo.dailytasks
				DWH.dbo.tbl_SupervisorInspections_FeatureFindings
				DWH.dbo.tbl_SupervisorInspections_InspectionResults
				DWH.dbo.tbl_PIP_InspectionMain
				DWH.dbo.tbl_PIP_ConditionsHazards
Description: <purpose of query, databases used (and descriptions if needed), what is output, why modified (if modified), etc.> 
******/


USE [SYSTEMDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sp_rpt_RATS]
	 @startdate date
	,@enddate date as


SELECT 
CASE WHEN left(department,1)='B' THEN 'Brooklyn'
	WHEN left(department,1)='M' THEN 'Manhattan'
	WHEN left(department,1)='X' THEN 'Bronx'
	ELSE 'ERR' END as Borough,
[NRR Zone],
department as district,
gispropnum,
props.omppropid,
signname,
coalesce(sla,'') as SLA,
sum(CASE WHEN Work_Type='Cleaning' THEN Visits ELSE 0 END) as [Cleaning Visits],
sum(CASE WHEN Work_Type='Cleaning' THEN Days_Visited ELSE 0 END) as [Cleaning Visit Days],
--avg(CASE WHEN Work_Type='Cleaning' THEN Crew_Size ELSE 0.0 END) as [Average Cleaning Crew Size], --this isn't working for some reason
round(sum(CASE WHEN Work_Type='Cleaning' THEN Work_Hours ELSE 0 END),1) as [Hours of Cleaning],
sum(CASE WHEN Work_Type='Packer' THEN Visits ELSE 0 END) as [Packer Visits],
sum(CASE WHEN Work_Type='Packer' THEN Days_Visited ELSE 0 END) as [Packer Visit Days],
coalesce(sum(Overflowing_Cans),0) as Overflowing_Cans,
coalesce(sum(Food_Waste),0) as Food_Waste,
last_DT.last_workentry as [Last Daily Tasks Entry],
--sum(CASE WHEN Work_Type='Packer' THEN Work_Hours ELSE 0 END) as Packer_Hours,
coalesce(supervisor_inspections,0) as [Supervisor Inspections],
coalesce(rodent_sightings,0) as [Supervisor Inspections with Rodent Conditions],
coalesce(num_burrows,0) as [Burrows Counted by Supervisors],
last_SI.last_supervisorinspection as [Last Supervisor Inspection],
coalesce(PIP_inspections,0) as [PIP Inspections],
coalesce(Burrows,0) as [Burrows Counted by PIP],
last_PIP.last_pipinspection as [Last PIP Inspection],
coalesce(Days_Baited,0) as [Days Baited],
coalesce(Baiting_Hours,0) as [Baiting Work Hours],
coalesce(rat_ice_applications,0) as [Dry Ice Applications]
FROM
( -- Query 1 - generates list of properties to include, including all subproperties
SELECT a.*,
b.sla FROM
(
SELECT gispropnum,
omppropid,
signname,
department,
CASE WHEN left(department,1)='B' THEN 'Brooklyn Bed Stuy and Bushwick'
	WHEN left(department,1)='X' THEN 'Bronx Grand Concourse'
	WHEN department IN ('M-01','M-03') THEN 'Manhattan East Village and Chinatown'
	WHEN department IN ('M-07','M-14') THEN 'Upper West Side'
	ELSE 'ERR' END AS 'NRR Zone'
FROM
					(SELECT OMPPROPID,GISPROPNUM, SIGNNAME, DEPARTMENT
						FROM ParksGIS.DPR.PROPERTY_EVW
						UNION 
						SELECT OMPPROPID,GISPROPNUM, SIGNNAME, DEPARTMENT 
						FROM ParksGIS.DPR.PLAYGROUND_EVW
						UNION 
						SELECT OMPPROPID,GISPROPNUM, DESCRIPTION, DEPARTMENT
						FROM ParksGIS.DPR.ZONE_EVW
						UNION
						SELECT OMPPROPID,GISPROPNUM,DESCRIPTION,DEPARTMENT
						FROM ParksGIS.DPR.GREENSTREET
						) as GIS
WHERE gispropnum IN ('B351',	'B555',	'M015-01',	'M048',	'M105-06',	'M144',	'MZ436',	'X008',	'X011',	'X030',	'X030-01',	'X034',	'X047',	'X148B1',	'X148C',	'X148C4',	'X148C6',	'X148D',	'X148E1',	'X148F5',	'X153',	'X225',	'X226',	'X236',	'X254',	'X348',	'B016',	'B016-01',	'B016-02',	'B088',	'B088-02',	'B088-03',	'B139',	'B140',	'B217',	'B237',	'B262',	'B263',	'B266',	'B269',	'B298',	'B317',	'B322',	'B323',	'B334',	'B348',	'B359',	'M015',	'M033',	'M053',	'M065',	'M067',	'M071-04',	'M071-08',	'M071-13',	'M071-16',	'M071-ZN07',	'M071-ZN09',	'M082',	'M088',	'M088-01',	'M088-03',	'M105',	'M105-01',	'M105-02',	'M105-04',	'M105-08',	'M113',	'M116',	'M122',	'M123',	'M124',	'M144-01',	'M144-ZN01',	'M144-ZN02',	'M144-ZN03',	'M144-ZN04',	'M144-ZN05',	'M144-ZN06',	'M165',	'M188',	'M188A',	'M195',	'M196',	'M200',	'M201',	'M220',	'M224',	'M228',	'M229',	'M235',	'M238',	'M241',	'M246',	'M255',	'M259',	'M270',	'M321',	'X001-ZN02',	'X001A-01',	'X006',	'X008-01',	'X008-03',	'X011-ZN01',	'X011-ZN02',	'X017',	'X017-01',	'X017-02',	'X028',	'X030-02',	'X030-99',	'X030-ZN01',	'X030-ZN02',	'X032',	'X034-01',	'X034-06',	'X034-ZN01',	'X034-ZN02',	'X037',	'X042',	'X047-01',	'X047-ZN01',	'X047-ZN02',	'X068',	'X071',	'X085',	'X102',	'X108',	'X114',	'X129',	'X148C5',	'X148C7',	'X148D1',	'X148E',	'X153-01',	'X168',	'X174',	'X219',	'X244',	'X252',	'X257',	'X258',	'X263',	'X274',	'X280',	'X289',	'X291',	'X292',	'X300',	'X302',	'X348-01',	'X348-02',	'B006',	'B023',	'B037',	'B041',	'B045',	'B340',	'B395',	'B429',	'B430',	'M002',	'M004',	'M016',	'M080',	'M247',	'M254',	'X008-ZN01',	'X008-ZN02',	'X008-ZN03',	'X018',	'X030-ZN03',	'X036',	'X058',	'X059',	'X061',	'X069',	'X081',	'X115',	'X153-02',	'X271',	'X001A',	'X057',	'X067',	'X105',	'X130',	'X148B2',	'X148C1',	'X148C3',	'X269',	'XZ475')
OR OMPPROPID IN ('B351',	'B555',	'M015-01',	'M048',	'M105-06',	'M144',	'MZ436',	'X008',	'X011',	'X030',	'X030-01',	'X034',	'X047',	'X148B1',	'X148C',	'X148C4',	'X148C6',	'X148D',	'X148E1',	'X148F5',	'X153',	'X225',	'X226',	'X236',	'X254',	'X348',	'B016',	'B016-01',	'B016-02',	'B088',	'B088-02',	'B088-03',	'B139',	'B140',	'B217',	'B237',	'B262',	'B263',	'B266',	'B269',	'B298',	'B317',	'B322',	'B323',	'B334',	'B348',	'B359',	'M015',	'M033',	'M053',	'M065',	'M067',	'M071-04',	'M071-08',	'M071-13',	'M071-16',	'M071-ZN07',	'M071-ZN09',	'M082',	'M088',	'M088-01',	'M088-03',	'M105',	'M105-01',	'M105-02',	'M105-04',	'M105-08',	'M113',	'M116',	'M122',	'M123',	'M124',	'M144-01',	'M144-ZN01',	'M144-ZN02',	'M144-ZN03',	'M144-ZN04',	'M144-ZN05',	'M144-ZN06',	'M165',	'M188',	'M188A',	'M195',	'M196',	'M200',	'M201',	'M220',	'M224',	'M228',	'M229',	'M235',	'M238',	'M241',	'M246',	'M255',	'M259',	'M270',	'M321',	'X001-ZN02',	'X001A-01',	'X006',	'X008-01',	'X008-03',	'X011-ZN01',	'X011-ZN02',	'X017',	'X017-01',	'X017-02',	'X028',	'X030-02',	'X030-99',	'X030-ZN01',	'X030-ZN02',	'X032',	'X034-01',	'X034-06',	'X034-ZN01',	'X034-ZN02',	'X037',	'X042',	'X047-01',	'X047-ZN01',	'X047-ZN02',	'X068',	'X071',	'X085',	'X102',	'X108',	'X114',	'X129',	'X148C5',	'X148C7',	'X148D1',	'X148E',	'X153-01',	'X168',	'X174',	'X219',	'X244',	'X252',	'X257',	'X258',	'X263',	'X274',	'X280',	'X289',	'X291',	'X292',	'X300',	'X302',	'X348-01',	'X348-02',	'B006',	'B023',	'B037',	'B041',	'B045',	'B340',	'B395',	'B429',	'B430',	'M002',	'M004',	'M016',	'M080',	'M247',	'M254',	'X008-ZN01',	'X008-ZN02',	'X008-ZN03',	'X018',	'X030-ZN03',	'X036',	'X058',	'X059',	'X061',	'X069',	'X081',	'X115',	'X153-02',	'X271',	'X001A',	'X057',	'X067',	'X105',	'X130',	'X148B2',	'X148C1',	'X148C3',	'X269',	'XZ475')
) a
INNER JOIN
(SELECT DISTINCT obj_code as property_number, obj_udfchar02 as sla
FROM eamprod.dbo.r5objects
WHERE obj_notused = '-'
AND obj_status <> 'D') as b --this exists to eliminate properties that appear in the above but not in AMPS; if they are not in AMPS they do not exist for the purposes of rat tracking
on a.OMPPROPID=b.property_number COLLATE Latin1_general_BIN
) 
as props

LEFT JOIN

( -- Query 3 contains Supervisor Inspection information

  SELECT omppropid
	    ,count(distinct(inspection_date)) as supervisor_inspections
		,sum(rodent) as rodent_sightings
		,sum(CASE WHEN rodent = 1 THEN
				  CASE WHEN is_numeric = 1 THEN cast(comments as float) ELSE 0 END -- casting as float prevents error if decimal value is entered
				  ELSE 0 END) as num_burrows
  FROM
  (
  SELECT district
		,omppropid
		,inspection_date
		,date_started
		,date_completed
		,overall_rating
		,cleanliness_rating
		,feature_category
		,feature
		,results
		,findings
		,CASE WHEN lower(Findings) LIKE '%rodent%' THEN 1 ELSE 0 END AS rodent
		,r.[action]
		,comments
		,isnumeric(comments) as is_numeric
  FROM [DWH].[dbo].[tbl_supervisorinspections_inspectionresults] l
		LEFT JOIN [DWH].[dbo].[tbl_SupervisorInspections_FeatureFindings] r
		on l.inspection_id = r.inspection_id
  WHERE l.inspection_status = 'Completed'
		and feature = 'Litter'
		and cast(inspection_date as date) BETWEEN @startdate and @enddate
  ) a

--WHERE omppropid IN ('B351',	'B555',	'M015-01',	'M048',	'M105-06',	'M144',	'MZ436',	'X008',	'X011',	'X030',	'X030-01',	'X034',	'X047',	'X148B1',	'X148C',	'X148C4',	'X148C6',	'X148D',	'X148E1',	'X148F5',	'X153',	'X225',	'X226',	'X236',	'X237',	'X254',	'X348',	'B016',	'B016-01',	'B016-02',	'B088',	'B088-02',	'B088-03',	'B139',	'B140',	'B217',	'B237',	'B262',	'B263',	'B266',	'B269',	'B298',	'B317',	'B322',	'B323',	'B334',	'B348',	'B359',	'M015',	'M033',	'M053',	'M065',	'M067',	'M071-04',	'M071-08',	'M071-13',	'M071-16',	'M071-ZN07',	'M071-ZN09',	'M082',	'M088',	'M088-01',	'M088-03',	'M105',	'M105-01',	'M105-02',	'M105-04',	'M105-08',	'M113',	'M116',	'M122',	'M123',	'M124',	'M144-01',	'M144-ZN01',	'M144-ZN02',	'M144-ZN03',	'M144-ZN04',	'M144-ZN05',	'M144-ZN06',	'M165',	'M188',	'M188A',	'M195',	'M196',	'M200',	'M201',	'M220',	'M224',	'M228',	'M229',	'M235',	'M238',	'M241',	'M246',	'M255',	'M259',	'M270',	'M321',	'X001-ZN02',	'X001A-01',	'X006',	'X008-01',	'X008-03',	'X011-ZN01',	'X011-ZN02',	'X017',	'X017-01',	'X017-02',	'X028',	'X030-02',	'X030-99',	'X030-ZN01',	'X030-ZN02',	'X032',	'X034-01',	'X034-06',	'X034-ZN01',	'X034-ZN02',	'X037',	'X042',	'X047-01',	'X047-ZN01',	'X047-ZN02',	'X068',	'X071',	'X085',	'X102',	'X108',	'X114',	'X129',	'X148C5',	'X148C7',	'X148D1',	'X148E',	'X153-01',	'X168',	'X174',	'X219',	'X244',	'X252',	'X257',	'X258',	'X263',	'X274',	'X280',	'X289',	'X291',	'X292',	'X300',	'X302',	'X348-01',	'X348-02',	'B006',	'B023',	'B037',	'B041',	'B045',	'B340',	'B395',	'B429',	'B430',	'M002',	'M004',	'M016',	'M080',	'M247',	'M254',	'X008-ZN01',	'X008-ZN02',	'X008-ZN03',	'X018',	'X030-ZN03',	'X036',	'X058',	'X059',	'X061',	'X069',	'X081',	'X115',	'X153-02',	'X271',	'X001A',	'X057',	'X067',	'X105',	'X130',	'X148B2',	'X148C1',	'X148C3',	'X269',	'XZ475')
group by omppropid 

) as SI

on SI.omppropid = props.omppropid COLLATE Latin1_general_BIN



LEFT JOIN 
( -- Query 4 contains PIP inspection information
SELECT [Prop ID],
count(distinct cast([Date] as date)) as PIP_inspections,
sum(CASE WHEN ProbHaz='Rodent holes' THEN 
		(CASE WHEN isnumeric(Number)=1 THEN Number
		WHEN Number='10+' THEN 10
		ELSE 0 END)
	ELSE 0 END
	) as Burrows
FROM 
DWH.dbo.tbl_PIP_ConditionsHazards
WHERE cast([Date] as date) BETWEEN @startdate and @enddate
group by [Prop ID]
) as PIP
on PIP.[Prop ID] = props.omppropid


LEFT JOIN 
( -- Query 5 contains AMPS baiting work orders

SELECT PropID
	  ,count(distinct [Date Worked]) as Days_Baited
	  ,sum([Labor Hours]) as Baiting_Hours
	  ,sum(CASE WHEN Comments LIKE '%rat ice%' THEN 1 ELSE 0 END) as rat_ice_applications

FROM (
SELECT l.evt_code as WorkOrder_ID
	  ,l.evt_object as 'PropID'
	  ,q.obj_desc as 'Prop Name'
	  ,REPLACE(REPLACE(l.evt_desc, CHAR(10), ''), CHAR(13), '') AS 'Description'
	  ,l.evt_udfchar13 as 'Work Order Status'
	  ,cast(r.boo_date as date) as 'Date Worked'
	  ,count(r.boo_acd) as 'Applications'
	  ,sum(r.boo_hours) as 'Labor Hours'
	  ,coalesce(l.commentvalues,'') as 'Comments'
	FROM 
	(SELECT 
		R5EVENTS.*,CommentValues
		
		FROM EAMPROD.dbo.R5Events as R5EVENTS
		LEFT JOIN 
			(/*this subquery concatenates all comments for a given work order. **please update to non-cludgy version when we have 2017 thankssss** */
			SELECT Details.ADD_CODE,
			STUFF((
				SELECT '; ' + replace(replace(cast(ADD_TEXT as nvarchar(100)),char(13),'. '),char(10),'. ')
				FROM eamprod.dbo.R5ADDETAILS
				WHERE (ADD_CODE=Details.ADD_CODE)
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS CommentValues
		
			FROM eamprod.dbo.r5addetails as Details
			GROUP BY ADD_CODE) as Comments
		on R5EVENTS.EVT_CODE=Comments.ADD_CODE) as l
	LEFT JOIN eamprod.dbo.r5bookedhours r
		ON l.evt_code = r.boo_event 
	LEFT JOIN eamprod.dbo.r5objects q
		ON l.evt_object = q.obj_code
WHERE r.boo_act = 10
	and l.evt_status not in ('REJ','CANC')
	and (lower(l.evt_desc) like '% rat %' or lower(l.evt_desc) like '% rats %' or lower(evt_desc) like '%rodent%' or lower(l.evt_desc) like '%bait%' or l.evt_standwork = 'PEST')
	and (lower(l.evt_desc) not like '%hornet%' and lower(l.evt_desc) not like '%bee%')
	and cast(r.boo_date as date) BETWEEN @startdate and @enddate
	and l.evt_class NOT IN ('DAILY', 'FITNESS', 'REC-INSP', 'BP-VIO', 'SIGNS')
	and l.evt_desc <> 'Adhoc Inspection'
	and l.evt_mrc <> 'NYC'
	and l.evt_createdby NOT IN ('R5', 'KYLE.MATTISON', 'JILL.SLATER', 'YEUKCHUNG.NG', 'SCOTT.DAVENPORT', 'PETER.CARLO')
	and r.boo_hours > 0.0000
GROUP BY l.evt_code, l.evt_object, q.obj_desc, REPLACE(REPLACE(l.evt_desc, CHAR(10), ''), CHAR(13), ''), cast(l.evt_created as date), cast(l.evt_completed as date),l.evt_udfchar13, r.boo_date, l.commentvalues
) as a
GROUP BY PropID

) as WO
on WO.PropID COLLATE Latin1_General_BIN = props.omppropid


left join 
( -- Query 2 contains Daily Task information

 SELECT omppropid as property_number
	    ,CASE WHEN route_name like '%packer%' THEN 'Packer' ELSE 'Cleaning' END AS Work_Type 
		,count(date_worked) as Visits
		,count(DISTINCT date_worked) as Days_Visited
		,sum(ncrew) as Crew_Size
		,sum(ncrew*nhours) as Work_Hours
		,sum(CASE WHEN lower(notes) LIKE '%overflow%' THEN 1 ELSE 0 END) as Overflowing_Cans
		,sum(CASE WHEN lower(notes) LIKE '%food%' THEN 1 ELSE 0 END) as Food_Waste
FROM [DWH].[dbo].[tbl_dailytasks]
WHERE omppropid IN ('B351',	'B555',	'M015-01',	'M048',	'M105-06',	'M144',	'MZ436',	'X008',	'X011',	'X030',	'X030-01',	'X034',	'X047',	'X148B1',	'X148C',	'X148C4',	'X148C6',	'X148D',	'X148E1',	'X148F5',	'X153',	'X225',	'X226',	'X236',	'X254',	'X348',	'B016',	'B016-01',	'B016-02',	'B088',	'B088-02',	'B088-03',	'B139',	'B140',	'B217',	'B237',	'B262',	'B263',	'B266',	'B269',	'B298',	'B317',	'B322',	'B323',	'B334',	'B348',	'B359',	'M015',	'M033',	'M053',	'M065',	'M067',	'M071-04',	'M071-08',	'M071-13',	'M071-16',	'M071-ZN07',	'M071-ZN09',	'M082',	'M088',	'M088-01',	'M088-03',	'M105',	'M105-01',	'M105-02',	'M105-04',	'M105-08',	'M113',	'M116',	'M122',	'M123',	'M124',	'M144-01',	'M144-ZN01',	'M144-ZN02',	'M144-ZN03',	'M144-ZN04',	'M144-ZN05',	'M144-ZN06',	'M165',	'M188',	'M188A',	'M195',	'M196',	'M200',	'M201',	'M220',	'M224',	'M228',	'M229',	'M235',	'M238',	'M241',	'M246',	'M255',	'M259',	'M270',	'M321',	'X001-ZN02',	'X001A-01',	'X006',	'X008-01',	'X008-03',	'X011-ZN01',	'X011-ZN02',	'X017',	'X017-01',	'X017-02',	'X028',	'X030-02',	'X030-99',	'X030-ZN01',	'X030-ZN02',	'X032',	'X034-01',	'X034-06',	'X034-ZN01',	'X034-ZN02',	'X037',	'X042',	'X047-01',	'X047-ZN01',	'X047-ZN02',	'X068',	'X071',	'X085',	'X102',	'X108',	'X114',	'X129',	'X148C5',	'X148C7',	'X148D1',	'X148E',	'X153-01',	'X168',	'X174',	'X219',	'X244',	'X252',	'X257',	'X258',	'X263',	'X274',	'X280',	'X289',	'X291',	'X292',	'X300',	'X302',	'X348-01',	'X348-02',	'B006',	'B023',	'B037',	'B041',	'B045',	'B340',	'B395',	'B429',	'B430',	'M002',	'M004',	'M016',	'M080',	'M247',	'M254',	'X008-ZN01',	'X008-ZN02',	'X008-ZN03',	'X018',	'X030-ZN03',	'X036',	'X058',	'X059',	'X061',	'X069',	'X081',	'X115',	'X153-02',	'X271',	'X001A',	'X057',	'X067',	'X105',	'X130',	'X148B2',	'X148C1',	'X148C3',	'X269',	'XZ475')
and date_worked BETWEEN @startdate and @enddate
GROUP BY omppropid, route_name
--ORDER BY property_number, work_type

) as DT
on DT.property_number = props.omppropid

left join 
(--query 7 gets the last supervisor inspection
  SELECT omppropid
		,max(inspection_date) as last_supervisorInspection
  FROM [DWH].[dbo].[tbl_supervisorinspections_inspectionresults]
  WHERE inspection_date < = @enddate
  and inspection_status = 'Completed'
  group by omppropid
) as last_SI
on last_SI.omppropid = props.OMPPROPID COLLATE Latin1_general_BIN

left join 
(--query 8 gets last PIP inspection
SELECT [Prop ID],max(cast([Date] as date)) as last_pipinspection
FROM DWH.dbo.tbl_PIP_InspectionMain
where cast([Date] as date) <= @enddate
group by [Prop ID]
) as last_PIP
on last_PIP.[Prop ID] = props.OMPPROPID

left join 
(--query 6 gets the last Daily Task entry

SELECT omppropid
	  ,max(date_worked) as last_workentry
FROM [DWH].[dbo].[tbl_dailytasks]
WHERE date_worked <= @enddate
GROUP BY omppropid

) as last_DT
on last_DT.omppropid = props.OMPPROPID 


group by gispropnum,
props.omppropid,
signname,
department,
[NRR Zone],
sla,
supervisor_inspections,
supervisor_inspections,
rodent_sightings,
num_burrows,
PIP_inspections,
Burrows,
last_DT.last_workentry,
last_SI.last_supervisorinspection,
last_PIP.last_pipinspection,
wo.baiting_hours,
wo.days_baited,
wo.rat_ice_applications

order by Borough,district,gispropnum,omppropid,sla

GO