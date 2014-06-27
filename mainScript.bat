@rem *****************************************
@rem Set base variables
@rem *****************************************

@cls

@echo off

Setlocal EnableDelayedExpansion

rem database params

SET PGPASSWORD=14707796
SET DBNAME=dentsply_fullsb
SET DBUSER=postgres

rem salesforce params

SET READENDPOINT=https://test.salesforce.com/services/Soap/u/29.0
SET READUSERNAME=kgalant@dentsply.com.fullsb
rem SET READPASSWORD=11e9c01ede56ee50aab74f014238e17c
SET READPASSWORD=ce9f52eab752286ade885e5c3c4668b8
SET WRITEENDPOINT=https://test.salesforce.com/services/Soap/u/29.0
SET WRITEUSERNAME=kgalant@wellspect.com.fullsb
rem SET WRITEPASSWORD=11e9c01ede56ee50aab74f014238e17c
SET WRITEPASSWORD=ce9f52eab752286ade885e5c3c4668b8
SET LOGPREFIX=%date:~6,4%%date:~3,2%%date:~0,2%_%time:~0,2%.%time:~3,2%.%time:~6,2%.%time:~9,2%
SET LOGFILE="%BASEDIR%logs\log-%LOGPREFIX%.txt"
SET LIMIT=
SET FILEPREFIX=%1
SET BULKAPI=true
SET BATCHSIZE=200

@echo Log file: %LOGFILE%

IF NOT DEFINED FILEPREFIX (
	SET FILEPREFIX=0*
)

rem assuming directory structure going out from the place where this batch file resides
SET BASEDIR=%~dp0
SET BASEFILEDIR=%BASEDIR%files\
SET MAPPINGDIR=%BASEDIR%mappingfiles
SET CONFIGSDIR=%BASEDIR%configs

SET CLIQ=c:\Dev\ApexDataLoader\cliq_process\
SET PSQLCMD="C:\Program Files\PostgreSQL\9.3\bin\psql.exe"
SET BATDIR=%~dp0
SET FART=%BASEDIR%fart.exe
SET BTSTARTED=0

SET STDEXPORT=stdexport
SET STDINSERT=stdinsert
SET STDUPSERT=stdupsert


SET DLPATH=c:\Dev\ApexDataLoader


for /f %%d in ('dir /a:-d /b %BASEDIR%configs\%FILEPREFIX%') do (
   @echo Processing file %%d

	SET EXP=0
	SET TRUNC=0
	SET LOADPGSQL=0
	SET REMAP=0
	SET FARTMAP=0
	SET UNLOADPGSQL=0
	SET IMP=0
	SET UPS=0
	SET EXPMAP=0
	SET DOFIRSTSQL=0
	SET UNLOADWHERE=
   
		for /f "eol=# tokens=1,2 delims=:" %%a in (%BASEDIR%configs\%%d) do (
			SET %%a=%%b
			rem echo SET %%a=%%b
		)
	
	@echo ******************************
	@echo !JOBDESC!
	@echo ******************************
	
rem		echo FIELDSTRING=!FIELDSTRING!
rem 	echo SOQL=!SOQL!
rem 	echo MAPPINGSOQL=!MAPPINGSOQL!
rem 	echo OLDNEWIDFILENAME=!OLDNEWIDFILENAME!
rem 	echo ENTITY=!ENTITY!
rem 	echo FIELDSTOREMAP=!FIELDSTOREMAP!
rem 	echo FILENAME=!FILENAME!
rem 	echo MAPPEDFILENAME=!MAPPEDFILENAME!
rem 	echo SFMAPPINGFILE=!SFMAPPINGFILE!
rem echo UNLOADWHERE=%UNLOADWHERE%

	IF !EXP!==1 (
		@echo Max rowcount for export: !LIMIT!
		IF !BTSTARTED!==0 (
			@start c:\tools\baretail.exe %LOGFILE%
			SET BTSTARTED=1			
		)
		call :StandardExport !OBJECT! !ENTITY! "!SOQL!" !FILENAME! !READENDPOINT! !READUSERNAME! !READPASSWORD!
	) ELSE (
		@echo Skipping: Export for !JOBDESC!
	)

	IF !TRUNC!==1 (
		call :Truncate
	) ELSE (
		@echo Skipping: Truncate for !JOBDESC!
	)
	
		
	IF !FARTMAP!==1 (
		call :Fart !FILENAME! !FARTMAPPING!
	) ELSE (
		@echo Skipping: FART remap for !JOBDESC!
	)
	
	
	IF !LOADPGSQL!==1 (
		call :LoadToPostgres !OBJECT! "!FIELDSTRING!" !FILENAME!
	) ELSE (
		@echo Skipping: Load into Postgres for !JOBDESC!
	)

	IF !REMAP!==1 (
		for %%c in (!FIELDSTOREMAP!) do (
			call :Remap "%%c"
		)
	) ELSE (
		@echo Skipping: Load into Postgres for !JOBDESC!
	)

	IF !DOFIRSTSQL!==1 (
		call :DoSQL "!FIRSTSQL!"
	)
	
	IF !UNLOADPGSQL!==1 (
	rem call :UnloadFromPostgres !OBJECT! "!FIELDSTRING!" !MAPPEDFILENAME!
		IF [!FIELDSTRINGEXPORT!]==[] (
			call :UnloadFromPostgres !OBJECT! "!FIELDSTRING!" !MAPPEDFILENAME! "!UNLOADWHERE!"
		) ELSE (
			call :UnloadFromPostgres !OBJECT! "!FIELDSTRINGEXPORT!" !MAPPEDFILENAME!
		)
	) ELSE (
		@echo Requested not to Unload from Postgres for !JOBDESC! by parameter set
	)
	
	IF !IMP!==1 (
		IF !BTSTARTED!==0 (
			@start c:\tools\baretail.exe %LOGFILE%
			SET BTSTARTED=1			
		)
		call :StandardImport !OBJECT! !ENTITY! %MAPPINGDIR%\!SFMAPPINGFILE! !MAPPEDFILENAME!
	) ELSE (
		@echo Skipping: Import for !JOBDESC!
	)
	
	IF !UPS!==1 (
		IF !BTSTARTED!==0 (
			@start c:\tools\baretail.exe %LOGFILE%
			SET BTSTARTED=1			
		)
		call :StandardUpsert !OBJECT! !ENTITY! %MAPPINGDIR%\!SFMAPPINGFILE! !FILENAME!
	) ELSE (
		@echo Skipping: Upsert for !JOBDESC!
	)

	IF !EXPMAP!==1 (
		echo !JOBDESC! - Updating mapping table in local database
		call :StandardExport !OBJECT! !ENTITY! "!MAPPINGSOQL!" !OLDNEWIDFILENAME! !WRITEENDPOINT! !WRITEUSERNAME! !WRITEPASSWORD!
		call :UpdateDBMappingTable !OLDNEWIDFILENAME! !OBJECT!
	) ELSE (
		@echo Skipping: Export mapping for !JOBDESC!
	)
)

exit /b











@echo off
rem *****************************************************
rem *				FART								*
rem *				Find And Replace Text				*
rem * Expects following parameters to be set:			*
rem * JOBDESC											* 
rem * 1 - FILENAME, 									* 
rem * 2 - FART mapping file,							* 
rem * Will FART against the FILENAME for each mapping  	*
rem * line in the FART mapping file like				*
rem * texttofind=texttoreplace							*
rem *													*
rem *****************************************************

:Fart

@echo off
@echo !JOBDESC! - FART - Find And Replace Text
@echo %time%: Starting FART
@echo Filename: %~1
@echo mapping file: %~2

for /f "eol=# tokens=1,2 delims== " %%a in (%~2) do (
			for /f "tokens=*" %%x in ('%FART% %~1 %%a %%b') do set FARTOUTPUT=%%x
			echo Replaced %%a with %%b : !FARTOUTPUT!
			
		)

@echo %time%: Finished FART
exit /b

@echo off
rem *****************************************************
rem *				StandardExport						*
rem * Expects following parameters to be set:			*
rem * JOBDESC								* 
rem * 1 - OBJECT, 										* 
rem * 2 - ENTITY,										* 
rem * 3 - SOQL,											* 
rem * 4 - FILENAME										* 
rem * Will execute the SOQL against the ENTITY, then 	*
rem * Move the output to FILENAME						*
rem *													*
rem *****************************************************

:StandardExport
@echo off
@echo !JOBDESC! - StandardExport
@echo %time%: Making Apex DataLoader config file (process-conf.xml)

SET FILETS=_%time:~0,2%.%time:~3,2%.%time:~6,2%.%time:~9,2%

@java -jar c:\tools\saxon9he.jar -s:%BASEDIR%%STDEXPORT%\process-conf-base.xml -xsl:PrepExportConfig.xsl -o:%BASEDIR%%STDEXPORT%\process-conf-%~1.xml csv="%BASEDIR%%STDEXPORT%\output\%~1_!FILETS!.csv" dataaccess=csvWrite logdir=%BASEDIR%%STDEXPORT%\log entity=%~2 soql="%~3 !LIMIT!" operation=extract endpoint=%~5 username=%~6 password=%~7 bulkapi=!BULKAPI!  batchsize=!BATCHSIZE!


@type %BASEDIR%%STDEXPORT%\doctype.txt %BASEDIR%%STDEXPORT%\process-conf-%~1.xml > %BASEDIR%%STDEXPORT%\process-conf.xml 2>>%LOGFILE%

@echo %time%: Calling export using %~6
@java -cp %DLPATH%\* -Dsalesforce.config.dir=%BASEDIR%%STDEXPORT%\ com.salesforce.dataloader.process.ProcessRunner process.name=standard_export >> %LOGFILE% 2>&1
rem call %DLPATH%\Java\bin\java.exe -cp %DLPATH%\* -Dsalesforce.config.dir=%BASEDIR%%STDEXPORT% com.salesforce.dataloader.process.ProcessRunner process.name=standard_export
@echo %time%: Export complete

IF NOT EXIST %BASEFILEDIR%%~1 (
	@mkdir %BASEFILEDIR%%~1
)

move "%BASEDIR%%STDEXPORT%\output\%~1_!FILETS!.csv" %~4
rem this is CALLed, so we need to Exit /b instead of the GOTO
exit /b

@echo off
rem *****************************************************
rem *				StandardImport						*
rem * Expects following parameters to be set:			*
rem * JOBDESC											* 
rem * 1 - OBJECT, 										* 
rem * 2 - ENTITY,										* 
rem * 3 - Mapping_FILENAME								* 
rem * 4 - FILENAME										* 
rem * Will execute the SOQL against the ENTITY, then 	*
rem * Move the output to FILENAME						*
rem *													*
rem *****************************************************

:StandardImport
@echo off
@echo !JOBDESC! - StandardImport
@echo %time%: Making Apex DataLoader config file (process-conf.xml)

@java -jar c:\tools\saxon9he.jar -s:%BASEDIR%%STDINSERT%\process-conf-base.xml -xsl:PrepExportConfig.xsl -o:%BASEDIR%%STDINSERT%\process-conf-%~1.xml csv=%~4 dataaccess=csvRead logdir=%BASEDIR%%STDINSERT%\log mappingfile=%~3 entity=%~2 operation=insert endpoint=%WRITEENDPOINT% username=%WRITEUSERNAME% password=%WRITEPASSWORD% bulkapi=!BULKAPI!  batchsize=!BATCHSIZE!

@type %BASEDIR%%STDINSERT%\doctype.txt %BASEDIR%%STDINSERT%\process-conf-%OBJECT%.xml > %BASEDIR%%STDINSERT%\process-conf.xml  2>>%LOGFILE%



@echo %time%: Calling import using %WRITEUSERNAME%
@java -cp %DLPATH%\* -Dsalesforce.config.dir=%BASEDIR%%STDINSERT%\ com.salesforce.dataloader.process.ProcessRunner process.name=standard_insert >> %LOGFILE% 2>&1
@echo %time%: Import complete

rem this is CALLed, so we need to Exit /b instead of the GOTO
exit /b

@echo off
rem *****************************************************
rem *				StandardImport						*
rem * Expects following parameters to be set:			*
rem * JOBDESC											* 
rem * 1 - OBJECT, 										* 
rem * 2 - ENTITY,										* 
rem * 3 - Mapping_FILENAME								* 
rem * 4 - FILENAME										* 
rem * Will execute the SOQL against the ENTITY, then 	*
rem * Move the output to FILENAME						*
rem *													*
rem *****************************************************

:StandardUpsert
@echo off
@echo !JOBDESC! - StandardUpsert
@echo %time%: Making Apex DataLoader config file (process-conf.xml)

@java -jar c:\tools\saxon9he.jar -s:%BASEDIR%%STDUPSERT%\process-conf-base.xml -xsl:PrepExportConfig.xsl -o:%BASEDIR%%STDUPSERT%\process-conf-%~1.xml csv=%~4 dataaccess=csvRead logdir=%BASEDIR%%STDUPSERT%\log mappingfile=%~3 entity=%~2 operation=upsert endpoint=%WRITEENDPOINT% username=%WRITEUSERNAME% password=%WRITEPASSWORD% bulkapi=!BULKAPI!  batchsize=!BATCHSIZE! externalid=OldId__c 

@type %BASEDIR%%STDUPSERT%\doctype.txt %BASEDIR%%STDUPSERT%\process-conf-%OBJECT%.xml > %BASEDIR%%STDUPSERT%\process-conf.xml  2>>%LOGFILE%

@echo %time%: Calling upsert
@java -cp %DLPATH%\* -Dsalesforce.config.dir=%BASEDIR%%STDUPSERT%\ com.salesforce.dataloader.process.ProcessRunner process.name=standard_upsert >> %LOGFILE% 2>&1
@echo %time%: Upsert complete

rem this is CALLed, so we need to Exit /b instead of the GOTO
exit /b




@echo off
rem *****************************************************
rem *				Truncate							*
rem * Expects following parameters to be set:			*
rem * JOBDESC, OBJECT, NEXTSTEP							* 
rem * Will truncate the OBJECT table in Postgres 		*
rem *													*
rem *****************************************************

:Truncate

@echo !JOBDESC! - Truncate
%PSQLCMD% -U %DBUSER% -d %DBNAME% -c "TRUNCATE !OBJECT!;"
rem this is CALLed, so we need to Exit /b instead of the GOTO
exit /b

@echo off
rem *****************************************************
rem *				LoadToPostgres						*
rem * Expects following parameters to be set:			*
rem * 1 - object										*
rem * 2 - Field string									*
rem * 3 - Filename to load from 						*
rem *													*
rem * Will load the FILENAME into Postgres			 	*
rem *													*
rem *****************************************************

:LoadToPostgres

@echo !OBJECT! - Load into PostgreSQL
@echo %time%: calling database command
%PSQLCMD% -U %DBUSER% -d %DBNAME% -c "COPY %~1 (%~2) FROM '%~3' DELIMITER ',' CSV ENCODING 'UTF-8' NULL '' HEADER;"
@echo %time%: database command complete
rem this is CALLed, so we need to Exit /b instead of the GOTO
exit /b

@echo off
rem *****************************************************
rem *					Remap							*
rem * Expects following parameters to be set:			*
rem * param1=item to remap, OBJECT, NEXTSTEP 			*
rem *													*
rem * Will remap the ids using existing mapping	table	*
rem * (mapping_master). Assumes mapping table is 		*
rem * updated											*
rem *													*
rem *****************************************************

:Remap
@echo ***********************************************************
@echo *                                                         *
@echo * !OBJECT! - Remap %~1 in PGSQL
@echo * %time%: calling database command 
rem %PSQLCMD% -U %DBUSER% -d %DBNAME% -c "UPDATE !OBJECT! SET %~1 = 'cannot_map' WHERE id in (select id from !OBJECT! t left join mapping_master m on (t.%~1=m.dentsplyid) WHERE m.wellspectid is null and %~1<>''); UPDATE !OBJECT! SET %~1 = COALESCE(rt.wellspectid, 'cannot map') FROM (SELECT m.wellspectid, m.dentsplyid FROM mapping_master m WHERE m.dentsplyid is not null and m.dentsplyid<>'') rt WHERE !OBJECT!.%~1 = rt.dentsplyid; "
%PSQLCMD% -U %DBUSER% -d %DBNAME% -c "UPDATE !OBJECT! SET %~1 = rt.wellspectid FROM (SELECT m.wellspectid, m.dentsplyid FROM mapping_master m WHERE m.dentsplyid is not null and m.dentsplyid<>'') rt WHERE !OBJECT!.%~1 = rt.dentsplyid; "
@echo * %time%: database command complete
@echo *                                                         *
@echo ***********************************************************
rem this is CALLed, so we need to Exit /b instead of the GOTO
exit /b

@echo off
rem *****************************************************
rem *					DoSQL							*
rem * Expects following parameters to be set:			*
rem * param1=SQL to run						 			*
rem *													*
rem * Will run the SQL verbatim							*
rem *													*
rem *****************************************************

:DoSQL
@echo !OBJECT! - DoSQL in PGSQL
@echo %time%: calling database command 
%PSQLCMD% -U %DBUSER% -d %DBNAME% -c "%~1"
@echo %time%: database command complete
rem this is CALLed, so we need to Exit /b instead of the GOTO
exit /b


@echo off
rem *****************************************************
rem *				UnloadFromPostgres					*
rem * Expects following parameters to be set:			*
rem * 1 - object										*
rem * 2 - Field string									*
rem * 3 - Filename to load from 						*
rem * 4 - WHERE-clause (if any)													*
rem * Will load the FILENAME into Postgres			 	*
rem *													*
rem *****************************************************



:UnloadFromPostgres
@echo !OBJECT! - Unload from PostgreSQL
%PSQLCMD% -U %DBUSER% -d %DBNAME% -c "COPY (SELECT %~2 FROM %~1 %~4) TO '%~3' DELIMITER ',' CSV ENCODING 'UTF-8' NULL '' HEADER;"
rem this is CALLed, so we need to Exit /b instead of the GOTO
exit /b


@echo off
rem *****************************************************
rem *				UpdateDBMappingTable				*
rem * Expects following parameters to be set:			*
rem * 1 - Filename to load mapping from					*
rem * 2 - String to prefix tablekey field in table		*
rem *													*
rem * Will update the FILENAME into Postgres master	 	*
rem * mapping table										*
rem *****************************************************

:UpdateDBMappingTable
@echo !OBJECT! - Update PostgreSQL MappingTable

%PSQLCMD% -U %DBUSER% -d %DBNAME% -c "CREATE LOCAL TEMPORARY TABLE mapping_full_temp (   dentsplyid VARCHAR(18),   wellspectid VARCHAR(18),   tablekey VARCHAR(255) )  ON COMMIT PRESERVE ROWS;  COPY mapping_full_temp (wellspectid, dentsplyid, tablekey) FROM '%~1' DELIMITER ',' CSV ENCODING 'UTF-8' NULL '' HEADER;  DELETE FROM mapping_master WHERE dentsplyid IN (select dentsplyid from mapping_full_temp) or wellspectid in (select wellspectid from mapping_full_temp) or tablekey like '%~2_%%';  INSERT INTO mapping_master(dentsplyid, wellspectid, tablekey) SELECT dentsplyid, wellspectid, '%~2_' || tablekey FROM mapping_full_temp WHERE dentsplyid is not null and dentsplyid<>'' and wellspectid is not null and wellspectid<>'';       DROP TABLE mapping_full_temp;"

rem this is CALLed, so we need to Exit /b instead of the GOTO
exit /b
