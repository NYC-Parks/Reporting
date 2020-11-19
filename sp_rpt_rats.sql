/****** 
RATS Query
Created By: Emma Dixon
Modified By: <Modifier info. Blank until modified>
Created Date:  <MM/DD/YYYY>                                                                                                                                                          
Modified Date: <MM/DD/YYYY> 
Project: <Name of project>
Tables Used: <Databases/tables>
Description: <purpose of query, databases used (and descriptions if needed), what is output, why modified (if modified), etc.> 
******/


SELECT 
CASE WHEN left(department,1)='B' THEN 'Brooklyn'
	WHEN left(department,1)='M' THEN 'Manhattan'
	WHEN left(department,1)='X' THEN 'Bronx'
	ELSE 'ERR' END as Borough,
[NRR Zone],
department as district,
gispropnum,
omppropid,
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
sum(coalesce(Baiting_Entries,0)) as [Baiting Work Entries],
sum(coalesce(Baiting_Hours,0)) as [Baiting Work Hours],
sum(coalesce(rat_ice_applications,0)) as [Dry Ice Applications]
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

SELECT
propid,
count(distinct cast(inspectiondate as date)) as supervisor_inspections,
sum(rodent) as rodent_sightings,
sum(CASE WHEN rodent = 1 THEN
		CASE WHEN is_numeric=1 THEN cast(comments as float) ELSE 0 END --casting as float prevents error if decimal value is entered
		ELSE 0 END) as num_burrows
FROM

(
SELECT insp.evt_mrc as district,
		insp.evt_object as propid,
		cast(insp.inspectiondate as date) as inspectiondate,
		insp.evt_created,
		insp.evt_completed,
		insp.overall_rating,
		insp.cleanliness_rating,
		res.category as feature_category,
		res.features as feature,
		res.results,
		find.FND_DESC as 'finding',
		CASE WHEN lower(find.FND_DESC) LIKE '%rodent%' THEN 1 ELSE 0 END AS rodent,
		act.mth_desc as 'action',
		res.comments,
		isnumeric(res.comments) as is_numeric
FROM AMPs_INS.dbo.Inspection_results as res
	LEFT JOIN AMPS_INS.dbo.Inspections as insp
	on res.evt_code=insp.guidid
	LEFT JOIN AMPS_INS.dbo.ref_findings as find
	on find.fnd_code=res.fnd_code
	LEFT JOIN AMPS_INS.dbo.ref_action as act
	on act.MTH_CODE=res.act_code
WHERE 
evt_status = 'Completed'
and cast(inspectiondate as date) BETWEEN @start and @end
and features='Litter'
--order by propid
) c 
--WHERE propid IN ('B351',	'B555',	'M015-01',	'M048',	'M105-06',	'M144',	'MZ436',	'X008',	'X011',	'X030',	'X030-01',	'X034',	'X047',	'X148B1',	'X148C',	'X148C4',	'X148C6',	'X148D',	'X148E1',	'X148F5',	'X153',	'X225',	'X226',	'X236',	'X237',	'X254',	'X348',	'B016',	'B016-01',	'B016-02',	'B088',	'B088-02',	'B088-03',	'B139',	'B140',	'B217',	'B237',	'B262',	'B263',	'B266',	'B269',	'B298',	'B317',	'B322',	'B323',	'B334',	'B348',	'B359',	'M015',	'M033',	'M053',	'M065',	'M067',	'M071-04',	'M071-08',	'M071-13',	'M071-16',	'M071-ZN07',	'M071-ZN09',	'M082',	'M088',	'M088-01',	'M088-03',	'M105',	'M105-01',	'M105-02',	'M105-04',	'M105-08',	'M113',	'M116',	'M122',	'M123',	'M124',	'M144-01',	'M144-ZN01',	'M144-ZN02',	'M144-ZN03',	'M144-ZN04',	'M144-ZN05',	'M144-ZN06',	'M165',	'M188',	'M188A',	'M195',	'M196',	'M200',	'M201',	'M220',	'M224',	'M228',	'M229',	'M235',	'M238',	'M241',	'M246',	'M255',	'M259',	'M270',	'M321',	'X001-ZN02',	'X001A-01',	'X006',	'X008-01',	'X008-03',	'X011-ZN01',	'X011-ZN02',	'X017',	'X017-01',	'X017-02',	'X028',	'X030-02',	'X030-99',	'X030-ZN01',	'X030-ZN02',	'X032',	'X034-01',	'X034-06',	'X034-ZN01',	'X034-ZN02',	'X037',	'X042',	'X047-01',	'X047-ZN01',	'X047-ZN02',	'X068',	'X071',	'X085',	'X102',	'X108',	'X114',	'X129',	'X148C5',	'X148C7',	'X148D1',	'X148E',	'X153-01',	'X168',	'X174',	'X219',	'X244',	'X252',	'X257',	'X258',	'X263',	'X274',	'X280',	'X289',	'X291',	'X292',	'X300',	'X302',	'X348-01',	'X348-02',	'B006',	'B023',	'B037',	'B041',	'B045',	'B340',	'B395',	'B429',	'B430',	'M002',	'M004',	'M016',	'M080',	'M247',	'M254',	'X008-ZN01',	'X008-ZN02',	'X008-ZN03',	'X018',	'X030-ZN03',	'X036',	'X058',	'X059',	'X061',	'X069',	'X081',	'X115',	'X153-02',	'X271',	'X001A',	'X057',	'X067',	'X105',	'X130',	'X148B2',	'X148C1',	'X148C3',	'X269',	'XZ475')
group by propid 

) as SI

on SI.propid = props.omppropid



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
WHERE cast([Date] as date) BETWEEN @start and @end
group by [Prop ID]
) as PIP
on PIP.[Prop ID] = props.omppropid


LEFT JOIN 
( -- Query 5 contains AMPS baiting work orders

SELECT

PropID,
count([Date Worked]) as Baiting_Entries,
sum([LABOR HOURS]) as Baiting_Hours,
sum(CASE WHEN Comments LIKE '%rat ice%' THEN 1 ELSE 0 END) as rat_ice_applications

FROM
( 


SELECT WO.EVT_CODE as WorkOrder_ID,
WO.EVT_OBJECT AS 'PropID', 
R5OBJECTS.OBJ_DESC AS 'Prop Name', 
REPLACE(REPLACE(WO.EVT_DESC, CHAR(10), ''), CHAR(13), '') AS 'Description', 
--cast(WO.EVT_CREATED as date) as 'Date Created',
--cast(WO.EVT_COMPLETED as date) AS 'Date Completed', 
WO.EVT_UDFCHAR13 as 'Work Order Status',
cast(bookedhours.boo_date as date) as 'Date Worked',
/*sum(CASE WHEN BOOKEDHOURS.BOO_ACT = 20 THEN BOOKEDHOURS.BOO_HOURS
	ELSE 0 END) AS 'TRAVEL HOURS', */
sum(BOOKEDHOURS.BOO_HOURS) AS 'LABOR HOURS',
--MAX(BOOKEDHOURS.BOO_DATE) AS 'LastDateWorked',
coalesce(WO.CommentValues,'') as 'Comments'
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
		on R5EVENTS.EVT_CODE=Comments.ADD_CODE) as WO

		LEFT JOIN 
		(SELECT * FROM EAMPROD.dbo.R5Bookedhours WHERE r5Bookedhours.boo_act=10 --only labor entries
		) as BookedHours
		on WO.EVT_CODE = bookedhours.BOO_EVENT

		LEFT JOIN EAMPROD.dbo.r5objects
		on WO.EVT_OBJECT = R5OBJECTS.OBJ_CODE


WHERE      (lower(WO.evt_desc) like '% rat %' or lower(WO.evt_desc) like '% rats %' or lower(WO.evt_desc) like '%rodent%' or lower(WO.evt_desc) like '%bait%' or WO.EVT_STANDWORK = 'PEST') and 
						  (lower(WO.evt_desc) not like '%hornet%' and lower(WO.evt_desc) not like '%bee%')
						  and cast(bookedhours.boo_date as date) BETWEEN @start and @end
                         and (WO.EVT_CLASS NOT IN ('DAILY', 'FITNESS', 'REC-INSP', 'BP-VIO', 'SIGNS')) AND (WO.EVT_DESC <> 'Adhoc Inspection') AND 
                         (WO.EVT_MRC <> 'NYC') AND (WO.EVT_CREATEDBY NOT IN ('R5', 'KYLE.MATTISON', 'JILL.SLATER', 'YEUKCHUNG.NG', 'SCOTT.DAVENPORT', 
                         'PETER.CARLO')) 
			AND BOOKEDHOURS.BOO_HOURS > 0.0000
			--AND WO.EVT_OBJECT IN ('B351',	'B555',	'M015-01',	'M048',	'M105-06',	'M144',	'MZ436',	'X008',	'X011',	'X030',	'X030-01',	'X034',	'X047',	'X148B1',	'X148C',	'X148C4',	'X148C6',	'X148D',	'X148E1',	'X148F5',	'X153',	'X225',	'X226',	'X236',	'X237',	'X254',	'X348',	'B016',	'B016-01',	'B016-02',	'B088',	'B088-02',	'B088-03',	'B139',	'B140',	'B217',	'B237',	'B262',	'B263',	'B266',	'B269',	'B298',	'B317',	'B322',	'B323',	'B334',	'B348',	'B359',	'M015',	'M033',	'M053',	'M065',	'M067',	'M071-04',	'M071-08',	'M071-13',	'M071-16',	'M071-ZN07',	'M071-ZN09',	'M082',	'M088',	'M088-01',	'M088-03',	'M105',	'M105-01',	'M105-02',	'M105-04',	'M105-08',	'M113',	'M116',	'M122',	'M123',	'M124',	'M144-01',	'M144-ZN01',	'M144-ZN02',	'M144-ZN03',	'M144-ZN04',	'M144-ZN05',	'M144-ZN06',	'M165',	'M188',	'M188A',	'M195',	'M196',	'M200',	'M201',	'M220',	'M224',	'M228',	'M229',	'M235',	'M238',	'M241',	'M246',	'M255',	'M259',	'M270',	'M321',	'X001-ZN02',	'X001A-01',	'X006',	'X008-01',	'X008-03',	'X011-ZN01',	'X011-ZN02',	'X017',	'X017-01',	'X017-02',	'X028',	'X030-02',	'X030-99',	'X030-ZN01',	'X030-ZN02',	'X032',	'X034-01',	'X034-06',	'X034-ZN01',	'X034-ZN02',	'X037',	'X042',	'X047-01',	'X047-ZN01',	'X047-ZN02',	'X068',	'X071',	'X085',	'X102',	'X108',	'X114',	'X129',	'X148C5',	'X148C7',	'X148D1',	'X148E',	'X153-01',	'X168',	'X174',	'X219',	'X244',	'X252',	'X257',	'X258',	'X263',	'X274',	'X280',	'X289',	'X291',	'X292',	'X300',	'X302',	'X348-01',	'X348-02',	'B006',	'B023',	'B037',	'B041',	'B045',	'B340',	'B395',	'B429',	'B430',	'M002',	'M004',	'M016',	'M080',	'M247',	'M254',	'X008-ZN01',	'X008-ZN02',	'X008-ZN03',	'X018',	'X030-ZN03',	'X036',	'X058',	'X059',	'X061',	'X069',	'X081',	'X115',	'X153-02',	'X271',	'X001A',	'X057',	'X067',	'X105',	'X130',	'X148B2',	'X148C1',	'X148C3',	'X269',	'XZ475')

GROUP BY WO.EVT_CODE,WO.EVT_OBJECT,R5OBJECTS.OBJ_DESC,REPLACE(REPLACE(WO.EVT_DESC, CHAR(10), ''), CHAR(13), ''), 
cast(WO.EVT_CREATED as date),
cast(WO.EVT_COMPLETED as date), 
WO.EVT_UDFCHAR13,
bookedhours.boo_date, WO.CommentValues

--order by PropID, [Date Worked]
) as b
GROUP BY PropID 
) as WO
on WO.PropID COLLATE Latin1_General_BIN = props.omppropid


left join 
( -- Query 2 contains Daily Task information

SELECT 
property_number,
Work_Type,
count(Work_Date) as Visits,
count(DISTINCT Work_Date) as Days_Visited,
sum(cast(Crew_Size as float)) as Crew_Size,
sum(cast(Crew_Size * Mins_Worked as float)/60.0) as Work_Hours,
sum(CASE WHEN lower(notes) LIKE '%overflow%' THEN 1 ELSE 0 END) as Overflowing_Cans,
sum(CASE WHEN lower(notes) LIKE '%food%' THEN 1 ELSE 0 END) as Food_Waste

FROM
(
SELECT  
	  isnull(tbl_daily_task_property.property_number,'-') as property_number
	  ,case when lower(route_name) LIKE '%packer%' THEN 'Packer' ELSE 'Cleaning' END AS 'Work_Type'
      ,isnull(sum(DailyTasks.dbo.tbl_daily_task_crew.cpw+DailyTasks.dbo.tbl_daily_task_crew.jtp+DailyTasks.dbo.tbl_daily_task_crew.csa
				+DailyTasks.dbo.tbl_daily_task_crew.apsw+DailyTasks.dbo.tbl_daily_task_crew.npw),0) as 'Crew_Size'
      ,cast(DailyTasks.dbo.tbl_daily_task.date_worked as date) as 'Work_Date'
      ,cast(min(DailyTasks.dbo.tbl_daily_task_activity.start_time) as time(0)) as 'start_time'
      ,cast(max(DailyTasks.dbo.tbl_daily_task_activity.end_time) as time(0)) as 'end_time'
	  ,DailyTasks.dbo.tbl_daily_task_activity.dumping as dumping
	  ,Case when max(Repeat_Count.Repeats) = 1 then datediff(mi,min(DailyTasks.dbo.tbl_daily_task_activity.start_time),max(DailyTasks.dbo.tbl_daily_task_activity.end_time))
			else (datediff(mi,min(DailyTasks.dbo.tbl_daily_task_activity.start_time),max(DailyTasks.dbo.tbl_daily_task_activity.end_time))/max(Repeat_Count.Repeats)) End as 'Mins_Worked'	
	  ,DailyTasks.dbo.tbl_daily_task_activity.notes 

      
  FROM DailyTasks.dbo.tbl_daily_task_activity
		left outer join DailyTasks.dbo.tbl_daily_task_property on DailyTasks.dbo.tbl_daily_task_activity.daily_task_activity__id = DailyTasks.dbo.tbl_daily_task_property.daily_task_activity__id
		inner join DailyTasks.dbo.ref_activity on DailyTasks.dbo.tbl_daily_task_activity.activity__id = DailyTasks.dbo.ref_activity.activity__id
		left outer join DailyTasks.dbo.tbl_daily_task_crew on DailyTasks.dbo.tbl_daily_task_activity.daily_task_activity__id = DailyTasks.dbo.tbl_daily_task_crew.daily_task_activity__id
		left outer join DailyTasks.dbo.tbl_daily_task on DailyTasks.dbo.tbl_daily_task.daily_task__id = DailyTasks.dbo.tbl_daily_task_activity.daily_task__id
		left outer join EAMPROD.dbo.R5OBJECTS	on DailyTasks.dbo.tbl_daily_task_property.property_number = OBJ_CODE collate SQL_Latin1_General_CP1_CI_AS
		left outer join DailyTasks.dbo.tbl_route on DailyTasks.dbo.tbl_daily_task.route__id =  DailyTasks.dbo.tbl_route.route__id
		left outer join ( select	DailyTasks.dbo.tbl_daily_task_activity.daily_task_activity__id
									,max(daily_task__id) as 'DT_ID'
									,max(DailyTasks.dbo.tbl_daily_task_property.property_number)as 'One_prop'
									,count(daily_task__id) as 'Repeats'
							from DailyTasks.dbo.tbl_daily_task_activity
									left outer join DailyTasks.dbo.tbl_daily_task_property on DailyTasks.dbo.tbl_daily_task_property.daily_task_activity__id = DailyTasks.dbo.tbl_daily_task_activity.daily_task_activity__id
							group by DailyTasks.dbo.tbl_daily_task_activity.daily_task_activity__id
										) as Repeat_Count 
			on Repeat_Count.daily_task_activity__id = DailyTasks.dbo.tbl_daily_task_activity.daily_task_activity__id
		left outer join (SELECT district, max(sector) as sector FROM dailytasks.dbo.ref_sector_districts group by district) as ref_dist
					on district=EAMPROD.dbo.R5OBJECTS.OBJ_MRC COLLATE latin1_general_BIN
		
		
Where 	DailyTasks.dbo.tbl_daily_task_property.property_number IN ('B351',	'B555',	'M015-01',	'M048',	'M105-06',	'M144',	'MZ436',	'X008',	'X011',	'X030',	'X030-01',	'X034',	'X047',	'X148B1',	'X148C',	'X148C4',	'X148C6',	'X148D',	'X148E1',	'X148F5',	'X153',	'X225',	'X226',	'X236',	'X254',	'X348',	'B016',	'B016-01',	'B016-02',	'B088',	'B088-02',	'B088-03',	'B139',	'B140',	'B217',	'B237',	'B262',	'B263',	'B266',	'B269',	'B298',	'B317',	'B322',	'B323',	'B334',	'B348',	'B359',	'M015',	'M033',	'M053',	'M065',	'M067',	'M071-04',	'M071-08',	'M071-13',	'M071-16',	'M071-ZN07',	'M071-ZN09',	'M082',	'M088',	'M088-01',	'M088-03',	'M105',	'M105-01',	'M105-02',	'M105-04',	'M105-08',	'M113',	'M116',	'M122',	'M123',	'M124',	'M144-01',	'M144-ZN01',	'M144-ZN02',	'M144-ZN03',	'M144-ZN04',	'M144-ZN05',	'M144-ZN06',	'M165',	'M188',	'M188A',	'M195',	'M196',	'M200',	'M201',	'M220',	'M224',	'M228',	'M229',	'M235',	'M238',	'M241',	'M246',	'M255',	'M259',	'M270',	'M321',	'X001-ZN02',	'X001A-01',	'X006',	'X008-01',	'X008-03',	'X011-ZN01',	'X011-ZN02',	'X017',	'X017-01',	'X017-02',	'X028',	'X030-02',	'X030-99',	'X030-ZN01',	'X030-ZN02',	'X032',	'X034-01',	'X034-06',	'X034-ZN01',	'X034-ZN02',	'X037',	'X042',	'X047-01',	'X047-ZN01',	'X047-ZN02',	'X068',	'X071',	'X085',	'X102',	'X108',	'X114',	'X129',	'X148C5',	'X148C7',	'X148D1',	'X148E',	'X153-01',	'X168',	'X174',	'X219',	'X244',	'X252',	'X257',	'X258',	'X263',	'X274',	'X280',	'X289',	'X291',	'X292',	'X300',	'X302',	'X348-01',	'X348-02',	'B006',	'B023',	'B037',	'B041',	'B045',	'B340',	'B395',	'B429',	'B430',	'M002',	'M004',	'M016',	'M080',	'M247',	'M254',	'X008-ZN01',	'X008-ZN02',	'X008-ZN03',	'X018',	'X030-ZN03',	'X036',	'X058',	'X059',	'X061',	'X069',	'X081',	'X115',	'X153-02',	'X271',	'X001A',	'X057',	'X067',	'X105',	'X130',	'X148B2',	'X148C1',	'X148C3',	'X269',	'XZ475')
		and DailyTasks.dbo.tbl_daily_task.date_worked BETWEEN @start and @end

GROUP BY	

		isnull(tbl_daily_task_property.property_number,'-')
		,DailyTasks.dbo.tbl_daily_task_activity.daily_task_activity__id
		,DailyTasks.dbo.tbl_daily_task.operator 
		,cast( DailyTasks.dbo.tbl_daily_task.date_worked as date)
		,DailyTasks.dbo.tbl_daily_task.daily_task__id
		,DailyTasks.dbo.tbl_daily_task.fixed_post
		,DailyTasks.dbo.tbl_route.route_name
		,DailyTasks.dbo.tbl_daily_task_activity.dumping
		,DailyTasks.dbo.tbl_daily_task_activity.notes 
--ORDER BY 'Work Date',DailyTasks.dbo.tbl_daily_task.daily_task__id,start_time
) a
GROUP BY property_number,
Work_Type
) as DT
on DT.property_number = props.omppropid

left join 
(--query 7 gets the last supervisor inspection
SELECT evt_object,max(cast(inspectiondate as date)) as last_supervisorinspection
FROM AMPS_INS.dbo.Inspections
where cast(inspectiondate as date) <= @end
and evt_status = 'Completed'
group by evt_object
) as last_SI
on last_SI.evt_object = props.OMPPROPID

left join 
(--query 8 gets last PIP inspection
SELECT [Prop ID],max(cast([Date] as date)) as last_pipinspection
FROM DWH.dbo.tbl_PIP_InspectionMain
where cast([Date] as date) <= @end
group by [Prop ID]
) as last_PIP
on last_PIP.[Prop ID] = props.OMPPROPID

left join 
(--query 6 gets the last Daily Task entry
SELECT property_number,max(cast(task.date_worked as date)) as last_workentry 
FROM 
dailytasks.dbo.tbl_daily_task as task
LEFT JOIN dailytasks.dbo.tbl_daily_task_activity as act
on task.daily_task__id=act.daily_task__id
LEFT JOIN dailytasks.dbo.tbl_daily_task_property as prop
on prop.daily_task_activity__id=act.daily_task_activity__id
WHERE cast(task.date_worked as date) <= @end
group by property_number
) as last_DT
on last_DT.property_number = props.OMPPROPID 

group by gispropnum,
omppropid,
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
last_PIP.last_pipinspection


order by Borough,district,gispropnum,omppropid,sla