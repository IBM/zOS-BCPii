## Example-LPARLoad-REXX

This sample demonstrates how to call the BCPii HWIREST service to issue REST API    
operations from a TSO/E REXX or ISV REXX interface to load an LPAR, including a possible activation of the LPAR before hand.

This sample uses HWIREST to:
- List CPCs, filtered by the CPC name (CPCName), in order to retrieve the URI and target name associated with the CPC of interest
- List the LPARs on that CPC, filtered by the LPAR name (LPARName), in order to retrieve the URI and target name associated with that LPAR
- inspect the status of the LPAR
  - if the LPAR is already `operating` then return a message and exit
  - if the LPAR is `not-activated` then
    - ACTIVATE the LPAR
    - POLL the returned job-uri for the result of the ACTIVATE operation
- Load the LPAR, passing in the specified:
  - LOAD_ADDR via the JSON attribute `load-address` in the request body
  - LOAD_PARM via the JSON attribute `load-parameter` in the request body
- POLL the job-uri for the result of the LOAD operation

## RXLOAD1 RC
This sample will return one of these return codes:

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
| 1010   | Query of JOB URI did not complete successfully  |
| 1011   | JSON Parser failed |
| 1012   | LPAR not activated |
| 1013   | ACTIVATE failed |
| 1014   | Query of LPAR status failed |
| 1015   | Unexpected LPAR status |


## System and Exec Prep work
- Store RXLOAD1 into a data set
- Ensure your z/OS user ID has sufficient access to the following RACF Facility class profiles:
    - READ access to HWI.TARGET.netid.nau
    - CONTROL access to HWI.TARGET.netid.nau.imagename

    <p>where netid.nau represents the 3-to-17 character SNA name of the particular CPC and imagename represents the 1-to-8 character LPAR name which will be the target of the request.
    Optionally the * char can be used instead of the imagename to represent all of the LPARs available on that CPC.
    </p>

## Invocation
**Syntax**:
```
  RXLOAD1 -C CPCName -L LPARName -A LoadAddr -P LoadParm -I -V
 ```
 where:
- **Required**
  - *CPCname* is the name of the CPC associated with the LPAR to load
  - *LPARname* is the name of the LPAR on that CPC that you wish to load
  - *LoadAddr* is value of the Load Address
  - *LoadParm* is value of the Load Parameter
- **Optional**
  - *-I* indicates the exec is running in an ISV REXX environment
  - *-V* enables verbose JSON parser tracing  

**Sample JCL invocation using TSO REXX**
```
//HWITSORX JOB NOTIFY=&SYSUID,MSGLEVEL=1,MSGCLASS=H
/*JOBPARM SYSAFF=????
//**********************************************************
//*  Requirements:
//*  The dataset containing the REXX exec to be run must be
//*  specified on the SYSEXEC DD card
//**********************************************************
//RUNJCL  EXEC PGM=IKJEFT01,DYNAMNBR=30,REGION=4096K   
//SYSEXEC  DD  DSN=HWI.USER.REXX,DISP=SHR   
//SYSTSPRT DD  SYSOUT=*                                
//SYSTSIN  DD  *                                       
  %RXLOAD1 -C CPC1 -L LP01 -A 01234 -P LPARM1           
/*                                                     
```

**sample success output:**
```
  %RXLOAD1 -C CPC1 -L LP01 -A 01234 -P LPARM1

CPC Name =   CPC1
LPAR Name =  LP01
Load address =  01234
Load parm =  LPARM1

Obtaining CPC uri and target name
REQUEST ----->
>GET /api/cpcs?name=CPC1
CPC TargetName: IBM390PS.CPC1
CPC Uri: /api/cpcs/abcdefgh-9999-9999-9999-99

Obtaining LPAR uri, target name and status
REQUEST ----->
>GET /api/cpcs/abcdefgh-9999-9999-9999-99/logical-partitions?name=LP01
  >target name:IBM390PS.CPC1
Lpar TargetName: IBM390PS.CPC1.LP01
Lpar Uri: /api/logical-partitions/abcdefgh-9999-9999-9999-99
Lpar Status: not-activated

Invoke activate with uri: /api/logical-partitions/abcdefgh-9999-9999-9999-99/operations/activate
Request Body: {"activation-profile-name":"LP01","force":true}
REQUEST ----->
>POST /api/logical-partitions/abcdefgh-9999-9999-9999-99/operations/activate
  >target name:IBM390PS.CPC1.LP01
  >request body:{"activation-profile-name":"LP01","force":true}
JobUri: /api/jobs/abcdefgh-9999-9999-9999-99

Polling Job Status
REQUEST ----->
>GET /api/jobs/abcdefgh-9999-9999-9999-99
  >target name:IBM390PS.CPC1.LP01
JobStatus: running
Wait 10 seconds...

Polling Job Status
REQUEST ----->
>GET /api/jobs/abcdefgh-9999-9999-9999-99
  >target name:IBM390PS.CPC1.LP01
JobStatus: complete  
JobStatusCode: 204
*SUCCESS* Job completed successfully

Invoke load with uri: /api/logical-partitions/abcdefgh-9999-9999-9999-99/operations/load
Request Body: {"clear-indicator":false, "store-status-indicator":true, "load-address":"01234", "load-parameter":"LPARM1" }
REQUEST ----->
>POST /api/logical-partitions/abcdefgh-9999-9999-9999-99/operations/load
  >target name:IBM390PS.CPC1.LP01
  >request body:{"clear-indicator":false, "store-status-indicator":true, "load-address":"01234", "load-parameter":"LPARM1" }
JobUri: /api/jobs/abcdefgh-9999-9999-9999-999

Polling Job Status
REQUEST -----> 
>GET /api/jobs/abcdefgh-9999-9999-9999-999
  >target name:IBM390PS.CPC1.LP01
JobStatus: running
Wait 10 seconds...

Polling Job Status
REQUEST ----->
>GET /api/jobs/abcdefgh-9999-9999-9999-999
  >target name:IBM390PS.CPC1.LP01
JobStatus: complete  
JobStatusCode: 204
*SUCCESS* Job completed successfully

********************************************
RXLOAD1 ended with completion code:0
********************************************
READY
END                                                 
```
**sample failure output:**
```
READY                                                  
  %RXLOAD1 -C CPC1 -L LP01 -A 01234 -P LPARM1           
                                                       
CPC Name =   CPC1                                       
LPAR Name =  LP01                                       
Load address =  01234                                  
Load parm =  LPARM1

Obtaining CPC uri and target name
REQUEST ----->                                         
>GET /api/cpcs?name=CPC1                                      
CPC TargetName: IBM390PS.CPC1                           
CPC Uri: /api/cpcs/abcdefgh-9999-9999-99xx-cccccccccccc

Obtaining LPAR uri, target name and status
REQUEST ----->                                                  
>GET /api/cpcs/abcdefgh-9999-9999-99xx-cccccccccccc/logical-partitions?name=LP01
  >target name:IBM390PS.CPC1
                                          
Lpar TargetName: IBM390PS.CPC1.LP01                     
Lpar Uri: /api/logical-partitions/abcdefgh-9999-9999-99xx-cccccccccccc
Lpar Status: operating
** Unexpected Lpar Status: operating **        
                                              
********************************************  
RXLOAD1 ended with completion code:1015      
********************************************  
READY                                         
END