## Example-LPARLoad-SYSREXX

This sample uses HWIREST API to:
- List CPCs, filtered by the CPC name (ARG_CPC_NAME), in order to retrieve the URI and target name associated with that CPC
  - use the ARG_NET_ID to cross check against the target name to verify the correct CPC was returned
- List the LPARs on that CPC, filtered by the LPAR name (ARG_LPAR_NAME), in order to retrieve the URI and target name associated with that LPAR
  - use the ARG_NET_ID + ARG_LPAR_NAME to cross check against the target name to verify the correct LPAR was returned
- inspect the status of the LPAR
  - if the LPAR is already `operating` then there is nothing to do
  - if the LPAR is `not-activated` then
    - ACTIVATE the LPAR
    - POLL the returned job-uri for the result of the ACTIVATE operation
    - Query the status of the LPAR to ensure its in `not-operating` status before continuing to the LOAD
- Load the LPAR, passing in the specified:
  - LOADADDR_VALUE, correlates with the JSON attribute `load-address` in the request body
  - LOADPARM_VALUE, correlates with the JSON attribute `load-parameter` in the request body
- POLL the job-uri for the result of the LOAD operation

## System and Exec Prep work
1. Ensure your z/OS user ID has the specified access to the following FACILITY Class Profiles
    - READ access to HWI.TARGET.netid.nau
    - CONTROL HWI.TARGET.netid.nau.imagename

    <p>where netid.nau represents the 3– to 17– character SNA name of the particular CPC
    and imagename represents the 1– to 8- character LPAR name that will be used as input</p>

1. Store the hwixmrs3.rexx into a data set that is in the search path as defined in an AXRnn parmlib member.

1. Update the following variables in hwixmrs3.rexx
```
ARG_CPC_NAME - name of the CPC associated with the LPAR to be LOADED
ARG_NET_ID - NetID of the CPC associated with the LPAR to be LOADED
ARG_LPAR_NAME - name of the LPAR to be loaded
ARG_LOAD_ADDR - value for the load address
ARG_LOAD_PARM - value for the load parameter
```

## Invocation
<b>NOTE:</b> The LOAD and ACTIVATE operation are only permitted from a SYSTEM REXX, C, or ASM environment.
The following sample invocation takes advantage of HWIREXX to drive the exec in a SYSTEM REXX environment.
 
[HWIREXX Documentation](https://www.ibm.com/docs/en/zos/2.4.0?topic=environment-using-hwirexx-interface)

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
 REQUEST ----->
 >GET /api/cpcs?name=T256
 Cpc TargetName: IBM390PS.T256
 Cpc Uri: /api/cpcs/fff-88888
 REQUEST ----->
 >GET /api/cpcs/fff-88888/logical-partitions?name=TA5
   >target name:IBM390PS.T256
 Lpar TargetName: IBM390PS.T256.TA5
 Lpar Uri: /api/logical-partitions/111-eeee-bbbb
 Lpar Status: not-activated
 Invoke activate with uri: /api/logical-partitions/111-eeee-bbbb/operations/activate
 REQUEST ----->
 >POST /api/logical-partitions/111-eeee-bbbb/operations/activate
   >target name:IBM390PS.T256.TA5
   >request body:{}
 JobUri: /api/jobs/777-eeee-21111
 Polling Job Status
 REQUEST ----->
 >GET /api/jobs/777-eeee-21111
   >target name:IBM390PS.T256.TA5
 REQUEST ----->
 >GET /api/jobs/777-eeee-21111
   >target name:IBM390PS.T256.TA5
 JobStatusCode: 204
 JobReasonCode: 0
 *SUCCESS* Job completed successfully
 Job Result = 0
 REQUEST ----->
 >GET /api/logical-partitions/111-eeee-bbbb
   >target name:IBM390PS.T256.TA5
 Lpar Status: not-operating
 Invoke load with uri: /api/logical-partitions/111-eeee-bbbb/operations/load
 REQUEST ----->
 >POST /api/logical-partitions/111-eeee-bbbb/operations/load
   >target name:IBM390PS.T256.TA5
   >request body:{"clear-indicator":false, "store-status-indicator":true, "load-address":"0A503", "load-parameter":"A5C04TM" }
 JobUri: /api/jobs/fff-ccc-ddd
 Polling Job Status
  REQUEST ----->
 >GET /api/jobs/fff-ccc-ddd
   >target name:IBM390PS.T256.TA5
 REQUEST ----->
 >GET /api/jobs/fff-ccc-ddd
   >target name:IBM390PS.T256.TA5
 REQUEST ----->
 >GET /api/jobs/fff-ccc-ddd
   >target name:IBM390PS.T256.TA5
 JobStatusCode: 204
 JobReasonCode: 0
 *SUCCESS* Job completed successfully
 Job Result = 0
 HWIXMRS3 ending with completion code:0
```
**sample failure output:**
```
HWIXMRS3 starting.
REQUEST ----->
>GET /api/cpcs?name=T256
Cpc TargetName: IBM390PS.T256
Cpc Uri: /api/cpcs/bbb-aaa-333
REQUEST ----->
>GET /api/cpcs/bbb-aaa-333/logical-partitions?name=TA5
  >target name:IBM390PS.T256
Lpar TargetName: IBM390PS.T256.TA5
Lpar Uri: /api/logical-partitions/4444-rrrr-4444
Lpar Status: operating
** Unexpected Lpar Status operating **
HWIXMRS3 ending with completion code:1006
```
## HWXMRS3 RC
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
| 10010  | Query of JOB URI did not complete successfully  |
| 10011  | JSON Parser failed |
| 10012  | LPAR not activated |
| 10013  | ACTIVATE failed |
| 10014  | Query of LPAR status failed |