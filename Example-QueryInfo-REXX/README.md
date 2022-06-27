## Example-QueryInfo-REXX

This sample uses HWIREST API to:
- List CPCs and retrieve the URI and target name associated with the LOCAL CPC or the CPCname provided
- Retrieve the following CPC information:
    - total memory installed
    - total memory available for LPARs
    - primary SE MAC
    - LPAR Resource Assignment
- List the LPARs on the target CPC and retrieve the URI and target name associated with the LOCAL LPAR or the LPARname provided
- Retrieve the following LPAR information:
    - Dedicated Logical CP #
    - Online Logical CP #
    - Reserved Logical CP #
    - Dedicated Logical ZIIP #
    - Online Logical ZIIP #
    - Reserved Logical ZIIP #
    - Dedicated ICF or Shared ICF
    - Online Logical ICF #
    - Reserved Logical ICF #

## System Prep work
- Store RXQUERY1 into a data set
- Ensure your z/OS user ID has READ access to the following FACILITY Class Profiles
    - HWI.TARGET.netid.nau
    - HWI.TARGET.netid.nau.imagename

    <p>where netid.nau represents the 3– to 17– character SNA name of the particular CPC
    and imagename represents the 1– to 8- character LPAR name that will be the targets of the request</p>


## Invocation
**Syntax**:
```
  RXQUERY1 CPCname LPARname -v -I
 ```
 where:
  - *CPCname* is the name of the CPC you wish to query
      - specify `LOCAL_CPC` to default to the LOCAL CPC
      - **required**
  - *LPARname* is the name of the LPAR on that CPC that you wish to query
      - specify `LOCAL_LPAR` to default to the LOCAL LPAR
      - **required**
  - *–v* is an optional parameter that will turn on verbose JSON parser tracing
  - *–I* is an optional parameter indicates the exec is running in an ISV REXX environment

**sample invocation in TSO:**
<br>RXQUERY1 has been copied into data set HWI.HWIREST.REXX
```
ex 'HWI.HWIREST.REXX(RXQUERY1)' 'LOCAL_CPC LOCAL_LPAR'
ex 'HWI.HWIREST.REXX(RXQUERY1)' 'LOCAL_CPC LPAR1 -v'
ex 'HWI.HWIREST.REXX(RXQUERY1)' 'CPC1 LPAR1 -v'
ex 'HWI.HWIREST.REXX(RXQUERY1)' 'CPC1 LPAR1 -v -I'
```

**sample output for `ex 'HWI.HWIREST.REXX(RXQUERY1)' 'CPC1 LPAR1'`:**
```
 Starting RXQUERY1 for CPC name:CPC1 and LPAR name:LPAR1

------->
 GET request being made....
 uri:/api/cpcs?name=CPC1

 Rexx RC: (0)
 HTTP Status: (200)
 SE DateTime: (Thu, 18 Mar 2021 15:11:00 GMT)
 SE requestId: (Sxd7277f62-87f0-11eb-a206-1111111fffffff50.1 Rx1e)
 Response Body: ({"cpcs":[{"name":"CPC1","se-version":"2.15.0","location":"local","object-uri":"/api/cpcs/111111111-aaaa-bbbb-8888-33333333333","target-name":"IBM390PS.CPC1"}]})

 <-------

 Successfully obtained CPC Info:
   uri:/api/cpcs/111111111-aaaa-bbbb-8888-33333333333
   target-name:IBM390PS.CPC1


 ------->
 GET request being made....
 uri:/api/cpcs/111111111-aaaa-bbbb-8888-33333333333?properties=storage-total-installed,storage-customer,lan-interface1-address,lan-i
 nterface2-address,network1-ipv4-pri-ipaddr,network2-ipv4-pri-ipaddr&cached-acceptable=true
 targetname:IBM390PS.CPC1

 Rexx RC: (0)
 HTTP Status: (200)
 SE DateTime: (Thu, 18 Mar 2021 15:11:00 GMT)
 SE requestId: (Sxd7277f62-87f0-11eb-a206-1111111fffffff50.1 Rx1f)
 Response Body: ({"lan-interface1-address":"1111111fffffff52","lan-interface2-address":"1111111fffffff53","network2-ipv4-pri-ipaddr":null,"n
 etwork1-ipv4-pri-ipaddr":"1.11.66.123","storage-customer":4456448,"storage-total-installed":4620288})

 <-------

 CPC total storage available:(4620288)
 CPC storage available to LPARs:(4456448)
 CPC SE MAC LAN interface 1:(1111111fffffff52)
 CPC SE LAN 1, primary IPv4 address:(1.11.66.123)
 CPC SE MAC LAN interface 2:(1111111fffffff53)
 CPC SE LAN 2, primary IPv4 address:(false)

 ------->
 GET request being made....
 uri:/api/cpcs/111111111-aaaa-bbbb-8888-33333333333/logical-partitions?name=LPAR1
 targetname:IBM390PS.CPC1

 Rexx RC: (0)
 HTTP Status: (200)
 SE DateTime: (Thu, 18 Mar 2021 15:11:03 GMT)
 SE requestId: (Sxd7277f62-87f0-11eb-a206-1111111fffffff50.1 Rx21)
 Response Body: ({"logical-partitions":[{"name":"LPAR1","request-origin":true,"object-uri":"/api/logical-partitions/a347633b-d493-3f7c
 -a11f-f882dd27dcfb","target-name":"IBM390PS.CPC1.LPAR1","status":"operating"}]})

 <-------

 Successfully obtained LPAR Info:
   uri:/api/logical-partitions/aaaaaaaaa-dddd-3333-aaaa-fffffffff
   target-name:IBM390PS.CPC1.LPAR1


 ------->
 GET request being made....
 uri:/api/logical-partitions/aaaaaaaaa-dddd-3333-aaaa-fffffffff?properties=processor-usage,number-general-purpose-processors,numbe
 r-reserved-general-purpose-processors,number-general-purpose-cores,number-reserved-general-purpose-cores,number-ziip-processors,num
 ber-reserved-ziip-processors,number-ziip-cores,number-reserved-ziip-cores,number-icf-processors,number-reserved-icf-processors,numb
 er-icf-cores,number-reserved-icf-cores&cached-acceptable=true
 targetname:IBM390PS.CPC1.LPAR1

 Rexx RC: (0)
 HTTP Status: (200)
 SE DateTime: (Thu, 18 Mar 2021 15:11:03 GMT)
 SE requestId: (Sxd7277f62-87f0-11eb-a206-1111111fffffff50.1 Rx22)
 Response Body: ({"number-reserved-icf-processors":0,"number-ziip-processors":3,"number-icf-processors":0,"number-reserved-general-p
 urpose-processors":0,"processor-usage":"shared","number-general-purpose-processors":3,"number-ziip-cores":3,"number-general-purpose
 -cores":3,"number-reserved-ziip-cores":0,"number-icf-cores":0,"number-reserved-icf-cores":0,"number-reserved-general-purpose-cores"
 :0,"number-reserved-ziip-processors":0})

 <-------


 Processor Usage:(shared)
 GPP #:(3)
 GPP Reserved #:(0)
 GPP Cores #:(3)
 GPP Reserved Cores #:(0)
 ZIIP #:(3)
 ZIIP Reserved #:(0)
 ZIIP Cores #:(3)
 ZIIP Reserved Cores #:(0)
 ICF #:(0)
 ICF Reserved #:(0)
 ICF Cores #:(0)
 ICF Reserved Cores #:(0)
 ```

**sample output for `ex 'HWI.HWIREST.REXX(RXQUERY1)' 'LOCAL_CPC LOCAL_LPAR'`:**
```
 Starting RXQUERY1 for CPC name:LOCAL_CPC and LPAR name:LOCAL_LPAR

 ------->
 GET request being made....
 uri:/api/cpcs

 Rexx RC: (0)
 HTTP Status: (200)
 SE DateTime: (Thu, 02 Dec 2021 00:41:33 GMT)
 SE requestId: (Sx13dc0888-1cde-11ec-85fd-1111111fffffffff4.61 Rx0)
 Response Body: ({"cpcs":[{"name":"T123","se-version":"2.15.0","location":"remote","object-uri":"/api/cpcs/cccccccc-dddddddddddddd",
 "target-name":"IBM390PS.T123"},{"name":"T231","se-version":"2.15.0","location":"local","object-uri":"/api/cpcs/bbbbbb-1111-3333-9999-44444",
 "target-name":"IBM390PS.T231"},{"name":"T321","se-version":"2.15.0","location":"remote","object-uri":"/api/cpcs/bbbbb-77777-888",
 "target-name":"IBM390PS.T321"}]})

 <-------

 Processing information for 22 CPC(s)... searching for local
 found local CPC

 Successfully obtained local CPC Info:
   name:T231
   uri:/api/cpcs/bbbbbb-1111-3333-9999-44444
   target-name:IBM390PS.T231


 ------->
 GET request being made....
 uri:/api/cpcs/bbbbbb-1111-3333-9999-44444?properties=storage-total-installed,storage-customer,lan-interface1-address,lan-i
 nterface2-address,network1-ipv4-pri-ipaddr,network2-ipv4-pri-ipaddr&cached-acceptable=true
1targetname:IBM390PS.T231

 Rexx RC: (0)
 HTTP Status: (200)
 SE DateTime: (Thu, 02 Dec 2021 00:41:33 GMT)
 SE requestId: (Sx13dc0888-1cde-11ec-85fd-1111111fffffffff4.61 Rx1)
 Response Body: ({"lan-interface1-address":"1111111fffffffff6","lan-interface2-address":"1111111fffffffff7","network2-ipv4-pri-ipaddr":null,"n
 etwork1-ipv4-pri-ipaddr":"1.00.22.66","storage-customer":2883584,"storage-total-installed":3145728})

 <-------


 CPC total storage available:(3145728)
 CPC storage available to LPARs:(2883584)
 CPC SE MAC LAN interface 1:(1111111fffffffff6)
 CPC SE LAN 1, primary IPv4 address:(1.00.22.66)
 CPC SE MAC LAN interface 2:(1111111fffffffff7)
 CPC SE LAN 2, primary IPv4 address:(false)


 ------->
 GET request being made....
 uri:/api/cpcs/bbbbbb-1111-3333-9999-44444/logical-partitions
 targetname:IBM390PS.T231

 Rexx RC: (0)
 HTTP Status: (200)
 SE DateTime: (Thu, 02 Dec 2021 00:41:34 GMT)
 SE requestId: (Sx13dc0888-1cde-11ec-85fd-1111111fffffffff4.61 Rx2)
 Response Body: ({"logical-partitions":[{"name":"LPAR1","request-origin":false,"object-uri":"/api/logical-partitions/222-777-888",
 "target-name":"IBM390PS.T231.LPAR1","status":"operating"},{"name":"LPAR2","request-origin":true,"object-uri":"/
 api/logical-partitions/6666666-8888-33333-eeeeeeeee","target-name":"IBM390PS.T231.LPAR2","status":"operating"}]})

 <-------

 Processing information for 2 LPAR(s)... searching for local
 found local LPAR

 Successfully obtained local LPAR Info:
   name:LPAR2
   uri:/api/logical-partitions/6666666-8888-33333-eeeeeeeee
   target-name:IBM390PS.T231.LPAR2


 ------->
 GET request being made....
 uri:/api/logical-partitions/6666666-8888-33333-eeeeeeeee?properties=processor-usage,number-general-purpose-processors,numbe
 r-reserved-general-purpose-processors,number-general-purpose-cores,number-reserved-general-purpose-cores,number-ziip-processors,num
 ber-reserved-ziip-processors,number-ziip-cores,number-reserved-ziip-cores,number-icf-processors,number-reserved-icf-processors,numb
 er-icf-cores,number-reserved-icf-cores&cached-acceptable=true
 targetname:IBM390PS.T231.LPAR2

 Rexx RC: (0)
 HTTP Status: (200)
 SE DateTime: (Thu, 02 Dec 2021 00:41:34 GMT)
 SE requestId: (Sx13dc0888-1cde-11ec-85fd-1111111fffffffff4.61 Rx3)
1Response Body: ({"number-reserved-icf-processors":0,"number-ziip-processors":0,"number-icf-processors":0,"number-reserved-general-p
 urpose-processors":0,"processor-usage":"shared","number-general-purpose-processors":3,"number-ziip-cores":0,"number-general-purpose
 -cores":3,"number-reserved-ziip-cores":1,"number-icf-cores":0,"number-reserved-icf-cores":0,"number-reserved-general-purpose-cores"
 :0,"number-reserved-ziip-processors":1})

 <-------


 Processor Usage:(shared)
 GPP #:(3)
 GPP Reserved #:(0)
 GPP Cores #:(3)
 GPP Reserved Cores #:(0)
 ZIIP #:(0)
 ZIIP Reserved #:(1)
 ZIIP Cores #:(0)
 ZIIP Reserved Cores #:(1)
 ICF #:(0)
 ICF Reserved #:(0)
 ICF Cores #:(0)
 ICF Reserved Cores #:(0)
 ```
