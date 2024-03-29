# zOS-BCPii
zOS Base Control Program internal interface

![](images/BCPii.jpg)

**Base Control Program internal interface (z/OS BCPii)**
- Allows authorized z/OS applications to have HMC-like control over systems in the process control (HMC) network.
- Does not use any external network; Communicates directly with the SE rather than going over an IP network.
- A z/OS address space that manages authorized interaction with the interconnected hardware.<br/><br/>

This repository contains samples that take advantage of new z/OS BCPii HWIREST interface to issue various requests against the CPC and more.<br/><br/>

<b>System Requirements for HWIREST invocation</b>
- minimum IBM Z15 hardware level for:
  - SE and HMC associated with the local and target CPC
- mimimum BCPii microcode level applied to the corresponding SE and HMC:
  - SE 2.15.0 with MCL P46598.370, Bundle S38
  - HMC 2.15.0 with MCL P46686.001, Bundle H25
- minimum BCPii level
  - z/OS 2.4 with APAR
     - [**OA60351**](https://www.ibm.com/support/pages/apar/OA60351)
     - [**OA61976 - TSO/E and ISV REXX env**](https://www.ibm.com/support/pages/apar/OA61976)
     
<b>HWIREST Interface Considerations</b>
- C, Assembler
  - Request Body maximum 64KB
  - Response Body maximum 15MB

- System/ISV REXX
  - Request Body maximum 64KB
  - Response Body maximum 2.5MB

- TSO/E REXX
  - Request Body maximum 32767 bytes
  - Response Body maximum 2.5MB

<b>Usage Notes</b>
- In the event the SE System BCPii Permissions on the Security panel are NOT granted in order to restrict access to LPARs only (disallow CPC access), the application should use the following List Permitted Logical Partitions REST API to obtain the URI and Target Name information for the target LPAR
  - ```GET /api/console/operations/list-permitted-logical-partitions```

<br/>[**Example-QueryInfo-REXX**](https://github.com/IBM/zOS-BCPii/tree/master/Example-QueryInfo-REXX)

This sample demonstrates how to use the BCPii HWIREST REXX interface to query CPC and LPAR information.

<br/>[**Example-LPARActivate-C**](https://github.com/IBM/zOS-BCPii/tree/master/Example-LPARActivate-C)

This sample demonstrates how to use the BCPii HWIREST C interface to activate an LPAR and POLL to determine if the operation was successful.

<br/>[**Example-LPARLoad-SystemRexx**](https://github.com/IBM/zOS-BCPii/tree/master/Example-LPARLoad-SYSREXX)

This sample demonstrates how to use BCPii HWIREST SYSTEM REXX interface to load an LPAR, including a possible activation of the LPAR before hand.

<br/>[**Example-LPARLoad-Rexx**](https://github.com/IBM/zOS-BCPii/tree/master/Example-LPARLoad-REXX)

This sample demonstrates how to use BCPii HWIREST in a TSO/E REXX or ISV REXX interface to load an LPAR, including a possible activation of the LPAR before hand.

<br/>[**Example-Energy-REXX**](https://github.com/IBM/zOS-BCPii/tree/master/Example-Energy-REXX)

This sample uses BCPii HWIREST REXX interface to retrieve energy management information for a target CPC. The results are stored in .csv format, in a member in a z/OS data set.

<br/>[**Example-Audit-REXX**](https://github.com/IBM/zOS-BCPii/tree/master/Example-Audit-REXX)

This sample uses BCPii HWIREST REXX interface to audit LPARs on a target CPC. The results are stored in .csv format, in a member in a z/OS data set.

<br/>[**Example-Crypto-REXX**](https://github.com/IBM/zOS-BCPii/tree/master/Example-Crypto-REXX)

This sample uses BCPii HWIREST REXX interface to retrieve crypto information from image activation profiles associated with LPARs located on a specific  CPC. The results are stored in .csv format, in a member in a z/OS data set. Note the crypto properties are valid on z16 processors or higher.

<br/>[**Example-CustomUsrGrp-REXX**](https://github.com/IBM/zOS-BCPii/tree/master/Example-CustomUsrGrp-REXX)

This sample uses BCPii HWIREST REXX interface to list custom user groups and group members located on a specific CPC (SE).  It can also be used to add an LPAR to a custom user group or remove an LPAR from a customer user group.


<br/><br/><b>Publication References:</b>
- Syntax of HWIREST and other useful BCPii information: [**IBM z/OS MVS Programming: Callable Services for High-Level Languages**](https://www.ibm.com/docs/en/zos/3.1.0?topic=services-base-control-program-internal-interface-bcpii)

- REST API operations documentation, including HTTP Status, error reason codes, etc.
    - [**Hardware Management Console Web Services API**](https://www.ibm.com/docs/en/systems-hardware/zsystems/3932-A02?topic=library-hardware-management-console-web-services-api-version-2160)

- [**MVS System Management Facilities (SMF): BCPii SMF 106**](https://www.ibm.com/docs/en/zos/3.1.0?topic=records-record-type-106-x6a-bcpii-activity)
- [**MVS System Codes: BCPii System Code '042'X**](https://www.ibm.com/docs/en/zos/3.1.0?topic=codes-042)
- [**MVS System Messages, Vol 6 (GOS-IEA) HWI mesages**](https://www.ibm.com/docs/en/zos/3.1.0?topic=iea-hwi-messages)
- [**z/OS MVS Diagnosis: Tools and Service Aids - SYSBCPII component trace**](https://www.ibm.com/docs/en/zos/3.1.0?topic=trace-requesting-sysbcpii)
- [**zOS Hot Topics: BCPii - A RESTed development**](https://www.ibm.com/support/z-content-solutions/hot-topics/)
    - 2022 Hot Topics -> BCPii - A RESTed development 

<br/><br/><b>Other useful references:</b>
- [**z/OS client web enablement toolkit: JSON Parser**](https://www.ibm.com/docs/en/zos/3.1.0?topic=toolkit-zos-json-parser)
- [**z/OS client web enablement toolkit github**](https://github.com/IBM/zOS-Client-Web-Enablement-Toolkit)
