## Example-LPARActivate-C

This sample uses HWIREST API to:
- List CPCs, filtered by the CPC name provided, in order to retrieve the URI and target name associated with that CPC
- List the LPARs on that CPC, filtered by the LPAR name provided, in order to retrieve the URI and target name associated with that LPAR
- Query the status of the LPAR to ensure it's in the required 'not-activated' status
- Query the next activation profile for the LPAR so it can be re-used as input for the LPAR Activate
- Activate the LPAR and POLL the job-uri for the result of the operation
- Re-query the current status of the LPAR

## System Prep work
1. Ensure your z/OS user ID has the specified access to the following FACILITY Class Profiles
    - READ access to HWI.TARGET.netid.nau
    - CONTROL HWI.TARGET.netid.nau.imagename

    <p>where netid.nau represents the 3– to 17– character SNA name of the particular CPC
    and imagename represents the 1– to 8- character LPAR name that will be used as input</p>

1. Create the following data sets for the application
   * hlq.HWIREST.CPP - DSORG=PO,RECFM=VB,LRECL=255 - used to store the C++ source files
   * hlq.HWIREST.H - DSORG=PO,RECFM=VB,LRECL=255 - used to store the header files
   * hlq.HWIREST.LISTCPP - DSORG=PO,RECF=VBA,LRECL=137 - used to store listings
   * hlq.HWIREST.OBJ - DSORG=PO,RECF=FB,LRECL=80 - used to store objects
   * hlq.HWIREST.JCL - DSORG=PO,RECFM=FB,LRECL=80 - used to hold the JCLs
1. Store the [**.cpp files**](https://github.com/IBM/zOS-BCPii/tree/master/Example-LPARActivate-C/cpp) into hlq.HWIREST.CPP data sets
1. Store the [**.h files**](https://github.com/IBM/zOS-BCPii/tree/master/Example-LPARActivate-C/h) into hlq.HWIREST.H data sets
1. Store the [**hwirstcx.jcl**](https://github.com/IBM/zOS-BCPii/tree/master/Example-LPARActivate-C/jcl) into hlq.HWIREST.JCL and customize for your environment
   - this JCL will compile and bind the various source files to create the executable, HWIRSTC1
   - replace hlq., update `SYSAFF`, and possibly update `JCLLIB ORDER` value
1. Submit job <b>HWIRSTCX</b> to generate the HWIRSTC1 executable
1. Store the [**hwirstc1.jcl**](https://github.com/IBM/zOS-BCPii/tree/master/Example-LPARActivate-C/jcl) into hlq.HWIREST.JCL and customize for your environment
   - this JCL will be used to execute the application
   - replace the hlq., update `SYSAFF`, and update the CPCname and LPARname with the desired targets
1. Submit job <b>HWIRSTC1</b> to execute the application

## Invocation
**Syntax**:
```
 HWIRSTC1 CPCname LPARname
 ```
 where:
  - *CPCname* is the name of the CPC that is associated wth the target LPAR , **required**
  - *LPARname* is the name of the LPAR you wish to activate, **required**

NOTE: runtime option POSIX(ON) is required

**sample invocation using BATCH:**

[**jcl/hwirstcx.jcl**](https://github.com/IBM/zOS-BCPii/tree/master/Example-LPARActivate-C/jcl)
```
HWIRST1  EXEC PGM=HWIRSTC1,
    PARM='POSIX(ON),MSGFILE(SYSOUT) / T256 TA5'
```

**sample output:**
```
SUCCESS: Parser initialized.
argv passed in: T256 length 4
argv passed in: TA5 length 3
*>>
*>>REQUEST:
GET /api/cpcs?name=T256
*>>
*>>REQUEST was successful: 200
* >responseBody:'{"cpcs":[{"name":"T256","se-version":"2.15.0","location":"local","object-uri":"/api/cpcs/ffff-999-333-888","target-name":"IBM390PS.T256"}]}'
*>>
CPCuri:/api/cpcs/ffff-999-333-888
CPCtargetName:IBM390PS.T256
*>>
*>>REQUEST:
GET /api/cpcs/ffff-999-333-888/logical-partitions?name=TA5
* >targetName:'IBM390PS.T256'
*>>
*>>REQUEST was successful: 200
* >responseBody:'{"logical-partitions":[{"name":"TA5","request-origin":false,"object-uri":"/api/logical-partitions/11111-cccc-aaaa","target-name":"IBM390PS.T256.TA5","status":"not-activated"}]}'
*>>
LPARuri:/api/logical-partitions/11111-cccc-aaaa
LPARtargetName:IBM390PS.T256.TA5
*>>
*>>REQUEST:
GET /api/logical-partitions/11111-cccc-aaaa?properties=status&cached-acceptable=true
* >targetName:'IBM390PS.T256.TA5'
*>>
*>>REQUEST was successful: 200
* >responseBody:'{"status":"not-activated"}'
*>>
LPAR status is not-activated
*>>
*>>REQUEST:
GET /api/logical-partitions/11111-cccc-aaaa?properties=next-activation-profile-name&cached-acceptable=true
* >targetName:'IBM390PS.T256.TA5'
*>>
*>>REQUEST was successful: 200
* >responseBody:'{"next-activation-profile-name":"TA5"}'
*>>
LPAR next-activation-profile-name is TA5
*>>
*>>REQUEST:
POST /api/logical-partitions/11111-cccc-aaaa/operations/activate
* >targetName:'IBM390PS.T256.TA5'
* >requestBody:'{"activation-profile-name":"TA5","force":true}'
*>>
*>>REQUEST was successful: 202
* >responseBody:'{"job-uri":"/api/jobs/99999-4444-6666"}'
*>>
jobUri:/api/jobs/99999-4444-6666
*>>starting polling at Wed Apr  7 23:04:17 2021
elapsed time for activate LPAR completion is 22.00 seconds
*>>
*>>REQUEST:
GET /api/logical-partitions/11111-cccc-aaaa?properties=status&cached-acceptable=true
* >targetName:'IBM390PS.T256.TA5'
*>>
*>>REQUEST was successful: 200
* >responseBody:'{"status":"not-operating"}'
*>>
LPAR status is not-operating
SUCCESS: Parser work area freed.
```