## REXX Custom User Group Sample

This REXX sample utilizes the **HWIREST API** to do one of the following:
- List the Custom User Groups on a CPC
- List the members of a Custom User Group on a CPC
- Attempt to add an LPAR as a new member to the Custom User Group on a CPC
- Attempt to remove an LPAR as a member from the Custom User Group on a CPC

Note: The Custom User Groups being displayed and modified are located on the Support Element (SE)

## System Prep work
- Store RXUSRGP1 into a data set
- Ensure your z/OS user ID has sufficient access to the following RACF Facility class profiles:
    - At least READ access (for LIST) or CONTROL access (for Add or Remove) to:
        - HWI.TARGET.netid.nau
    - At least READ access to: 
        - HWI.TARGET.netid.nau.imagename

    <p>where netid.nau represents the 3-to-17 character SNA name of the CPC, 
    and imagename represents the 1-to-8 character LPAR name
    or * to represent all of the LPARs available on the CPC </p>

## Invocation
**Syntax**:
```
RXUSRGP1 [-C CPCName] [-L LPARName] [-G CustomUserGroup] [-A Action {ADD, REMOVE, LIST}] [-I] [-V] [-H]
```

 Optional Input Parameters:<br>
  - CPCName  - The name of the CPC of interest, the default is the local CPC if not specified<br>
  - LPARName - The name of the LPAR to Add or Remove to/from a user group, the default is the local LPAR if not specified <br>
  - CustomUserGroup - The name of the Custom User Group to target<br>
  - Action        - The action to take against the Custom User Group, 
                    limited to ADD, REMOVE, or LIST<br>
  - -I            - indicate running in ISV REXX environment, default
                    is TSO/E<br>
  - -V            - turn on additional verbose JSON tracing<br>
  - -H            - Display sample parameters and how to invoke the sample<br>

**Note**: If no arguments are supplied the default action lists all of the Custom User Groups on the local CPC.

**Sample Invocation in TSO:**

RXUSRGP1 has been copied into data set HWI.USER.REXX <br>

  List all Custom User Groups on the specified CPC:<br>
  - Local CPC:
    ```
    ex 'HWI.USER.REXX(RXUSRGP1)'
    ```

  - Remote CPC:
    ```
    ex 'HWI.USER.REXX(RXUSRGP1)' '-C CPC1'
    ```

  List the members of the TEST Custom User Group:
  - Local CPC:
    ```
    ex 'HWI.USER.REXX(RXUSRGP1)' '-G TEST'
    ```

  - Remote CPC:
    ```
    ex 'HWI.USER.REXX(RXUSRGP1)' '-C CPC1 -G TEST'
    ```

  Add the target LPAR to the TEST Custom User Group

  - Local CPC and default LPAR:
    ```
    ex 'HWI.USER.REXX(RXUSRGP1)' '-G TEST -A ADD'
    ```
  - Local CPC and specific LPAR: 
    ```
    ex 'HWI.USER.REXX(RXUSRGP1)' '-L LPAR1 -G TEST -A ADD'
    ```                          
  - Remote CPC and specific LPAR:
    ```
    ex 'HWI.USER.REXX(RXUSRGP1)' '-C CPC1 -L LPAR1 -G TEST -A ADD'
    ```

  Remove the target LPAR from the TEST Custom User Group

  - Local CPC and default LPAR:
    ```
    ex 'HWI.USER.REXX(RXUSRGP1)' '-G TEST -A REMOVE'
    ```
 - Local CPC and specific LPAR: 
    ```
    ex 'HWI.USER.REXX(RXUSRGP1)' '-L LPAR1 -G TEST -A REMOVE'
    ```      
  - Remote CPC and specific LPAR:
    ```
    ex 'HWI.USER.REXX(RXUSRGP1)' '-C CPC1 -L LPAR1 -G TEST -A REMOVE'
    ```

**Sample Batch Invocation via JCL:**
RXUSRGP1 has been copied into data set HWI.USER.REXX

```
 //RXUSRGP1 JOB ,
 // CLASS=J,NOTIFY=&SYSUID,MSGLEVEL=1,
 //  MSGCLASS=H,REGION=0M,TIME=1440
 //STEP1    EXEC PGM=IKJEFT01,DYNAMNBR=20
 //SYSUDUMP DD SYSOUT=(H,,STD)
 //SYSTSPRT DD SYSOUT=(H,,STD)
 //SYSTSIN  DD * UB
 PROFILE NOPREFIX
 EX 'HWI.USER.REXX(RXUSRGP1)' -
 '-C CPC1 -L LPAR1 -G TESTGRP -A ADD'
 /*
 ```
 - exec is running in a TSO/E rexx environment

## Example Generated Output

### Success Path for List Custom User Groups Invocation
```
------ Listing Custom User Groups -------------------- 
                                                       
------ Parameter Information ------------------------- 
                                                       
CPC : CPC1                                         
LPAR: Local LPAR                                       
Custom User Group: not specified                       
Action Requested : LIST                                
                                                       
------ Obtaining CPC Information --------------------- 
                                                       
------->                                               
GET request being made....                             
URI: /api/cpcs?name=CPC1                           
ENCODING: 0                                            
TIMEOUT: 0
                                                                              
Rexx RC: (0)                                                                  
HTTP Status: (200)                                                            
SE DateTime: (Tue, 11 Oct 2022 15:45:14 GMT)                                  
SE requestId: (Sx59168340-3e9f-11ed-81ce-00106f25da94.17 Rx2)                 
Response Body: ({"cpcs":[{"name":"CPC1","se-version":"2.16.0","location":"remote","object-uri":"/api/cpcs/670cabda-12b6-313a-b2
10-b2591e9cc9e2","target-name":"IBM390PS.CPC1"}]})                        
                                                                              
<-------                                                                           
                                                                              
Successfully obtained CPC Info:                                               
  uri:/api/cpcs/670cabda-12b6-313a-b210-b2591e9cc9e2                          
  target-name:IBM390PS.CPC1                                              
                                                                          
------->
GET request being made.... 
URI: /api/groups                                                             
TARGETNAME: IBM390PS.CPC1                                               
ENCODING: 0                                                                  
TIMEOUT: 0                                                                   
                                                                             
Rexx RC: (0)                                                                 
HTTP Status: (200)                                                           
SE DateTime: (Tue, 11 Oct 2022 15:45:15 GMT)                                 
SE requestId: (Sxd2739d34-496e-11ed-bf40-fa163e35e1fa.4 Rx2) 
Response Body: ({"groups":[{"name":"CG1","object-uri":"/api/groups/d8475cb5-9454-303e-9522-da772d672790","target-name":"IBM390PS.CPC1"}]})

<-------                                                                     
                                                                             
Found 1 custom user groups                                                   
Custom User Group Name: CG1 | URI: /api/groups/d8475cb5-9454-303e-9522-da772d672790

```

### Success Path for List Custom User Group Members Invocation
```
------ Listing Custom User Groups -------------------- 
                                                       
------ Parameter Information ------------------------- 
                                                       
CPC : CPC1                                         
LPAR: Local LPAR                                       
Custom User Group: CG1                                 
Action Requested : LIST                                
                                                       
------ Obtaining CPC Information --------------------- 
                                                       
------->                                               
GET request being made....                             
URI: /api/cpcs?name=CPC1                           
ENCODING: 0                                            
TIMEOUT: 0                                             
                                                       
Rexx RC: (0)
HTTP Status: (200)                                                              
SE DateTime: (Tue, 11 Oct 2022 18:18:24 GMT)                                    
SE requestId: (Sx59168340-3e9f-11ed-81ce-00106f25da94.19 Rx0)                   
Response Body: ({"cpcs":[{"name":"CPC1","se-version":"2.16.0","location":"remote","object-uri":"/api/cpcs/670cabda-12b6-313a-b210-b2591e9cc9e2","target-name":"IBM390PS.CPC1"}]})                                                             
<-------                                                                        
                                                                      
Successfully obtained CPC Info:                                                 
  uri:/api/cpcs/670cabda-12b6-313a-b210-b2591e9cc9e2                            
  target-name:IBM390PS.CPC1

------->                                                                        
GET request being made....                                                      
URI: /api/groups?name=CG1                                                       
TARGETNAME: IBM390PS.CPC1
ENCODING: 0                                                                 
TIMEOUT: 0                                                                  
                                                                            
Rexx RC: (0)                                                                
HTTP Status: (200)                                                          
SE DateTime: (Tue, 11 Oct 2022 18:18:29 GMT)                                
SE requestId: (Sxd2739d34-496e-11ed-bf40-fa163e35e1fa.6 Rx0)                
Response Body: ({"groups":[{"name":"CG1","object-uri":"/api/groups/d785448e-c273-392c-ac09-dae9b3d83572","target-name":"IBM390PS.CPC1"}]})  

<-------                                                                    
                                                                            
Custom User Group Name: CG1 | URI: /api/groups/d785448e-c273-392c-ac09-dae9b3d83572
                                                                            
------ Listing Custom User Group Members -----------                        
                                                                            
------->                                                                    
GET request being made....
URI: /api/groups/d785448e-c273-392c-ac09-dae9b3d83572/members               
TARGETNAME: IBM390PS.CPC1                                               
ENCODING: 0                                                                 
TIMEOUT: 0                                                                  
                                                                            
Rexx RC: (0)                                                                
HTTP Status: (200)                                                          
SE DateTime: (Tue, 11 Oct 2022 18:18:29 GMT)                                
SE requestId: (Sxd2739d34-496e-11ed-bf40-fa163e35e1fa.6 Rx1)
Response Body: ({"members":[{"name":"LP01","target-name":"IBM390PS.CPC1.LP01","object-uri":"/api/logical-partitions/444fae65-f640-3f63-b8fd-e954e0e44f6f"},{"name":"LP02","target-name":"IBM390PS.CPC1.LP02","object-uri":"/api/logical-partitions/934c6d39-c32d-36bc-9a65-154abc8711f3"}]})
<-------                                                                    
                                                                            
Found 2 members in group CG1                                                
Custom User Group Member : LP01 | URI: /api/logical-partitions/444fae65-f640-3f63-b8fd-e954e0e44f6f
Custom User Group Member : LP02 | URI: /api/logical-partitions/934c6d39-c32d-36bc-9a65-154abc8711f3      
```

### Success Path for Add Invocation
```
------ Parameter Information ------------------------- 
                                                       
CPC : CPC1                               
LPAR: LP02                                             
Custom User Group: CG1                                 
Action Requested : ADD                                 
                                                       
------ Obtaining CPC Information --------------------- 
                                                       
------->                                               
GET request being made....                             
URI: /api/cpcs?name=CPC1          
ENCODING: 0                                            
TIMEOUT: 0                                             
                                                       
Rexx RC: (0)                                           
HTTP Status: (200)
SE DateTime: (Tue, 11 Oct 2022 16:31:33 GMT)                                  
SE requestId: (Sx59168340-3e9f-11ed-81ce-00106f25da94.18 Rx0)                 
Response Body: ({"cpcs":[{"name":"CPC1","se-version":"2.16.0","location":"remote","object-uri":"/api/cpcs/670cabda-12b6-313a-b2
10-b2591e9cc9e2","target-name":"IBM390PS.CPC1"}]})                        
                                                                              
<-------                                                    
                                                                              
Successfully obtained CPC Info:                                               
  uri:/api/cpcs/670cabda-12b6-313a-b210-b2591e9cc9e2                          
  target-name:IBM390PS.CPC1                                                     
                                                                              
------->                                                                      
GET request being made....                                                    
URI: /api/groups?name=CG1                                                     
TARGETNAME: IBM390PS.CPC1       
ENCODING: 0
TIMEOUT: 0                                                                   
                                                                             
Rexx RC: (0)                                                                 
HTTP Status: (200)                                                           
SE DateTime: (Tue, 11 Oct 2022 16:31:36 GMT)                                 
SE requestId: (Sxd2739d34-496e-11ed-bf40-fa163e35e1fa.5 Rx0)                 
Response Body: ({"groups":[{"name":"CG1","object-uri":"/api/groups/d785448e-c273-392c-ac09-dae9b3d83572","target-name":"IBM390PS.CPC1"}]})
                                                                             
<-------                                                                     
                                                                             
Custom User Group Name: CG1 | URI: /api/groups/d785448e-c273-392c-ac09-dae9b3d83572
                                                                             
------->                                                                     
GET request being made....                                                   
URI: /api/cpcs/670cabda-12b6-313a-b210-b2591e9cc9e2/logical-partitions?name=LP02
TARGETNAME: IBM390PS.CPC1                                              
ENCODING: 0
TIMEOUT: 0                                                                   
                                                                             
Rexx RC: (0)                                                                 
HTTP Status: (200)                                                           
SE DateTime: (Tue, 11 Oct 2022 16:31:36 GMT)                                 
SE requestId: (Sxd2739d34-496e-11ed-bf40-fa163e35e1fa.5 Rx1)                 
Response Body: ({"logical-partitions":[{"name":"LP02","request-origin":false,"object-uri":"/api/logical-partitions/934c6d39-c32d-36bc-9a65-154abc8711f3", "target-name":"IBM390PS.CPC1.LP02","status":"operating"}]})
                                                                             
<-------                                                                     
                                                                             
                                                                             
Successfully obtained LPAR Info:                                             
LPAR  uri:/api/logical-partitions/934c6d39-c32d-36bc-9a65-154abc8711f3       
LPAR  target-name:IBM390PS.CPC1.LP02

------ Adding LPAR to custom user group ----------
                                                                              
------->                                                                      
POST request being made....                                                   
URI: /api/groups/d785448e-c273-392c-ac09-dae9b3d83572/operations/add-member   
TARGETNAME: IBM390PS.CPC1                                                
REQUEST BODY: {"object-uri":"/api/logical-partitions/934c6d39-c32d-36bc-9a65-154abc8711f3"}
CLIENT CORRELATOR:                                                            
ENCODING: 0                                                                   
TIMEOUT: 0                                                                    
                                                                              
Rexx RC: (0)                                                                  
HTTP Status: (204)                                                            
SE DateTime: (Tue, 11 Oct 2022 16:31:36 GMT)                                  
SE requestId: (Sxd2739d34-496e-11ed-bf40-fa163e35e1fa.5 Rx2)                  
Response Body: (RESPONSE.RESPONSEBODY)                                        
```

### Success Path for Remove Invocation
```
------ Parameter Information ------------------------- 
                                                       
CPC : CPC1                                         
LPAR: LP02                                             
Custom User Group: CG1                                 
Action Requested : REMOVE                              
                                                       
------ Obtaining CPC Information --------------------- 
                                                       
------->                                               
GET request being made....                             
URI: /api/cpcs?name=CPC1                           
ENCODING: 0                                            
TIMEOUT: 0                                             
                                                       
Rexx RC: (0)                                           
HTTP Status: (200)
SE DateTime: (Tue, 11 Oct 2022 18:34:05 GMT)                                    
SE requestId: (Sx59168340-3e9f-11ed-81ce-00106f25da94.19 Rx1)                   
Response Body: ({"cpcs":[{"name":"CPC1","se-version":"2.16.0","location":"remote","object-uri":"/api/cpcs/670cabda-12b6-313a-b210-b2591e9cc9e2","target-name":"IBM390PS.CPC1"}]})

<-------

Successfully obtained CPC Info:                                                 
  uri:/api/cpcs/670cabda-12b6-313a-b210-b2591e9cc9e2                            
  target-name:IBM390PS.CPC1                                                           
                                                                                
------->                                                                        
GET request being made....                                                      
URI: /api/groups?name=CG1                                                       
TARGETNAME: IBM390PS.CPC1                                                   
ENCODING: 0
TIMEOUT: 0                                                                    
                                                                              
Rexx RC: (0)                                                                  
HTTP Status: (200)                                                            
SE DateTime: (Tue, 11 Oct 2022 18:34:10 GMT)                                  
SE requestId: (Sxd2739d34-496e-11ed-bf40-fa163e35e1fa.6 Rx2)                  
Response Body: ({"groups":[{"name":"CG1","object-uri":"/api/groups/d785448e-c273-392c-ac09-dae9b3d83572","target-name":"IBM390PS.CPC1"}]})

<-------                                                                      
                                                                              
Custom User Group Name: CG1 | URI: /api/groups/d785448e-c273-392c-ac09-dae9b3d83572
                                                                              
------->                                                                      
GET request being made....                                                    
URI: /api/cpcs/670cabda-12b6-313a-b210-b2591e9cc9e2/logical-partitions?name=LP02
TARGETNAME: IBM390PS.CPC1
ENCODING: 0                                                                    
TIMEOUT: 0                                                                     
                                                                               
Rexx RC: (0)                                                                   
HTTP Status: (200)                                                             
SE DateTime: (Tue, 11 Oct 2022 18:34:10 GMT)                                   
SE requestId: (Sxd2739d34-496e-11ed-bf40-fa163e35e1fa.6 Rx3)                   
Response Body: ({"logical-partitions":[{"name":"LP02","request-origin":false,"object-uri":"/api/logical-partitions/934c6d39-c32d-36bc-9a65-154abc8711f3","target-name":"IBM390PS.CPC1.LP02","status":"operating"}]})

<-------

Successfully obtained LPAR Info:                                               
LPAR  uri:/api/logical-partitions/934c6d39-c32d-36bc-9a65-154abc8711f3         
LPAR  target-name:IBM390PS.CPC1.LP02

------ Removing LPAR from custom user group -------
                                                                               
------->                                                                       
POST request being made....                                                    
URI: /api/groups/d785448e-c273-392c-ac09-dae9b3d83572/operations/remove-member 
TARGETNAME: IBM390PS.CPC1                                                  
REQUEST BODY: {"object-uri":"/api/logical-partitions/934c6d39-c32d-36bc-9a65-154abc8711f3"}
CLIENT CORRELATOR:                                                             
ENCODING: 0                                                                    
TIMEOUT: 0                                                                     
                                                                               
Rexx RC: (0)                                                                   
HTTP Status: (204)                                                             
SE DateTime: (Tue, 11 Oct 2022 18:34:10 GMT)                                   
SE requestId: (Sxd2739d34-496e-11ed-bf40-fa163e35e1fa.6 Rx4)                   
Response Body: (RESPONSE.RESPONSEBODY)
```