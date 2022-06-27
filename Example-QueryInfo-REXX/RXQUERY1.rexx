/* REXX */
/* START OF SPECIFICATIONS *********************************************/
/* Beginning of Copyright and License                                  */
/*                                                                     */
/* Copyright 2021 IBM Corp.                                            */
/*                                                                     */
/* Licensed under the Apache License, Version 2.0 (the "License");     */
/* you may not use this file except in compliance with the License.    */
/* You may obtain a copy of the License at                             */
/*                                                                     */
/* http://www.apache.org/licenses/LICENSE-2.0                          */
/*                                                                     */
/* Unless required by applicable law or agreed to in writing,          */
/* software distributed under the License is distributed on an         */
/* "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,        */
/* either express or implied.  See the License for the specific        */
/* language governing permissions and limitations under the License.   */
/*                                                                     */
/* End of Copyright and License                                        */
/***********************************************************************/
/*                                                                     */
/*  SCRIPT NAME=RXQUERY1                                               */
/*                                                                     */
/*  DESCRIPTIVE NAME:                                                  */
/*    Sample REXX code that uses HWIREST API to obtain CPC and LPAR    */
/*    information.  It also takes advantage of the JSON Parser         */
/*    to retrieve various pieces of the information.                   */
/*                                                                     */
/* OPERATION:                                                          */
/*                                                                     */
/*  CODE FLOW in this sample:                                          */
/*    Call List CPCs to retrieve uri and target name for the specific  */
/*         CPC                                                         */
/*    Call Get CPC Properties to retreive a few specific CPC attributes*/
/*    Call Get Logical Partition Resource Assignments for the CPC      */
/*    Call List Logical Partitions of CPC to retrieve uri and          */
/*         target name for the specific LPAR                           */
/*    Call Get LPAR Properites to retrieve a few specific LPAR         */
/*         attributes                                                  */
/*                                                                     */
/*                                                                     */
/* INVOCATION:                                                         */
/*     Expects two input parms, name of a CPC and name of an LPAR.     */
/*     Use the value 'LOCAL_CPC' to indicate local CPC.                */
/*     Use the value 'LOCAL_LPAR' to indicate local LPAR.              */
/*     Takes an optional '-I' to indicate exec is running in an        */
/*        ISV REXX environment.                                        */
/*     Takes an optional '-v' to enable verbose json tracing.          */
/*                                                                     */
/*     invocation examples:                                            */
/*        'HWI.HWIREST.REXX(RXQUERY1)' 'TZ15 SCOUT'                    */
/*            - TZ15 is the CPC Name, SCOUT is the LPAR Name           */
/*        'HWI.HWIREST.REXX(RXQUERY1)' 'LOCAL_CPC SCOUT'               */
/*            - LPAR SCOUT on the local CPC                            */
/*        'HWI.HWIREST.REXX(RXQUERY1)' 'LOCAL_CPC LOCAL_LPAR -v'       */
/*            - LOCAL LPAR with json parser tracing                    */
/*        'HWI.HWIREST.REXX(RXQUERY1)' 'LOCAL_CPC LOCAL_LPAR -I'       */
/*            - LOCAL LPAR in an ISV REXX environment                  */
/*                                                                     */
/* DEPENDENCIES                                                        */
/*     none.                                                           */
/*                                                                     */
/*    NOTES:                                                           */
/* No recovery logic has been supplied in this sample.                 */
/*                                                                     */
/*    REFERENCE:                                                       */
/*        See the z/OS MVS Programming: Callable Services for          */
/*        High-Level Languages publication for more information        */
/*        regarding the usage of HWIREST and JSON Parser APIs.         */
/*                                                                     */
/* 12/01/2021 GG: enhance to support LOCAL CPC and LPAR                */
/* 02/22/2022 GG: enhance to support ISV REXX environment (-I)         */
/*                                                                     */
/* END OF SPECIFICATIONS  * * * * * * * * * * * * * * * * * * * * * * **/

MACLIB_DATASET = 'SYS1.MACLIB'
VERBOSE = 0    /* JSON parser specific, enabled via -v */
TRUE = 1
FALSE = 0
localCPC = TRUE
localLPAR = TRUE

hwiHostRC = 0     /* HWIHOST rc */
HWIHOST_ON = FALSE
ISVREXX = FALSE  /* default to TSO/E, enable via -I */
PARSER_INIT = FALSE

/*********************/
/* Get program args  */
/*********************/
parse arg argString
if GetArgs(argString) <> 0 then
   exit -1

say 'Starting RXQUERY1 for CPC name:'||CPCname||' and LPAR name:'||LPARname
if ISVREXX then
  do
    say 'Running in an ISV REXX environment'
    hwiHostRC = hwihost("ON")
    say 'HWIHOST("ON") return code is :('||hwiHostRC||')'

    if hwiHostRC <> 0 then
      exit fatalErrorAndCleanup('** unable to turn on HWIHOST **')
    HWIHOST_ON = TRUE
  end

call IncludeConstants

call JSON_getToolkitConstants
if RESULT <> 0 then
  exit fatalErrorAndCleanup( '** Environment error **' )

PROC_GLOBALS = 'VERBOSE parserHandle '||HWT_CONSTANTS

/*********************************/
/* Create a new parser instance. */
/*********************************/
parserHandle = ''
call JSON_initParser
if RESULT <> 0 then
  exit fatalErrorAndCleanup( '** Parser init failure **' )

/*********************************/
/* Start of BCPii logic          */
/*********************************/
if localCPC then
  do
    if getLocalCPCInfo() <> TRUE then
      exit fatalErrorAndCleanup( '** failed to get local CPC info **' )
  end
else
  do
    if getCPCInfo() <> TRUE then
      exit fatalErrorAndCleanup( '** failed to get CPC info **' )
  end

call QueryCPC

/*************************************************/
/* NOTE: If you modify this sample to retrieve   */
/*       the full CPC data model and encounter a */
/*       JSON Parser error for the following     */
/*       request (i.e. get lpar info), invoke    */
/*       reinitParser between the two functions  */
/*       as a work around for the error.         */
/*                                               */
/* call reinitParser                             */
/*                                               */
/*************************************************/

if localLPAR then
  do
    if getLocalLPARInfo() <> TRUE then
      exit fatalErrorAndCleanup( '** failed to get local LPAR info **' )
  end
else
  do
    if getLPARInfo() <> TRUE then
      exit fatalErrorAndCleanup( '** failed to get LPAR info **' )
  end

call QueryLPAR

call Cleanup

return 0 /* end main */

/***********************************************/
/* Function: reinitParser                      */
/*                                             */
/* Terminate the existing parser handle and    */
/* initialize a brand new parser handle.       */
/***********************************************/
reinitParser:
  if PARSER_INIT then
    do
      /* set ahead of time because we want to avoid an endless error
        loop in the event JSON_termParser invokes fatalError and
        goes through this path again
      */
      PARSER_INIT = FALSE
      call JSON_termParser
    end


  call JSON_initParser
  if RESULT <> 0 then
    exit fatalErrorAndCleanup( '** Parser init failure **' )

return 0

/***********************************************/
/* Function:  fatalErrorAndCleanup             */
/*                                             */
/* Surfaces the input message, and invokes     */
/* cleanup to ensure the parser is terminated  */
/* and HWIHOST is set to off, and returns      */
/* a canonical failure code.                   */
/*                                             */
/* Returns: -1 to indicate fatal script error. */
/***********************************************/
fatalErrorAndCleanup:
 errorMsg = arg(1)
 say errorMsg
 call Cleanup
 return -1  /* end function */

/*******************************************************/
/* Function: Cleanup                                   */
/*                                                     */
/* Terminate the parser instance and, if running in an */
/* ISV REXX environment, turn off HWIHOST.             */
/*******************************************************/
Cleanup:

if PARSER_INIT then
  do
    /* set ahead of time because we want to avoid an endless error
       loop in the event JSON_termParser invokes fatalError and
       goes through this path again
    */
    PARSER_INIT = FALSE
    call JSON_termParser
  end

if HWIHOST_ON then
  do
    /* set ahead of time because we want to avoid an endless error
       loop in the event HWIHOST(OFF) fails and invokes fatalError,
       which will goes through this path again
    */
    HWIHOST_ON = FALSE
    hwiHostRC = hwihost("OFF")
    say 'HWIHOST("OFF") return code is: ('||hwiHostRC||')'

    if hwiHostRC <> 0 then
      exit fatalErrorAndCleanup('** unable to turn off HWIHOST **')
  end

return 0

/*******************************************************/
/* Function:  GetLocalCPCInfo                          */
/*                                                     */
/* Retrieve the uri and target name associated with    */
/* local CPC and prime CPCuri and CPCtargetName        */
/* variables with the info                             */
/*                                                     */
/*******************************************************/
GetLocalCPCInfo:

methodSuccess = 1 /* assume true */
localCPCfound = FALSE

/* First list the cpcs, then retrieve local
   CPC which will have
           "location":"local"

   GET /api/cpcs

   v1: HWILIST(HWI_LIST_LOCAL_CPC)
*/
reqUri = '/api/cpcs'
CPCInfoResponse = GetRequest(reqUri)

if CPCInfoResponse = '' Then
  do
    say 'fatalError ** failed to retrieve CPC info **'
    return 0
  end

/* Parse the response to obtain the uri
   and target name associated with CPC,
   which will be used to query storage info
*/
call JSON_parseJson CPCInfoResponse
CPCArray = JSON_findValue(0, "cpcs", HWTJ_ARRAY_TYPE)
if wasJSONValueFound(CPCArray) = FALSE then
  do
    say 'fatalError ** failed to retrieve CPCs **'
    return 0
  end

/**************************************************************/
 /* Determine the number of CPCs represented in the array     */
 /**************************************************************/
 CPCs = JSON_getArrayDim(CPCArray)
 if CPCs <= 0 then
    return fatalError( '** Unable to retrieve number of array entries **' )

 /********************************************************************/
 /* Traverse the CPCs array to populate CPCsList.                    */
 /* We use the REXX (1-based) idiom  but adjust for the differing    */
 /* (0-based) idiom of the toolkit.                                  */
 /********************************************************************/
 say 'Processing information for '||CPCs||' CPC(s)... searching for local'
 do i = 1 to CPCs
    nextEntryHandle = JSON_getArrayEntry(CPCArray,i-1)
    CPClocation = JSON_findValue(nextEntryHandle,"location",HWTJ_STRING_TYPE)

    if CPClocation = 'local' then
      do
        say 'found local CPC'
        if localCPCfound <> FALSE then
          do
            say 'fatalError ** found two local CPCs **'
            return 0
          end
        localCPCfound = TRUE

        CPCuri=JSON_findValue(nextEntryHandle,"object-uri",HWTJ_STRING_TYPE)
        if wasJSONValueFound(CPCuri) = FALSE then
          do
            say 'fatalError **failed to obtain CPC uri**'
            return 0
          end

        CPCtargetName=JSON_findValue(nextEntryHandle,"target-name",,
                      HWTJ_STRING_TYPE)
        if wasJSONValueFound(CPCtargetName) = FALSE then
          do
            say 'fatalError **failed to obtain CPC target name**'
            return 0
          end

        CPCname=JSON_findValue(nextEntryHandle,"name",HWTJ_STRING_TYPE)
        if wasJSONValueFound(CPCname) = FALSE then
          do
            say 'fatalError **failed to obtain CPC name**'
            return 0
          end
      end
 end /* endloop thru the JSON LPARs array */

if localCPCfound = FALSE then
  do
    methodSuccess = FALSE
    Say 'Failed to retrieve local CPC info'
  end
else
  do
   Say
   Say 'Successfully obtained local CPC Info:'
   Say '  name:'||CPCname
   Say '  uri:'||CPCuri
   Say '  target-name:'||CPCtargetName
   Say
  end

return methodSuccess

/*******************************************************/
/* Function:  wasJSONValueFound                        */
/*                                                     */
/* return FALSE is the content is an empty string or   */
/* the string '(not found), otherwise return TRUE      */
/*                                                     */
/*******************************************************/
wasJSONValueFound:
valueString = arg(1)

if valueString = '' | valueString = '(not found)' then
  return FALSE
else
  return TRUE

/*******************************************************/
/* Function:  GetCPCInfo                               */
/*                                                     */
/* Retrieve the uri and target name associated with    */
/* CPCname  and prime CPCuri and CPCtargetName         */
/* variables with the info                             */
/*                                                     */
/*******************************************************/
GetCPCInfo:

methodSuccess = 1 /* assume true */
emptyCPCResponse = '{"cpcs":[]}'

/* First list the cpcs, filtering the response for
   just information regarding CPC

   GET /api/cpcs?name=CPCname

   v1: HWICONN(HWI_CPC,IBM390PS.CPC)

   NOTE:
   If you wanted to obtain information for the 'local'
   CPC, then you'd retrieve the full list and search for
   the CPC with the
         "location":"local"
   attribute, this would be equivalent to HWICONN(HWI_CPC,*)
*/
reqUri = '/api/cpcs?name='||CPCname
CPCInfoResponse = GetRequest(reqUri)

emptyCPCArray = INDEX(CPCInfoResponse, emptyCPCResponse)
if emptyCPCArray > 0 | CPCInfoResponse = '' Then
  do
    say 'fatalError ** failed to get CPC info **'
    return 0
  end

/* Parse the response to obtain the uri
   and target name associated with CPC,
   which will be used to query storage info
*/
call JSON_parseJson CPCInfoResponse

CPCuri = JSON_findValue(0,"object-uri", HWTJ_STRING_TYPE)
if CPCuri = '' then
  methodSuccess = 0

CPCtargetName = JSON_findValue(0,"target-name", HWTJ_STRING_TYPE)
if CPCtargetName = '' then
  methodSuccess = 0

if methodSuccess then
  do
   Say
   Say 'Successfully obtained CPC Info:'
   Say '  uri:'||CPCuri
   Say '  target-name:'||CPCtargetName
   Say
  end
else
  do
   Say
   Say 'Obtained some or none of the CPC Info:'
   Say '  uri:('||CPCuri||')'
   Say '  target-name:('||CPCtargetName||')'
   Say 'full response body:('||CPCInfoResponse||')'
   Say
   Say 'Fatal ERROR - ** failed to obtain CPC info **'
   Say
  end

return methodSuccess

/*******************************************************/
/* Function:  QueryCPC                                 */
/*                                                     */
/* For CPC retrieve:                                   */
/*          - total memory installed                   */
/*          - total memory available for LPARs         */
/*          - primary SE MAC                           */
/*                                                     */
/*                                                     */
/*******************************************************/
QueryCPC:
/* Now use the retrieved CPC uri and CPC target-name
   to retrieve information for CPC specifically,
   filtering by specific attributes

   GET <CPC uri>?properties=storage-total-installed,
                        storage-customer,
                        etc...
                      &cached-acceptable=true


   v1: HWIQUERY(CPC connection token)
*/
queryStorageTotal = 'storage-total-installed'
queryStorageAvail = 'storage-customer'
queryMAC1 = 'lan-interface1-address'
queryMAC2 = 'lan-interface2-address'
queryNET1IPV4IP = 'network1-ipv4-pri-ipaddr'
queryNET2IPV4IP = 'network2-ipv4-pri-ipaddr'

CPCQueryUri = CPCuri||'?cached-acceptable=true&properties=',
  ||queryStorageTotal,
  ||','||queryStorageAvail,
  ||','||queryMAC1,
  ||','||queryMAC2,
  ||','||queryNET1IPV4IP,
  ||','||queryNET2IPV4IP

CPCQueryResponse = GetRequest(CPCQueryUri,CPCtargetName)
if CPCQueryResponse = '' Then
  do
    say 'fatalError ** failed to query CPC '||CPCname||' **'
    return 0
  end

/* Parse the response to obtain the values of the
   properties queried
*/
call JSON_parseJson CPCQueryResponse

storagetotal = JSON_findValue(0,queryStorageTotal, HWTJ_NUMBER_TYPE)
LPARstorage = JSON_findValue(0,queryStorageAvail, HWTJ_NUMBER_TYPE)
MACaddress1 = JSON_findValue(0,queryMAC1, HWTJ_STRING_TYPE)
MACaddress2 = JSON_findValue(0,queryMAC2, HWTJ_STRING_TYPE)
LAN1IP = JSON_findValue(0,queryNET1IPV4IP, HWTJ_STRING_TYPE)
LAN2IP = JSON_findValue(0,queryNET2IPV4IP, HWTJ_STRING_TYPE)

Say
Say 'CPC total storage available:('||storagetotal||')'
Say 'CPC storage available to LPARs:('||LPARstorage||')'
Say 'CPC SE MAC LAN interface 1:('||MACaddress1||')'
Say 'CPC SE LAN 1, primary IPv4 address:('||LAN1IP||')'
Say 'CPC SE MAC LAN interface 2:('||MACaddress2||')'
Say 'CPC SE LAN 2, primary IPv4 address:('||LAN2IP||')'
Say

return 0

/*******************************************************/
/* Function:  GetLPARInfo                              */
/*                                                     */
/* Retrieve the uri and target name associated with    */
/* an LPAR that exists on CPC and prime                */
/* LPARuri and LPARtargetName variables with the info  */
/*                                                     */
/*******************************************************/
GetLPARInfo:

methodSuccess = 1 /* assume true */
emptyLPARResponse = '{"logical-partitions":[]}'

/* First list all the LPARS on CPC, filtering the response
   for information specific to LPAR:
   /api/cpcs/{cpc-id}/logical-partitions?name=LPAR

   v1:HWICONN(HWI_IMAGE,IBM390PS.CPC.LPAR)

   NOTE:
   If you want to obtain information for the  'local'
   LPAR, then you're retrieve the full list and search
   for the LPAR with the
        "request-origin":true
   attribute, this would be equivalent to HWICONN(HWI_LIST,*)
*/
LPARlisturi = CPCuri||'/logical-partitions?name='||LPARname
LPARInfoResponse = GetRequest(LPARlisturi,CPCtargetName)

emptyLPARArray = INDEX(LPARInfoResponse, emptyLPARResponse)
if emptyLPARArray > 0 | LPARInfoResponse = '' Then
  do
    say 'fatalError ** failed to get LPAR '||LPARname||' info **'
    return 0
  end

/* Parse the response to obtain the uri
   and target name associated with CPC,
   which will be used to query storage info
*/
call JSON_parseJson LPARInfoResponse

LPARuri = JSON_findValue(0,"object-uri", HWTJ_STRING_TYPE)
if LPARuri = '' then
  methodSuccess = 0

LPARtargetName = JSON_findValue(0,"target-name", HWTJ_STRING_TYPE)
if LPARtargetName = '' then
  methodSuccess = 0

if methodSuccess then
  do
   say
   Say 'Successfully obtained LPAR Info:'
   Say '  uri:'||LPARuri
   Say '  target-name:'||LPARtargetName
   Say
  end
else
  do
   say
   Say 'Obtained some or none of the LPAR Info:'
   Say '  uri:('||LPARuri||')'
   Say '  target-name:('||LPARtargetName||')'
   Say 'full response body:('||LPARInfoResponse||')'
   Say
   Say 'fatalError ** failed to obtain LPAR info **'
  end

return methodSuccess

/*******************************************************/
/* Function:  GetLocalLPARInfo                         */
/*                                                     */
/* Retrieve the uri and target name associated with    */
/* local LPAR and prime LPARuri and LPARtargetName     */
/* variables with the info                             */
/*                                                     */
/*******************************************************/
GetLocalLPARInfo:

methodSuccess = TRUE /* assume true */
localLPARfound = FALSE

/* First list the LPAR, then retrieve local
   LPAR which will have
        “request-origin” : true

   GET /api/cpcs/{cpc-id}/logical-partitions

   v1: HWILIST(HWI_LIST_LOCALIMAGE)
*/
LPARlisturi = CPCuri||'/logical-partitions'
LPARInfoResponse = GetRequest(LPARlisturi,CPCtargetName)

if LPARInfoResponse = '' Then
  do
    say 'fatalError ** failed to get local LPAR info **'
    return 0
  end

call JSON_parseJson LPARInfoResponse
LPARArray = JSON_findValue(0, "logical-partitions", HWTJ_ARRAY_TYPE)
if wasJSONValueFound(LPARArray) = FALSE then
  do
    say 'fatalError ** failed to retrieve LPARs **'
    return 0
  end

/**************************************************************/
 /* Determine the number of LPARs represented in the array    */
 /**************************************************************/
LPARs = JSON_getArrayDim(LPARArray)
 if LPARs <= 0 then
    return fatalError( '** Unable to retrieve number of array entries **' )

 /********************************************************************/
 /* Traverse the LPARs array to populate LPARsList.                  */
 /* We use the REXX (1-based) idiom  but adjust for the differing    */
 /* (0-based) idiom of the toolkit.                                  */
 /********************************************************************/
 say 'Processing information for '||LPARs||' LPAR(s)... searching for local'
 do i = 1 to LPARs
    nextEntryHandle = JSON_getArrayEntry(LPARArray,i-1)
    LPARlocal = JSON_findValue(nextEntryHandle,"request-origin",,
                       HWTJ_BOOLEAN_TYPE)

    if LPARlocal = 'true' then
      do
        say 'found local LPAR'
        if localLPARfound <> 0 then
          do
            say 'fatalError ** found two local LPARs **'
            return 0
          end
        localLPARfound = TRUE

        LPARuri=JSON_findValue(nextEntryHandle,"object-uri",HWTJ_STRING_TYPE)
        if wasJSONValueFound(LPARuri) = FALSE then
          do
            say 'fatalError **failed to obtain LPAR uri**'
            return 0
          end

        LPARtargetName=JSON_findValue(nextEntryHandle,"target-name",,
                       HWTJ_STRING_TYPE)
         if wasJSONValueFound(LPARtargetName) = FALSE then
          do
            say 'fatalError **failed to obtain LPAR target name**'
            return 0
          end

        LPARname=JSON_findValue(nextEntryHandle,"name",HWTJ_STRING_TYPE)
        if wasJSONValueFound(LPARname) = FALSE then
          do
            say 'fatalError **failed to obtain LPAR name**'
            return 0
          end
      end
 end /* endloop thru the JSON LPARs array */

if localLPARfound = FALSE then
  do
    methodSuccess = FALSE
    Say 'Failed to retrieve local LPAR info'
  end
else
  do
   say
   Say 'Successfully obtained local LPAR Info:'
   Say '  name:'||LPARname
   Say '  uri:'||LPARuri
   Say '  target-name:'||LPARtargetName
   Say
  end

return methodSuccess

/*******************************************************/
/* Function:  QueryLPAR                                */
/*                                                     */
/* Retrieve LPAR Info:                                 */
/*     Dedicated Logical CP #                          */
/*     Online Logical CP #                             */
/*     Reserved Logical CP #                           */
/*     Dedicated Logical ZIIP #                        */
/*     Online Logical ZIIP #                           */
/*     Reserved Logical ZIIP #                         */
/*     Dedicated ICF or Shared ICF                     */
/*     Online Logical ICF #                            */
/*     Reserved Logical ICF #                          */
/*                                                     */
/*                                                     */
/*******************************************************/
QueryLPAR:

/* Now use the retrieved LPAR uri and LPAR target-name
   to retrieve information for LPAR specifically,
   filtering by specific attributes

   GET <LPAR uri>?properties=processor-usage,
               number-general-purpose-processors,
               number-reserved-general-purpose-processors,
               number-general-purpose-cores,
               number-reserved-general-purpose-cores,
               etc....
             &cached-acceptable=true
   v1: HWIQUERY(LPAR connection token)
*/
queryUsage = 'processor-usage'
queryGPP = 'number-general-purpose-processors'
queryResGPP = 'number-reserved-general-purpose-processors'
queryGPPCores = 'number-general-purpose-cores'
queryResGPPCores = 'number-reserved-general-purpose-cores'
queryZIIP = 'number-ziip-processors'
queryResZIIP = 'number-reserved-ziip-processors'
queryZIIPCores = 'number-ziip-cores'
queryResZIIPCores = 'number-reserved-ziip-cores'
queryICF = 'number-icf-processors'
queryResICF = 'number-reserved-icf-processors'
queryICFCores = 'number-icf-cores'
queryResICFCores = 'number-reserved-icf-cores'

LPARQueryUri = LPARuri||'?cached-acceptable=true&properties=',
  ||queryUsage,
  ||','||queryGPP,
  ||','||queryResGPP,
  ||','||queryGPPCores,
  ||','||queryResGPPCores,
  ||','||queryZIIP,
  ||','||queryResZIIP,
  ||','||queryZIIPCores,
  ||','||queryResZIIPCores,
  ||','||queryICF,
  ||','||queryResICF,
  ||','||queryICFCores,
  ||','||queryResICFCores

LPARQueryResponse = GetRequest(LPARQueryUri, LPARtargetName)
if LPARQueryResponse = '' Then
  do
    say 'fatalError ** failed to query LPAR info **'
    return 0
  end

/* Parse the response to obtain the values of the
   properties queried
*/
call JSON_parseJson LPARQueryResponse

processorUsage = JSON_findValue(0,queryUsage, HWTJ_STRING_TYPE)

GPPvalue = JSON_findValue(0,queryGPP,HWTJ_NUMBER_TYPE)
ResGPPvalue = JSON_findValue(0,queryResGPP,HWTJ_NUMBER_TYPE)
GPPCoresvalue = JSON_findValue(0,queryGPPCores,HWTJ_NUMBER_TYPE)
ResGPPCoresvalue = JSON_findValue(0,queryResGPPCores,HWTJ_NUMBER_TYPE)

ZIIPvalue = JSON_findValue(0,queryZIIP,HWTJ_NUMBER_TYPE)
ResZIIPvalue = JSON_findValue(0,queryResZIIP,HWTJ_NUMBER_TYPE)
ZIIPCoresvalue = JSON_findValue(0,queryZIIPCores,HWTJ_NUMBER_TYPE)
ResZIIPCoresvalue = JSON_findValue(0,queryResZIIPCores,HWTJ_NUMBER_TYPE)

ICFvalue = JSON_findValue(0,queryICF,HWTJ_NUMBER_TYPE)
ResICFvalue = JSON_findValue(0,queryResICF,HWTJ_NUMBER_TYPE)
ICFCoresvalue = JSON_findValue(0,queryICFCores,HWTJ_NUMBER_TYPE)
ResICFCoresvalue = JSON_findValue(0,queryResICFCores,HWTJ_NUMBER_TYPE)

Say
Say 'Processor Usage:('||processorUsage||')'

Say 'GPP #:('||GPPvalue||')'
Say 'GPP Reserved #:('||ResGPPvalue||')'
Say 'GPP Cores #:('||GPPCoresvalue||')'
Say 'GPP Reserved Cores #:('||ResGPPCoresvalue||')'

Say 'ZIIP #:('||ZIIPvalue||')'
Say 'ZIIP Reserved #:('||ResZIIPvalue||')'
Say 'ZIIP Cores #:('||ZIIPCoresvalue||')'
Say 'ZIIP Reserved Cores #:('||ResZIIPCoresvalue||')'

Say 'ICF #:('||ICFvalue||')'
Say 'ICF Reserved #:('||ResICFvalue||')'
Say 'ICF Cores #:('||ICFCoresvalue||')'
Say 'ICF Reserved Cores #:('||ResICFCoresvalue||')'
Say

return 0

/*******************************************************/
/* Function:  GetRequest                               */
/*                                                     */
/* Default to a GET of all the cpcs if no args provided*/
/* optional args:                                      */
/*     arg1 -> uri                                     */
/*     arg2 -> targetName                              */
/*                                                     */
/* On success, returns the respones body               */
/* On failure, returns an empty string                 */
/*******************************************************/
GetRequest:
drop userRequest.
drop response.

uriArg = arg(1)
targetnameArg = arg(2)

userRequest.httpmethod = HWI_REST_GET

if uriArg <> '' Then
  userRequest.uri = uriArg
else
  userRequest.uri = '/api/cpcs'

if targetnameArg <> '' Then
  userRequest.targetname = targetnameArg
else
  userRequest.targetname = ''

Say
Say '------->'
Say 'GET request being made....'
say 'uri:'||userRequest.uri

if userRequest.targetName <> '' Then
  say 'targetname:'||userRequest.targetName

userRequest.REQUESTBODY = ''
userRequest.CLIENTCORRELATOR = ''
userRequest.ENCODING = 0
userRequest.REQUESTTIMEOUT = 0 /* use default timeout of 60 minutes */

Address BCPII "HWIREST userRequest. response."

/* GET requests return 200 when successful */
call surfaceResponse RC, response.
Say
Say '<-------'
Say

if RC = 0 & response.httpStatus = 200 Then
  return response.responseBody
else
  return ''

/********************************************************/
/* Procedure: surfaceResponse()                         */
/*            parse through the response parm and if    */
/*            the request failed showcase the issue     */
/*                                                      */
/********************************************************/
surfaceResponse:

  say
  say 'Rexx RC: ('||arg(1)||')'

  /* continue processing even if RC <> 0
     because additional information could
     have been returned in the response.
     to help understand the error
  */
  response = arg(2)

  say 'HTTP Status: ('||response.httpstatus||')'
  successIndex = INDEX(response.httpstatus, '2')

  if successIndex = 1 then
    do /* SE responded successfully */
      say 'SE DateTime: ('||response.responsedate||')'
      say 'SE requestId: (' || response.requestId || ')'

      if response.httpstatusNum = '201' Then
        say 'Location Response: (' || response.location || ')'

      if  response.responsebody <> '' Then
        do
          Say 'Response Body: (' || response.responsebody || ')'
          return response.responsebody
        end
    end /* SE responded successfully */
  else
    do /* error path */
      say 'Reason Code: ('||response.reasoncode||')'

      if response.responsedate <> '' then
        say 'SE DateTime: ('||response.responsedate||')'

      if response.requestId <> '' Then
        say 'SE requestId: (' || response.requestId || ')'

      if response.responsebody <> '' Then
        do /* an error occurred */
          call JSON_parseJson response.responsebody

          if RESULT <> 0 then
            say 'failed to parse response'
          else
            do
              bcpiiErr=JSON_findValue(0, "bcpii-error", HWTJ_BOOLEAN_TYPE)
              if bcpiiErr = 'true' then
                say '*** BCPii generated error message:'
              else
                say '*** SE generated error message:'

              errmessage=JSON_findValue(0,"message", HWTJ_STRING_TYPE)
              say '('||errmessage||')'
              say

              say 'Complete Response Body: (' || response.responsebody || ')'
            end /* bcpii err */
        end /* response body */
    end /* error path */


 return '' /* end procedure */

/*******************************************************/
/* Function:  IncludeConstants()                       */
/* Simulate include-file functionality which REXX does */
/* not provide.  Include the constants for the product */
/* and for specific testcases via (abuse of) the       */
/* interpret instruction.                              */
/*******************************************************/
IncludeConstants:

 constantsFile.0=2
 constantsFile.1="'"||MACLIB_DATASET||"(HWICIREX)'"
 constantsFile.2="'"||MACLIB_DATASET||"(HWIC2REX)'"

 i=1
 do while i <= constantsFile.0
    call InterpretRexxFile constantsFile.i
    i=i+1
    end

 return  /* end function */

/***********************************/
/* Function:  InterpretRexxFile()  */
/***********************************/
InterpretRexxFile:
 parse arg file
 numSourceLines = 0
 rc = 0

 if ISVREXX then
   do
     "ALLOC F(MYIND) DSN("||file||") SHR"
     Address MVS "EXECIO * DISKR MYIND ( FINIS STEM REXXSRC."
     "FREE F(MYIND)"
   end
 else
   do
     address TSO
     "ALLOC F(MYIND) DSN("||file||") SHR REU"
     "EXECIO * DISKR MYIND ( FINIS STEM REXXSRC."
     "FREE F(MYIND)"
   end

 if rc <> 0 then
   do
     errMsg = '** fatal error, rc=('||rc,
             ||') encountered trying to read content from (',
             ||file||'), if in ISV environment, ensure you used ',
             '-I option **'
     exit fatalErrorAndCleanup(errMsg)
   end

 /**********************************/
 /* Interpret the rexx source file */
 /* line by line, to pick up the   */
 /* constants it defines...        */
 /**********************************/
 j=1
 do while j <= REXXSRC.0
    /**********************************************/
    /* Try to recognize and ignore comment lines, */
    /* interpreting all other lines...            */
    /**********************************************/
    currLine = getInterpretableRexxLine( REXXSRC.j )
    if length( currLine ) > 0 then do
       numSourceLines = numSourceLines + 1
       interpret currLine
       end
    j=j+1
    end

 return  /* end function */

/******************************************/
/* Function:  getInterpretableRexxLine()  */
/******************************************/
getInterpretableRexxLine:
 parse arg inString

 outLine = strip(inString)
 if substr(outLine,1,2) == '/*' then
    outLine = ''
 if substr(outLine,1,1) == '!' then
    outLine = ''

 return outLine  /* end function */

/**************************************************************/
/* NOTE: the following was taken from sample hwtjxrx1.rexx    */
/**************************************************************/
/******************************************************************/
/* Procedure: traverseJsonObject                                  */
/*                                                                */
/* Traverses the designated object. Traversal is accomplished by  */
/* retrieving each object entry, and invoking traverseJsonEntry   */
/* upon it.  Note that the nature of a given entry may result in  */
/* a recursive call to this procedure.                            */
/*                                                                */
/* Returns: 0 if successful, -1 if not.                           */
/******************************************************************/
traverseJsonObject: procedure  expose (PROC_GLOBALS)
 objectHandle = arg(1)
 indentLevel = arg(2)
 /*********************************************/
 /* First, determine the number of name:value */
 /* pairs in the object.                      */
 /*********************************************/
 numEntries = JSON_getNumObjectEntries(objectHandle)
 if numEntries <= 0 then
    return fatalError( '** Unable to determine num object entries **' )
 /****************************************************************/
 /* Since the REXX iteration idiom is 1-based, we iterate from 1 */
 /* until the object is exhausted or fatal error.  However the   */
 /* Parser has a different (0-based) idiom, so we adjust the     */
 /* index value accordingly when we use it.                      */
 /****************************************************************/
 do i = 1 to numEntries
    /******************************************/
    /* Retrieve the next name:value pair into */
    /* objectEntry.  stem variable            */
    /******************************************/
    objectEntry. = ''
    call JSON_getObjectEntry objectHandle, i-1
    if RESULT <> 0 then
       return fatalError( '** Unable to obtain object entry ('||i-1||') **' )
    /*********************************************************/
    /* Print the entry name (portion of the name:value pair) */
    /*********************************************************/
    say indent(objectEntry.name,indentLevel)
    /**************************************************/
    /* Print the value portion of this entry.  This   */
    /* may or may not be a simple value, so we call   */
    /* a value traversal function to handle all cases */
    /**************************************************/
    call traverseJsonEntry objectEntry.valueHandle, 2+indentLevel
    end /* endloop thru object entries */
 return 0  /* end function */


/*****************************************************************************/
/* Function: traverseJsonEntry                                               */
/*                                                                           */
/* Perform a depth-first traversal of the designated JSON entry, to          */
/* demonstrate a common means of "auto-discovering" JSON data.               */
/*                                                                           */
/* Recursion occurs when the input handle designates an array or object type */
/* When the input handle designates a primitive type (e.g, string, number,   */
/* boolean, or null type), the value is retrieved and displayed.             */
/*                                                                           */
/* Usage: This type of "auto-discovery" is especially useful when the data   */
/* is unpredictable (not guaranteed to contain particular name:value pairs). */
/*                                                                           */
/* Returns: 0 if successful, -1 if not.                                      */
/*****************************************************************************/
traverseJsonEntry: procedure  expose (PROC_GLOBALS)
 entryHandle = arg(1)
 indentLevel = arg(2)
 /*********************************************************************/
 /* To properly traverse the entry, we first must determine its type  */
 /*********************************************************************/
 entryType = JSON_getType(entryHandle)
 select
    when entryType == HWTJ_OBJECT_TYPE then
       do
       call traverseJsonObject entryHandle, 2+indentLevel
       end  /* endif object */
    when entryType == HWTJ_ARRAY_TYPE then
       do
       call traverseJsonArray entryHandle, 2+indentLevel
       end /* endif array */
    when entryType == HWTJ_STRING_TYPE then
       do
       value = JSON_getValue(entryHandle, HWTJ_STRING_TYPE)
       say indent(value,indentLevel)
       end /* endif primitive type string */
    when entryType == HWTJ_NUMBER_TYPE then
       do
       value = JSON_getValue(entryHandle, HWTJ_NUMBER_TYPE)
       say indent(value,indentLevel)
       end /* endif primitive type number */
    when entryType == HWTJ_BOOLEAN_TYPE then
       do
       value = JSON_getValue(entryHandle, HWTJ_BOOLEAN_TYPE)
       say indent(value,indentLevel)
       end /* endif primitive type boolean */
    when entryType == HWTJ_NULL_TYPE then
       do
       value = '(null)'
       say indent(value,indentLevel)
       end /* endif primitive type null */
    otherwise
       do
       /***************************************************/
       /* If we've reached this point there is a problem. */
       /***************************************************/
       return fatalError( '** unable to retrieve JSON type **' )
       end /* endif problem */
    end /* end select */
return 0  /* end function */


/******************************************************************/
/* Procedure: traverseJsonArray                                   */
/*                                                                */
/* Traverses the designated array. Traversal is accomplished by   */
/* retrieving each entry, and invoking traverseJsonEntry upon     */
/* it.  Note that the nature of a given entry may result in a     */
/* recursive call to this procedure.                              */
/*                                                                */
/* Returns: 0 if successful, -1 if not.                           */
/******************************************************************/
traverseJsonArray: procedure  expose (PROC_GLOBALS)
 arrayHandle = arg(1)
 indentLevel = arg(2)
 numEntries = JSON_getArrayDim( arrayHandle )
 if numEntries == 0 then
    do
    say '(empty array)'
    return 0
    end /* endif empty array */
 /*******************************************************/
 /* Loop, getting each array entry, and traversing it.  */
 /* Again, we must reconcile the the REXX 1-based idiom */
 /* with that of the  toolkit.                          */
 /*******************************************************/
 do i = 1 to numEntries
    entryHandle = JSON_getArrayEntry( arrayHandle, i-1 )
    call traverseJsonEntry entryHandle, 2+indentLevel
    end /* endloop thru array entries */
 return 0  /* end function */

/***********************************************/
/* Function:  indent                           */
/*                                             */
/* Return the input string prepended with the  */
/* designated number of blanks.                */
/*                                             */
/* Returns: string as described above.         */
/***********************************************/
indent:
 source = ''
 target = arg(1)
 indentSize = arg(2)
 padChar = ' '
 return insert(source,target,0,indentSize,padChar)   /* end function */


 /***********************************************/
/* Function:  fatalError                       */
/*                                             */
/* Surfaces the input message, and returns     */
/* a canonical failure code.                   */
/*                                             */
/* Returns: -1 to indicate fatal script error. */
/***********************************************/
fatalError:
 errorMsg = arg(1)
 say errorMsg
 return -1  /* end function */


/***********************************************************/
/* Function: JSON_getValue                                 */
/*                                                         */
/* Return the value portion of the designated Json object  */
/* according to its type.  If this type indicates a        */
/* simple data value, then one of the "get value" toolkit  */
/* apis (HWTJGVAL, HWTJGBOV) is used.  If the type         */
/* an object or array, then the handle is simply echoed    */
/* back.                                                   */
/*                                                         */
/* Returns: The value of the designated entry as described */
/* above, if successful.  An empty string is returned      */
/* otherwise.                                              */
/***********************************************************/
JSON_getValue:
 entryHandle = arg(1)
 valueType = arg(2)
 /**********************************************/
 /* Get the value for a String or Number type  */
 /**********************************************/
 if valueType == HWTJ_STRING_TYPE | valueType == HWTJ_NUMBER_TYPE then
    do
    /***********************************/
    /* Call the HWTJGVAL toolkit api.  */
    /***********************************/
    ReturnCode = -1
    DiagArea. = ''
    address hwtjson "hwtjgval ",
                    "ReturnCode ",
                    "parserHandle ",
                    "entryHandle ",
                    "valueOut ",
                    "DiagArea."
    RexxRC = RC
    if JSON_isError(RexxRC,ReturnCode) then
       do
       call JSON_surfaceDiag 'hwtjgval', RexxRC, ReturnCode, DiagArea.
       say '** hwtjgval failure **'
       valueOut = ''
       end /* endif hwtjgval failed */
    return valueOut
    end  /* endif string or number type */
 /*************************************/
 /* Get the value for a Boolean type  */
 /*************************************/
 if valueType == HWTJ_BOOLEAN_TYPE then
    do
    ReturnCode = -1
    DiagArea. = ''
    /**********************************/
    /* Call the HWTJGBOV toolkit api  */
    /**********************************/
    address hwtjson "hwtjgbov ",
                    "ReturnCode ",
                    "parserHandle ",
                    "entryHandle ",
                    "valueOut ",
                    "DiagArea."
    RexxRC = RC
    if JSON_isError(RexxRC,ReturnCode) then
       do
       call JSON_surfaceDiag 'hwtjgbov', RexxRC, ReturnCode, DiagArea.
       say '** hwtjgbov failure **'
       valueOut = ''
       end /* endif hwtjgbov failed */
    return valueOut
    end  /* endif number type */
 /******************************************/
 /* Use your own discretion for NULL type  */
 /******************************************/
 if valueType == HWTJ_NULL_TYPE then
    do
    valueOut = '*null*'
    say 'Returning arbitrary '||valueOut||' for null type'
    return valueOut
    end
  /***************************************************************/
  /* To reach this point, valueType must be a non-primitive type */
  /* (i.e., either HWTJ_ARRAY_TYPE or HWTJ_OBJECT_TYPE), and we  */
  /* Simply echo back the input handle as our return value       */
  /***************************************************************/
  return entryHandle  /* end function */


/*************************************************************************/
/* Function: JSON_initParser                                             */
/*                                                                       */
/*  Create a Json parser instance via the HWTJINIT toolkit api.          */
/*  Initializes the global variable parserHandle with the handle         */
/*  returned by the api.  This handle is required by other toolkit api's */
/*  (and so this HWTJINIT api must be invoked before invoking any other  */
/*  parse-related api).                                                  */
/*                                                                       */
/* Returns: 0 if successful, -1 if not.                                  */
/*************************************************************************/
JSON_initParser:
 if VERBOSE then
    say 'Initializing Json Parser'
 /***********************************/
 /* Call the HWTJINIT toolkit api.  */
 /***********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjinit ",
                 "ReturnCode ",
                 "handleOut ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjinit', RexxRC, ReturnCode, DiagArea.
    return fatalError( '** hwtjinit failure **' )
    end  /* endif hwtjinit failure */
 /********************************/
 /* Set the all-important global */
 /********************************/
 parserHandle = handleOut
 if VERBOSE then
    say 'Json Parser init (hwtjinit) succeeded'

 PARSER_INIT = TRUE
 return 0  /* end function */


/***********************************************************************/
/* Function:  JSON_parseJson                                           */
/*                                                                     */
/*  Parse the input text body via call to the HWTJPARS toolkit api.    */
/*                                                                     */
/*  HWTJPARS builds an internal representation of the input JSON text  */
/*  which allows search, traversal, and modification operations        */
/*  against that representation.  Note that HWTJPARS does *not* make   */
/*  its own copy of the input source, and therefore the caller must    */
/*  ensure that the provided source string remains unmodified for the  */
/*  duration of the associated parser instance (i.e., if the source    */
/*  string is modified, subsequent service call behavior and results   */
/*  from the parser are unpredictable).                                */
/*                                                                     */
/* Returns:                                                            */
/*  0 if successful, -1 if not.                                        */
/***********************************************************************/
JSON_parseJson:
 jsonTextBody = arg(1)
 if VERBOSE then
    say 'Invoke Json Parser'
 /***********************************/
 /* Call the HWTJPARS toolkit api.  */
 /***********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjpars ",
                 "ReturnCode ",
                 "parserHandle ",
                 "jsonTextBody ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjpars', RexxRC, ReturnCode, DiagArea.
    return fatalError( '** hwtjpars failure **' )
    end /* endif hwtjpars failure */
 if VERBOSE then
    say 'JSON data parsed successfully'
 return 0  /* end function */


/**********************************************************/
/* Function:  JSON_termParser                             */
/*                                                        */
/* Cleans up parser resources and invalidates the parser  */
/* instance handle, via call to the HWTJTERM toolkit api. */
/* Note that as the REXX environment is single-threaded,  */
/* no consideration of any "busy" outcome from the api is */
/* done (as it would be in other language environments).  */
/*                                                        */
/* Returns: 0 if successful, -1 if not.                   */
/**********************************************************/
JSON_termParser:
 if VERBOSE then
    say 'Terminate Json Parser'
 /**********************************/
 /* Call the HWTJTERM toolkit api. */
 /**********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjterm ",
                 "ReturnCode ",
                 "parserHandle ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjterm', RexxRC, ReturnCode, DiagArea.
    return fatalError( '** hwtjterm failure **' )
    end /* endif hwtjterm failure */
 if VERBOSE then
    say 'Json Parser terminated'
 return 0  /* end function */


/****************************************************************************/
/* Function: JSON_toString                                                  */
/*                                                                          */
/* Creates a single string representation of the Json parser's current      */
/* data, via call to the HWTJSERI toolkit api.  This is typically used      */
/* after having used create services to modify or insert additional JSON    */
/* data.  If an an error occurs during serialization, an empty string is    */
/* produced.                                                                */
/*                                                                          */
/* Returns: A string as described above.                                    */
/****************************************************************************/
JSON_toString:
 if VERBOSE then
    say 'Serialize Parser data'
 /***********************************/
 /* Call the HWTJSERI toolkit api.  */
 /***********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjseri ",
                 "ReturnCode ",
                 "parserHandle ",
                 "serializedDataOut ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjseri', RexxRC, ReturnCode, DiagArea.
    say 'Unable to serialize JSON data'
    return ''
    end /* endif hwtjseri failure */
 if VERBOSE then
    say 'JSON data serialized'
 return serializedDataOut  /* end function */


/**********************************************************/
/* Function:  JSON_findValue                              */
/*                                                        */
/* Return the value associated with the input name from   */
/* the designated Json object, via the various toolkit    */
/* api's { HWTJSRCH, HWTJGVAL, HWTJGBOV }, as appropriate.*/
/*                                                        */
/* Returns: The value of the designated entry in the      */
/* designated Json object, if found and of the designated */
/* type, or suitable failure string if not.               */
/**********************************************************/
JSON_findValue:
 objectToSearch = arg(1)
 searchName = arg(2)
 expectedType = arg(3)
 /********************************************************/
 /* Search the specified object for the specified name   */
 /********************************************************/
 if VERBOSE then
    say 'Invoke Json Search for 'searchName
 /********************************************************/
 /* Invoke the HWTJSRCH toolkit api.                     */
 /* The value 0 is specified (for the "startingHandle")  */
 /* to indicate that the search should start at the      */
 /* beginning of the designated object.                  */
 /********************************************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjsrch ",
                 "ReturnCode ",
                 "parserHandle ",
                 "HWTJ_SEARCHTYPE_OBJECT ",
                 "searchName ",
                 "objectToSearch ",
                 "0 ",
                 "searchResult ",
                 "DiagArea."
 RexxRC = RC
 /************************************************************/
 /* Differentiate a not found condition from an error, and   */
 /* tolerate the former.  Note the order dependency here,    */
 /* at least as the called routines are currently written.   */
 /************************************************************/
 if JSON_isNotFound(RexxRC,ReturnCode) then
    return '(not found)'
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjsrch', RexxRC, ReturnCode, DiagArea.
    say '** hwtjsrch failure **'
    return ''
    end /* endif hwtjsrch failed */
 /******************************************************/
 /* Process the search result, according to type.  We  */
 /* should first verify the type of the search result. */
 /******************************************************/
 resultType = JSON_getType( searchResult )
 if resultType <> expectedType then
    do
      if VERBOSE then
       say '** Type mismatch ('||resultType||','||expectedType||') **'

      if resultType == HWTJ_FALSEVALUETYPE then
        return 'false' /*@GG rexx treats NULLS as false?*/
      else if resultType == HWTJ_TRUEVALUETYPE then
        return 'true'
      else if resultType == HWTJ_NULLVALUETYPE then
        return 'null'
    return ''
    end /* endif unexpected type */
 /********************************************************/
 /* If the expected type is not a simple value, then the */
 /* search result is itself a handle to a nested object  */
 /* or array, and we simply return it as such.           */
 /********************************************************/
 if expectedType == HWTJ_OBJECT_TYPE | expectedType == HWTJ_ARRAY_TYPE then
    do
    return searchResult
    end /* endif object or array type */
 /*******************************************************/
 /* Return the located string or number, as appropriate */
 /*******************************************************/
 if expectedType == HWTJ_STRING_TYPE | expectedType == HWTJ_NUMBER_TYPE then
    do
    if VERBOSE then
       say 'Invoke Json Get Value'
    /***********************************/
    /* Call the HWTJGVAL toolkit api.  */
    /***********************************/
    ReturnCode = -1
    DiagArea. = ''
    address hwtjson "hwtjgval ",
                    "ReturnCode ",
                    "parserHandle ",
                    "searchResult ",
                    "result ",
                    "DiagArea."
    RexxRC = RC
    if JSON_isError(RexxRC,ReturnCode) then
       do
       call JSON_surfaceDiag 'hwtjgval', RexxRC, ReturnCode, DiagArea.
       say '** hwtjgval failure **'
       return ''
       end /* endif hwtjgval failed */
    return result
    end /* endif string or number type */
 /****************************************************/
 /* Return the located boolean value, as appropriate */
 /****************************************************/
  if expectedType == HWTJ_BOOLEAN_TYPE then
    do
    if VERBOSE then
        say 'Invoke Json Get Boolean Value'
    /***********************************/
    /* Call the HWTJGBOV toolkit api.  */
    /***********************************/
    ReturnCode = -1
    DiagArea. = ''
    address hwtjson "hwtjgbov ",
                    "ReturnCode ",
                    "parserHandle ",
                    "searchResult ",
                    "result ",
                    "DiagArea."
     RexxRC = RC
     if JSON_isError(RexxRC,ReturnCode) then
       do
       call JSON_surfaceDiag 'hwtjgbov', RexxRC, ReturnCode, DiagArea.
       say '** hwtjgbov failure **'
       return ''
       end /* endif hwtjgbov failed */
    return result
    end /* endif boolean type */
 /**********************************************/
 /* This return should not occur, in practice. */
 /* Note that we did not account for expected  */
 /* type == HWTJ_NULL_TYPE above, and could do */
 /* so here if that were meaningful (but more  */
 /* efficiently we might do that earlier in    */
 /* the routine to avoid wasteful processing). */
 /**********************************************/
 if VERBOSE then
    say '** No return value found **'
 return ''  /* end function */


/***********************************************************/
/* Function:  JSON_getType                                 */
/*                                                         */
/* Determine the Json type of the designated search result */
/* via the HWTJGJST toolkit api.                           */
/*                                                         */
/* Returns: Non-negative integral number indicating type   */
/* if successful, -1 if not.                               */
/***********************************************************/
JSON_getType:
 searchResult = arg(1)
 if VERBOSE then
    say 'Invoke Json Get Type'
 /***********************************/
 /* Call the HWTJGJST toolkit api.  */
 /***********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjgjst ",
                 "ReturnCode ",
                 "parserHandle ",
                 "searchResult ",
                 "resultTypeName ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjgjst', RexxRC, ReturnCode, DiagArea.
    return fatalError( '** hwtjgjst failure **' )
    end /* endif hwtjgjst failure */
 else
    do
    /*******************************************************/
    /* Convert the returned type name into its equivalent  */
    /* constant, and return that more convenient value.    */
    /* Note that the interpret instruction might more      */
    /* typically be used here, but the goal here is to     */
    /* familiarize the reader with these types.            */
    /*******************************************************/
    type = strip(resultTypeName)
    if type == 'HWTJ_STRING_TYPE' then
       return HWTJ_STRING_TYPE
    if type == 'HWTJ_NUMBER_TYPE' then
       return HWTJ_NUMBER_TYPE
    if type == 'HWTJ_BOOLEAN_TYPE' then
       return HWTJ_BOOLEAN_TYPE
    if type == 'HWTJ_ARRAY_TYPE' then
       return HWTJ_ARRAY_TYPE
    if type == 'HWTJ_OBJECT_TYPE' then
       return HWTJ_OBJECT_TYPE
    if type == 'HWTJ_NULL_TYPE' then
       return HWTJ_NULL_TYPE
    end /* endif hwtjgjst ok */
 /**********************************************/
 /* This return should not occur, in practice. */
 /**********************************************/
 return fatalError( 'Unsupported Type ('||type||') from hwtjgjst' )


/**************************************************/
/* Function:  JSON_getArrayDim                    */
/*                                                */
/* Return the number of entries in the array      */
/* designated by the input handle, obtained       */
/* via the HWTJGNUE toolkit api.                  */
/*                                                */
/* Returns: Non-negative integral number of array */
/* entries if successful, -1 if not.              */
/**************************************************/
JSON_getArrayDim:
 arrayHandle = arg(1)
 if VERBOSE then
    say 'Getting array dimension'
 /***********************************/
 /* Call the HWTJGNUE toolkit api.  */
 /***********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjgnue ",
                 "ReturnCode ",
                 "parserHandle ",
                 "arrayHandle ",
                 "dimOut ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjgnue', RexxRC, ReturnCode, DiagArea.
    return fatalError( '** hwtjgnue failure **' )
    end /* endif hwtjgnue failure */
 arrayDim = strip(dimOut,'L',0)
 if arrayDim == '' then
    return 0
 return arrayDim  /* end function */


/*************************************************/
/* Function:  JSON_getArrayEntry                */
/*                                              */
/* Return a handle to the designated entry of   */
/* the array designated by the input handle,    */
/* obtained via the HWTJGAEN toolkit api.       */
/*                                              */
/* Returns: Output handle from toolkit api if   */
/* successful, empty result if not.             */
/************************************************/
JSON_getArrayEntry:
 arrayHandle = arg(1)
 whichEntry = arg(2)
 result = ''
 if VERBOSE then
    say 'Getting array entry'
 /***********************************/
 /* Call the HWTJGAEN toolkit api.  */
 /***********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjgaen ",
                 "ReturnCode ",
                 "parserHandle ",
                 "arrayHandle ",
                 "whichEntry ",
                 "handleOut ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjgaen', RexxRC, ReturnCode, DiagArea.
    say '** hwtjgaen failure **'
    end /* endif hwtjgaen failure */
 else
    result = handleOut
 return result  /* end function */


/*******************************************************/
/* Function:  JSON_getToolkitConstants                 */
/*                                                     */
/* Access constants used by the toolkit (for return    */
/* codes, etc), via the HWTCONST toolkit api.          */
/*                                                     */
/* Returns: 0 if toolkit constants accessed, -1 if not */
/*******************************************************/
JSON_getToolkitConstants:
 if VERBOSE then
    say 'Setting hwtcalls on'
 /***********************************************/
 /* Ensure that the toolkit host command is     */
 /* available in your REXX environment (no harm */
 /* done if already present).  Do this before   */
 /* your first toolkit api invocation.          */
 /***********************************************/
 call hwtcalls "on"
 if VERBOSE then
    say 'Including HWT Constants...'
 /************************************************/
 /* Call the HWTCONST toolkit api.  This should  */
 /* make all toolkit-related constants available */
 /* to procedures via (expose of) HWT_CONSTANTS  */
 /************************************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtconst ",
                 "ReturnCode ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
     do
     call JSON_surfaceDiag 'hwtconst', RexxRC, ReturnCode, DiagArea.
     return fatalError( '** hwtconst (json) failure **' )
     end /* endif hwtconst error */
 return 0  /* end subroutine */


/*********************************************************/
/* Function: JSON_getObjectEntry                         */
/*                                                       */
/* Access the designated entry of the designated Json    */
/* object, via the HWTJGOEN toolkit api. Populate the    */
/* caller's objectEntry. stem variable with the name     */
/* portion of the entry, and the valueHandleOut returned */
/* by the api (the value designated by this handle may   */
/* be any of several types, and the caller has prior     */
/* knowledge of, or will discover, its type so that it   */
/* can make appropriate use of it).                      */
/*                                                       */
/* Returns: 0 to indicate that the objectEntry. stem     */
/* variable was successfully populated, -1 otherwise.    */
/*********************************************************/
JSON_getObjectEntry:
 objectHandle = arg(1)
 whichEntry = arg(2)
 if VERBOSE then
    say 'Get object entry ('||whichEntry||')'
 /*************************************/
 /* Invoke the HWTJGOEN api to access */
 /* the designated entry              */
 /*************************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjgoen ",
                 "ReturnCode ",
                 "parserHandle ",
                 "objectHandle ",
                 "whichEntry ",
                 "nameOut ",
                 "valueHandleOut ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    say 'Unable to get object entry('||whichEntry||')'
    call JSON_surfaceDiag 'hwtjgoen', RexxRC, ReturnCode, DiagArea.
    return fatalError( '** hwtjgoen failure **' )
    end /* endif hwtjgoen failure */
 objectEntry.name = nameOut
 objectEntry.valueHandle = valueHandleOut
 return 0  /* end function */


/********************************************************/
/* Function: JSON_getNumObjectEntries                   */
/*                                                      */
/* Get the number of entries for the Json object which  */
/* is designated by the input handle, via the HWTJGNUE  */
/* toolkit api.                                         */
/*                                                      */
/* Returns: Non-negative integral number of object      */
/* entries if successful, -1 if not.                    */
/********************************************************/
JSON_getNumObjectEntries:
 objectHandle = arg(1)
 if VERBOSE then
    say 'Determining number of object entries'
 /**********************************/
 /* Call the HWTJGNUE toolkit api. */
 /**********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjgnue ",
                 "ReturnCode ",
                 "parserHandle ",
                 "objectHandle ",
                 "numEntriesOut ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    say 'Unable to determine number of object entries'
    call JSON_surfaceDiag 'hwtjgnue', RexxRC, ReturnCode, DiagArea.
    return fatalError( '** hwtjgnue failure **' )
    end /* endif hwtjgnue failure */
 if VERBOSE then
    say numEntriesOut' entries were found'
 return numEntriesOut  /* end function */


/*************************************************************/
/* Function:  JSON_isNotFound                                */
/*                                                           */
/* Check the input processing codes. Note that if the input  */
/* RexxRC is nonzero, then the toolkit return code is moot   */
/* (the toolkit function was likely not even invoked). If    */
/* the toolkit return code is relevant, check it against the */
/* specific return code for a "not found" condition.         */
/*                                                           */
/* Returns:  1 if HWTJ_JSRCH_SRCHSTR_NOT_FOUND condition, 0  */
/* otherwise.                                                */
/*************************************************************/
JSON_isNotFound:
 RexxRC = arg(1)
 if RexxRC <> 0 then
    return 0
 ToolkitRC = strip(arg(2),'L',0)
 if ToolkitRC == HWTJ_JSRCH_SRCHSTR_NOT_FOUND then
    return 1
 return 0  /* end function */


/*************************************************************/
/* Function:  JSON_isError                                   */
/*                                                           */
/* Check the input processing codes. Note that if the input  */
/* RexxRC is nonzero, then the toolkit return code is moot   */
/* (the toolkit function was likely not even invoked). If    */
/* the toolkit return code is relevant, check it against the */
/* set of { HWTJ_xx } return codes for evidence of error.    */
/* This set is ordered: HWTJ_OK < HWTJ_WARNING < ...         */
/* with remaining codes indicating error, so we may check    */
/* via single inequality.                                    */
/*                                                           */
/* Returns:  1 if any toolkit error is indicated, 0          */
/* otherwise.                                                */
/*************************************************************/
JSON_isError:
 RexxRC = arg(1)
 if RexxRC <> 0 then
    return 1
 ToolkitRC = strip(arg(2),'L',0)
 if ToolkitRC == '' then
       return 0
 if ToolkitRC <= HWTJ_WARNING then
       return 0
 return 1  /* end function */


/***********************************************/
/* Procedure: JSON_surfaceDiag                 */
/*                                             */
/* Surface input error information.  Note that */
/* when the RexxRC is nonzero, the ToolkitRC   */
/* and DiagArea content are moot and are       */
/* suppressed (so as to not mislead).          */
/*                                             */
/***********************************************/
JSON_surfaceDiag: procedure expose DiagArea.
  who = arg(1)
  RexxRC = arg(2)
  ToolkitRC = arg(3)
  say
  say '*ERROR* ('||who||') at time: '||Time()
  say 'Rexx RC: '||RexxRC||', Toolkit ReturnCode: '||ToolkitRC
  if RexxRC == 0 then
     do
     say 'DiagArea.ReasonCode: '||DiagArea.HWTJ_ReasonCode
     say 'DiagArea.ReasonDesc: '||DiagArea.HWTJ_ReasonDesc
     end
  say
 return  /* end procedure */

/***********************************************/
/* Function:  GetArgs                          */
/*                                             */
/* Parse script arguments and make appropriate */
/* variable assignments, or return fatal error */
/* code via usage() invocation.                */
/*                                             */
/* Returns: 0 if successful, -1 if not.        */
/***********************************************/
GetArgs:
 S = arg(1)
 argCount = words(S)
 if argCount == 0 | argCount < 2 | argCount > 4 then
    return usage( 'Wrong number of arguments' )

 do i = 1 to argCount
   localArg = word(S,i)
   if (i == 1) then
     do
       CPCname = localArg
       if CPCname <> 'LOCAL_CPC' then
         localCPC = FALSE
     end
   else if (i == 2) then
     do
       LPARname = localArg
       if LPARname <> 'LOCAL_LPAR' then
         localLPAR = FALSE
     end
   else
     do
       if TRANSLATE(localArg) == '-V' then
         VERBOSE = 1
       else if TRANSLATE(localArg) == '-I' then
         ISVREXX = TRUE
       else
         do
           argErr = 'unrecognized argument ('||localArg||')'
           return usage(argErr)
         end
     end
 end /* argCount loop */
return 0  /* end function */

/***********************************************/
/* Function: usage                             */
/*                                             */
/* Provide usage guidance to the invoker.      */
/*                                             */
/* Returns: -1 to indicate fatal script error. */
/***********************************************/
usage:
 whyString = arg(1)
 say
 say 'usage:'
 say 'ex RXQUERY1 CPCName LPARName [-I] [-v]'
 say '    REQUIRED:'
 say '       CPCName/arg1 is the name of the CPC,'
 say '              specify `LOCAL_CPC` to default to the LOCAL CPC'
 say '       LPARName/arg2 is the name of the LPAR,'
 say '              specify `LOCAL_LPAR` to default to the LOCAL LPAR'
 say '    OPTIONAL'
 say '         -v turn on addition verbose JSON tracing'
 say '         -I indicate running in an isv rexx, default if not'
 say '               specified is TSO/E REXX'
 say
 say '('||whyString||')'
 say
 return -1  /* end function */