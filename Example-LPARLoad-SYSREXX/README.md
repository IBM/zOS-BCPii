## Example-LPARLoad-SYSREXX

This sample demonstrates how to use BCPii HWIREST from a System REXX interface to load an LPAR, including a possible activation of the LPAR before hand.

This sample uses HWIREST to:

- List CPCs, filtered by the CPC name (ARG_CPC_NAME), in order to retrieve the URI and target name associated with that CPC
- List the LPARs on that CPC, filtered by the LPAR name (ARG_LPAR_NAME), in order to retrieve the URI and target name associated with that LPAR
- Inspect the status of the LPAR
  - if the LPAR is already `operating` then there is nothing to do
  - if the LPAR is `not-activated` then
    - ACTIVATE the LPAR
    - POLL the returned job-uri for the result of the ACTIVATE operation
    - If Activate is successful, Continue to the LOAD
- Load the LPAR, passing in the specified:
  - LOADADDR_VALUE, correlates with the JSON attribute `load-address` in the request body
  - LOADPARM_VALUE, correlates with the JSON attribute `load-parameter` in the request body
- POLL the job-uri for the result of the LOAD operation

## System and Exec Prep work
1. Ensure your z/OS user ID has the specified access to the following FACILITY Class Profiles
    - READ access to HWI.TARGET.netid.nau
    - CONTROL HWI.TARGET.netid.nau.imagename

    <p>where netid.nau represents the 3-to-17 character SNA name of the particular CPC and imagename represents the 1-to-8 character LPAR name that will be used as input.  
    Optionally the * char can be used instead of imagename to represent all of the LPARs available on that CPC.   </p>

1. Store hwixmrs3.rexx into a data set that is in the search path as defined in an AXRnn parmlib member.

1. Update the following variables in hwixmrs3.rexx
```
ARG_CPC_NAME  - name of the CPC associated with the LPAR to be LOADED
ARG_LPAR_NAME - name of the LPAR to be loaded
ARG_LOAD_ADDR - value for the load address
ARG_LOAD_PARM - value for the load parameter

Optionally update:
POLL_INTERVAL - seconds between poll attempts (default 5 seconds)  
POLL_TIME_LIMIT - abandon polling if no response (default 10 minutes)          
```

## Invocation
<b>NOTE:</b>The following sample invocation takes advantage of HWIREXX to drive the exec in a SYSTEM REXX environment.
 
[HWIREXX Documentation](https://www.ibm.com/docs/en/zos/2.5.0?topic=environment-using-hwirexx-interface)

**sample JCL invocation using HWIREXX:**

```
//HWISYSRX JOB NOTIFY=&SYSUID,MSGLEVEL=1,MSGCLASS=H
/*JOBPARM SYSAFF=????
//**********************************************************
//*  Sample JCL that takes advantage of HWIREXX helper
//*  program to drive the invocation of HWIXMRS3 in a
//*  SYSTEM REXX environment, avoiding the need to code
//*  an assembler program with an AXREXX macro invocation.
//*
//*  Requirements:
//*  The data set that is specified in the DSN parameter must be
//*  a PDS data set if callers desire to pre-allocate it.
//*  Otherwise it will be allocated by the System REXX services
//*  (TSO MUST BE EQUAL Y FOR OUTPUT TO DATASET TO WORK)
//*
//*  The dataset that contains the REXX exec to be run must be
//*  specified in the AXRxx member in SYS1.PARMLIB
//**********************************************************
//STEP1   EXEC PGM=HWIREXX,REGION=1M,
//   PARM=('NAME=HWIXMRS3',
//         'DSN=HWI.SAMPLE.REXX.OUTPUT',
//             'TSO=Y',
//             'SYNC=Y',
//             'TIMELIM=Y',
//             'TIME=240')
//*
//STEPLIB  DD  DSN=SYS1.LINKLIB,DISP=SHR
//SYSPRINT DD  SYSOUT=*
```

**sample success output:**
```
 HWIXMRS3 starting.
 CPC NAME = CPC1
 LPAR NAME = LP1
 LOAD Address = 1234
 LOAD Parm = lparm1

 Obtaining CPC URI and TargetName
 REQUEST ----->
 >GET /api/cpcs?name=CPC1
 Cpc TargetName: IBM390PS.CPC1
 Cpc Uri: /api/cpcs/fff-abcd-9999

 Obtaining LPAR URI, TargetName and Status
 REQUEST ----->
 >GET /api/cpcs/fff-abcd-9999/logical-partitions?name=LP1
   >target name:IBM390PS.CPC1
 Lpar TargetName: IBM390PS.CPC1.LP1
 Lpar Uri: /api/logical-partitions/111-eeee-bbbb
 Lpar Status: not-activated

 Invoke activate with uri: /api/logical-partitions/111-eeee-bbbb/operations/activate
 REQUEST ----->
 >POST /api/logical-partitions/111-eeee-bbbb/operations/activate
   >target name:IBM390PS.CPC1.LP1
   >request body:{}
 JobUri: /api/jobs/777-eeee-9999

 Polling Job Status
 REQUEST ----->
 >GET /api/jobs/777-eeee-9999
   >target name:IBM390PS.CPC1.LP1
 JobStatus: running
 Wait 5 seconds...         

 Polling Job Status
 REQUEST ----->
 >GET /api/jobs/777-eeee-9999
   >target name:IBM390PS.CPC1.LP1
 JobStatus: complete   
 JobStatusCode: 204
 Job completed successfully
 Activate elapsed time(sec): 6.512851

 Invoke load with uri: /api/logical-partitions/111-eeee-bbbb/operations/load
 Request Body: {"clear-indicator":false, "store-status-indicator":true, "load-address":"1234", "load-parameter":"lparm1" }                            
 REQUEST ----->
 >POST /api/logical-partitions/111-eeee-bbbb/operations/load
   >target name:IBM390PS.CPC1.LP1
   >request body:{"clear-indicator":false, "store-status-indicator":true, "load-address":"1234", "load-parameter":"lparm1" }
 JobUri: /api/jobs/fff-ccc-ddd

 Polling Job Status
  REQUEST ----->
 >GET /api/jobs/fff-ccc-ddd
   >target name:IBM390PS.CPC1.LP1
 JobStatus: running       
 Wait 5 seconds...         

 Polling Job Status
 REQUEST ----->
 >GET /api/jobs/fff-ccc-ddd
   >target name:IBM390PS.CPC1.LP1
 JobStatus: running      
 Wait 5 seconds...    

 Polling Job Status
 REQUEST ----->
 >GET /api/jobs/fff-ccc-ddd
   >target name:IBM390PS.CPC1.LP1
 JobStatus: complete  
 JobStatusCode: 204                 
 Job completed successfully         
 Load elapsed time(sec): 13.438364
 
 HWIXMRS3 ending with completion code:0
```
**sample failure output:**
```
HWIXMRS3 starting.
CPC NAME = CPC1 
LPAR NAME = LP1
LOAD Address = 1234
LOAD Parm = lparm1

Obtaining CPC URI and TargetName
REQUEST ----->
>GET /api/cpcs?name=CPC1
Cpc TargetName: IBM390PS.CPC1
Cpc Uri: /api/cpcs/bbb-aaa-333

Obtaining LPAR URI, TargetName and Status
REQUEST ----->
>GET /api/cpcs/bbb-aaa-333/logical-partitions?name=LP1
  >target name:IBM390PS.CPC1
Lpar TargetName: IBM390PS.CPC1.LP1
Lpar Uri: /api/logical-partitions/4444-rrrr-4444
Lpar Status: operating

** Unexpected Lpar Status operating **

HWIXMRS3 ending with completion code:1015
```
## HWIXMRS3 RC
| Return Code | Description |
| ----------- | ----------- |
| 0      | Success |
| 1001   | Missing value(s) for one or more of the required arguments |
| 1002   | JSON Parser constants file error |
| 1003   | JSON Parser initilization error|
| 1004   | Bad REXX RC from HWIREST   |
| 1005   | Failed to obtained CPC information |
| 1006   | Failed to obtain LPAR information |
| 1007   | LOAD request failed |
| 1008   | POLLing job-uri failed |
| 1009   | Failed to obtain JOB STATUS |
| 1010  | Query of JOB URI did not complete successfully  |
| 1011  | JSON Parser failed |
| 1012  | LPAR not activated |
| 1013  | ACTIVATE failed |
| 1014  | Query of LPAR status failed |
| 1015  | Unexpected LPAR status      |