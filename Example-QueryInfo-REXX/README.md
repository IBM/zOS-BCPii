## Example-QueryInfo-REXX

This samples uses HWIREST API to:
- List CPCs, filtered by the CPC name provided, in order to retrieve the URI and target name associated with that CPC
- Retrieve the following CPC information:
    - total memory installed
    - total memory available for LPARs
    - primary SE MAC
    - LPAR Resource Assignment
- List the LPARs on that CPC, filtered by the LPAR name provided, in order to retrieve the URI and target name associated with that LPAR
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
    and imagename represents the 1– to 8- character LPAR name that will be used as input</p>


## Invocation
**Syntax**:
```
 RXQUERY1 CPCname LPARname -v
 ```
 where:
  - *CPCname* is the name of the CPC you wish to query, **required**
  - *LPARname* is the name of the LPAR on that CPC that you wish to query, **required**
  - *–v* is an optional parameter that will turn on verbose JSON parser tracing

**sample invocation in TSO:**
<br>RXQUERY1 has been copied into data set HWI.HWIREST.REXX
```
ex 'HWI.HWIREST.REXX(RXQUERY1)' 'T256 TA4'
ex 'HWI.HWIREST.REXX(RXQUERY1)' 'T256 TA4 -V'
```

**sample output:**
```
------->
 GET request being made....
 uri:/api/cpcs?name=T256

 Rexx RC: (0)
 HTTP Status: (200)
 SE DateTime: (Thu, 18 Mar 2021 15:11:00 GMT)
 SE requestId: (Sxd7277f62-87f0-11eb-a206-00106f253850.1 Rx1e)
 Response Body: ({"cpcs":[{"name":"T256","se-version":"2.15.0","location":"local","object-uri":"/api/cpcs/111111111-aaaa-bbbb-8888-33333333333","target-name":"IBM390PS.T256"}]})

 <-------

 Successfully obtained CPC Info:
   uri:/api/cpcs/111111111-aaaa-bbbb-8888-33333333333
   target-name:IBM390PS.T256


 ------->
 GET request being made....
 uri:/api/cpcs/111111111-aaaa-bbbb-8888-33333333333?properties=storage-total-installed,storage-customer,lan-interface1-address,lan-i
 nterface2-address,network1-ipv4-pri-ipaddr,network2-ipv4-pri-ipaddr&cached-acceptable=true
 targetname:IBM390PS.T256

 Rexx RC: (0)
 HTTP Status: (200)
 SE DateTime: (Thu, 18 Mar 2021 15:11:00 GMT)
 SE requestId: (Sxd7277f62-87f0-11eb-a206-00106f253850.1 Rx1f)
 Response Body: ({"lan-interface1-address":"00106f253852","lan-interface2-address":"00106f253853","network2-ipv4-pri-ipaddr":null,"n
 etwork1-ipv4-pri-ipaddr":"9.12.16.169","storage-customer":4456448,"storage-total-installed":4620288})

 <-------

 CPC total storage available:(4620288)
 CPC storage available to LPARs:(4456448)
 CPC SE MAC LAN interface 1:(00106f253852)
 CPC SE LAN 1, primary IPv4 address:(9.12.16.169)
 CPC SE MAC LAN interface 2:(00106f253853)
 CPC SE LAN 2, primary IPv4 address:(false)

 ------->
 GET request being made....
 uri:/api/cpcs/111111111-aaaa-bbbb-8888-33333333333/logical-partitions?name=TA4
 targetname:IBM390PS.T256

 Rexx RC: (0)
 HTTP Status: (200)
 SE DateTime: (Thu, 18 Mar 2021 15:11:03 GMT)
 SE requestId: (Sxd7277f62-87f0-11eb-a206-00106f253850.1 Rx21)
 Response Body: ({"logical-partitions":[{"name":"TA4","request-origin":true,"object-uri":"/api/logical-partitions/a347633b-d493-3f7c
 -a11f-f882dd27dcfb","target-name":"IBM390PS.T256.TA4","status":"operating"}]})

 <-------

 Successfully obtained LPAR Info:
   uri:/api/logical-partitions/aaaaaaaaa-dddd-3333-aaaa-fffffffff
   target-name:IBM390PS.T256.TA4


 ------->
 GET request being made....
 uri:/api/logical-partitions/aaaaaaaaa-dddd-3333-aaaa-fffffffff?properties=processor-usage,number-general-purpose-processors,numbe
 r-reserved-general-purpose-processors,number-general-purpose-cores,number-reserved-general-purpose-cores,number-ziip-processors,num
 ber-reserved-ziip-processors,number-ziip-cores,number-reserved-ziip-cores,number-icf-processors,number-reserved-icf-processors,numb
 er-icf-cores,number-reserved-icf-cores&cached-acceptable=true
 targetname:IBM390PS.T256.TA4

 Rexx RC: (0)
 HTTP Status: (200)
 SE DateTime: (Thu, 18 Mar 2021 15:11:03 GMT)
 SE requestId: (Sxd7277f62-87f0-11eb-a206-00106f253850.1 Rx22)
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

