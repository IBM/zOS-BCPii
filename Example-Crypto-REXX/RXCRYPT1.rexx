/* REXX */
/* START OF SPECIFICATIONS *********************************************/
/* Beginning of Copyright and License                                  */
/*                                                                     */
/* Copyright 2022 IBM Corp.                                            */
/*                                                                     */
/* Licensed under the Apache License, Version 2.0 (the "License");     */
/* you may not use this file except in compliance with the License.    */
/* You may obtain a copy of the License at                             */
/*                                                                     */
/* http://www.apache.org/licenses/LICENSE-2.0                          */
/*                                                                     */
/* Unless required by applicable law or agreed to in writing,          */
/* "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,        */
/* either express or implied.  See the License for the specific        */
/* language governing permissions and limitations under the License.   */
/*                                                                     */
/* End of Copyright and License                                        */
/***********************************************************************/
/*                                                                     */
/*  SCRIPT NAME=RXCRYPT1                                               */
/*                                                                     */
/*  DESCRIPTIVE NAME:                                                  */
/*    Sample REXX code that uses HWIREST API to query Image            */
/*    Activation Profile information.                                  */
/*    It also takes advantage of the JSON Parser to retrieve           */
/*    various pieces of the information.                               */
/*                                                                     */
/* OPERATION:                                                          */
/*                                                                     */
/*  CODE FLOW in this sample:                                          */
/*    Call Get CPC info to retrieve uri and target name for the        */
/*         specific CPC                                                */
/*    Call List Logical Partitions of CPC to retrieve uri and          */
/*         target name and status info for LPARs                       */
/*    Call Query Crypto to retrieve a set of specific Image            */
/*         Activation Profile attributes for LPARs in the              */
/*         specified status (default = operating)                      */
/*         Sample assumes the image activation profile name is         */
/*         the same as the LPAR name                                   */
/*    Write collected content out to the provided partitioned data set */
/*                                                                     */
/* INVOCATION:                                                         */
/*     RXCRYPT1 -D outputDataSet [-C CPCname] [-S Status] [-I] [-V]    */
/*                                                                     */
/*     Required input parameters:                                      */
/*        -D <data set name> is the name of a pre-existing partitioned */
/*           data set. If the query is successful, a member containing */
/*           the query information in CSV format will be stored into   */
/*           the data set, the member will either be named LOCAL or    */
/*           the CPC name provided via -C option                       */
/*     Optional input parameters:                                      */
/*        -C <CPCname> is the name of the CPC which hosts the LPARs    */
/*           whose corresponding image activation profile info will    */  
/*           be retrieved                                              */  
/*           default is LOCAL                                          */ 
/*        -S <Status> represents the status of the LPAR and is an      */
/*           optional filter for the list of LPARs                     */
/*           The names associated with these LPARs are used as input   */
/*           for which image activation profiles need to be queried.   */
/*           Valid values:                                             */
/*           operating - query profiles for activation image profiles  */
/*                       associated with active/operating LPARs        */
/*           not-operating - query profiles for activation image       */
/*                       profiles associated with active/not operating */
/*                       LPARS                                         */
/*           not-activated - query profiles for activation image       */
/*                       profiles associated with not activated LPARs  */
/*           Any other value, or no parm specified will default to     */
/*           operating                                                 */
/*        -I indicate running out of ISV REXX environment,             */
/*           default is TSO/E                                          */
/*        -V turn on additional verbose JSON tracing                   */
/*                                                                     */
/*        EX 'HWI.HWIREST.REXX(RXCRYPT1))'                             */
/*            '-D HWI.CRYPTO -I'                                       */
/*            data set is HWI.CRYPTO, run out of ISV REXX,             */
/*            if successful will create HWI.CRYPTO(LOCAL)              */
/*                                                                     */
/*        EX 'HWI.HWIREST.REXX(RXCRYPT1))'                             */
/*            '-D HWI.CRYPTO -S not-activated'                         */
/*            data set is HWI.CRYPTO, run from TSO REXX,               */
/*            will query crypto information associated with LPARs      */
/*            in operating status on the LOCAL CPC                     */
/*            if successful will create HWI.CRYPTO(LOCAL)              */
/*                                                                     */
/* DEPENDENCIES:                                                       */
/*     z16 - The crypto properties are supported on z16 processors     */
/*           and above.                                                */
/*                                                                     */
/* NOTES:                                                              */
/*     No recovery logic has been supplied in this sample.             */
/*                                                                     */
/* REFERENCE:                                                          */
/*     See the z/OS MVS Programming: Callable Services for             */
/*     High-Level Languages publication for more information           */
/*     regarding the usage of HWIREST and JSON Parser APIs.            */
/*                                                                     */
/*                                                                     */
/* END OF SPECIFICATIONS  * * * * * * * * * * * * * * * * * * * * * * **/

MACLIB_DATASET = 'SYS1.MACLIB'

TEMP_DATASET = '' /* required input via -D */

TRUE = 1
FALSE = 0

hwiHostRC = 0     /* HWIHOST rc */
HWIHOST_ON = FALSE
PARSER_INIT = FALSE
ISVREXX = FALSE  /* default to TSO/E, enable via -I */
VERBOSE = FALSE  /* JSON parser specific, enabled via -V */
localCPC = TRUE  /* default to lpars on the LOCAL CPC, change via -C */

MemberName = 'LOCAL' /* default CPC */

/* Properties constants */
CRYPTOAUTH = 'crypto-activity-cpu-counter-authorization-control'
ASSIGNED_DOMAINS_PROP = 'assigned-crypto-domains'
ASSIGNED_CRYPTOS_PROP = 'assigned-cryptos'

/*********************************/
/* Get program args              */
/*********************************/
parse arg argString
if GetArgs(argString) <> 0 then
  exit -1

/********************************************************/
/* Ensure the output dataset specified actually exists  */
/********************************************************/
if VerifyDataSet(TEMP_DATASET) <> 0 then
  do
    errMsg = '** specified data set ('||TEMP_DATASET||') does not exist **'
    exit fatalErrorAndCleanup(errMsg)
  end

/**********************************************/
/* Ensure the requested LPAR status is valid  */
/**********************************************/
Call VerifyStatus(ReqstdLPAR_Status) 

if localCPC then
  say 'Obtaining LPARs on LOCAL CPC'
else
  say 'Obtaining LPARs on CPC:'||CPCname

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
    if getLocalCPCInfo() <> 0 then
      exit fatalErrorAndCleanup( '** failed to get LOCAL CPC info **' )
  end
else
  do
    if getCPCInfo() <> 0 then
      do
        errMsg = '** failed to get CPC info for ('||CPCname||') **'
        exit fatalErrorAndCleanup(errMsg)
      end
    MemberName = CPCname
  end

if getLPARList() <> 0 then
  exit fatalErrorAndCleanup( '** failed to obtain list of LPARs **' )

/***************************************************************
  The CPC has at least one LPAR so prime the list of attributes
  that need to be retrieved for each LPAR
***************************************************************/
call PrepCryptoAttrs
call PrepHdrRow
outLC = 1 /* HdrRow */

do iLpar = 1 to LPARsList.0
  LPARuri = LPARsList.iLpar.uri
  LPARtargetName = LPARsList.iLpar.targetName
  LPARName = LPARsList.iLpar.Name
  LPARstatus = LPARsList.iLpar.status

  /********************************************************
   Only retrieve content for LPARs in the specified status
   NOTE: Default is to retrive content for operating LPARs
  *********************************************************/
  if TRANSLATE(LPARstatus) <> TRANSLATE(ReqstdLPAR_Status) then
    do
      say '========================================================='
      say 'skipping over ('||LPARname||') because the status is (',
          ||LPARstatus||')'
      say ' '
    end
  else
    do
      if QueryCrypto() <> 0 then
        do
          errMsg = '** fatal error encountered for LPAR ('||LPARName||')'
          exit fatalErrorAndCleanup(errMsg)
        end
    end

end /* query each LPAR */

/* the final count for the lines to write out*/
REXXWRT.0 = outLC

tempFile ="'"||TEMP_DATASET||"("||MemberName||")'"

if WriteToFile(tempFile) <> 0 then
  do
    errMsg = '** failed to write out content to ('||tempFile||') **'
    exit fatalErrorAndCleanup(errMsg)
  end
else
  do
    say 'Results successfully written to ('||tempFile||')'
  end

call Cleanup

return 0 /* end main */

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
/* Retrieve the uri and target name and SE version     */
/* associated with the LOCAL CPC                       */
/* Prime CPCuri and CPCtargetName variables            */
/* Verify SE version is z16 or higher                  */
/*                                                     */
/* Return 0 on success, -1 on error                    */
/*******************************************************/
GetLocalCPCInfo:

emptyCPCResponse = '{"cpcs":[]}'
localCPCfound = FALSE

/* First list the cpcs, then retrieve LOCAL
   CPC which will have
           "location":"local"

   GET /api/cpcs

   v1: HWILIST(HWI_LIST_LOCAL_CPC)
*/
reqUri = '/api/cpcs'
CPCInfoResponse = GetRequest(reqUri)

emptyCPCArray = INDEX(CPCInfoResponse, emptyCPCResponse)
if emptyCPCArray > 0 | CPCInfoResponse = '' Then
  do
    return fatalError('** failed to get CPC info **')
  end

/* Parse the response to obtain the uri
   and target name associated with CPC
*/
call JSON_parseJson CPCInfoResponse
CPCArray = JSON_findValue(0, "cpcs", HWTJ_ARRAY_TYPE)
if foundJSONValue(CPCArray) = FALSE then
  do
    return fatalError('** failed to retrieve CPCs **')
  end

 /**************************************************************/
 /* Determine the number of CPCs represented in the array      */
 /**************************************************************/
 CPCs = JSON_getArrayDim(CPCArray)
 if CPCs <= 0 then
    return fatalError( '** Unable to retrieve number of CPCs **' )

 /********************************************************************/
 /* Traverse the CPCs array to populate CPCsList.                    */
 /* We use the REXX (1-based) idiom  but adjust for the differing    */
 /* (0-based) idiom of the toolkit.                                  */
 /********************************************************************/
 say 'Processing information for '||CPCs||' CPC(s)... searching for LOCAL'
 do i = 1 to CPCs
    nextEntryHandle = JSON_getArrayEntry(CPCArray,i-1)
    CPClocation = JSON_findValue(nextEntryHandle,"location",HWTJ_STRING_TYPE)

    if CPClocation = 'local' then
      do
        say 'found LOCAL CPC'
        if localCPCfound = TRUE then
          do
            return fatalError('** found two LOCAL CPCs **')
          end
        localCPCfound = TRUE

      CPCversion=JSON_findValue(nextEntryHandle,"se-version",HWTJ_STRING_TYPE)
        if foundJSONValue(CPCversion) = FALSE then
          do
            return fatalError,
            ('ERROR: found LOCAL CPC but it did not contain an se-version')
          end

        CPCuri=JSON_findValue(nextEntryHandle,"object-uri",HWTJ_STRING_TYPE)
        if foundJSONValue(CPCuri) = FALSE then
          do
            return fatalError,
            ('ERROR: found LOCAL CPC but it did not contain an object-uri')
          end

        CPCtargetName=JSON_findValue(nextEntryHandle,"target-name",,
                                    HWTJ_STRING_TYPE)
        if foundJSONValue(CPCtargetName) = FALSE then
          do
            return fatalError,
            ('ERROR: found LOCAL CPC but it did not contain target-name')
          end

        CPCname=JSON_findValue(nextEntryHandle,"name",HWTJ_STRING_TYPE)
        if foundJSONValue(CPCname) = FALSE then
          do
            return fatalError,
            ('ERROR: found LOCAL CPC but it did not contain a name property')
          end
      end
 end /* endloop thru the JSON LPARs array */

if localCPCfound then
  do
    Say
    Say 'Successfully obtained LOCAL CPC Info:'
    Say '  name:'||CPCname
    Say '  uri:'||CPCuri
    Say '  target-name:'||CPCtargetName
    Say '  SE version: '||CPCversion
    Say                                                                 
    if substr(CPCversion,3,2) < 16 then                                 
      do                                                                
        errMsg = '** Crypto attributes supported on z16 or higher only **'
        return fatalError(errMsg)                                        
      end                                                               
      else                                                              
        return 0
  end


/* if  still here then something went wrong */
return fatalError('ERROR ** failed to obtain LOCAL CPC info **')

/*******************************************************/
/* Function:  GetCPCInfo                               */
/*                                                     */
/* Retrieve the uri, target name and SE version        */
/* associated with CPCname                             */
/* Prime CPCuri and CPCtargetName variables            */
/* Verify SE version is z16 or higher                  */
/*                                                     */
/* Return 0 if successful, otherwise return -1         */
/*******************************************************/
GetCPCInfo:

methodSuccess = TRUE /* assume success */
emptyCPCResponse = '{"cpcs":[]}'

/* First list the cpcs, filtering the response for
   just information regarding CPC

   GET /api/cpcs?name=CPCname

   v1: HWICONN(HWI_CPC,IBM390PS.CPC)

   NOTE:
   If you wanted to obtain information for the 'LOCAL'
   CPC, then you'd retrieve the full list and search for
   the CPC with the
         "location":"LOCAL"
   attribute, this would be equivalent to HWICONN(HWI_CPC,*)
*/
reqUri = '/api/cpcs?name='||CPCname
CPCInfoResponse = GetRequest(reqUri)

emptyCPCArray = INDEX(CPCInfoResponse, emptyCPCResponse)
if emptyCPCArray > 0 | CPCInfoResponse = '' Then
  do
    return fatalError('** failed to retrieve CPC **')
  end

/* Parse the response to obtain the uri, target name
   and SE version associated with the CPC 
*/
call JSON_parseJson CPCInfoResponse

CPCversion = JSON_findValue(0,"se-version", HWTJ_STRING_TYPE) 
if foundJSONValue(CPCversion) = FALSE then                    
  methodSuccess = FALSE                                       

CPCuri = JSON_findValue(0,"object-uri", HWTJ_STRING_TYPE)
if foundJSONValue(CPCuri) = FALSE then
  methodSuccess = FALSE

CPCtargetName = JSON_findValue(0,"target-name", HWTJ_STRING_TYPE)
if foundJSONValue(CPCtargetName) = FALSE then
  methodSuccess = FALSE

if methodSuccess then
  do
    Say
    Say 'Successfully obtained CPC Info:'
    Say '  uri:'||CPCuri
    Say '  target-name:'||CPCtargetName
    Say '  SE version: '||CPCversion
    Say
    if substr(CPCversion,3,2) < 16 then                                 
      do                                                                 
       errMsg = '** Crypto attributes supported on z16 or higher only **'
       return fatalError(errMsg)                                
      end                                                                
      else                                                                
       return 0                                                         
  end

Say
Say 'Obtained some or none of the CPC Info:'
Say '  uri:('||CPCuri||')'
Say '  target-name:('||CPCtargetName||')'
Say 'full response body:('||CPCInfoResponse||')'
Say
return fatalError(' ** failed to obtain CPC info **')

/*******************************************************/
/* Function:  getLPARList                              */
/*                                                     */
/* Retrieve the uri and target name associated with    */
/* all the LPARs that exist on the CPC and prime       */
/* LPARsList. with the uri and targets info.           */
/*                                                     */
/* Return 0 if successful, otherwise return -1         */
/*******************************************************/
getLPARList:

emptyLPARResponse = '{"logical-partitions":[]}'

/* List all the LPARS on CPC:
   /api/cpcs/{cpc-id}/logical-partitions
*/
LPARlisturi = CPCuri||'/logical-partitions'
LPARsInfoResponse = GetRequest(LPARlisturi,CPCtargetName)

emptyLPARArray = INDEX(LPARInfoResponse, emptyLPARResponse)
if emptyLPARArray > 0 | LPARInfoResponse = '' Then
  do
    return fatalError('** failed to get LPARs **')
  end

call JSON_parseJson LPARsInfoResponse
LPARArray = JSON_findValue( 0, "logical-partitions", HWTJ_ARRAY_TYPE )
if foundJSONValue(LPARArray) = FALSE then
    return fatalError( '** Unable to locate logical-partitions array **' )

 /**************************************************************/
 /* Determine the number of LPARs represented in the array     */
 /*                                                            */
 /* NOTE: if you area confident the CPC has LPARs but an empty */
 /* list is returned, or an LPAR you expect to be in the list  */
 /* is not there, ensure you have the appropriate access level */
 /* to the FACILITY Class profile for the the expected LPAR(s) */
 /* in addition to verifying firmware security configurations. */
 /**************************************************************/
 LPARs = JSON_getArrayDim( LPARArray )
 if LPARs = -1 then
    return fatalError( '** Unable to retrieve number of array entries **' )
 else if LPARs = 0 then
    return fatalError( '** empty list of LPARs returned **' )

 /********************************************************************/
 /* Traverse the LPARs array to populate LPARsList.                  */
 /* We use the REXX (1-based) idiom  but adjust for the differing    */
 /* (0-based) idiom of the toolkit.                                  */
 /********************************************************************/
 say 'Processing information for '||LPARs||' LPAR(s) returned from LIST LPARs'
 drop LPARsList.
 LPARsList.0 = LPARs
 do i = 1 to LPARs
    nextEntryHandle = JSON_getArrayEntry(LPARArray,i-1)
    LPARsList.i.uri=JSON_findValue(nextEntryHandle,"object-uri",,
                     HWTJ_STRING_TYPE)
    if foundJSONValue(LPARsList.i.uri) = FALSE then
      do
        errMsg = 'Failed to obtain uri for LPAR entry ('||i||')'
        return fatalError(errMsg)
      end

    LPARsList.i.targetName=JSON_findValue(nextEntryHandle,"target-name",,
                     HWTJ_STRING_TYPE)
    if foundJSONValue(LPARsList.i.targetName) = FALSE then
      do
        errMsg = 'Failed to obtain target name for LPAR entry ('||i||')'
        return fatalError(errMsg)
      end

    LPARsList.i.name=JSON_findValue(nextEntryHandle,"name",HWTJ_STRING_TYPE)
    if foundJSONValue(LPARsList.i.name) = FALSE then
      do
        errMsg = 'Failed to obtain name for LPAR entry ('||i||')'
        return fatalError(errMsg)
      end

    LPARsList.i.status = JSON_findValue(nextEntryHandle,"status",,
                     HWTJ_STRING_TYPE)
    if foundJSONValue(LPARsList.i.status) = FALSE then
      do
        errMsg = 'Failed to obtain status for LPAR entry ('||i||')'
        return fatalError(errMsg)
      end
 end /* endloop thru the JSON LPARs array */

return 0

/*******************************************************/
/* Function:  QueryCrypto                              */
/*                                                     */
/* Retrieve attributes identified by                   */
/* CryptoAttr stem variable                            */
/*                                                     */
/* Return 0 if successful, otherwise return -1         */
/*******************************************************/
QueryCrypto:
/* Now use the retrieved CPC uri and LPAR name
   to retrieve crypto information for the LPAR
   We're assuming the image activation profile name 
   matches the LPAR name

   GET <CPC uri>/image-activation-profiles/<profile name>?properties
*/

If CryptoAttr.0 < 1 then
  do
    return fatalError('** no LPAR attributes to query **')
  end

CryptoQueryUri = CPCuri||'/image-activation-profiles/'
CryptoQueryUri = CryptoQueryUri||LPARname
CryptoQueryUri = CryptoQueryUri||'?properties='
 do i = 1 to CryptoAttr.0
   CryptoQueryUri = CryptoQueryUri||CryptoAttr.i

   /* more properties still to add so need a ',' */
   if i < CryptoAttr.0 then
     CryptoQueryUri = CryptoQueryUri||','
 end
 CryptoQueryUri = CryptoQueryUri||'&cached-acceptable=true'

say '========================================================='
say 'Starting to process content for LPAR '||LPARName

CryptoQueryResponse = GetRequest(CryptoQueryUri, CPCtargetName)

if CryptoQueryResponse = '' Then
  do
    return fatalError('** Failed to retrieve Crypto info **')
  end

/* Parse the response to obtain the values of the properties queried */

outLC = outLC + 1
REXXWRT.outLC = ','||LPARName||','||LPARstatus

call JSON_parseJson CryptoQueryResponse

do i = 1 to CryptoAttr.0
    if CryptoAttr.i = CRYPTOAUTH then
      do /* simple property */
        CryptoAttrResponse = JSON_findValue2(0, CryptoAttr.i)
        say CryptoAttr.i||':('||CryptoAttrResponse||')'
        outLC = outLC + 1
        REXXWRT.outLC = ',,,'||CRYPTOAUTH||','||CryptoAttrResponse
      end /* simple property */
    else /* complex property with nested content */
      do
        ArrayResponse = JSON_findValue(0,CryptoAttr.i,HWTJ_ARRAY_TYPE)
        if CryptoAttr.i = ASSIGNED_DOMAINS_PROP then
          do
            if getassignedDomains(ArrayResponse) <> 0 then
              return fatalError('failed to parse assigned domains')
          end
        else if CryptoAttr.i = ASSIGNED_CRYPTOS_PROP then
          do
            if getassignedCryptos(ArrayResponse) <> 0 then
              return fatalError('failed to parse assigned cryptos')
          end
        else
          return fatalError('Requested attribute not recognized')
      end /* complex property with nested content */

end /* i, attribute count */
say '  '
say 'Finished processing content for LPAR '||LPARName
say '  '
return 0

/*******************************************************/
/* Function: getAssignedCryptos                        */
/*                                                     */
/* Retrieve content returned from the assigned cryptos */
/* value, which is an array of zero or more objects.   */
/* Store the specific content into REXXWRT stem        */
/*                                                     */
/* Return 0 if successful, otherwise return -1         */
/*******************************************************/
getAssignedCryptos:
 ArrayResponse = arg(1)

 keyType = 'assigned-cryptos'

 /* First assess if this property was even found in the response */
 if foundJSONValue(ArrayResponse) = FALSE then
   do
     say '** Unable to locate '||keyType||' in the response **'
     return 0
   end

 /****************************************************************/
 /* Determine the number of items in the array                   */
 /****************************************************************/
 Cryptos = JSON_getArrayDim(ArrayResponse)
 if Cryptos = -1 then
    return fatalError( '** Unable to retrieve cryptos **' )
 else if Cryptos = 0 then
    say '** Empty list of cryptos returned **'

 /****************************************************************/
 /* Traverse the array to populate Cryptos list                  */
 /****************************************************************/
 If Cryptos > 0 then do
   say 'Processing information for '||Cryptos||' cryptos'
   say 'Number , Activation Type '
   outLC = outLC + 1
   REXXWRT.outLC = ',,,'||keyType||' (Number & Activation Type Array)'
   outLC = outLC + 1
 drop CryList.
 CryList.0 = Cryptos
 do j = 1 to Cryptos
    nextEntryHandle = JSON_getArrayEntry(ArrayResponse,j-1)
    CryList.j.num=JSON_findValue2(nextEntryHandle,"number")
    CryList.j.type=JSON_findValue(nextEntryHandle,"activation-type",,
                        HWTJ_STRING_TYPE)

    say CryList.j.num || ' , ' || Crylist.j.type
                          
    if j=1 then
      REXXWRT.outLC = ',,,'||CryList.j.num||','||CryList.j.type
    else
      REXXWRT.outLC = REXXWRT.outLC||','||CryList.j.num||','||CryList.j.type

 end /* array entries */
 end /* Cryptos  */

 return 0 /* end function */

/*******************************************************/
/* Function: getAssignedDomains                        */
/*                                                     */
/* Retrieve content returned from the assigned crypto  */
/* domains value, which is an array of zero or more    */
/* objects.                                            */
/* Store the specific content into REXXWRT stem.       */
/*                                                     */
/* Return 0 if successful, otherwise return -1         */
/*******************************************************/
getAssignedDomains:
 ArrayResponse = arg(1)

 keyType = 'assigned-crypto-domains'

 /* First assess if this property was even found in the response */
 if foundJSONValue(ArrayResponse) = FALSE then
   do
     say '** Unable to locate '||keyType||' in the response **'
     return 0
   end

 /****************************************************************/
 /* Determine the number of items in the array                   */
 /****************************************************************/
 Domains = JSON_getArrayDim(ArrayResponse)
 if Domains = -1 then
    return fatalError( '** Unable to retrieve crypto domains **' )
 else if Domains = 0 then
    say '** Empty list of crypto domains returned **'

 /****************************************************************/
 /* Traverse the array to populate domains list                  */
 /****************************************************************/
 If Domains > 0 then do
   say 'Processing information for '||Domains||' crypto domains'
   say 'Index , Mode'
   outLC = outLC + 1
   REXXWRT.outLC = ',,,'||keyType||' (Domain Index & Access Mode Array)'
   outLC = outLC + 1
 drop DmnsList.
 DmnsList.0 = Domains
 do k = 1 to Domains
    nextEntryHandle = JSON_getArrayEntry(ArrayResponse,k-1)
    DmnsList.k.index=JSON_findValue2(nextEntryHandle,"domain-index")
    DmnsList.k.mode=JSON_findValue(nextEntryHandle,"access-mode",,
                        HWTJ_STRING_TYPE)

    say DmnsList.k.index || ' , ' || Dmnslist.k.mode
                          
    if k=1 then
      REXXWRT.outLC = ',,,'||DmnsList.k.index||','||DmnsList.k.mode
    else
      REXXWRT.outLC = REXXWRT.outLC||','||DmnsList.k.index||','||DmnsList.k.mode

 end /* array entries */
 end /* domains  */

 return 0 /* end function */

/*******************************************************/
/* Function:  GetRequest                               */
/*                                                     */
/* Default to GET all the cpcs if no args provided     */
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

call EntryArrow 
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
call ExitArrow 

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
/*        Say 'Response Body: (' || response.responsebody || ')' */
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

 /**************************************/
 /* Read the lines of the designated   */
 /* (constants) rexx source file into  */
 /* a stem variable...                 */
 /**************************************/
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
    say 'In JSON_findValue Invoke Json Search for 'searchName
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

      if resultType == 'HWTJ_STRING_TYPE' then
        say 'unexpected type: HWTJ_STRING_TYPE'
      else if resultType == 'HWTJ_NUMBER_TYPE' then
        say 'unexpected type: HWTJ_NUMBER_TYPE'
      else if resultType == 'HWTJ_BOOLEAN_TYPE' then
        say 'unexpected type: HWTJ_BOOLEAN_TYPE'
      else if resultType == 'HWTJ_ARRAY_TYPE' then
        say 'unexpected type: HWTJ_ARRAY_TYPE'
      else if resultType == 'HWTJ_OBJECT_TYPE' then
        say 'unexpected type: HWTJ_OBJECT_TYPE'
      else if resultType == HWTJ_NULL_TYPE then
       say 'unexpected type: HWTJ_NULL_TYPE'
      else
        say 'unexpected type: not recognized'

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

 /****************************************************/
 /* Return the located null value                    */
 /****************************************************/
 if resultType == HWTJ_NULL_TYPE then
    do
    if VERBOSE then
        say 'null value encountered'
    return '(null)'
    end /* endif null type */

 /**********************************************/
 /* This return should not occur, in practice. */
 /**********************************************/
 if VERBOSE then
    say '** No return value found **'
 return ''  /* end function */

/**********************************************************/
/* Function:  JSON_findValue2                             */
/*                                                        */
/* Return the value associated with the input name from   */
/* the designated Json object, via the various toolkit    */
/* api's { HWTJSRCH, HWTJGVAL, HWTJGBOV }, as appropriate.*/
/*                                                        */
/* To be used when the type is unknown and could be       */
/* either a string, number, boolean, or null.              */
/*                                                        */
/* Returns: The value of the designated entry in the      */
/* designated Json object, if found or suitable failure   */
/* string if not.                                         */
/**********************************************************/
JSON_findValue2:
 objectToSearch = arg(1)
 searchName = arg(2)

 /********************************************************/
 /* Search the specified object for the specified name   */
 /********************************************************/
 if VERBOSE then
    say 'In JSON_findValue2 Invoke Json Search for 'searchName
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

 /********************************************************/
 /* If the expected type is not a simple value, then the */
 /* search result is itself a handle to a nested object  */
 /* or array, and we simply return it as such.           */
 /********************************************************/
 if resultType == HWTJ_OBJECT_TYPE | resultType == HWTJ_ARRAY_TYPE then
    do
    say 'failed: result for '||searchName||' is object or array'
    return searchResult
    end /* endif object or array type */
 /*******************************************************/
 /* Return the located string or number, as appropriate */
 /*******************************************************/
 if resultType == HWTJ_STRING_TYPE | resultType == HWTJ_NUMBER_TYPE then
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
 if resultType == HWTJ_BOOLEAN_TYPE then
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

 /****************************************************/
 /* Return the located null value                    */
 /****************************************************/
 if resultType == HWTJ_NULL_TYPE then
    do
    if VERBOSE then
        say 'null value encountered'
    return '(null)'
    end /* endif null type */

 /**********************************************/
 /* This return should not occur, in practice. */
 /**********************************************/
 if VERBOSE then
    say '** No return value found **'
 return ''  /* end function */

/**********************************************************/
/* Function:  JSON_findValue3                             */
/*                                                        */
/* Return the value associated with the input name from   */
/* the designated Json object, via the various toolkit    */
/* api's { HWTJSRCH, HWTJGVAL}, as appropriate.           */
/*                                                        */
/* To be used when the type is could be either a number   */
/* or a NULL.                                             */
/*                                                        */
/* Returns: The value of the designated entry in the      */
/* designated Json object, if found or suitable failure   */
/* string if not.                                         */
/**********************************************************/
JSON_findValue3:
 objectToSearch = arg(1)
 searchName = arg(2)

 /********************************************************/
 /* Search the specified object for the specified name   */
 /********************************************************/
 if VERBOSE then
    say 'In JSON_findValue3 Invoke Json Search for 'searchName
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

 if resultType == HWTJ_NUMBER_TYPE then
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
    end /* endif number type */
 else if resultType == HWTJ_NULL_TYPE then
    do
       result = '(null)'
       return result
    end /* endif nulltype */
 else
    return fatalError( '** Unexpected entry type **' )

 return ''  /* end function - JSON_findValue3 */

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

/***********************************************************************/
/* Function:  GetArgs                                                  */
/*                                                                     */
/* Parse script arguments and make appropriate variable assignments    */
/* or return fatal error code via usage() invocation.                  */
/*    Required input parameters:                                       */
/*      -D <data set name> name of a pre-existing partitioned data set */
/*    Optional input parameters:                                       */
/*      -C <CPCname> name of the CPC to query, default is LOCAL CPC    */
/*      -S <Status> LPAR Status of the profiles to query,              */
/*         defaults to operating                                       */
/*      -I indicate running out of ISV REXX environment,               */
/*         default is TSO/E                                            */
/*      -V turn on additional verbose JSON tracing                     */       
/*                                                                     */
/* Returns: 0 if successful                                            */
/*          -1 if not successful                                       */
/***********************************************************************/
GetArgs:
 parmString = arg(1)
 argCount = words(parmString)

 /* require at least 2: -D <outputDataSet> */
 if argCount == 0 | argCount < 2 | argCount > 8 then
    return usage('Wrong number of arguments')

 dataSetProvided = FALSE
 i = 1
 do while i < (argCount + 1)
   localArg = word(parmString,i)
   if TRANSLATE(localArg) == '-I' then
     do /* -I for isvrexx */
       ISVREXX = TRUE
       i = i + 1
     end
   else if TRANSLATE(localArg) == '-V' then
     do /* -V for json verbose*/
       VERBOSE = TRUE
       i = i + 1
     end
  else if TRANSLATE(localArg) == '-C' then
    do /* -C <CPCName> */
      i = i + 1
      if i > argCount then
       return usage('-C option specified, but is missing CPC name')

      CPCname = word(parmString, i)
      localCPC = FALSE
      i = i + 1
    end
  else if TRANSLATE(localArg) == '-S' then
    do /* -S <Status> */
      i = i + 1
      if i > argCount then
       return usage('-S option specified, but is missing Status')

      ReqstdLPAR_Status = word(parmString, i)
      i = i + 1
    end
  else if TRANSLATE(localArg) == '-D' then
    do /* -D <data set name> */
      i = i + 1
      if i > argCount then
       return usage('-D option specified, but is missing the data set name')

      TEMP_DATASET = word(parmString, i)
      dataSetProvided = TRUE
      i = i + 1
    end
  else
    do
      errMsg = 'Found unsupported argument:'||localArg
      return usage(errMsg)
    end
 end /* while loop */

if dataSetProvided = FALSE then
  return usage ('Missing required data set name for output')

return 0  /* end function */

/***********************************************/
/* Function: VerifyStatus                      */
/*                                             */
/* Verify the requested LPAR status            */
/* If invalid, set it to 'operating'           */
/*                                             */
/* Returns: 0 if successful                    */
/*         -1 if not successful                */
/***********************************************/
VerifyStatus:

statusString = arg(1)
LPAR_STATUS_NOT_ACTIVATED = TRANSLATE('not-activated')
LPAR_STATUS_NOT_OPERATING = TRANSLATE('not-operating')
LPAR_STATUS_OPERATING = TRANSLATE('operating')

Select
 When TRANSLATE(statusString) = LPAR_STATUS_NOT_ACTIVATED
  then say 'LPAR status '||statusString||' will be used'
 When TRANSLATE(statusString) = LPAR_STATUS_NOT_OPERATING
  then say 'LPAR status '||statusString||' will be used'
 When TRANSLATE(statusString) = LPAR_STATUS_OPERATING
  then say 'LPAR status '||statusString||' will be used'
 OTHERWISE
  do
   call EntryArrow
   say 'Invalid LPAR status entered, default of operating will be used'
   ReqstdLPAR_Status = 'operating'
   call ExitArrow
  end
end

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
 say 'USAGE: RXCRYPT1 -D outputDataSet [-C CPCname] [-I] [-V]'
 say '    REQUIRED'
 say '         -D outputDataSet, name of an existing partitioned'
 say '               data set, if the LPAR query is successful, a member '
 say '               containing the query information in CSV format will '
 say '               be stored into the data set, the member will either '
 say '               be named LOCAL or the CPC name specified via -C option'
 say '    OPTIONAL'
 say '         -C CPCname, name of the CPC to query, default if'
 say '               not specified is the LOCAL CPC'
 say '         -S <Status> LPAR Status of the profiles to query,'
 say '               default if invalid or not specified is operating'
 say '         -I indicate running in an isv rexx, default if not'
 say '               specified is TSO/E REXX'
 say '         -V turn on additional verbose JSON tracing'
 say
 say 'ERROR DETAILS: ('||whyString||')'
 say

 return -1  /* end function */

/***********************************************/
/* Function:  PrepHdrRow()                     */
/*                                             */
/* Prime the header row (RXXWRT.1) for the     */
/* the csv file format data set member         */
/***********************************************/
PrepHdrRow:

if CryptoAttr.0 < 1 then
  do
    say 'FATAL error, no attributes to write out'
    return
  end

/* prep the header line in the CSV file */

REXXWRT.1 = MemberName||',LPAR Name,LPAR status,Attributes'                  

return  /* end function */

/***********************************************************************/
/* Function:  PrepCryptoAttrs()                                        */
/*                                                                     */
/* Generate CryptoAttr stem that contains the property names to be     */
/* retrieved for an LPAR.                                              */
/*                                                                     */
/* In the case where the property is a simple entity and the value     */
/* type is either a string, boolean, number set the '.0' suffix to 0.  */
/* For example, sysplex-name is a simple property that will return a   */
/* string, so you'd add the following for it:                          */
/*     CryptoAttr.attrI = 'sysplex-name'                               */
/*     CryptoAttr.attrI.0 = 0                                          */
/*                                                                     */
/* In the case where the property is a complex property and the value  */
/* type is an array of objects, set the '.0' suffix to 1.              */
/* Also you must add explicit support to the QueryCrypto() routine     */
/* to account for whatever values you will derive and store from the   */
/* complex property.                                                   */
/*                                                                     */
/***********************************************************************/
PrepCryptoAttrs:

drop CryptoAttr.

attrI = 1
CryptoAttr.attrI = 'crypto-activity-cpu-counter-authorization-control'
CryptoAttr.attrI.0 = 0
attrI = attrI + 1
CryptoAttr.attrI = 'assigned-crypto-domains'
CryptoAttr.attrI.0 = 1
attrI = attrI + 1
CryptoAttr.attrI = 'assigned-cryptos'
CryptoAttr.attrI.0 = 1

/* total number of LPAR attributes to query
   NOTE: this is not the total number of properties in the csv file
         because each complex property may result in one or more
         properties
*/
CryptoAttr.0 = attrI

return  /* end function */

/*************************************************/
/* Function:  foundJSONvalue()                   */
/* Return true if the content is not empty       */
/*************************************************/
foundJSONValue:
parse arg jsonValueArg

if jsonValueArg = '' | jsonValueArg = '(not found)' then
  return FALSE

return TRUE

/*************************************************/
/* Function:  EntryArrow                         */
/* Print entry arrow '--------------->'          */
/*************************************************/
EntryArrow:
say
say '--------------->'
return

/*************************************************/
/* Function:  ExitArrow                          */
/* Print entry arrow '<---------------'          */
/*************************************************/
ExitArrow:
say '<---------------'
say
return

/*************************************************/
/* Function:  WriteToFile()                      */
/* This will write out the REXXWRT stem contents */
/*************************************************/
WriteToFile:
parse arg file

rc = 0
if ISVREXX then
  do
    "ALLOC F(MYOUTD) DSN("||file||") SHR"
    Address MVS "EXECIO * DISKW MYOUTD (STEM REXXWRT. FINIS"
    return_code = RC
    "FREE F(MYOUTD)"
  end
else
  do
    Address TSO
    "ALLOC F(MYOUTD) DSN("||file||") SHR REU"
    "EXECIO * DISKW MYOUTD (STEM REXXWRT. FINIS"
    return_code = RC
    "FREE F(MYOUTD)"
  end

RC = return_code

if RC <> 0 then
  do
    errMsg = '** fatal error, rc=('||RC,
             ||') encountered trying to write out content **'
    return fatalError(errMsg)
  end

return  rc /* end function */

/*************************************************/
/* Function:  VerifyDataSet()                    */
/*                                               */
/* Verify the data set identified by the         */
/* userDataSet argument exists.                  */
/*                                               */
/* Return 0 if data set exists,                  */
/* Otherwise return a non zero                   */
/*************************************************/
VerifyDataSet:
parse arg userDataSet

dsAvailable = ''
rc = 0
if ISVREXX then
  do
    "ALLOC F(MYOUTD) DSN("||userDataSet||") SHR"
    if rc <> 0 then
      do
        say '** fatal error, attempt to verify ('||,
            userDataSet||') exists using ALLOC '||,
            'resulted in ('||rc||')'
      end
    else
      do
        "FREE F(MYOUTD)"
      end
  end
else
  do
    dsAvailable = SYSDSN("'"userDataSet"'")
    if dsAvailable <> "OK" then
      do
        errMsg = '** fatal error, attempt to verify ('||,
                 userDataSet||') exists resulted in ('||dsAvailable||')'
        return fatalError(errMsg)
      end
  end
return  rc /* end function */