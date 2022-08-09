## REXX Custom User Group Sample

This REXX sample utilizes the **HWIREST API** to do one of the following:
- List the Custom User Groups on a CPC
- List the members of the Custom User Group on a CPC
- Attempts to add the LPAR as a new member to the Custom User Group on a CPC
- Attempts to remove the LPAR as a member from the Custom User Group on a CPC

Note: The Custom User Group being displayed and modified are located on the Support Element (SE)

## System Prep work
- Store USRGRP01 into a data set of at least fb80
- Ensure your z/OS user ID has at least READ and CONTROL access to the following FACILITY Class Profile
    - HWI.TARGET.netid.nau

    <p>where netid.nau represents the 3– to 17– character SNA name of the particular CPC. </p>

## Invocation
**Syntax**:
```
USRGRP01 [-C CPCName] [-L LPARName] [-G CustomUserGroup] [-A Action {ADD, REMOVE, LIST}] [-I] [-V] [-H]
```

 Optional Input Parameters:<br>
  - CPCName  - The name of the CPC to query, the default is the local CPC if not specified or provided<br>
  - LPARName - The name of the LPAR to query and target, the default is
                 the local LPAR if not specified or provided<br>
  - UserGroupName - The name of the Custom User Group to target<br>
  - Action        - The action to take against the Custom User Group
                    limited to ADD, REMOVE, or LIST<br>
  - -I            - indicate running in ISV REXX environment, default
                    is TSO/E<br>
  - -V            - turn on additional verbose JSON tracing<br>
  - -H            - Display sample parameters and how to invoke the sample<br>

**Note**: If no arguments are supplied then the sample will default to listing all of the Custom User Groups on the local CPC.

**Sample Invocation in TSO:**

USRGRP01 has been copied into data set HWI.USER.REXX <br>

  List all Custom User Groups on the specified CPC:<br>
  - Local CPC and LPAR:
    ```
    ex 'HWI.USER.REXX(USRGRP01)'
    ```

  - Remote CPC and LPAR:
    ```
    ex 'HWI.USER.REXX(USRGRP01)' '-C CPC1 -L LPAR1'
    ```

  List the members of the TEST Custom User Group:
  - Local CPC and LPAR:
    ```
    ex 'HWI.USER.REXX(USRGRP01)' '-G TEST'
    ```

  - Remote CPC and LPAR:
    ```
    ex 'HWI.USER.REXX(USRGRP01)' '-C CPC1 -L LPAR1 -G TEST'
    ```

  Add an LPAR as a new member to the TEST Custom User Group

  - Local CPC and LPAR:
    ```
    ex 'HWI.USER.REXX(USRGRP01)' '-G TEST -A ADD'
    ```

  - Remote CPC and LPAR:
    ```
    ex 'HWI.USER.REXX(USRGRP01)' '-C CPC1 -L LPAR1 -G TEST -A ADD'
    ```

  Remove an LPAR member from the TEST Custom User Group

  - Local CPC and LPAR:
    ```
    ex 'HWI.USER.REXX(USRGRP01)' '-G TEST -A REMOVE'
    ```

  - Remote CPC and LPAR:
    ```
    ex 'HWI.USER.REXX(USRGRP01)' '-C CPC1 -L LPAR1 -G TEST -A REMOVE'
    ```

**Sample Batch Invocation via JCL:**
USRGRP01 has been copied into data set HWI.USER.REXX

```
 //USRGRP01 JOB ,
 // CLASS=J,NOTIFY=&SYSUID,MSGLEVEL=1,
 //  MSGCLASS=H,REGION=0M,TIME=1440
 //STEP1    EXEC PGM=IKJEFT01,DYNAMNBR=20
 //SYSUDUMP DD SYSOUT=(H,,STD)
 //SYSTSPRT DD SYSOUT=(H,,STD)
 //SYSTSIN  DD * UB
 PROFILE NOPREFIX
 EX 'HWI.USER.REXX(USRGRP01)'  -
 'LOCAL_CPC LOCAL_LPAR TESTGRP ADD'
 /*
 ```
 - exec is running in a TSO/E rexx environment

## Example Generated Output

### Success Path for List Custom User Groups Invocation
```
------->
GET request being made....
URI: /api/cpcs?name=CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:24:18 GMT)
SE requestId: (Sxabd34565-df4e-33fg-1010-99574c560a56.12 Rx3)
Response Body: ({"cpcs":[{"name":"CPC1","se-version":"","location":"remote","object-uri":"/api/cpcs/3e0fa09f-1551-3825-959e-fef
48552cf6c","target-name":"IBM390PS.CPC1"}]})

<-------

Successfully obtained CPC Info:
  uri:/api/cpcs/3e0fa09f-1551-3825-959e-fef48552cf6c
  target-name:IBM390PS.CPC1

------->
GET request being made....
URI: /api/cpcs/3e0fa09f-1551-3825-959e-fef48552cf6c/logical-partitions?name=LP01
TARGETNAME: IBM390PS.CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:24:23 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rx0)
Response Body: ({"logical-partitions":[{"name":"LP01","request-origin":false,"object-uri":"/api/logical-partitions/05911b9e-6488-39
00-bacc-36941e1872d3","target-name":"IBM390PS.CPC1.LP01","status":"operating"}]})

<-------

Successfully obtained LPAR Info:
  uri:/api/logical-partitions/05911b9e-6488-3900-bacc-36941e1872d3
  target-name:IBM390PS.CPC1.LP01

------->
GET request being made....
URI: /api/groups
TARGETNAME: IBM390PS.CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:24:23 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rx1)
Response Body: ({"groups":[{"name":"TESTGRP2","object-uri":"/api/groups/4a264a63-81b5-37b3-9ba9-b8ccc0f6c4c3","target-name":"IBM390
PS.CPC1"},{"name":"TESTGRP1","object-uri":"/api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954","target-name":"IBM390PS.CPC1"}
]})

<-------

Procesing the 2 number of custom user groups
Custom User Group Name: TESTGRP2 | URI: /api/groups/4a264a63-81b5-37b3-9ba9-b8ccc0f6c4c3
Custom User Group Name: TESTGRP1 | URI: /api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954
```

### Success Path for List Custom User Group Members Invocation
```
------->
GET request being made....
URI: /api/cpcs?name=CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:27:38 GMT)
SE requestId: (Sxabd34565-df4e-33fg-1010-99574c560a56.12 Rx4)
Response Body: ({"cpcs":[{"name":"CPC1","se-version":"","location":"remote","object-uri":"/api/cpcs/3e0fa09f-1551-3825-959e-fef
48552cf6c","target-name":"IBM390PS.CPC1"}]})

<-------

Successfully obtained CPC Info:
  uri:/api/cpcs/3e0fa09f-1551-3825-959e-fef48552cf6c
  target-name:IBM390PS.CPC1


------->
GET request being made....
URI: /api/cpcs/3e0fa09f-1551-3825-959e-fef48552cf6c/logical-partitions?name=LP01
TARGETNAME: IBM390PS.CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:27:39 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rx2)
Response Body: ({"logical-partitions":[{"name":"LP01","request-origin":false,"object-uri":"/api/logical-partitions/05911b9e-6488-39
00-bacc-36941e1872d3","target-name":"IBM390PS.CPC1.LP01","status":"operating"}]})

<-------

Successfully obtained LPAR Info:
  uri:/api/logical-partitions/05911b9e-6488-3900-bacc-36941e1872d3
  target-name:IBM390PS.CPC1.LP01

------->
GET request being made....
URI: /api/groups
TARGETNAME: IBM390PS.CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:27:39 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rx3)
Response Body: ({"groups":[{"name":"TESTGRP2","object-uri":"/api/groups/4a264a63-81b5-37b3-9ba9-b8ccc0f6c4c3","target-name":"IBM390
PS.CPC1"},{"name":"TESTGRP1","object-uri":"/api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954","target-name":"IBM390PS.CPC1"}
]})

<-------

Procesing the 2 number of custom user groups
Custom User Group Name: TESTGRP2 | URI: /api/groups/4a264a63-81b5-37b3-9ba9-b8ccc0f6c4c3
Custom User Group Name: TESTGRP1 | URI: /api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954

------->
GET request being made....
URI: /api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954/members
TARGETNAME: IBM390PS.CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:27:39 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rx4)
Response Body: ({"members":[{"name":"LP01","target-name":"IBM390PS.CPC1.LP01","object-uri":"/api/logical-partitions/05911b9e-64
88-3900-bacc-36941e1872d3"},{"name":"LP02","target-name":"IBM390PS.CPC1.LP02","object-uri":"/api/logical-partitions/a3449515-93
65-3102-9eed-2481cbbc71b9"}]})

<-------

The number of members in the group is: 2
Custom User Group Member Name: LP01 | URI: /api/logical-partitions/05911b9e-6488-3900-bacc-36941e1872d3
Custom User Group Member Name: LP02 | URI: /api/logical-partitions/a3449515-9365-3102-9eed-2481cbbc71b9
```

### Success Path for Add Invocation
```
------->
GET request being made....
URI: /api/cpcs?name=CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:40:43 GMT)
SE requestId: (Sxabd34565-df4e-33fg-1010-99574c560a56.12 Rx8)
Response Body: ({"cpcs":[{"name":"CPC1","se-version":"","location":"remote","object-uri":"/api/cpcs/3e0fa09f-1551-3825-959e-fef
48552cf6c","target-name":"IBM390PS.CPC1"}]})

<-------

Successfully obtained CPC Info:
  uri:/api/cpcs/3e0fa09f-1551-3825-959e-fef48552cf6c
  target-name:IBM390PS.CPC1

------->
GET request being made....
URI: /api/cpcs/3e0fa09f-1551-3825-959e-fef48552cf6c/logical-partitions?name=LP07
TARGETNAME: IBM390PS.CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:40:44 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rx9)
Response Body: ({"logical-partitions":[{"name":"LP07","request-origin":false,"object-uri":"/api/logical-partitions/14486735-ca03-31
f7-9f13-363fdbb0b06a","target-name":"IBM390PS.CPC1.LP07","status":"operating"}]})

<-------

Successfully obtained LPAR Info:
  uri:/api/logical-partitions/14486735-ca03-31f7-9f13-363fdbb0b06a
  target-name:IBM390PS.CPC1.LP07

------->
GET request being made....
URI: /api/groups
TARGETNAME: IBM390PS.CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:40:44 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rxa)
Response Body: ({"groups":[{"name":"TESTGRP2","object-uri":"/api/groups/4a264a63-81b5-37b3-9ba9-b8ccc0f6c4c3","target-name":"IBM390
PS.CPC1"},{"name":"TESTGRP1","object-uri":"/api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954","target-name":"IBM390PS.CPC1"}
]})

<-------

Procesing the 2 number of custom user groups
Custom User Group Name: TESTGRP2 | URI: /api/groups/4a264a63-81b5-37b3-9ba9-b8ccc0f6c4c3
Custom User Group Name: TESTGRP1 | URI: /api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954

------->
GET request being made....
URI: /api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954/members
TARGETNAME: IBM390PS.CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:40:44 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rxb)
Response Body: ({"members":[{"name":"LP01","target-name":"IBM390PS.CPC1.LP01","object-uri":"/api/logical-partitions/05911b9e-64
88-3900-bacc-36941e1872d3"},{"name":"LP02","target-name":"IBM390PS.CPC1.LP02","object-uri":"/api/logical-partitions/a3449515-93
65-3102-9eed-2481cbbc71b9"}]})

<-------

The number of members in the group is: 2
Custom User Group Member Name: LP01 | URI: /api/logical-partitions/05911b9e-6488-3900-bacc-36941e1872d3
Custom User Group Member Name: LP02 | URI: /api/logical-partitions/a3449515-9365-3102-9eed-2481cbbc71b9
Adding new member to the Custom User Group

------->
POST request being made....
URI: /api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954/operations/add-member
TARGETNAME: IBM390PS.CPC1
REQUEST BODY: {"object-uri":"/api/logical-partitions/14486735-ca03-31f7-9f13-363fdbb0b06a"}
CLIENT CORRELATOR:
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (204)
SE DateTime: (Tue, 19 Jul 2022 19:40:46 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rxc)
Response Body: (RESPONSE.RESPONSEBODY)

------->
GET request being made....
URI: /api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954/members
TARGETNAME: IBM390PS.CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:40:46 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rxd)
Response Body: ({"members":[{"name":"LP07","target-name":"IBM390PS.CPC1.LP07","object-uri":"/api/logical-partitions/14486735-ca
03-31f7-9f13-363fdbb0b06a"},{"name":"LP01","target-name":"IBM390PS.CPC1.LP01","object-uri":"/api/logical-partitions/05911b9e-64
88-3900-bacc-36941e1872d3"},{"name":"LP02","target-name":"IBM390PS.CPC1.LP02","object-uri":"/api/logical-partitions/a3449515-93
65-3102-9eed-2481cbbc71b9"}]})

<-------

The number of members in the group is: 3
Custom User Group Member Name: LP07 | URI: /api/logical-partitions/14486735-ca03-31f7-9f13-363fdbb0b06a
Custom User Group Member Name: LP01 | URI: /api/logical-partitions/05911b9e-6488-3900-bacc-36941e1872d3
Custom User Group Member Name: LP02 | URI: /api/logical-partitions/a3449515-9365-3102-9eed-2481cbbc71b9
```

### Success Path for Remove Invocation
```
------->
GET request being made....
URI: /api/cpcs?name=CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:42:51 GMT)
SE requestId: (Sxabd34565-df4e-33fg-1010-99574c560a56.12 Rx9)
Response Body: ({"cpcs":[{"name":"CPC1","se-version":"","location":"remote","object-uri":"/api/cpcs/3e0fa09f-1551-3825-959e-fef
48552cf6c","target-name":"IBM390PS.CPC1"}]})

<-------

Successfully obtained CPC Info:
  uri:/api/cpcs/3e0fa09f-1551-3825-959e-fef48552cf6c
  target-name:IBM390PS.CPC1

------->
GET request being made....
URI: /api/cpcs/3e0fa09f-1551-3825-959e-fef48552cf6c/logical-partitions?name=LP07
TARGETNAME: IBM390PS.CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:42:53 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rxe)
Response Body: ({"logical-partitions":[{"name":"LP07","request-origin":false,"object-uri":"/api/logical-partitions/14486735-ca03-31
f7-9f13-363fdbb0b06a","target-name":"IBM390PS.CPC1.LP07","status":"operating"}]})

<-------

Successfully obtained LPAR Info:
  uri:/api/logical-partitions/14486735-ca03-31f7-9f13-363fdbb0b06a
  target-name:IBM390PS.CPC1.LP07

------->
GET request being made....
URI: /api/groups
TARGETNAME: IBM390PS.CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:42:53 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rxf)
Response Body: ({"groups":[{"name":"TESTGRP2","object-uri":"/api/groups/4a264a63-81b5-37b3-9ba9-b8ccc0f6c4c3","target-name":"IBM390
PS.CPC1"},{"name":"TESTGRP1","object-uri":"/api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954","target-name":"IBM390PS.CPC1"}
]})

<-------

Procesing the 2 number of custom user groups
Custom User Group Name: TESTGRP2 | URI: /api/groups/4a264a63-81b5-37b3-9ba9-b8ccc0f6c4c3
Custom User Group Name: TESTGRP1 | URI: /api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954

------->
GET request being made....
URI: /api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954/members
TARGETNAME: IBM390PS.CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:42:53 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rx10)
Response Body: ({"members":[{"name":"LP07","target-name":"IBM390PS.CPC1.LP07","object-uri":"/api/logical-partitions/14486735-ca
03-31f7-9f13-363fdbb0b06a"},{"name":"LP01","target-name":"IBM390PS.CPC1.LP01","object-uri":"/api/logical-partitions/05911b9e-64
88-3900-bacc-36941e1872d3"},{"name":"LP02","target-name":"IBM390PS.CPC1.LP02","object-uri":"/api/logical-partitions/a3449515-93
65-3102-9eed-2481cbbc71b9"}]})

<-------

The number of members in the group is: 3
Custom User Group Member Name: LP07 | URI: /api/logical-partitions/14486735-ca03-31f7-9f13-363fdbb0b06a
Custom User Group Member Name: LP01 | URI: /api/logical-partitions/05911b9e-6488-3900-bacc-36941e1872d3
Custom User Group Member Name: LP02 | URI: /api/logical-partitions/a3449515-9365-3102-9eed-2481cbbc71b9
Removing target LPAR from Custom User Group

------->
POST request being made....
URI: /api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954/operations/remove-member
TARGETNAME: IBM390PS.CPC1
REQUEST BODY: {"object-uri":"/api/logical-partitions/14486735-ca03-31f7-9f13-363fdbb0b06a"}
CLIENT CORRELATOR:
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (204)
SE DateTime: (Tue, 19 Jul 2022 19:42:54 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rx11)
Response Body: (RESPONSE.RESPONSEBODY)

------->
GET request being made....
URI: /api/groups/a74cd19b-8f10-31fb-ae01-b072083b2954/members
TARGETNAME: IBM390PS.CPC1
ENCODING: 0
TIMEOUT: 0

Rexx RC: (0)
HTTP Status: (200)
SE DateTime: (Tue, 19 Jul 2022 19:42:54 GMT)
SE requestId: (Sxe4fdf896-907d-22fd-ccf5-bc2345678901.4 Rx12)
Response Body: ({"members":[{"name":"LP01","target-name":"IBM390PS.CPC1.LP01","object-uri":"/api/logical-partitions/05911b9e-64
88-3900-bacc-36941e1872d3"},{"name":"LP02","target-name":"IBM390PS.CPC1.LP02","object-uri":"/api/logical-partitions/a3449515-93
65-3102-9eed-2481cbbc71b9"}]})

<-------

The number of members in the group is: 2
Custom User Group Member Name: LP01 | URI: /api/logical-partitions/05911b9e-6488-3900-bacc-36941e1872d3
Custom User Group Member Name: LP02 | URI: /api/logical-partitions/a3449515-9365-3102-9eed-2481cbbc71b9
```